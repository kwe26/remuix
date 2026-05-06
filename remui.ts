import { type Request, type Response } from 'express';
import { createRemUiSsrMiddleware } from './remui_ssr.ts';

export type JsonPrimitive = string | number | boolean | null;
export type JsonObject = { [key: string]: JsonValue };
export type JsonValue =
  | JsonPrimitive
  | JsonNode
  | JsonObject
  | ConditionBuilder
  | EqlBuilder
  | WebViewCbBuilder
  | SendBackBuilder
  | JsonValue[];
export type JsonNode = { type: string;[key: string]: JsonValue };
export type UiChild = JsonNode | ConditionBuilder | JsonPrimitive | undefined;
export type UiProps = Record<string, JsonValue | undefined>;
export type CallbackNode = Record<string, unknown>;
type CallbackPayload = CallbackNode | CallbackNode[];

export type UiMetadataEntry = { name: string; content: JsonValue };
export type UiMetadataState = {
  meta: UiMetadataEntry[];
  tag?: string;
  alt?: string;
};

const UI_METADATA_SYMBOL = Symbol.for('remui.ui.metadata');

export interface UiNodeActions {
  meta(name: string, content: JsonValue): UiNode;
  tag(name: string): UiNode;
  alt(value: string): UiNode;
}

export type UiNode = JsonNode & UiNodeActions;

export class ConditionBuilder {
  type = 'condition' as const;
  var: string;
  eq: JsonValue;
  child?: JsonValue;
  elseIf?: ConditionBuilder;

  constructor(node: JsonNode) {
    this.var = node.var?.toString() ?? '';
    this.eq = node.eq ?? null;
    if (node.child !== undefined) {
      this.child = node.child;
    }
  }

  equate(variable: unknown, eq: JsonValue, props: UiProps = {}, ...children: UiChild[]): ConditionBuilder {
    const next = createConditionBuilder(variable, eq, props, ...children);
    this.appendElseIf(next);
    return this;
  }

  private appendElseIf(next: ConditionBuilder): void {
    let cursor: ConditionBuilder = this;

    while (cursor.elseIf !== undefined) {
      cursor = cursor.elseIf;
    }

    cursor.elseIf = next;
  }
}

export class EqlBuilder {
  type = 'eql' as const;
  var: string;
  eq: JsonValue;
  value: JsonValue;
  elseIf?: EqlBuilder;
  elseValue?: JsonValue;

  constructor(variable: unknown, eq: JsonValue, value: JsonValue) {
    this.var = normalizeVarName(variable);
    this.eq = eq;
    this.value = value;
  }

  equate(variable: unknown, eq: JsonValue, value: JsonValue): EqlBuilder {
    const next = new EqlBuilder(variable, eq, value);
    this.appendElseIf(next);
    return this;
  }

  else(value: JsonValue): EqlBuilder {
    this.elseValue = value;
    return this;
  }

  private appendElseIf(next: EqlBuilder): void {
    let cursor: EqlBuilder = this;

    while (cursor.elseIf !== undefined) {
      cursor = cursor.elseIf;
    }

    cursor.elseIf = next;
  }
}

export type WebViewMatchMode = 'contains' | 'exact' | 'startsWith';

export type WebViewMatch = {
  value: string;
  mode: WebViewMatchMode;
};

export class WebViewCbBuilder {
  type = 'webView' as const;
  urlValue = '';
  isFullscreen = false;
  matches: WebViewMatch[] = [];
  remuiPath = '';

  url(value: string): WebViewCbBuilder {
    this.urlValue = value;
    return this;
  }

  fullscreen(value = true): WebViewCbBuilder {
    this.isFullscreen = value;
    return this;
  }

  match(value: string, mode: WebViewMatchMode = 'contains'): WebViewCbBuilder {
    this.matches.push({ value, mode });
    return this;
  }

  remuiContains(value: string): WebViewCbBuilder {
    this.remuiPath = value;
    return this;
  }

