# remui_x

RemUI demo workspace with:

- Bun + Express backend schema routes
- Flutter runtime renderer (`remx`) with JSON widget registry
- Callback bridge (`/ui/callbacks`) with vars and shared preferences
- Rich navigation widgets: `Sidebar`, `SidebarWithUI`, `BottomNavigationBar`, `NavigationRail`

## Install

```bash
bun install
```

## Run Backend

```bash
bun run index.ts
```

## Run Flutter Client

```bash
cd remx
flutter run
```

## Docs

- `docs/remui.html` - Architecture + DSL guide
- `docs/widgets.html` - Widget schema reference (including Sidebar + NavigationRail)

This project was created using `bun init` in bun v1.3.13. [Bun](https://bun.com) is a fast all-in-one JavaScript runtime.
