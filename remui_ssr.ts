import type { NextFunction, Request, RequestHandler, Response } from 'express';
import type { JsonNode, JsonValue, UiMetadataState } from './remui';

const UI_METADATA_SYMBOL = Symbol.for('remui.ui.metadata');
const REMUI_FLUTTER_USER_AGENT = 'RemUI-Flutter/1.0';

type SsrPayload = Record<string, JsonValue>;
type SsrMetaBucket = {
  title?: string;
  entries: Array<{ name: string; content: string }>;
};

// ─── Type guards ──────────────────────────────────────────────────────────────

function isObject(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}

function isWidgetNode(value: unknown): value is JsonNode {
  return isObject(value) && typeof value.type === 'string';
}

// ─── HTML escaping ────────────────────────────────────────────────────────────

function escapeHtml(value: unknown): string {
  return String(value)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');
}

function escapeScript(value: string): string {
  return value.replace(/</g, '\\u003c').replace(/>/g, '\\u003e');
}

// ─── Variable interpolation ───────────────────────────────────────────────────

function interpolateText(input: string, vars: Record<string, unknown>): string {
  return input.replace(/\{([^}]+)\}/g, (_match, rawPath: string) => {
    const key = rawPath.trim();
    const value = key.split('.').reduce<unknown>((current, segment) => {
      if (!isObject(current)) return undefined;
      return current[segment];
    }, vars);
    if (value === undefined || value === null) return 'unknown';
    if (Array.isArray(value)) return value.map((item) => String(item)).join(', ');
    return String(value);
  });
}

// ─── Metadata helpers ─────────────────────────────────────────────────────────

function readMetadata(node: JsonNode | undefined | null): UiMetadataState | undefined {
  if (!node || typeof node !== 'object') return undefined;
  return (node as Record<PropertyKey, unknown>)[UI_METADATA_SYMBOL] as UiMetadataState | undefined;
}

function collectMetaBuckets(value: unknown, bucket: SsrMetaBucket): void {
  if (!isWidgetNode(value)) {
    if (Array.isArray(value)) {
      for (const item of value) collectMetaBuckets(item, bucket);
    } else if (isObject(value)) {
      for (const nested of Object.values(value)) collectMetaBuckets(nested, bucket);
    }
    return;
  }
  const metadata = readMetadata(value);
  if (metadata) {
    for (const entry of metadata.meta) {
      const name = entry.name.trim().toLowerCase();
      const content = escapeHtml(resolvePrimitive(entry.content, {}));
      if (name === 'title') bucket.title = content;
      else if (name) bucket.entries.push({ name, content });
    }
  }
  for (const nested of Object.values(value)) {
    if (typeof nested === 'function') continue;
    collectMetaBuckets(nested, bucket);
  }
}

// ─── Color resolution (matches Flutter's Resolv.color) ────────────────────────

const NAMED_COLORS: Record<string, string> = {
  transparent: 'transparent',
  black: '#000000',
  white: '#ffffff',
  red: '#f44336',
  pink: '#e91e63',
  purple: '#9c27b0',
  deeppurple: '#673ab7',
  indigo: '#3f51b5',
  blue: '#2196f3',
  lightblue: '#03a9f4',
  cyan: '#00bcd4',
  teal: '#009688',
  green: '#4caf50',
  lightgreen: '#8bc34a',
  lime: '#cddc39',
  yellow: '#ffeb3b',
  amber: '#ffc107',
  orange: '#ff9800',
  deeporange: '#ff5722',
  brown: '#795548',
  grey: '#9e9e9e',
  bluegrey: '#607d8b',
};

// Material Design 3 default light theme colors
const THEME_COLORS: Record<string, string> = {
  primary: '#6750a4',
  onprimary: '#ffffff',
  primarycontainer: '#eaddff',
  onprimarycontainer: '#21005d',
  secondary: '#625b71',
  onsecondary: '#ffffff',
  secondarycontainer: '#e8def8',
  onsecondarycontainer: '#1d192b',
  tertiary: '#7d5260',
  ontertiary: '#ffffff',
  tertiarycontainer: '#ffd8e4',
  ontertiarycontainer: '#31111d',
  error: '#b3261e',
  onerror: '#ffffff',
  errorcontainer: '#f9dedc',
  onerrorcontainer: '#410e0b',
  surface: '#fffbfe',
  onsurface: '#1c1b1f',
  surfacevariant: '#e7e0ec',
  onsurfacevariant: '#49454f',
  outline: '#79747e',
  outlinevariant: '#cac4d0',
  shadow: '#000000',
  scrim: '#000000',
  inverseprimary: '#d0bcff',
  inversesurface: '#313033',
  oninversesurface: '#f4eff4',
};

function resolveColor(value: JsonValue | undefined): string | undefined {
  if (value === undefined || value === null) return undefined;
  const raw = String(value).trim();
  if (!raw) return undefined;

  // CSS hex — pass through (#RGB, #RGBA, #RRGGBB, #RRGGBBAA)
  if (raw.startsWith('#')) return raw;

  const token = raw.toLowerCase()
    .replace('color.', '')
    .replace('theme:', '')
    .replace('scheme.', '')
    .replace(/\s/g, '');

  if (token in NAMED_COLORS) return NAMED_COLORS[token]!;
  if (token in THEME_COLORS) return THEME_COLORS[token]!;

  // Bare hex like 0xFF6750A4 (Flutter ARGB int format → CSS rgba)
  const ffHex = token.match(/^0xff([0-9a-f]{6})$/i);
  if (ffHex) return `#${ffHex[1]}`;
  const argbHex = token.match(/^0x([0-9a-f]{2})([0-9a-f]{6})$/i);
  if (argbHex) {
    const alpha = parseInt(argbHex[1]!, 16) / 255;
    const r = parseInt(argbHex[2]!.slice(0, 2), 16);
    const g = parseInt(argbHex[2]!.slice(2, 4), 16);
    const b = parseInt(argbHex[2]!.slice(4, 6), 16);
    return `rgba(${r},${g},${b},${alpha.toFixed(3)})`;
  }

  return undefined;
}

// ─── Flex alignment (matches Flutter's Resolv.resolvMainAxis / resolveCrossAxis) ─

function resolveMainAxisCSS(value: JsonValue | undefined, fallback = 'flex-start'): string {
  const raw = String(value ?? '').toLowerCase().replace(/\s/g, '');
  switch (raw) {
    case 'start': return 'flex-start';
    case 'end': return 'flex-end';
    case 'center': return 'center';
    case 'spacebetween': case 'between': return 'space-between';
    case 'spacearound': case 'around': return 'space-around';
    case 'spaceevenly': case 'evenly': return 'space-evenly';
    default: return fallback;
  }
}

function resolveCrossAxisCSS(value: JsonValue | undefined, fallback = 'center'): string {
  const raw = String(value ?? '').toLowerCase().replace(/\s/g, '');
  switch (raw) {
    case 'start': return 'flex-start';
    case 'end': return 'flex-end';
    case 'center': return 'center';
    case 'stretch': return 'stretch';
    case 'baseline': return 'baseline';
    default: return fallback;
  }
}

// ─── Font weight (matches Flutter's Resolv.fontWeight) ────────────────────────

const FONT_WEIGHT_MAP: Record<string, string> = {
  thin: '100', w100: '100', '100': '100',
  extralight: '200', ultralight: '200', w200: '200', '200': '200',
  light: '300', w300: '300', '300': '300',
  normal: '400', regular: '400', w400: '400', '400': '400',
  medium: '500', w500: '500', '500': '500',
  semibold: '600', demibold: '600', w600: '600', '600': '600',
  bold: '700', w700: '700', '700': '700',
  extrabold: '800', ultrabold: '800', w800: '800', '800': '800',
  black: '900', heavy: '900', w900: '900', '900': '900',
};

function resolveFontWeightCSS(value: JsonValue | undefined): string | undefined {
  if (value === undefined || value === null) return undefined;
  return FONT_WEIGHT_MAP[String(value).toLowerCase().trim()];
}

// ─── CSS style attribute builder ──────────────────────────────────────────────

function buildStyle(styles: Record<string, string | number | undefined>): string {
  return Object.entries(styles)
    .filter(([, v]) => v !== undefined && v !== '')
    .map(([k, v]) => `${k}:${v}`)
    .join(';');
}

// ─── Icon content (renders as Material Icons ligature, Unicode codepoint, image, or widget) ──