  build(): JsonNode {
    return {
      type: this.type,
      url: this.urlValue,
      fullscreen: this.isFullscreen,
      matches: this.matches,
      remuiContains: this.remuiPath,
    };
  }

  toJSON(): JsonNode {
    return this.build();
  }
}

const MULTI_CHILD_TYPES = new Set(['Column', 'Row']);
const runtimeVars = new Map<string, JsonValue>();
const materialIconCodes: Map<string, string> = new Map();

class CallbackBuilder {
  private readonly req: Request;
  private readonly res: Response;
  private readonly id: string;
  private readonly callbacks: CallbackNode[] = [];

  constructor(req: Request, res: Response, id: string) {
    this.req = req;
    this.res = res;
    this.id = id;
  }

  data<T = Record<string, unknown>>(): T {
    return (this.req.body ?? {}) as T;
  }

  add(callback: CallbackNode): CallbackBuilder {
    this.callbacks.push(callback);
    return this;
  }

  setSharedPref(entry: string): CallbackBuilder {
    return this.add({ setSharedPref: entry });
  }

  remSharedPref(entry: string): CallbackBuilder {
    return this.add({ remSharedPref: entry });
  }

  closeDialog(): CallbackBuilder {
    return this.add({ closeDialog: true });
  }

  reloadRetain(): CallbackBuilder {
    return this.add({ reloadRetain: true });
  }

  setVar(name: string, value: JsonValue): CallbackBuilder {
    return this.add({
      setVar: {
        var: name,
        value,
      },
    });
  }

  setPrefs(entries: Record<string, JsonValue> | string): CallbackBuilder {
    return this.add({ setPrefs: entries });
  }

  addWebView(webView: WebViewCbBuilder): CallbackBuilder {
    return this.add({ webView: webView.build() });
  }

  push(path: string): CallbackBuilder {
    return this.add({ push: path });
  }

  pushReplace(path: string): CallbackBuilder {
    return this.add({ pushReplace: path });
  }

  pushPage(path: string): CallbackBuilder {
    return this.push(path);
  }

  pushPageReplace(path: string): CallbackBuilder {
    return this.pushReplace(path);
  }

  send(statusCode = 200): void {
    this.res.status(statusCode).json({
      id: this.id,
      callbacks: this.callbacks,
    });
  }
}

export class SendBackBuilder {
  private readonly callbacks: CallbackNode[] = [];
  private timeoutMs: number | null = null;

  timeout(ms: number): SendBackBuilder {
    const normalized = Number.isFinite(ms) ? Math.max(0, Math.trunc(ms)) : 0;
    this.timeoutMs = normalized;
    return this;
  }

  add(callback: CallbackNode): SendBackBuilder {
    this.callbacks.push(callback);
    return this;
  }

  setSharedPref(entry: string): SendBackBuilder {
    return this.add({ setSharedPref: entry });
  }

  remSharedPref(entry: string): SendBackBuilder {
    return this.add({ remSharedPref: entry });
  }

  reloadRetain(): SendBackBuilder {
    return this.add({ reloadRetain: true });
  }

  loadRetain(): SendBackBuilder {
    return this.reloadRetain();
  }

  setVar(name: string, value: JsonValue): SendBackBuilder {
    return this.add({
      setVar: {
        var: name,
        value,
      },
    });
  }

  setPrefs(entries: Record<string, JsonValue> | string): SendBackBuilder {
    return this.add({ setPrefs: entries });
  }

  addWebView(webView: WebViewCbBuilder): SendBackBuilder {
    return this.add({ webView: webView.build() });
  }

  push(path: string): SendBackBuilder {
    return this.add({ push: path });
  }

  pushReplace(path: string): SendBackBuilder {
    return this.add({ pushReplace: path });
  }

  pushPage(path: string): SendBackBuilder {
    return this.push(path);
  }

  pushPageReplace(path: string): SendBackBuilder {
    return this.pushReplace(path);
  }

