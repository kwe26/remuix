/**
 * remui_icons.ts
 *
 * Material Design Icons Library Management (~7999 icons)
 * - Loads icons from Flutter's Material Icons repository
 * - Provides lookup utilities
 * - Generates interactive HTML documentation
 */

export interface IconEntry {
  name: string;
  codepoint: string; // Format: "M:0x..."
}

export interface IconLibrary {
  total: number;
  icons: Map<string, string>;
  loadedAt: Date | null;
}

class MaterialIconsStore implements IconLibrary {
  total: number = 0;
  icons: Map<string, string> = new Map(); // name (lowercase) -> "M:0xXXXXX"
  byCodepoint: Map<string, string> = new Map(); // "M:0xXXXXX" -> name
  loadedAt: Date | null = null;
  private isLoading = false;
  private loadPromise: Promise<void> | null = null;

  async load(): Promise<void> {
    if (this.isLoading) {
      return this.loadPromise ?? Promise.resolve();
    }

    if (this.loadedAt !== null) {
      return;
    }

    this.isLoading = true;
    this.loadPromise = this._performLoad();
    await this.loadPromise;
    this.isLoading = false;
  }

  private async _performLoad(): Promise<void> {
    try {
      const response = await fetch(
        'https://raw.githubusercontent.com/flutter/flutter/master/packages/flutter/lib/src/material/icons.dart',
      );

      if (!response.ok) {
        throw new Error(`Failed to fetch Flutter icons.dart (${response.status})`);
      }

      const text = await response.text();
      const iconRegex =
        /static const IconData\s+([a-zA-Z0-9_]+)\s*=\s*IconData\((0x[0-9a-fA-F]+),\s*fontFamily:\s*['"]MaterialIcons['"]|static const IconData ([a-zA-Z0-9_]+)\s*=\s*const IconData\((0x[0-9a-fA-F]+),\s*fontFamily:\s*['"]MaterialIcons['"]|static const IconData\s+(\w+)\s*=\s*IconData\(0x([0-9a-fA-F]+),/gm;

      let count = 0;
      let match;
      
      while ((match = iconRegex.exec(text)) !== null) {
        // Handle different regex capture group patterns
        const name = (match[1] || match[3] || match[5] || '').trim();
        let hex = (match[2] || match[4] || match[6] || '').trim();
        
        if (!name || !hex) continue;
        
        // Normalize hex format
        if (!hex.startsWith('0x')) {
          hex = '0x' + hex;
        }

        const normalized = `M:${hex.toUpperCase()}`;
        const lowerName = name.toLowerCase();

        this.icons.set(lowerName, normalized);
        this.byCodepoint.set(normalized, lowerName);
        count++;
      }

      this.total = count;
      this.loadedAt = new Date();
      console.log(`✓ Loaded ${count} Material Icons`);
      
      if (count === 0) {
        console.warn('⚠ No icons found in Flutter icons.dart. Check regex pattern.');
      }
    } catch (error) {
      console.error('✗ Failed to load Material Icons:', error);
    }
  }

  getByName(name: string): string | null {
    return this.icons.get(name.toLowerCase().trim()) ?? null;
  }

  getNameByCodepoint(cp: string): string | null {
    return this.byCodepoint.get(cp.toUpperCase()) ?? null;
  }

  getAllEntries(): IconEntry[] {
    return Array.from(this.icons.entries()).map(([name, codepoint]) => ({
      name,
      codepoint,
    }));
  }
}

const iconStore = new MaterialIconsStore();

/**
 * Initialize the Material Icons library
 */
export async function initializeMaterialIcons(): Promise<void> {
  await iconStore.load();
}

/**
 * Get the icons library
 */
export function getIconLibrary(): IconLibrary {
  return iconStore;
}

/**
 * Resolve icon to codepoint
 */
export function resolveIconToCodepoint(value: unknown): string | null {
  if (!value) return null;

  if (typeof value === 'string') {
    const trimmed = value.trim();

    // Try direct name lookup first
    const byName = iconStore.getByName(trimmed);
    if (byName) return byName;

    // Try parsing as codepoint
    if (trimmed.startsWith('M:')) {
      return trimmed.toUpperCase();
    }

    if (trimmed.startsWith('0x')) {
      return `M:${trimmed.toUpperCase()}`;
    }

    return null;
  }

  if (typeof value === 'number') {
    return `M:0x${value.toString(16).toUpperCase()}`;
  }

  return null;
}

/**
 * Get icon by name
 */
export function getIconByName(name: string): IconEntry | null {
  const cp = iconStore.getByName(name);
  return cp ? { name: name.toLowerCase(), codepoint: cp } : null;
}

/**
 * Search icons by query
 */
export function searchIcons(query: string, limit = 100): IconEntry[] {
  const q = query.toLowerCase();
  const results: IconEntry[] = [];

  for (const [name, cp] of iconStore.icons.entries()) {
    if (name.includes(q)) {
      results.push({ name, codepoint: cp });
      if (results.length >= limit) break;
    }
  }

  return results;
}

/**
 * Get all icons
 */
export function getAllIcons(limit?: number): IconEntry[] {
  const entries = iconStore.getAllEntries();
  return limit ? entries.slice(0, limit) : entries;
}

/**
 * Generate interactive HTML documentation for all icons
 */
export function generateIconsHtml(): string {
  const entries = iconStore.getAllEntries();
  const iconRows = entries
    .map(
      ({ name, codepoint }) => `
    <div class="icon-item" data-name="${name}" data-codepoint="${codepoint}">
      <div class="icon-display">
        <span class="material-icon" style="font-size: 48px;">&#x${codepoint.slice(2)};}</span>
      </div>
      <div class="icon-info">
        <div class="icon-name">${name}</div>
        <div class="icon-codepoint">${codepoint}</div>
      </div>
    </div>
  `,
    )
    .join('\n');

  return `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Material Icons Library (${entries.length} icons)</title>
  <link href="https://fonts.googleapis.com/css2?family=Roboto:wght@400;500;700&display=swap" rel="stylesheet">
  <link href="https://fonts.googleapis.com/icon?family=Material+Icons" rel="stylesheet">
  <style>
    * {
      margin: 0;
      padding: 0;
      box-sizing: border-box;
    }

    html, body {
      font-family: 'Roboto', sans-serif;
      background: linear-gradient(135deg, #f5f1e8 0%, #fffcf7 100%);
      color: #16202f;
    }

    body {
      padding: 24px;
      min-height: 100vh;
    }

    .container {
      max-width: 1400px;
      margin: 0 auto;
    }

    header {
      background: white;
      border-radius: 24px;
      padding: 32px;
      margin-bottom: 32px;
      box-shadow: 0 2px 12px rgba(0, 0, 0, 0.08);
      border: 1px solid #e9ded0;
    }

    h1 {
      font-size: 32px;
      font-weight: 700;
      margin-bottom: 12px;
      color: #153a7a;
    }

    .stats {
      display: flex;
      gap: 32px;
      margin-top: 20px;
      flex-wrap: wrap;
    }

    .stat {
      display: flex;
      flex-direction: column;
    }

    .stat-label {
      font-size: 12px;
      font-weight: 600;
      color: #5a6676;
      text-transform: uppercase;
      letter-spacing: 0.5px;
    }

    .stat-value {
      font-size: 24px;
      font-weight: 700;
      color: #153a7a;
      margin-top: 4px;
    }

    .search-box {
      background: white;
      border-radius: 18px;
      padding: 16px 20px;
      margin-bottom: 32px;
      border: 2px solid #e9ded0;
      display: flex;
      align-items: center;
      gap: 12px;
      transition: border-color 0.2s;
    }

    .search-box:focus-within {
      border-color: #153a7a;
      box-shadow: 0 4px 16px rgba(21, 58, 122, 0.1);
    }

    .search-box i {
      color: #b45309;
      font-size: 20px;
    }

    #search-input {
      flex: 1;
      border: none;
      outline: none;
      font-size: 16px;
      color: #16202f;
    }

    #search-input::placeholder {
      color: #5a6676;
    }

    .results-info {
      margin-bottom: 16px;
      padding: 12px 16px;
      background: #dce7ff;
      border-radius: 12px;
      color: #153a7a;
      font-size: 14px;
      font-weight: 500;
      display: none;
    }

    .results-info.show {
      display: block;
    }

    .icons-grid {
      display: grid;
      grid-template-columns: repeat(auto-fill, minmax(120px, 1fr));
      gap: 16px;
      animation: fadeIn 0.3s ease-in;
    }

    @keyframes fadeIn {
      from {
        opacity: 0;
        transform: translateY(4px);
      }
      to {
        opacity: 1;
        transform: translateY(0);
      }
    }

    .icon-item {
      background: white;
      border: 1px solid #e9ded0;
      border-radius: 16px;
      padding: 16px;
      display: flex;
      flex-direction: column;
      align-items: center;
      gap: 12px;
      cursor: pointer;
      transition: all 0.2s;
      text-align: center;
    }

    .icon-item:hover {
      background: #fffcf7;
      border-color: #153a7a;
      transform: translateY(-2px);
      box-shadow: 0 4px 16px rgba(21, 58, 122, 0.12);
    }

    .icon-display {
      display: flex;
      align-items: center;
      justify-content: center;
      height: 60px;
      width: 100%;
    }

    .icon-display .material-icon {
      color: #153a7a;
      transition: transform 0.2s;
    }

    .icon-item:hover .material-icon {
      transform: scale(1.1);
    }

    .icon-info {
      width: 100%;
      min-height: 50px;
      display: flex;
      flex-direction: column;
      justify-content: center;
    }

    .icon-name {
      font-size: 12px;
      font-weight: 600;
      color: #16202f;
      word-break: break-word;
      line-height: 1.3;
    }

    .icon-codepoint {
      font-size: 10px;
      color: #5a6676;
      font-family: 'Courier New', monospace;
      margin-top: 4px;
    }

    .no-results {
      text-align: center;
      padding: 60px 20px;
      color: #5a6676;
    }

    .no-results i {
      font-size: 64px;
      color: #b45309;
      display: block;
      margin-bottom: 16px;
    }

    .no-results p {
      font-size: 18px;
    }

    footer {
      text-align: center;
      margin-top: 48px;
      padding: 24px;
      color: #5a6676;
      font-size: 13px;
    }

    @media (max-width: 768px) {
      .icons-grid {
        grid-template-columns: repeat(auto-fill, minmax(100px, 1fr));
        gap: 12px;
      }

      header {
        padding: 20px;
      }

      h1 {
        font-size: 24px;
      }

      .stats {
        gap: 20px;
      }
    }
  </style>
</head>
<body>
  <div class="container">
    <header>
      <h1>Material Design Icons</h1>
      <p style="color: #5a6676; margin: 8px 0 0 0; font-size: 15px;">Flutter's comprehensive Material Icons library</p>
      <div class="stats">
        <div class="stat">
          <span class="stat-label">Total Icons</span>
          <span class="stat-value">${entries.length.toLocaleString()}</span>
        </div>
        <div class="stat">
          <span class="stat-label">Loaded At</span>
          <span class="stat-value">${
            iconStore.loadedAt
              ? iconStore.loadedAt.toLocaleString('en-US', {
                  year: 'numeric',
                  month: 'short',
                  day: 'numeric',
                  hour: '2-digit',
                  minute: '2-digit',
                })
              : 'N/A'
          }</span>
        </div>
      </div>
    </header>

    <div class="search-box">
      <i class="material-icons">search</i>
      <input
        type="text"
        id="search-input"
        placeholder="Search icons (e.g., home, settings, favorite)..."
        autocomplete="off"
      />
    </div>

    <div id="results-info" class="results-info"></div>

    <div id="icons-grid" class="icons-grid">
      ${iconRows}
    </div>

    <div id="no-results" class="no-results" style="display: none;">
      <i class="material-icons">search_off</i>
      <p>No icons found. Try a different search term.</p>
    </div>
  </div>

  <footer>
    <p>Material Design Icons sourced from <a href="https://github.com/flutter/flutter" style="color: #153a7a; text-decoration: none;">Flutter</a></p>
    <p>Interactive documentation powered by RemUI</p>
  </footer>

  <script>
    const searchInput = document.getElementById('search-input');
    const iconGrid = document.getElementById('icons-grid');
    const noResults = document.getElementById('no-results');
    const resultsInfo = document.getElementById('results-info');
    const allItems = Array.from(document.querySelectorAll('.icon-item'));

    function filterIcons(query) {
      const q = query.toLowerCase().trim();
      let visibleCount = 0;

      allItems.forEach((item) => {
        const name = item.dataset.name.toLowerCase();
        const codepoint = item.dataset.codepoint.toLowerCase();

        if (q === '' || name.includes(q) || codepoint.includes(q)) {
          item.style.display = '';
          visibleCount++;
        } else {
          item.style.display = 'none';
        }
      });

      if (visibleCount === 0) {
        iconGrid.style.display = 'none';
        noResults.style.display = 'block';
        resultsInfo.classList.remove('show');
      } else {
        iconGrid.style.display = 'grid';
        noResults.style.display = 'none';
        if (q) {
          resultsInfo.textContent = \`Found \${visibleCount} icon\${visibleCount !== 1 ? 's' : ''}\`;
          resultsInfo.classList.add('show');
        } else {
          resultsInfo.classList.remove('show');
        }
      }
    }

    searchInput.addEventListener('input', (e) => {
      filterIcons(e.target.value);
    });

    // Copy to clipboard on icon click
    allItems.forEach((item) => {
      item.addEventListener('click', () => {
        const name = item.dataset.name;
        navigator.clipboard.writeText(name).then(() => {
          const original = item.style.background;
          item.style.background = '#dce7ff';
          setTimeout(() => {
            item.style.background = original;
          }, 200);
        });
      });
    });

    // Initial display
    filterIcons('');
  </script>
</body>
</html>
`;
}
