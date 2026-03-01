# Reef

## Directory Map

```
Reef/
├── Reef-iOS/       — iPad SwiftUI app (iOS 18.2+, Supabase auth)
├── Reef-Web/       — Next.js landing page + document processing
└── docs/plans/     — Design docs (gitignored, local only)
```

## Web (Reef-Web)

- **NEVER kill processes on port 3000** (or any port) — the user runs their own dev server and browser. Only make code changes; don't start/stop/restart servers.
- Framer components use `WithFramerBreakpoints` with `variants` prop for responsive rendering (Phone/Tablet/Desktop). The `defaultResponsiveVariants` in Framer files are empty `{}` — pass variants from `page.tsx`.
- Framer components have fixed pixel widths (350px, 600px, 1200px etc.) that must be overridden with `!important` in `globals.css` for mobile.
- No Tailwind — all styling is plain CSS with custom properties in `globals.css`.