  build(): CallbackPayload {
    const payload: CallbackPayload = this.callbacks.length === 1
      ? this.callbacks[0] as CallbackNode
      : [...this.callbacks] as CallbackNode[];

    if (this.timeoutMs === null) {
      return payload;
    }

    return {
      timeout: this.timeoutMs,
      data: payload,
    };
  }

  toJSON(): CallbackPayload {
    return this.build();
  }
}

export function sendBack(): SendBackBuilder {
  return new SendBackBuilder();
}

type UiFactory = ((type: string, props?: UiProps, ...children: UiChild[]) => UiNode) & {
  getCallback: (req: Request, res: Response, id: string) => CallbackBuilder;
};

function getOrCreateUiMetadata(node: JsonNode): UiMetadataState {
  const current = (node as Record<PropertyKey, unknown>)[UI_METADATA_SYMBOL] as
    | UiMetadataState
    | undefined;
  if (current) {
    return current;
  }

  const next: UiMetadataState = { meta: [] };
  Object.defineProperty(node, UI_METADATA_SYMBOL, {
    value: next,
    enumerable: false,
    configurable: false,
    writable: false,
  });

  return next;
}

function decorateUiNode<T extends JsonNode>(node: T): T & UiNodeActions {
  const metadata = getOrCreateUiMetadata(node);

  Object.defineProperties(node, {
    meta: {
      enumerable: false,
      configurable: false,
      value(name: string, content: JsonValue): UiNode {
        metadata.meta.push({ name: name.toString().trim(), content });
        return node as T & UiNodeActions;
      },
    },
    tag: {
      enumerable: false,
      configurable: false,
      value(name: string): UiNode {
        metadata.tag = name.toString().trim();
        return node as T & UiNodeActions;
      },
    },
    alt: {
      enumerable: false,
      configurable: false,
      value(value: string): UiNode {
        metadata.alt = value.toString();
        return node as T & UiNodeActions;
      },
    },
  });

  return node as T & UiNodeActions;
}