function renderIconHtml(iconValue: unknown, sizeStyle = '', colorStyle = ''): string {
  // Widget node — render it directly (e.g. ui('Icon', {...}) or ui('Image', {...}))
  if (isWidgetNode(iconValue)) {
    return renderNode(iconValue, {});
  }

  if (iconValue === undefined || iconValue === null) return '';
  const raw = String(iconValue).trim();
  if (!raw) return '';

  // Remote image URL → <img>
  const lc = raw.toLowerCase();
  if (lc.startsWith('http://') || lc.startsWith('https://')) {
    const imgStyle = buildStyle({ width: sizeStyle || '24px', height: sizeStyle || '24px', 'object-fit': 'contain' });
    if (lc.endsWith('.svg')) {
      return `<img src="${escapeHtml(raw)}" style="${escapeHtml(imgStyle)}" aria-hidden="true" />`;
    }
    return `<img src="${escapeHtml(raw)}" style="${escapeHtml(imgStyle)}" aria-hidden="true" />`;
  }

  // Strip m: prefix
  const token = raw.startsWith('m:') || raw.startsWith('M:') ? raw.slice(2).trim() : raw;

  // Hex codepoints: 0xE145, U+E145, #E145, or bare 4–5 hex digits like E145
  const hexMatch = token.match(/^(?:0x|0X|[uU]\+|#)?([0-9a-fA-F]{4,5})$/);
  if (hexMatch) {
    const cp = parseInt(hexMatch[1]!, 16);
    const char = String.fromCodePoint(cp);
    const style = buildStyle({ 'font-size': sizeStyle, color: colorStyle });
    return `<span class="material-icons" style="${escapeHtml(style)}" aria-hidden="true">${char}</span>`;
  }

  // Treat as ligature name (e.g. "home", "settings")
  const style = buildStyle({ 'font-size': sizeStyle, color: colorStyle });
  return `<span class="material-icons" style="${escapeHtml(style)}" aria-hidden="true">${escapeHtml(token)}</span>`;
}

// ─── Action data ──────────────────────────────────────────────────────────────

function renderActionAttr(node: JsonNode): string {
  const action = node.action ?? node.onPressed ?? node.onClick;
  if (action === undefined) return '';
  return ` data-remui-action="${escapeHtml(JSON.stringify(action))}"`;
}

// ─── Primitive / value renderers ──────────────────────────────────────────────

function resolvePrimitive(value: JsonValue | undefined, vars: Record<string, unknown>): string {
  if (value === undefined || value === null) return '';
  if (typeof value === 'string') return interpolateText(value, vars);
  if (typeof value === 'number' || typeof value === 'boolean') return String(value);
  if (Array.isArray(value)) return value.map((item) => resolvePrimitive(item as JsonValue, vars)).join(', ');
  if (isWidgetNode(value)) return renderNode(value, vars);
  return escapeHtml(JSON.stringify(value));
}

function renderChildren(value: unknown, vars: Record<string, unknown>): string {
  if (value === undefined || value === null) return '';
  if (Array.isArray(value)) return value.map((item) => renderValue(item, vars)).join('');
  return renderValue(value, vars);
}

function renderObjectFallback(value: Record<string, unknown>, vars: Record<string, unknown>): string {
  const entries = Object.entries(value).filter(([, nested]) => nested !== undefined && nested !== null);
  if (entries.length === 0) return '';
  const rendered = entries
    .map(([key, nested]) => `
      <div class="rounded-xl border border-slate-200 bg-white p-3 shadow-sm">
        <div class="mb-2 text-[11px] font-semibold uppercase tracking-widest text-slate-500">${escapeHtml(key)}</div>
        <div>${renderValue(nested, vars)}</div>
      </div>`)
    .join('');
  return `<div class="grid gap-3 md:grid-cols-2">${rendered}</div>`;
}

function renderValue(value: unknown, vars: Record<string, unknown>): string {
  if (value === undefined || value === null) return '';
  if (typeof value === 'string') return escapeHtml(interpolateText(value, vars));
  if (typeof value === 'number' || typeof value === 'boolean') return escapeHtml(value);
  if (Array.isArray(value)) return value.map((item) => renderValue(item, vars)).join('');
  if (!isWidgetNode(value)) {
    if (isObject(value)) return renderObjectFallback(value, vars);
    return escapeHtml(String(value));
  }
  return renderNode(value, vars);
}

// ─── condition node ───────────────────────────────────────────────────────────

function renderConditionNode(node: JsonNode, vars: Record<string, unknown>): string {
  const varName = node.var?.toString() ?? '';
  const expected = resolvePrimitive(node.eq, vars);
  const current = vars[varName];
  const matches = String(current ?? '') === String(expected ?? '');
  if (matches) return renderChildren(node.child, vars);
  if (node.elseIf && isWidgetNode(node.elseIf)) return renderNode(node.elseIf, vars);
  return '';
}

// ─── TextField shell ──────────────────────────────────────────────────────────

function renderFieldShell(node: JsonNode, inner: string): string {
  const metadata = readMetadata(node);
  const labelText = metadata?.alt ?? node.labelText?.toString() ?? node.label?.toString() ?? '';
  const hintText = node.hintText?.toString() ?? '';
  return `
    <div class="w-full max-w-full">
      ${labelText ? `<div class="mb-1 text-sm font-semibold text-slate-800">${escapeHtml(labelText)}</div>` : ''}
      ${hintText ? `<div class="mb-1 text-xs text-slate-500">${escapeHtml(hintText)}</div>` : ''}
      ${inner}
    </div>`;
}

// ─── Tabs ─────────────────────────────────────────────────────────────────────

function renderTabsNode(node: JsonNode, vars: Record<string, unknown>): string {
  const tabs = (Array.isArray(node.tabs) ? node.tabs : Array.isArray(node.items) ? node.items : []) as JsonNode[];
  if (tabs.length === 0) return '';

  const views = (Array.isArray(node.children) ? node.children : Array.isArray(node.views) ? node.views : []) as unknown[];
  const variableName = node.variable?.toString() ?? '';
  const fromVar = variableName ? vars[variableName] : undefined;
  const initialIdx = Math.max(0, Math.min(tabs.length - 1,
    fromVar !== undefined ? (parseInt(String(fromVar), 10) || 0)
    : typeof node.currentIndex === 'number' ? node.currentIndex
    : typeof node.selectedIndex === 'number' ? node.selectedIndex
    : 0));

  const indicatorColor = resolveColor(node.indicatorColor) ?? '#6750a4';
  const labelColor = resolveColor(node.labelColor) ?? '#1c1b1f';
  const unselectedColor = resolveColor(node.unselectedLabelColor) ?? '#49454f';

  const tabButtons = tabs.map((tab, i) => {
    const isActive = i === initialIdx;
    const label = tab.label?.toString() ?? tab.text?.toString() ?? '';
    const iconHtml = tab.icon ? renderValue(tab.icon, vars) : '';
    const style = buildStyle({
      color: isActive ? labelColor : unselectedColor,
      'border-bottom': isActive ? `2px solid ${indicatorColor}` : '2px solid transparent',
    });
    return `<button type="button"
      class="remui-tab-btn flex items-center gap-1 px-3 py-2 text-sm font-semibold transition-colors cursor-pointer whitespace-nowrap"
      style="${escapeHtml(style)}"
      data-tab-index="${i}"
      data-remui-var="${escapeHtml(variableName)}"
      role="tab" aria-selected="${isActive}">${iconHtml}${escapeHtml(label)}</button>`;
  }).join('');

  const panels = tabs.map((_, i) => {
    const viewContent = i < views.length ? renderValue(views[i], vars) : '';
    return `<div class="remui-tab-panel${i === initialIdx ? '' : ' hidden'}" data-tab-panel="${i}" role="tabpanel" style="${i !== initialIdx ? 'display:none' : ''}">${viewContent}</div>`;
  }).join('');

  const heightStyle = node.height != null ? `height:${Number(node.height)}px` : '';
  const tabBarOnly = node.tabBarOnly === true;
  return `<div class="remui-tabs flex flex-col w-full"
    data-remui-tabs="${escapeHtml(variableName)}"
    data-tab-indicator="${escapeHtml(indicatorColor)}"
    data-tab-label="${escapeHtml(labelColor)}"
    data-tab-unselected="${escapeHtml(unselectedColor)}"
    style="${heightStyle}">
    <div class="flex overflow-x-auto border-b border-slate-200" role="tablist">${tabButtons}</div>
    ${tabBarOnly ? '' : `<div class="flex-1 overflow-auto">${panels}</div>`}
  </div>`;
}

// ─── RemNavbar ────────────────────────────────────────────────────────────────

function renderRemNavbar(node: JsonNode, vars: Record<string, unknown>): string {
  const bgColor = resolveColor(node.backgroundColor) ?? '#ffffff';
  const borderColor = resolveColor(node.borderColor) ?? '#e2e8f0';
  const titleColor = resolveColor(node.titleColor) ?? '#111827';
  const title = node.title != null ? (isWidgetNode(node.title) ? renderNode(node.title, vars) : `<span style="color:${escapeHtml(titleColor)};font-weight:700;font-size:15px">${escapeHtml(String(node.title))}</span>`) : '';
  const logo = isWidgetNode(node.logo) ? `<div style="width:34px;height:34px;flex-shrink:0">${renderNode(node.logo, vars)}</div>` : '';

  const dropdownEntries = Array.isArray(node.dropdowns) ? node.dropdowns as JsonNode[] : [];
  const navLinks = dropdownEntries.map((entry) => {
    const label = (entry.name ?? entry.label ?? '').toString();
    const actionAttr = renderActionAttr(entry);
    return `<a href="#" class="px-3 py-1.5 text-sm font-medium rounded-lg hover:bg-slate-100 transition-colors" style="color:${escapeHtml(titleColor)}" ${actionAttr}>${escapeHtml(label)}</a>`;
  }).join('');

  const searchNode = isWidgetNode(node.searchTextField) ? renderNode(node.searchTextField, vars) : '';

  const style = buildStyle({ background: bgColor, 'border-bottom': `1px solid ${borderColor}` });
  return `<header class="sticky top-0 z-30 w-full" style="${escapeHtml(style)}">
    <div class="mx-auto flex items-center gap-3 px-4 py-2 max-w-7xl">
      ${logo}${title}
      <nav class="hidden md:flex items-center gap-1 ml-2">${navLinks}</nav>
      <div class="flex-1"></div>
      ${searchNode ? `<div class="w-64">${searchNode}</div>` : ''}
    </div>
  </header>`;
}

// ─── RemBottomNavbar ──────────────────────────────────────────────────────────

function renderRemBottomNavbar(node: JsonNode, vars: Record<string, unknown>): string {
  const items = Array.isArray(node.items) ? node.items as JsonNode[] : [];
  const varName = node.variable?.toString() ?? '';
  const fromVar = varName ? vars[varName] : undefined;
  const initialIdx = fromVar !== undefined ? (parseInt(String(fromVar), 10) || 0)
    : typeof node.currentIndex === 'number' ? node.currentIndex : 0;
  const selectedIdx = Math.max(0, Math.min(items.length - 1, initialIdx));

  const activeColor = resolveColor(node.activeColor) ?? '#0d47a1';
  const inactiveColor = resolveColor(node.noActiveColor ?? node.inactiveColor) ?? '#64748b';
  const bgColor = resolveColor(node.backgroundColor) ?? '#ffffff';
  const borderColor = resolveColor(node.borderColor) ?? '#e2e8f0';
  const height = typeof node.height === 'number' ? node.height : 72;

  const itemsHtml = items.map((item, i) => {
    const isActive = i === selectedIdx;
    const label = item.label?.toString() ?? '';
    const iconHtml = renderIconHtml(item.icon, '22px', isActive ? activeColor : inactiveColor);
    const labelStyle = buildStyle({ color: isActive ? activeColor : inactiveColor, 'font-weight': isActive ? '700' : '500', 'font-size': '12px' });
    const action = renderActionAttr(item);
    const activeBg = resolveColor(node.activeBackgroundColor) ?? '#dbeafe';
    const bgStyle = isActive ? `background:${activeBg}` : '';
    return `<button type="button" class="flex flex-col items-center justify-center px-3.5 py-2.5 rounded-2xl transition-colors cursor-pointer border-0 bg-transparent" style="${escapeHtml(bgStyle)}" data-remui-nav-idx="${i}" data-remui-var="${escapeHtml(varName)}" ${action}>
      ${iconHtml}
      <span style="${escapeHtml(labelStyle)}">${escapeHtml(label)}</span>
    </button>`;
  }).join('');

  const style = buildStyle({ background: bgColor, 'border-top': `1px solid ${borderColor}`, height: `${height}px` });
  return `<footer class="w-full flex items-center overflow-x-auto px-3" style="${escapeHtml(style)}">${itemsHtml}</footer>`;
}

// ─── BottomNavigationBar ──────────────────────────────────────────────────────

function renderBottomNavBar(node: JsonNode, vars: Record<string, unknown>): string {
  const items = Array.isArray(node.items) ? node.items as JsonNode[] : [];
  const varName = node.variable?.toString() ?? '';
  const fromVar = varName ? vars[varName] : undefined;
  const initialIdx = typeof node.currentIndex === 'number' ? node.currentIndex : 0;
  const selectedIdx = Math.max(0, Math.min(items.length - 1,
    fromVar !== undefined ? (parseInt(String(fromVar), 10) || 0) : initialIdx));

  const itemsHtml = items.map((item, i) => {
    const isActive = i === selectedIdx;
    const label = item.label?.toString() ?? '';
    const iconWidget = item.icon;
    const iconHtml = isWidgetNode(iconWidget) ? renderNode(iconWidget, vars) : renderIconHtml(iconWidget, '24px');
    const action = renderActionAttr(item);
    const cls = isActive
      ? 'flex flex-col items-center gap-1 px-4 py-2 text-blue-600 cursor-pointer'
      : 'flex flex-col items-center gap-1 px-4 py-2 text-slate-500 cursor-pointer';
    return `<button type="button" class="${cls}" data-remui-nav-idx="${i}" data-remui-var="${escapeHtml(varName)}" ${action}>
      ${iconHtml}
      <span class="text-xs font-medium">${escapeHtml(label)}</span>
    </button>`;
  }).join('');

  return `<nav class="flex w-full border-t border-slate-200 bg-white">${itemsHtml}</nav>`;
}

// ─── Sidebar ──────────────────────────────────────────────────────────────────

function renderSidebarNode(node: JsonNode, vars: Record<string, unknown>): string {
  const items = Array.isArray(node.items) ? node.items as JsonNode[] : [];
  const varName = node.variable?.toString() ?? '';
  const fromVar = varName ? vars[varName] : undefined;
  const initialIdx = typeof node.currentIndex === 'number' ? node.currentIndex : 0;
  const selectedIdx = Math.max(0, Math.min(items.length - 1,
    fromVar !== undefined ? (parseInt(String(fromVar), 10) || 0) : initialIdx));

  const bgColor = resolveColor(node.color) ?? '#f8faff';
  const accentColor = resolveColor(node.accentColor) ?? '#2454ff';
  const textColor = resolveColor(node.textColor) ?? '#1a1f36';
  const width = typeof node.width === 'number' ? node.width : 272;

  const headerTitle = node.title?.toString() ?? '';
  const headerSubtitle = node.subtitle?.toString() ?? '';
  const showHeader = node.showHeader !== false;
  const headerWidget = isWidgetNode(node.header) ? renderNode(node.header, vars) : null;

  const headerHtml = showHeader ? `
    <div class="px-4 pt-4 pb-3">
      ${headerWidget ?? `
        <div class="flex items-center gap-3">
          <div class="w-10 h-10 rounded-xl flex items-center justify-center" style="background:${resolveColor(accentColor) ?? accentColor}22">
            ${renderIconHtml(node.headerIcon ?? 'dashboard', '22px', accentColor)}
          </div>
          <div>
            <div class="font-bold text-base" style="color:${escapeHtml(textColor)}">${escapeHtml(headerTitle)}</div>
            ${headerSubtitle ? `<div class="text-xs" style="color:${escapeHtml(textColor)}99">${escapeHtml(headerSubtitle)}</div>` : ''}
          </div>
        </div>
      `}
    </div>
    <div class="border-b" style="border-color:${escapeHtml(textColor)}2e"></div>` : '';

  const itemsHtml = items.map((item, i) => {
    const isActive = i === selectedIdx;
    const label = item.label?.toString() ?? '';
    const subtitle = item.subtitle?.toString() ?? '';
    const badge = item.badge;
    const action = renderActionAttr(item);
    const iconHtml = renderIconHtml(item.icon, '20px', isActive ? '#ffffff' : accentColor);
    const bg = isActive ? `background:linear-gradient(to right, ${accentColor}, ${accentColor}d0)` : `background:white;border:1px solid ${textColor}2e`;
    const labelStyle = `color:${isActive ? '#ffffff' : textColor};font-weight:600;font-size:14px`;
    const subtitleStyle = `color:${isActive ? '#ffffffaa' : `${textColor}80`};font-size:12px`;
    return `<div class="rounded-2xl px-3 py-2.5 flex items-center gap-3 cursor-pointer mb-2" style="${escapeHtml(bg)}" data-remui-nav-idx="${i}" data-remui-var="${escapeHtml(varName)}" ${action}>
      <div class="w-8 h-8 rounded-xl flex items-center justify-center flex-shrink-0 overflow-hidden" style="background:${isActive ? 'rgba(255,255,255,0.2)' : `${accentColor}18`}">${iconHtml}</div>
      <div class="flex-1 min-w-0">
        <div style="${escapeHtml(labelStyle)}">${escapeHtml(label)}</div>
        ${subtitle ? `<div style="${escapeHtml(subtitleStyle)}">${escapeHtml(subtitle)}</div>` : ''}
      </div>
      ${badge != null ? `<span class="text-xs font-bold px-2 py-0.5 rounded-full" style="background:${isActive ? 'rgba(255,255,255,0.24)' : `${accentColor}20`};color:${isActive ? '#fff' : accentColor}">${escapeHtml(String(badge))}</span>` : ''}
    </div>`;
  }).join('');

  const style = buildStyle({ background: bgColor, width: `${width}px`, 'min-width': `${width}px` });
  return `<nav class="flex flex-col h-full overflow-y-auto" style="${escapeHtml(style)}">
    ${headerHtml}
    <div class="flex-1 overflow-y-auto px-3 py-3">${itemsHtml}</div>
    ${isWidgetNode(node.footer) ? `<div class="px-4 py-3 border-t" style="border-color:${escapeHtml(textColor)}2e">${renderNode(node.footer as JsonNode, vars)}</div>` : ''}
  </nav>`;
}

// ─── NavigationRail ───────────────────────────────────────────────────────────

function renderNavigationRail(node: JsonNode, vars: Record<string, unknown>): string {
  const destinations = Array.isArray(node.destinations) ? node.destinations as JsonNode[]
    : Array.isArray(node.items) ? node.items as JsonNode[] : [];
  const varName = node.variable?.toString() ?? '';
  const fromVar = varName ? vars[varName] : undefined;
  const initialIdx = typeof node.selectedIndex === 'number' ? node.selectedIndex : 0;
  const selectedIdx = Math.max(0, Math.min(destinations.length - 1,
    fromVar !== undefined ? (parseInt(String(fromVar), 10) || 0) : initialIdx));

  const bgColor = resolveColor(node.backgroundColor) ?? 'transparent';
  const accentColor = resolveColor(node.indicatorColor) ?? '#eaddff';
  const selectedIconColor = resolveColor(node.selectedIconColor) ?? '#21005d';
  const unselectedIconColor = resolveColor(node.unselectedIconColor) ?? '#49454f';

  const itemsHtml = destinations.map((dest, i) => {
    const isActive = i === selectedIdx;
    const label = dest.label?.toString() ?? '';
    const iconHtml = renderIconHtml(dest.icon, '24px', isActive ? selectedIconColor : unselectedIconColor);
    const action = renderActionAttr(dest);
    const bg = isActive ? `background:${accentColor}` : '';
    return `<div class="flex flex-col items-center gap-1 py-2 px-3 rounded-2xl cursor-pointer" style="${escapeHtml(bg)}" data-remui-nav-idx="${i}" data-remui-var="${escapeHtml(varName)}" ${action}>
      ${iconHtml}
      <span class="text-xs" style="color:${isActive ? escapeHtml(selectedIconColor) : escapeHtml(unselectedIconColor)};font-weight:${isActive ? '700' : '500'}">${escapeHtml(label)}</span>
    </div>`;
  }).join('');

  const minWidth = typeof node.minWidth === 'number' ? node.minWidth : 72;
  const style = buildStyle({ background: bgColor, 'min-width': `${minWidth}px`, width: `${minWidth}px` });
  return `<nav class="flex flex-col items-center py-4 gap-1 h-full" style="${escapeHtml(style)}">${itemsHtml}</nav>`;
}

// ─── Main widget body renderer ────────────────────────────────────────────────

function renderWidgetBody(node: JsonNode, vars: Record<string, unknown>): string {
  const metadata = readMetadata(node);
  const actionAttr = renderActionAttr(node);
  const ariaLabel = metadata?.alt ? ` aria-label="${escapeHtml(metadata.alt)}"` : '';
  const dataType = ` data-remui-type="${escapeHtml(node.type)}"`;

  // ── Text ───────────────────────────────────────────────────────────────────
  if (node.type === 'Text') {
    const text = interpolateText(node.text?.toString() ?? '', vars);
    const color = resolveColor(node.color);
    const fontSize = node.fontSize != null ? `${Number(node.fontSize)}px` : undefined;
    const fontWeight = resolveFontWeightCSS(node.fontWeight);
    const overflowMap: Record<string, string> = { ellipsis: 'ellipsis', clip: 'clip', fade: 'clip', visible: 'unset' };
    const overflow = node.overflow ? overflowMap[String(node.overflow)] : undefined;
    const style = buildStyle({ color, 'font-size': fontSize, 'font-weight': fontWeight, 'text-overflow': overflow, overflow: overflow ? 'hidden' : undefined, 'white-space': overflow ? 'nowrap' : 'pre-wrap' });
    const hasAction = node.action != null || node.onClick != null || node.onPressed != null;
    const tag = hasAction ? 'span' : 'span';
    const cursor = hasAction ? 'cursor:pointer;' : '';
    return `<${tag}${dataType}${ariaLabel}${actionAttr} style="${escapeHtml(cursor + style)}">${escapeHtml(text)}</${tag}>`;
  }

  // ── Icon ───────────────────────────────────────────────────────────────────
  if (node.type === 'Icon') {
    const size = node.size != null ? `${Number(node.size)}px` : '24px';
    const color = resolveColor(node.color) ?? '#1c1b1f';
    return `<span${dataType}${ariaLabel}${actionAttr}>${renderIconHtml(node.icon, size, color)}</span>`;
  }

  // ── IconButton ─────────────────────────────────────────────────────────────
  if (node.type === 'IconButton') {
    const iconHtml = isWidgetNode(node.icon) ? renderNode(node.icon, vars) : renderIconHtml(node.icon, '24px');
    return `<button type="button"${dataType}${ariaLabel}${actionAttr} class="inline-flex items-center justify-center w-10 h-10 rounded-full hover:bg-slate-100 transition-colors border-0 bg-transparent cursor-pointer">${iconHtml}</button>`;
  }

  // ── Image ──────────────────────────────────────────────────────────────────
  if (node.type === 'Image') {
    const src = node.src?.toString() ?? node.imageUrl?.toString() ?? '';
    const w = node.width != null ? `width:${Number(node.width)}px;` : '';
    const h = node.height != null ? `height:${Number(node.height)}px;` : '';
    return `<img${dataType}${ariaLabel}${actionAttr} src="${escapeHtml(src)}" alt="${escapeHtml(metadata?.alt ?? node.alt?.toString() ?? '')}" class="rounded-2xl object-cover" style="${escapeHtml(w + h)}" />`;
  }

  // ── TextField ──────────────────────────────────────────────────────────────
  if (node.type === 'TextField') {
    const variableName = node.variable?.toString() ?? '';
    const currentValue = variableName ? vars[variableName] : node.text;
    const inputType = String(node.keyboardType ?? '').toLowerCase() === 'multiline' ? 'textarea' : 'input';
    const type = node.obscureText === true ? 'password' : 'text';
    const placeholder = node.hintText?.toString() ?? '';
    const name = variableName || undefined;
    const enabled = node.enabled !== false;
    const cls = 'w-full rounded-xl border border-slate-200 bg-slate-50 px-3 py-2.5 text-sm text-slate-900 outline-none transition placeholder:text-slate-400 focus:border-purple-500 focus:bg-white disabled:opacity-50';
    if (inputType === 'textarea') {
      return renderFieldShell(node, `<textarea${dataType}${actionAttr} name="${escapeHtml(name ?? '')}" placeholder="${escapeHtml(placeholder)}" data-remui-var="${escapeHtml(variableName)}" class="${cls} min-h-28"${enabled ? '' : ' disabled'}>${escapeHtml(interpolateText(currentValue?.toString() ?? '', vars))}</textarea>`);
    }
    return renderFieldShell(node, `<input${dataType}${actionAttr} type="${type}" name="${escapeHtml(name ?? '')}" value="${escapeHtml(interpolateText(currentValue?.toString() ?? '', vars))}" placeholder="${escapeHtml(placeholder)}" data-remui-var="${escapeHtml(variableName)}" class="${cls}"${enabled ? '' : ' disabled'} />`);
  }

  // ── Checkbox ───────────────────────────────────────────────────────────────
  if (node.type === 'Checkbox') {
    const variableName = node.variable?.toString() ?? '';
    const fromVar = variableName ? vars[variableName] : undefined;
    const checked = fromVar !== undefined
      ? (typeof fromVar === 'boolean' ? fromVar : String(fromVar).toLowerCase() === 'true')
      : Boolean(node.value ?? false);
    const label = node.label?.toString() ?? '';
    const subtitle = node.subtitle?.toString() ?? '';
    const activeColor = resolveColor(node.activeColor) ?? '#6750a4';
    if (node.tile === false) {
      return `<label${dataType}${actionAttr} class="inline-flex items-center gap-2 cursor-pointer">
        <input type="checkbox" data-remui-var="${escapeHtml(variableName)}" class="h-4 w-4 rounded" style="accent-color:${escapeHtml(activeColor)}" ${checked ? 'checked' : ''} />
        ${label ? `<span class="text-sm font-medium text-slate-800">${escapeHtml(label)}</span>` : ''}
      </label>`;
    }
    return `<label${dataType}${actionAttr} class="flex cursor-pointer items-start gap-3 rounded-xl border border-slate-200 bg-white p-3">
      <input type="checkbox" data-remui-var="${escapeHtml(variableName)}" class="mt-0.5 h-4 w-4 rounded flex-shrink-0" style="accent-color:${escapeHtml(activeColor)}" ${checked ? 'checked' : ''} />
      <span class="flex flex-col"><span class="text-sm font-medium text-slate-800">${escapeHtml(label)}</span>${subtitle ? `<span class="text-xs text-slate-500">${escapeHtml(subtitle)}</span>` : ''}</span>
    </label>`;
  }

  // ── Radio ──────────────────────────────────────────────────────────────────
  if (node.type === 'Radio') {
    const variableName = node.variable?.toString() ?? '';
    const currentVal = variableName ? vars[variableName] : node.groupValue;
    const value = node.value ?? node.selectedValue ?? node.label?.toString() ?? '';
    const checked = String(currentVal ?? '') === String(value);
    const label = node.label?.toString() ?? String(value);
    const subtitle = node.subtitle?.toString() ?? '';
    const activeColor = resolveColor(node.activeColor) ?? '#6750a4';
    if (node.tile === false) {
      return `<label${dataType}${actionAttr} class="inline-flex items-center gap-2 cursor-pointer">
        <input type="radio" name="${escapeHtml(variableName)}" data-remui-var="${escapeHtml(variableName)}" value="${escapeHtml(String(value))}" class="h-4 w-4" style="accent-color:${escapeHtml(activeColor)}" ${checked ? 'checked' : ''} />
        <span class="text-sm text-slate-800">${escapeHtml(label)}</span>
      </label>`;
    }
    return `<label${dataType}${actionAttr} class="flex cursor-pointer items-start gap-3 rounded-xl border border-slate-200 bg-white p-3">
      <input type="radio" name="${escapeHtml(variableName)}" data-remui-var="${escapeHtml(variableName)}" value="${escapeHtml(String(value))}" class="mt-0.5 h-4 w-4 flex-shrink-0" style="accent-color:${escapeHtml(activeColor)}" ${checked ? 'checked' : ''} />
      <span class="flex flex-col"><span class="text-sm font-semibold text-slate-900">${escapeHtml(label)}</span>${subtitle ? `<span class="text-xs text-slate-500">${escapeHtml(subtitle)}</span>` : ''}</span>
    </label>`;
  }

  // ── Slider ─────────────────────────────────────────────────────────────────
  if (node.type === 'Slider') {
    const variableName = node.variable?.toString() ?? '';
    const min = Number(node.min ?? 0);
    const max = Number(node.max ?? 100);
    const fromVar = variableName ? vars[variableName] : undefined;
    const value = fromVar !== undefined ? Number(fromVar) : Number(node.value ?? min);
    const activeColor = resolveColor(node.activeColor) ?? '#6750a4';
    return renderFieldShell(node, `
      <div${dataType}${actionAttr} class="space-y-2">
        <input type="range" data-remui-var="${escapeHtml(variableName)}" min="${min}" max="${max}" value="${value}" class="h-2 w-full cursor-pointer appearance-none rounded-full bg-slate-200" style="accent-color:${escapeHtml(activeColor)}" />
        <div class="flex justify-between text-xs text-slate-500">
          <span>${min}</span><span class="font-semibold text-slate-700">${value}</span><span>${max}</span>
        </div>
      </div>`);
  }

  // ── DatePicker ─────────────────────────────────────────────────────────────
  if (node.type === 'DatePicker') {
    const variableName = node.variable?.toString() ?? '';
    const mode = String(node.mode ?? 'both').toLowerCase();
    const inputType = mode === 'date' || mode === 'date-only' ? 'date'
      : mode === 'time' || mode === 'time-only' ? 'time' : 'datetime-local';
    const value = variableName ? vars[variableName] ?? '' : node.value ?? '';
    return renderFieldShell(node, `<input${dataType}${actionAttr} type="${inputType}" data-remui-var="${escapeHtml(variableName)}" value="${escapeHtml(String(value))}" class="w-full rounded-xl border border-slate-200 bg-slate-50 px-3 py-2.5 text-sm text-slate-900 outline-none transition focus:border-purple-500 focus:bg-white" />`);
  }

  // ── Buttons ────────────────────────────────────────────────────────────────
  if (node.type === 'FilledButton' || node.type === 'ElevatedButton' ||
      node.type === 'OutlinedButton' || node.type === 'TextButton') {
    const child = node.child ?? node.children ?? node.text ?? node.label;
    const childHtml = renderChildren(child, vars);
    const customBg = resolveColor(node.color);
    let cls: string;
    let style = '';
    if (node.type === 'FilledButton') {
      cls = 'inline-flex items-center justify-center rounded-xl px-4 py-2 text-sm font-semibold transition border-0 cursor-pointer';
      style = buildStyle({ background: customBg ?? '#6750a4', color: '#ffffff' });
    } else if (node.type === 'ElevatedButton') {
      cls = 'inline-flex items-center justify-center rounded-xl px-4 py-2 text-sm font-semibold shadow transition border-0 cursor-pointer';
      style = buildStyle({ background: customBg ?? '#ffffff', color: '#6750a4' });
    } else if (node.type === 'OutlinedButton') {
      cls = 'inline-flex items-center justify-center rounded-xl px-4 py-2 text-sm font-semibold transition cursor-pointer bg-transparent';
      style = buildStyle({ border: `1px solid ${customBg ?? '#79747e'}`, color: customBg ?? '#6750a4' });
    } else {
      cls = 'inline-flex items-center justify-center rounded-xl px-4 py-2 text-sm font-semibold transition border-0 bg-transparent cursor-pointer';
      style = buildStyle({ color: customBg ?? '#6750a4' });
    }
    return `<button type="button"${dataType}${ariaLabel}${actionAttr} class="${cls}" style="${escapeHtml(style)}">${childHtml}</button>`;
  }

  // ── AppBar ─────────────────────────────────────────────────────────────────
  if (node.type === 'AppBar') {
    const titleWidget = node.title;
    const titleHtml = isWidgetNode(titleWidget)
      ? renderNode(titleWidget, vars)
      : `<span class="text-base font-bold text-slate-900">${escapeHtml(String(titleWidget ?? ''))}</span>`;
    const rawActions = node.actions;
    const actionList = Array.isArray(rawActions) ? rawActions
      : isWidgetNode(rawActions) ? [rawActions] : [];
    const actionsHtml = actionList.map((a) => renderValue(a, vars)).join('');
    const bgColor = resolveColor(node.backgroundColor) ?? '#ffffff';
    const center = node.centerTitle === true;
    const style = buildStyle({ background: bgColor });
    return `<header${dataType}${ariaLabel} class="sticky top-0 z-30 border-b border-slate-200 backdrop-blur-xl" style="${escapeHtml(style)}">
      <div class="mx-auto flex items-center gap-4 px-4 py-3 max-w-7xl">
        ${center ? '<div class="flex-1"></div>' : ''}<div class="${center ? 'absolute left-1/2 -translate-x-1/2' : 'min-w-0 flex-1'}">${titleHtml}</div>
        <div class="flex items-center gap-2 ${center ? 'flex-1 justify-end' : ''}">${actionsHtml}</div>
      </div>
    </header>`;
  }

  // ── Dialog ─────────────────────────────────────────────────────────────────
  if (node.type === 'Dialog') {
    const body = node.body ?? node.child;
    const rawActions = node.actions;
    const actionList = Array.isArray(rawActions) ? rawActions : [];
    const radius = node.borderRadius != null ? `${Number(node.borderRadius)}px` : '24px';
    const bgColor = resolveColor(node.backgroundColor) ?? '#ffffff';
    return `<div class="fixed inset-0 z-40 flex items-center justify-center bg-slate-950/50 p-4 backdrop-blur-sm">
      <div${dataType}${ariaLabel} class="w-full max-w-2xl border border-slate-200 p-6 shadow-2xl" style="border-radius:${escapeHtml(radius)};background:${escapeHtml(bgColor)}">
        <div class="mb-4 border-b border-slate-100 pb-3">${renderChildren(node.title, vars)}</div>
        <div class="space-y-4">${renderChildren(body, vars)}</div>
        ${actionList.length > 0 ? `<div class="mt-5 flex flex-wrap justify-end gap-3 border-t border-slate-100 pt-4">${renderChildren(actionList, vars)}</div>` : ''}
      </div>
    </div>`;
  }

  // ── Scaffold ───────────────────────────────────────────────────────────────
  if (node.type === 'Scaffold') {
    const fab = node.floatingActionButton;
    const fabHtml = isWidgetNode(fab) ? `<div class="fixed bottom-6 right-6 z-20">${renderNode(fab, vars)}</div>` : '';
    return `<div${dataType}${ariaLabel} class="flex flex-col min-h-screen bg-slate-50">
      ${renderChildren(node.appBar, vars)}
      <div class="flex flex-1 w-full">${renderChildren(node.body, vars)}</div>
      ${node.bottomNavigationBar != null ? renderChildren(node.bottomNavigationBar, vars) : ''}
      ${fabHtml}
    </div>`;
  }

  // ── SidebarWithUI ──────────────────────────────────────────────────────────
  if (node.type === 'SidebarWithUI') {
    const contentPad = node.contentPadding != null ? Number(node.contentPadding) : 0;
    const bgColor = resolveColor(node.backgroundColor);
    const dividerColor = resolveColor(node.dividerColor) ?? 'rgba(0,0,0,0.1)';
    const showDivider = node.showDivider !== false;
    const style = buildStyle({ background: bgColor });
    return `<div${dataType}${ariaLabel} class="flex w-full min-h-0 flex-1" style="${escapeHtml(style)}">
      <div class="flex-shrink-0">${renderChildren(node.sidebar, vars)}</div>
      ${showDivider ? `<div style="width:1px;background:${escapeHtml(dividerColor)};flex-shrink:0"></div>` : ''}
      <div class="flex-1 min-w-0" style="padding:${contentPad}px">${renderChildren(node.child, vars)}</div>
    </div>`;
  }

  // ── Sidebar ────────────────────────────────────────────────────────────────
  if (node.type === 'Sidebar') return renderSidebarNode(node, vars);

  // ── NavigationRail ─────────────────────────────────────────────────────────
  if (node.type === 'NavigationRail') return renderNavigationRail(node, vars);

  // ── BottomNavigationBar ────────────────────────────────────────────────────
  if (node.type === 'BottomNavigationBar') return renderBottomNavBar(node, vars);

  // ── RemNavbar ──────────────────────────────────────────────────────────────
  if (node.type === 'RemNavbar') return renderRemNavbar(node, vars);

  // ── RemBottomNavbar ────────────────────────────────────────────────────────
  if (node.type === 'RemBottomNavbar') return renderRemBottomNavbar(node, vars);

  // ── RemDropdowns (standalone) ──────────────────────────────────────────────
  if (node.type === 'RemDropdowns') {
    const entries = Array.isArray(node.dropdowns) ? node.dropdowns as JsonNode[] : [];
    const textColor = resolveColor(node.textColor) ?? '#1f2937';
    const links = entries.map((e) => {
      const label = (e.name ?? e.label ?? '').toString();
      return `<a href="#"${renderActionAttr(e)} class="px-3 py-1.5 text-sm font-semibold rounded-lg hover:bg-slate-100 transition-colors" style="color:${escapeHtml(textColor)}">${escapeHtml(label)}</a>`;
    }).join('');
    return `<nav${dataType} class="flex items-center gap-1">${links}</nav>`;
  }

  // ── Tabs ───────────────────────────────────────────────────────────────────
  if (node.type === 'Tabs') return renderTabsNode(node, vars);

  // ── Column / Row / Flex ────────────────────────────────────────────────────
  if (node.type === 'Column' || node.type === 'Row' || node.type === 'Flex') {
    const isRow = node.type === 'Row'
      || (node.type === 'Flex' && String(node.direction ?? 'horizontal').toLowerCase() !== 'vertical');
    const direction = isRow ? 'row' : 'column';
    const mainVal = node.mainAxis ?? node.mainAxisAlignment;
    const crossVal = node.crossAxis ?? node.crossAxisAlignment;
    const justify = resolveMainAxisCSS(mainVal);
    // Flutter Column defaults crossAxis to start, Row to center
    const alignFallback = isRow ? 'center' : 'flex-start';
    const align = resolveCrossAxisCSS(crossVal, alignFallback);
    const mainAxisSize = node.mainAxisSize;
    const isShrink = String(mainAxisSize ?? '').toLowerCase() === 'min';
    const style = buildStyle({
      display: 'flex',
      'flex-direction': direction,
      'justify-content': justify,
      'align-items': align,
      ...(isShrink ? (isRow ? { width: 'fit-content' } : { height: 'fit-content' }) : {}),
    });
    const children = Array.isArray(node.children) ? node.children : [];
    return `<div${dataType}${ariaLabel}${actionAttr} style="${escapeHtml(style)}">${renderChildren(children, vars)}</div>`;
  }

  // ── Stack ──────────────────────────────────────────────────────────────────
  if (node.type === 'Stack') {
    const alignmentMap: Record<string, { ai: string; ji: string }> = {
      topLeft: { ai: 'start', ji: 'start' },
      topCenter: { ai: 'start', ji: 'center' },
      top: { ai: 'start', ji: 'center' },
      topRight: { ai: 'start', ji: 'end' },
      centerLeft: { ai: 'center', ji: 'start' },
      left: { ai: 'center', ji: 'start' },
      center: { ai: 'center', ji: 'center' },
      centerRight: { ai: 'center', ji: 'end' },
      right: { ai: 'center', ji: 'end' },
      bottomLeft: { ai: 'end', ji: 'start' },
      bottomCenter: { ai: 'end', ji: 'center' },
      bottom: { ai: 'end', ji: 'center' },
      bottomRight: { ai: 'end', ji: 'end' },
    };
    const aKey = String(node.alignment ?? 'topLeft').replace(/\s/g, '');
    const { ai, ji } = alignmentMap[aKey] ?? { ai: 'start', ji: 'start' };
    const children = Array.isArray(node.children) ? node.children : [];
    // CSS grid stack: all children in the same 1×1 cell
    const style = buildStyle({ display: 'grid', 'align-items': ai, 'justify-items': ji });
    const childrenHtml = children.map((c) => `<div style="grid-row:1;grid-column:1">${renderValue(c, vars)}</div>`).join('');
    return `<div${dataType}${ariaLabel}${actionAttr} style="${escapeHtml(style)}">${childrenHtml}</div>`;
  }

  // ── Center ─────────────────────────────────────────────────────────────────
  if (node.type === 'Center') {
    return `<div${dataType}${ariaLabel}${actionAttr} style="display:flex;align-items:center;justify-content:center">${renderChildren(node.child, vars)}</div>`;
  }

  // ── Padding ────────────────────────────────────────────────────────────────
  if (node.type === 'Padding') {
    const p = Number(node.padding ?? 0);
    const pt = Number(node.paddingTop ?? p);
    const pb = Number(node.paddingBottom ?? p);
    const pl = Number(node.paddingLeft ?? p);
    const pr = Number(node.paddingRight ?? p);
    const style = buildStyle({ padding: `${pt}px ${pr}px ${pb}px ${pl}px` });
    return `<div${dataType}${ariaLabel}${actionAttr} style="${escapeHtml(style)}">${renderChildren(node.child, vars)}</div>`;
  }

  // ── Card ───────────────────────────────────────────────────────────────────
  if (node.type === 'Card') {
    const bgColor = resolveColor(node.color) ?? '#ffffff';
    const elevation = Number(node.elevation ?? 1);
    const shadow = elevation > 0 ? `0 ${elevation * 2}px ${elevation * 8}px rgba(0,0,0,${Math.min(0.15, elevation * 0.03)})` : 'none';
    const style = buildStyle({ background: bgColor, 'box-shadow': shadow, 'border-radius': '12px' });
    return `<div${dataType}${ariaLabel}${actionAttr} style="${escapeHtml(style)}">${renderChildren(node.child, vars)}</div>`;
  }

  // ── Container ─────────────────────────────────────────────────────────────
  if (node.type === 'Container') {
    const bgColor = resolveColor(node.color);
    const w = node.width != null ? `${Number(node.width)}px` : undefined;
    const h = node.height != null ? `${Number(node.height)}px` : undefined;
    const radius = node.borderRadius != null ? `${Number(node.borderRadius)}px` : undefined;
    const bgImage = node.backgroundImage?.toString();
    const style = buildStyle({
      background: bgImage ? `url('${bgImage}') center/cover no-repeat` : bgColor,
      width: w, height: h,
      'border-radius': radius,
      'box-sizing': 'border-box',
    });
    return `<div${dataType}${ariaLabel}${actionAttr} style="${escapeHtml(style)}">${renderChildren(node.child, vars)}</div>`;
  }

  // ── SizedBox ───────────────────────────────────────────────────────────────
  if (node.type === 'SizedBox') {
    const w = node.width != null ? `${Number(node.width)}px` : undefined;
    // 'mediaQuery' height → 100vh approximation
    const rawH = node.height;
    const h = rawH === 'mediaQuery' ? '100vh' : rawH != null ? `${Number(rawH)}px` : undefined;
    const style = buildStyle({ width: w, height: h, 'flex-shrink': w || h ? '0' : undefined });
    const hasChild = node.child != null;
    return `<div${dataType}${ariaLabel}${actionAttr} style="${escapeHtml(style)}">${hasChild ? renderChildren(node.child, vars) : ''}</div>`;
  }

  // ── Expanded ───────────────────────────────────────────────────────────────
  if (node.type === 'Expanded') {
    const flex = node.flex != null ? Number(node.flex) : 1;
    const style = buildStyle({ flex: String(flex), 'min-width': '0', 'min-height': '0' });
    return `<div${dataType}${ariaLabel}${actionAttr} style="${escapeHtml(style)}">${renderChildren(node.child, vars)}</div>`;
  }

  // ── SingleChildScrollView / VerticalScroll / HorizontalScroll ─────────────
  if (node.type === 'SingleChildScrollView' || node.type === 'VerticalScroll') {
    return `<div${dataType}${ariaLabel}${actionAttr} style="overflow-y:auto">${renderChildren(node.child, vars)}</div>`;
  }
  if (node.type === 'HorizontalScroll') {
    return `<div${dataType}${ariaLabel}${actionAttr} style="overflow-x:auto">${renderChildren(node.child, vars)}</div>`;
  }

  // ── GestureDetector / InkWell ──────────────────────────────────────────────
  if (node.type === 'GestureDetector' || node.type === 'InkWell') {
    return `<div${dataType}${ariaLabel}${actionAttr} style="cursor:pointer">${renderChildren(node.child, vars)}</div>`;
  }

  // ── Chip ───────────────────────────────────────────────────────────────────
  if (node.type === 'Chip') {
    const label = node.label;
    const labelHtml = isWidgetNode(label) ? renderNode(label, vars) : `<span>${escapeHtml(String(label ?? ''))}</span>`;
    const bgColor = resolveColor(node.backgroundColor) ?? '#e7e0ec';
    const labelColor = resolveColor(node.labelColor) ?? '#1c1b1f';
    const avatarHtml = isWidgetNode(node.avatar) ? `<div class="w-6 h-6 rounded-full overflow-hidden mr-1">${renderNode(node.avatar, vars)}</div>` : '';
    return `<span${dataType}${ariaLabel}${actionAttr} class="inline-flex items-center rounded-full px-3 py-1 text-sm font-medium gap-1" style="background:${escapeHtml(bgColor)};color:${escapeHtml(labelColor)};cursor:${actionAttr ? 'pointer' : 'default'}">${avatarHtml}${labelHtml}</span>`;
  }

  // ── Avatar ─────────────────────────────────────────────────────────────────
  if (node.type === 'Avatar') {
    const radius = node.radius != null ? Number(node.radius) : node.size != null ? Number(node.size) / 2 : 20;
    const size = radius * 2;
    const imageUrl = node.imageUrl?.toString() ?? node.src?.toString() ?? '';
    const bgColor = resolveColor(node.backgroundColor) ?? '#e7e0ec';
    const fgColor = resolveColor(node.foregroundColor) ?? '#1c1b1f';
    const style = buildStyle({ width: `${size}px`, height: `${size}px`, 'border-radius': '50%', background: bgColor, color: fgColor, 'font-size': `${Math.round(size * 0.4)}px`, display: 'inline-flex', 'align-items': 'center', 'justify-content': 'center', overflow: 'hidden', 'flex-shrink': '0' });
    if (imageUrl) {
      return `<div${dataType}${ariaLabel}${actionAttr} style="${escapeHtml(style)}"><img src="${escapeHtml(imageUrl)}" alt="${escapeHtml(metadata?.alt ?? '')}" style="width:100%;height:100%;object-fit:cover" /></div>`;
    }
    return `<div${dataType}${ariaLabel}${actionAttr} style="${escapeHtml(style)}">${renderChildren(node.child, vars)}</div>`;
  }

  // ── Badge ──────────────────────────────────────────────────────────────────
  if (node.type === 'Badge') {
    const bgColor = resolveColor(node.color) ?? 'rgba(0,0,0,0.12)';
    const labelColor = resolveColor(node.labelColor) ?? '#000000';
    const fontSize = node.fontSize != null ? `${Number(node.fontSize)}px` : '11px';
    const style = buildStyle({ background: bgColor, color: labelColor, 'font-size': fontSize, 'font-weight': '700', padding: '2px 8px', 'border-radius': '999px', display: 'inline-block' });
    return `<span${dataType}${ariaLabel}${actionAttr} style="${escapeHtml(style)}">${escapeHtml(String(node.label ?? ''))}</span>`;
  }

  // ── Divider ────────────────────────────────────────────────────────────────
  if (node.type === 'Divider') {
    const thickness = Number(node.thickness ?? 1);
    const color = resolveColor(node.color) ?? '#cac4d0';
    return `<hr${dataType} style="border:none;border-top:${thickness}px solid ${escapeHtml(color)};margin:0;width:100%" />`;
  }

  // ── GridView ───────────────────────────────────────────────────────────────
  if (node.type === 'GridView') {
    const cols = Number(node.crossAxisCount ?? 2);
    const mainSpacing = Number(node.mainAxisSpacing ?? 0);
    const crossSpacing = Number(node.crossAxisSpacing ?? 0);
    const isHorizontal = String(node.scrollDirection ?? '').toLowerCase() === 'horizontal';
    const w = node.width != null ? `${Number(node.width)}px` : undefined;
    const h = node.height != null ? `${Number(node.height)}px` : undefined;
    const style = buildStyle({
      display: 'grid',
      'grid-template-columns': isHorizontal ? undefined : `repeat(${cols}, 1fr)`,
      'grid-template-rows': isHorizontal ? `repeat(${cols}, 1fr)` : undefined,
      gap: `${mainSpacing}px ${crossSpacing}px`,
      'overflow-y': !isHorizontal ? 'auto' : undefined,
      'overflow-x': isHorizontal ? 'auto' : undefined,
      width: w, height: h,
    });
    const children = Array.isArray(node.children) ? node.children : [];
    return `<div${dataType}${ariaLabel}${actionAttr} style="${escapeHtml(style)}">${renderChildren(children, vars)}</div>`;
  }

  // ── Carousel ───────────────────────────────────────────────────────────────
  if (node.type === 'Carousel') {
    const items = Array.isArray(node.items) ? node.items : [];
    const w = node.width != null ? `${Number(node.width)}px` : '100%';
    const h = node.height != null ? `${Number(node.height)}px` : '200px';
    const style = buildStyle({ display: 'flex', 'overflow-x': 'auto', gap: '12px', width: w, height: h, 'scroll-snap-type': 'x mandatory' });
    const childrenHtml = items.map((item) => `<div style="flex-shrink:0;scroll-snap-align:start">${renderValue(item, vars)}</div>`).join('');
    return `<div${dataType}${ariaLabel}${actionAttr} style="${escapeHtml(style)}">${childrenHtml}</div>`;
  }

  // ── Table ──────────────────────────────────────────────────────────────────
  if (node.type === 'Table') {
    const rows = Array.isArray(node.rows) ? node.rows : [];
    const hasBorder = node.border != null;
    const borderColor = resolveColor(node.borderColor) ?? '#000000';
    const style = hasBorder ? `border-collapse:collapse` : '';
    const tdStyle = hasBorder ? `border:1px solid ${escapeHtml(borderColor)};padding:6px 10px` : 'padding:6px 10px';
    const rowsHtml = rows.map((row) => {
      if (!Array.isArray(row)) return '';
      const cells = row.map((cell) => `<td style="${tdStyle}">${renderValue(cell, vars)}</td>`).join('');
      return `<tr>${cells}</tr>`;
    }).join('');
    return `<table${dataType}${ariaLabel}${actionAttr} style="${style}">${rowsHtml}</table>`;
  }

  // ── Timeout (transparent wrapper — just renders child, timer is client-side) ─
  if (node.type === 'Timeout') {
    const actionJson = escapeHtml(JSON.stringify(node.data ?? []));
    const ms = Number(node.timeout ?? node.duration ?? node.ms ?? 0);
    return `<div${dataType} data-remui-timeout="${ms}" data-remui-timeout-data="${actionJson}" style="display:contents">${renderChildren(node.child, vars)}</div>`;
  }

  // ── condition ──────────────────────────────────────────────────────────────
  if (node.type === 'condition') return renderConditionNode(node, vars);

  // ── Fallback ───────────────────────────────────────────────────────────────
  return `<div${dataType}${ariaLabel}${actionAttr} style="display:contents">${renderChildren(node.child ?? node.children ?? node.label ?? node.items ?? node.destinations, vars)}</div>`;
}

function renderNode(node: JsonNode, vars: Record<string, unknown>): string {
  return renderWidgetBody(node, vars);
}

// ─── <head> assembly ──────────────────────────────────────────────────────────

function renderHead(payload: SsrPayload, vars: Record<string, unknown>): string {
  const bucket: SsrMetaBucket = { entries: [] };
  for (const value of Object.values(payload)) collectMetaBuckets(value, bucket);

  const title = bucket.title ?? escapeHtml(String(payload.page ?? 'RemUI'));
  const metaTags = bucket.entries
    .map((entry) => `<meta name="${escapeHtml(entry.name)}" content="${escapeHtml(entry.content)}" />`)
    .join('');

  return [
    '<meta charset="utf-8" />',
    '<meta name="viewport" content="width=device-width, initial-scale=1" />',
    '<link rel="preconnect" href="https://fonts.googleapis.com" />',
    '<link href="https://fonts.googleapis.com/icon?family=Material+Icons" rel="stylesheet" />',
    '<script src="https://cdn.tailwindcss.com"></script>',
    '<script>tailwind.config = { theme: { extend: {} } };</script>',
    `<title>${title}</title>`,
    metaTags,
    `<script>window.__REMUI_PAYLOAD__ = ${escapeScript(JSON.stringify(payload))};</script>`,
    `<script>window.__REMUI_VARS__ = ${escapeScript(JSON.stringify(vars))};</script>`,
  ].join('\n  ');
}

// ─── Client-side script ───────────────────────────────────────────────────────

function renderClientScript(): string {
  return `
    (() => {
      const state = Object.assign({}, window.__REMUI_VARS__ || {});
      const prefsKey = 'remui.prefs';

      function readPrefs() {
        try { return JSON.parse(localStorage.getItem(prefsKey) || '{}'); } catch { return {}; }
      }

      function writePrefs(next) {
        localStorage.setItem(prefsKey, JSON.stringify(next));
      }

      function applyVars(next) {
        Object.assign(state, next || {});
        document.querySelectorAll('[data-remui-var]').forEach((el) => {
          const name = el.getAttribute('data-remui-var');
          if (!name) return;
          const value = state[name];
          if (el.type === 'checkbox') el.checked = Boolean(value);
          else if (el.type === 'radio') el.checked = String(value) === String(el.value);
          else if ('value' in el) el.value = value ?? '';
        });
      }

      function showToast(message) {
        const el = document.createElement('div');
        el.textContent = message;
        el.style.cssText = 'position:fixed;bottom:24px;left:50%;transform:translateX(-50%);background:#1c1b1f;color:#fff;padding:10px 20px;border-radius:8px;font-size:14px;z-index:9999;pointer-events:none;opacity:1;transition:opacity .4s';
        document.body.appendChild(el);
        setTimeout(() => { el.style.opacity = '0'; setTimeout(() => el.remove(), 400); }, 3000);
      }

      async function runCallbacks(callbacks) {
        let needsReload = false;
        let navigateTo = null;

        for (const cb of callbacks) {
          if (!cb || typeof cb !== 'object') continue;

          if (cb.setVar && cb.setVar.var) {
            state[cb.setVar.var] = cb.setVar.value;
          }
          if (cb.setSharedPref) {
            const next = readPrefs();
            for (const part of String(cb.setSharedPref).split('&')) {
              const sep = part.indexOf('=');
              if (sep > 0) next[part.slice(0, sep)] = part.slice(sep + 1);
            }
            writePrefs(next);
          }
          if (cb.remSharedPref) {
            const next = readPrefs();
            for (const key of String(cb.remSharedPref).split('&')) delete next[key];
            writePrefs(next);
          }
          if (cb.snackbar) showToast(String(cb.snackbar));
          if (cb.changePage || cb.pushPage) {
            navigateTo = (cb.changePage || cb.pushPage)?.path ?? (cb.changePage || cb.pushPage);
          }
          if (cb.popPage) { history.back(); return; }
          if (cb.reload || cb.reloadRetain) needsReload = true;
        }

        if (navigateTo && typeof navigateTo === 'string') {
          window.location.assign(navigateTo);
        } else if (needsReload) {
          window.location.reload();
        } else {
          applyVars(state);
        }
      }

      async function sendCallback(action) {
        const payload = { id: action.id, variables: { ...state }, prefs: readPrefs() };
        try {
          const res = await fetch('/ui/callbacks', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(payload),
          });
          if (!res.ok) return;
          const data = await res.json();
          const callbacks = Array.isArray(data.callbacks) ? data.callbacks : [];
          await runCallbacks(callbacks);
        } catch (e) {
          console.error('[RemUI] callback error', e);
        }
      }

      // Variable binding from inputs
      document.addEventListener('input', (e) => {
        const target = e.target;
        if (!(target instanceof HTMLElement)) return;
        const v = target.getAttribute('data-remui-var');
        if (!v) return;
        if (target instanceof HTMLInputElement) {
          if (target.type === 'checkbox') state[v] = target.checked;
          else if (target.type === 'radio') { if (target.checked) state[v] = target.value; }
          else state[v] = target.value;
        } else if ('value' in target) state[v] = target.value;
      }, true);

      document.addEventListener('change', (e) => {
        const target = e.target;
        if (!(target instanceof HTMLElement)) return;
        const v = target.getAttribute('data-remui-var');
        if (!v) return;
        if (target instanceof HTMLInputElement) {
          if (target.type === 'checkbox') state[v] = target.checked;
          else if (target.type === 'radio') { if (target.checked) state[v] = target.value; }
          else state[v] = target.value;
        }
      }, true);

      // Click / action handling
      document.addEventListener('click', async (e) => {
        // Tab switching
        const tabBtn = e.target instanceof Element ? e.target.closest('[data-tab-index]') : null;
        if (tabBtn instanceof HTMLElement) {
          const tabGroup = tabBtn.closest('[data-remui-tabs]');
          if (tabGroup instanceof HTMLElement) {
            const idx = tabBtn.getAttribute('data-tab-index');
            const indicatorColor = tabGroup.getAttribute('data-tab-indicator') || '#6750a4';
            const labelColor = tabGroup.getAttribute('data-tab-label') || '#1c1b1f';
            const unselectedColor = tabGroup.getAttribute('data-tab-unselected') || '#49454f';
            tabGroup.querySelectorAll('[data-tab-index]').forEach((b) => {
              b.setAttribute('aria-selected', 'false');
              b.style.borderBottom = '2px solid transparent';
              b.style.color = unselectedColor;
            });
            tabBtn.setAttribute('aria-selected', 'true');
            tabBtn.style.borderBottom = '2px solid ' + indicatorColor;
            tabBtn.style.color = labelColor;
            tabGroup.querySelectorAll('[data-tab-panel]').forEach((p) => {
              p.style.display = p.getAttribute('data-tab-panel') === idx ? '' : 'none';
            });
            const varName = tabGroup.getAttribute('data-remui-tabs');
            if (varName) state[varName] = idx;
            return;
          }
        }

        // Navigation item highlighting
        const navBtn = e.target instanceof Element ? e.target.closest('[data-remui-nav-idx]') : null;
        if (navBtn instanceof HTMLElement) {
          const varName = navBtn.getAttribute('data-remui-var');
          const idx = navBtn.getAttribute('data-remui-nav-idx');
          if (varName && idx !== null) state[varName] = idx;
        }

        const actionEl = e.target instanceof Element ? e.target.closest('[data-remui-action]') : null;
        if (!(actionEl instanceof HTMLElement)) return;
        const rawAction = actionEl.getAttribute('data-remui-action');
        if (!rawAction) return;

        let action;
        try { action = JSON.parse(rawAction); } catch { action = rawAction; }

        if (typeof action === 'string') {
          if (action.startsWith('nav:')) { window.location.assign(action.slice(4)); return; }
          return;
        }

        if (action && typeof action === 'object') {
          if (action.type === 'setVar' && action.var) {
            state[action.var] = action.value;
            applyVars(state);
            return;
          }
          if (action.action === 'submit' || action.id) {
            e.preventDefault();
            await sendCallback(action);
            return;
          }
          if (action.path) { window.location.assign(action.path); return; }
          if (action.changePage || action.pushPage) {
            const path = (action.changePage || action.pushPage)?.path ?? action.changePage ?? action.pushPage;
            if (typeof path === 'string') { window.location.assign(path); return; }
          }
        }
      });

      // Timeout widgets
      document.querySelectorAll('[data-remui-timeout]').forEach((el) => {
        const ms = parseInt(el.getAttribute('data-remui-timeout') || '0', 10);
        const raw = el.getAttribute('data-remui-timeout-data') || '[]';
        let data;
        try { data = JSON.parse(raw); } catch { data = []; }
        if (!Array.isArray(data)) data = [data];
        if (data.length > 0) setTimeout(() => runCallbacks(data), ms);
      });

      applyVars(state);
    })();
  `;
}

// ─── Full document assembly ───────────────────────────────────────────────────

function renderSsrDocument(req: Request, payload: unknown): string {
  const body = isObject(payload) ? (payload as SsrPayload) : {};
  const vars = isObject(body.vars) ? (body.vars as Record<string, unknown>) : {};
  const head = renderHead(body, vars);

  // Determine what the root UI node is
  const bodyNode = body.body ?? body.child ?? body;
  const isScaffold = isWidgetNode(bodyNode) && bodyNode.type === 'Scaffold';
  const isDialog = isWidgetNode(bodyNode) && bodyNode.type === 'Dialog';

  let rootShell: string;

  if (isScaffold || isDialog) {
    // Scaffold/Dialog manage their own full-page layout — render directly
    rootShell = renderNode(bodyNode, vars);
  } else {
    // Flat response: extract appBar / body / bottomNav separately
    const appBarHtml = isWidgetNode(body.appBar) ? renderNode(body.appBar as JsonNode, vars) : '';
    const bottomNavHtml = isWidgetNode(body.bottomNavigationBar)
      ? renderNode(body.bottomNavigationBar as JsonNode, vars) : '';
    const contentHtml = isWidgetNode(bodyNode) ? renderNode(bodyNode, vars) : renderChildren(bodyNode, vars);
    rootShell = `
      <div class="flex flex-col min-h-screen bg-slate-50">
        ${appBarHtml}
        <main class="flex flex-1 w-full mx-auto max-w-7xl px-4 py-6 sm:px-6 lg:px-8">${contentHtml}</main>
        ${bottomNavHtml}
      </div>`;
  }

  return `<!doctype html>
<html lang="en">
<head>
  ${head}
  <style>
    *, *::before, *::after { box-sizing: border-box; }
    html { scroll-behavior: smooth; }
    body { margin: 0; font-family: "Roboto", system-ui, sans-serif; background: #f8fafc; color: #1c1b1f; -webkit-font-smoothing: antialiased; }
    .material-icons { font-family: "Material Icons"; font-weight: normal; font-style: normal; display: inline-block; line-height: 1; letter-spacing: normal; text-transform: none; white-space: nowrap; word-wrap: normal; direction: ltr; -webkit-font-feature-settings: "liga"; font-feature-settings: "liga"; -webkit-font-smoothing: antialiased; vertical-align: middle; user-select: none; }
    [data-remui-type="Text"] { white-space: pre-wrap; }
    .remui-tab-btn:hover { opacity: 0.85; }
    input[type="range"] { cursor: pointer; }
    button { cursor: pointer; }
  </style>
</head>
<body>
  <div data-remui-path="${escapeHtml(req.originalUrl)}">
    ${rootShell}
  </div>
  <script>${renderClientScript()}</script>
</body>
</html>`;
}

// ─── Middleware ───────────────────────────────────────────────────────────────

function shouldRenderSsr(req: Request): boolean {
  if (req.method !== 'GET') return false;
  if (!req.originalUrl.startsWith('/ui/')) return false;
  const userAgent = String(req.headers['user-agent'] ?? '');
  if (userAgent.includes(REMUI_FLUTTER_USER_AGENT)) return false;
  const accept = String(req.headers.accept ?? '');
  return accept.includes('text/html') || accept.includes('*/*') || accept.length === 0;
}

export function createRemUiSsrMiddleware(): RequestHandler {
  return (req: Request, res: Response, next: NextFunction) => {
    if (!shouldRenderSsr(req)) { next(); return; }

    const originalJson = res.json.bind(res);
    res.json = ((body: unknown) => {
      const html = renderSsrDocument(req, body);
      res.status(res.statusCode || 200);
      res.setHeader('Content-Type', 'text/html; charset=utf-8');
      res.send(html);
      return res;
    }) as Response['json'];

    next();
  };
}