export async function loadMaterialIcons(): Promise<void> {
  try {
    materialIconCodes.clear();

    const flutterIconsResponse = await fetch(
      'https://raw.githubusercontent.com/flutter/flutter/master/packages/flutter/lib/src/material/icons.dart',
    );

    if (!flutterIconsResponse.ok) {
      throw new Error(`Failed to fetch Flutter icons.dart (${flutterIconsResponse.status})`);
    }

    const flutterIconsText = await flutterIconsResponse.text();
    const iconRegex = /static const IconData\s+([a-zA-Z0-9_]+)\s*=\s*IconData\((0x[0-9a-fA-F]+),\s*fontFamily:\s*'MaterialIcons'/g;

    for (const match of flutterIconsText.matchAll(iconRegex)) {
      const iconName = (match[1] ?? '').trim();
      const codepointHex = (match[2] ?? '').trim();

      if (!iconName || !codepointHex) {
        continue;
      }

      const normalizedHex = codepointHex.toUpperCase();
      materialIconCodes.set(iconName.toLowerCase(), `M:${normalizedHex}`);
    }

    console.log(`Loaded ${materialIconCodes.size} Flutter Material Icons`);
  } catch (error) {
    console.error('Failed to load Material Design Icons:', error);
  }
}

function isJsonNode(value: unknown): value is JsonNode {
  return typeof value === 'object' && value !== null && 'type' in value;
}

function isConditionBuilder(value: unknown): value is ConditionBuilder {
  return value instanceof ConditionBuilder;
}

function isEqlBuilder(value: unknown): value is EqlBuilder {
  return value instanceof EqlBuilder;
}

function serializeJsonValue(value: JsonValue): JsonValue {
  if (value instanceof SendBackBuilder) {
    return serializeJsonValue(value.build() as JsonValue);
  }

  if (isEqlBuilder(value)) {
    const node: Record<string, JsonValue> = {
      type: value.type,
      var: value.var,
      eq: serializeJsonValue(value.eq),
      value: serializeJsonValue(value.value),
    };

    if (value.elseIf !== undefined) {
      node.elseIf = serializeJsonValue(value.elseIf);
    }

    if (value.elseValue !== undefined) {
      node.else = serializeJsonValue(value.elseValue);
    }

    return node as JsonNode;
  }

  if (Array.isArray(value)) {
    return value.map((item) => serializeJsonValue(item));
  }

  if (isConditionBuilder(value)) {
    const node: Record<string, JsonValue> = {
      type: value.type,
      var: value.var,
      eq: serializeJsonValue(value.eq),
    };

    if (value.child !== undefined) {
      node.child = serializeJsonValue(value.child);
    }

    if (value.elseIf !== undefined) {
      node.elseIf = serializeJsonValue(value.elseIf);
    }

    return node as JsonNode;
  }

  return value;
}

function resolveIcon(value: unknown): string | null {
  if (value === null || value === undefined) return null;

  const formatMaterialCodepoint = (codePoint: number): string | null => {
    if (!Number.isInteger(codePoint) || codePoint < 0) {
      return null;
    }
    return `M:0x${codePoint.toString(16).toUpperCase()}`;
  };

  const parseCodePointToken = (rawToken: string): string | null => {
    let token = rawToken.trim();
    if (!token) {
      return null;
    }

    if (token.toLowerCase().startsWith('m:')) {
      token = token.substring(2).trim();
    }

    if (token.startsWith('0x') || token.startsWith('0X')) {
      const parsed = Number.parseInt(token.substring(2), 16);
      return Number.isNaN(parsed) ? null : formatMaterialCodepoint(parsed);
    }

    if (token.startsWith('u+') || token.startsWith('U+')) {
      const parsed = Number.parseInt(token.substring(2), 16);
      return Number.isNaN(parsed) ? null : formatMaterialCodepoint(parsed);
    }

    if (token.startsWith('#')) {
      const parsed = Number.parseInt(token.substring(1), 16);
      return Number.isNaN(parsed) ? null : formatMaterialCodepoint(parsed);
    }

    if (/^[0-9A-Fa-f]+$/.test(token) && /[A-Fa-f]/.test(token)) {
      const parsed = Number.parseInt(token, 16);
      return Number.isNaN(parsed) ? null : formatMaterialCodepoint(parsed);
    }

    return null;
  };

  if (typeof value === 'string') {
    const trimmed = value.trim();
    const explicitCodePoint = parseCodePointToken(trimmed);
    if (explicitCodePoint) {
      return explicitCodePoint;
    }
    const code = materialIconCodes.get(trimmed.toLowerCase());
    return code ? code : null;
  }

  if (typeof value === 'number') {
    return formatMaterialCodepoint(value);
  }

  return null;
}

function resolveTemplateString(input: string): string {
  return input.replace(/\{([^}]+)\}/g, (_match, rawPath: string) => {
    const key = normalizeVarName(rawPath);
    const value = runtimeVars.get(key);

    if (value === undefined || value === null) {
      return `{${rawPath}}`;
    }

    if (Array.isArray(value) || (typeof value === 'object' && value !== null)) {
      try {
        return JSON.stringify(value);
      } catch (_) {
        return String(value);
      }
    }

    return String(value);
  });
}

function resolveJsonValue(value: JsonValue): JsonValue {
  if (typeof value === 'string') {
    return resolveTemplateString(value);
  }

  if (Array.isArray(value)) {
    return value.map((item) => resolveJsonValue(item));
  }

  if (isConditionBuilder(value)) {
    const resolved: Record<string, JsonValue> = {
      type: value.type,
      var: resolveJsonValue(value.var) as JsonValue,
      eq: resolveJsonValue(value.eq),
    };

    if (value.child !== undefined) {
      resolved.child = resolveJsonValue(value.child);
    }

    if (value.elseIf !== undefined) {
      resolved.elseIf = resolveJsonValue(value.elseIf);
    }

    return resolved as JsonNode;
  }

  if (isJsonNode(value)) {
    const resolved: Record<string, JsonValue> = {};
    for (const [key, field] of Object.entries(value)) {
      resolved[key] = key === 'type' ? field : resolveJsonValue(field as JsonValue);
    }
    return resolved as JsonNode;
  }

  return value;
}

function toNode(value: UiChild): JsonNode | undefined {
  if (value === undefined || value === null) {
    return undefined;
  }

  if (isConditionBuilder(value)) {
    return resolveJsonValue(serializeJsonValue(value)) as JsonNode;
  }

  if (isJsonNode(value)) {
    return resolveJsonValue(value) as JsonNode;
  }

  return { type: 'Text', text: resolveTemplateString(String(value)) };
}

function asChildren(value: JsonValue | undefined): JsonNode[] {
  if (value === undefined || value === null) {
    return [];
  }

  if (Array.isArray(value)) {
    return value
      .map((item) => toNode(item as UiChild))
      .filter((item): item is JsonNode => item !== undefined);
  }

  const maybeNode = toNode(value as UiChild);
  return maybeNode ? [maybeNode] : [];
}

function createConditionBuilder(
  variable: unknown,
  eq: JsonValue,
  props: UiProps = {},
  ...children: UiChild[]
): ConditionBuilder {
  const node = buildUi(
    'condition',
    {
      var: normalizeVarName(variable),
      eq,
      ...props,
    },
    ...children,
  );

  return new ConditionBuilder(node);
}

export function eql(variable: unknown, eq: JsonValue, value: JsonValue): EqlBuilder {
  return new EqlBuilder(variable, eq, value);
}

function normalizeVarName(value: unknown): string {
  return String(value).trim();
}

function toStoredValue(value: unknown): JsonValue {
  if (
    value === null ||
    typeof value === 'string' ||
    typeof value === 'number' ||
    typeof value === 'boolean'
  ) {
    return value;
  }

  if (Array.isArray(value)) {
    return value.map((item) => toStoredValue(item));
  }

  if (isJsonNode(value)) {
    return value;
  }

  if (typeof value === 'function') {
    return toStoredValue(value());
  }

  return String(value);
}

export function clearRuntimeVars(): void {
  runtimeVars.clear();
}

export function setVar(name: unknown, value: unknown): JsonNode {
  const key = normalizeVarName(name);
  const stored = toStoredValue(value);
  runtimeVars.set(key, stored);
  return {
    type: 'setVar',
    var: key,
    value: stored,
  };
}

export function varSet(input: string | { var?: string; name?: string; value?: unknown }): JsonNode {
  if (typeof input === 'string') {
    const separator = input.indexOf('=');
    if (separator > 0) {
      const name = input.substring(0, separator).trim();
      const rawValue = input.substring(separator + 1);
      if (name) {
        return { type: 'setVar', var: name, value: toStoredValue(rawValue) };
      }
    }
    return { type: 'setVar', var: input.trim(), value: null };
  }

  const name = (input.var ?? input.name ?? '').toString();
  return { type: 'setVar', var: name, value: toStoredValue(input.value) };
}

export function setPrefs(entries: Record<string, JsonValue> | string): JsonNode {
  const normalized: Record<string, JsonValue> = {};

  if (typeof entries === 'string') {
    const params = new URLSearchParams(entries);
    if (params.size > 0) {
      for (const [key, value] of params.entries()) {
        normalized[key] = value;
      }
    } else {
      const key = entries.trim();
      if (key) {
        normalized[key] = '';
      }
    }
  } else if (entries && typeof entries === 'object') {
    for (const [key, value] of Object.entries(entries)) {
      normalized[key] = value;
    }
  }

  for (const [key, value] of Object.entries(normalized)) {
    const stored = toStoredValue(value);
    if (stored === null || stored === undefined) {
      setRuntimeVar(`prefs.${key}`, null);
      setRuntimeVar(`prefs.${key}.isPresent`, 'false');
    } else {
      setRuntimeVar(`prefs.${key}`, stored);
      setRuntimeVar(`prefs.${key}.isPresent`, 'true');
    }
  }

  return {
    type: 'setPrefs',
    entries: normalized,
  } as JsonNode;
}

export function getUiMetadata(node: JsonNode | undefined | null): UiMetadataState | undefined {
  if (!node || typeof node !== 'object') {
    return undefined;
  }

  return (node as Record<PropertyKey, unknown>)[UI_METADATA_SYMBOL] as UiMetadataState | undefined;
}

export function setRuntimeVar(name: string, value: JsonValue): void {
  runtimeVars.set(normalizeVarName(name), value);
}

export function hydrateRuntimeVarsFromContext(context: unknown): void {
  if (!context || typeof context !== 'object' || Array.isArray(context)) {
    return;
  }

  const rawPrefs = (context as Record<string, unknown>).prefs;
  if (!rawPrefs || typeof rawPrefs !== 'object' || Array.isArray(rawPrefs)) {
    return;
  }

  for (const [prefName, prefValue] of Object.entries(rawPrefs as Record<string, unknown>)) {
    const present =
      typeof prefValue === 'object' &&
      prefValue !== null &&
      (prefValue as Record<string, unknown>).isPresent === true;

    setRuntimeVar(`prefs.${prefName}.isPresent`, present ? 'true' : 'false');

    if (!present || typeof prefValue !== 'object' || prefValue === null) {
      continue;
    }

    const rawValue = (prefValue as Record<string, unknown>).value;
    if (
      rawValue === null ||
      typeof rawValue === 'string' ||
      typeof rawValue === 'number' ||
      typeof rawValue === 'boolean'
    ) {
      setRuntimeVar(`prefs.${prefName}`, rawValue as JsonValue);
      continue;
    }

    if (Array.isArray(rawValue)) {
      setRuntimeVar(
        `prefs.${prefName}`,
        rawValue.map((item) => String(item)) as JsonValue,
      );
    }
  }
}

export function getVar(name: unknown): JsonValue | undefined {
  return runtimeVars.get(normalizeVarName(name));
}

export function getRuntimeVars(): Record<string, JsonValue> {
  return Object.fromEntries(runtimeVars);
}

function buildUi(type: string, props: UiProps = {}, ...children: UiChild[]): UiNode {
  const hasChildrenProp = Object.prototype.hasOwnProperty.call(props, 'children');
  const isMultiChildType = MULTI_CHILD_TYPES.has(type);
  const { child, children: propChildren, ...rest } = props;

  if (type === 'Icon' && rest.icon) {
    const resolved = resolveIcon(rest.icon);
    if (resolved) {
      rest.icon = resolved;
    }
  }

  if (type === 'Text' && typeof rest.text === 'string') {
    rest.text = resolveTemplateString(rest.text);
  }

  const mergedChildren = [
    ...asChildren(child as JsonValue | undefined),
    ...asChildren(propChildren as JsonValue | undefined),
    ...children
      .map((item) => toNode(item))
      .filter((item): item is JsonNode => item !== undefined),
  ];

  const shouldUseChildrenArray = hasChildrenProp || isMultiChildType;

  if (mergedChildren.length === 0) {
    const serializedRest = Object.fromEntries(
      Object.entries(rest).map(([key, value]) => [key, resolveJsonValue(serializeJsonValue(value as JsonValue))]),
    ) as Record<string, JsonValue>;
    return decorateUiNode({ type, ...serializedRest } as JsonNode);
  }

  if (mergedChildren.length === 1 && !shouldUseChildrenArray) {
    const serializedRest = Object.fromEntries(
      Object.entries(rest).map(([key, value]) => [key, resolveJsonValue(serializeJsonValue(value as JsonValue))]),
    ) as Record<string, JsonValue>;
    return decorateUiNode({
      type,
      ...serializedRest,
      child: mergedChildren[0] as JsonValue,
    } as JsonNode);
  }

  const serializedRest = Object.fromEntries(
    Object.entries(rest).map(([key, value]) => [key, resolveJsonValue(serializeJsonValue(value as JsonValue))]),
  ) as Record<string, JsonValue>;

  return decorateUiNode({ type, ...serializedRest, children: mergedChildren } as JsonNode);
}

export const ui: UiFactory = Object.assign(buildUi, {
  getCallback(req: Request, res: Response, id: string): CallbackBuilder {
    return new CallbackBuilder(req, res, id);
  },
});

export function equate(
  variable: unknown,
  eq: JsonValue,
  props: UiProps = {},
  ...children: UiChild[]
): ConditionBuilder {
  return createConditionBuilder(variable, eq, props, ...children);
}

export function SnackBar(message: string): CallbackNode {
  return { snackbar: message };
}

export function notFound() {
  return (req: Request, res: Response): void => {
    const path = req.originalUrl || req.url;

    if (!path.startsWith('/ui/')) {
      res.status(404).json({
        error: 'Not Found',
        method: req.method,
        path,
      });
      return;
    }

    const screen = ui('Scaffold', {
      page: '.404',
      body: ui('Center', {
        child: ui('Padding', {
          padding: 16,
          child: ui('Center', {
            child: ui('SizedBox', {
              width: 300,
              height: 387,
              child: ui('Column', {
                crossAxis: 'center',
                children: [
                  ui('Icon', { icon: 'error_outline', size: 256, color: '#B42318' }),
                  ui('Text', { text: '404 Page Not Found', color: '#B42318', fontSize: 24 }),
                  ui('SizedBox', { height: 8 }),
                  ui('Text', { text: `Path: ${path}`, color: '#37474f' }),
                  ui('Text', { text: `Method: ${req.method}`, color: '#37474f' }),
                  ui('FilledButton', {
                    child: ui('Text', { text: 'Go Home' }),
                    onPressed: nav('/ui/main'), 
                  })
                ],
              })
            })
          }),
        }),
      }),
    });

    // Return 200 for /ui/* misses so Flutter can still render this schema page.
    sendUiResponse(res, screen, [SnackBar(`404: ${path}`)]);
  };
}

export function nav(path: string): string;
export function nav(path: string, mode: 'page' | 'dialog'): string | JsonNode;
export function nav(path: string, mode: 'page' | 'dialog' = 'page'): string | JsonNode {
  if (mode === 'dialog') {
    return {
      type: 'nav',
      path,
      mode,
    };
  }

  return `nav:${path}`;
}

export function navReplace(path: string): JsonNode;
export function navReplace(path: string, mode: 'page' | 'dialog'): JsonNode;
export function navReplace(
  path: string,
  mode: 'page' | 'dialog' = 'page',
): JsonNode {
  return {
    type: 'nav',
    path,
    mode,
    replace: true,
  };
}

export function WebViewCb(): WebViewCbBuilder {
  return new WebViewCbBuilder();
}

export function paym(
  gateway: string,
  callback: string,
  data: Record<string, JsonValue> = {},
): JsonNode {
  return {
    type: 'payment',
    gateway,
    callback,
    data,
  };
}

export function getPrefSyncCallbacks(): CallbackNode[] {
  const callbacks: CallbackNode[] = [];
  const allVars = getRuntimeVars();

  for (const [key, value] of Object.entries(allVars)) {
    if (key.startsWith('prefs.') && !key.endsWith('.isPresent')) {
      const prefName = key.substring(6);
      callbacks.push({
        setSharedPref: {
          name: prefName,
          value: value,
        },
      });
    }
  }

  return callbacks;
}

export function sendUiResponse(
  res: Response,
  screen: JsonNode,
  callbacks: CallbackNode[] = [],
): void {
  const prefCallbacks = getPrefSyncCallbacks();
  res.json({
    ...(screen as Record<string, JsonValue>),
    callbacks: [...callbacks, ...prefCallbacks],
    vars: getRuntimeVars(),
  });
}

export const remui = {
  notFound,
  ssr: createRemUiSsrMiddleware,
  sendBack,
};
