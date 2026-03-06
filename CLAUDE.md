# Reef

## Directory Map

```
Reef/
├── Reef-iOS/       — iPad SwiftUI app (iOS 18.2+, Supabase auth)
├── Reef-Web/       — Next.js landing page + document processing
├── Reef-Server/    — FastAPI backend (Python 3.12, Docker, Hetzner)
└── docs/plans/     — Design docs (gitignored, local only)
```

## Web (Reef-Web)

- **NEVER kill processes on port 3000** (or any port) — the user runs their own dev server and browser. Only make code changes; don't start/stop/restart servers.
- Framer components use `WithFramerBreakpoints` with `variants` prop for responsive rendering (Phone/Tablet/Desktop). The `defaultResponsiveVariants` in Framer files are empty `{}` — pass variants from `page.tsx`.
- Framer components have fixed pixel widths (350px, 600px, 1200px etc.) that must be overridden with `!important` in `globals.css` for mobile.
- No Tailwind — all styling is plain CSS with custom properties in `globals.css`.

## Environment Files

- `.env` files are **symlinked** to `~/.config/reef/` so they're shared across all worktrees/workspaces.
- After creating a new worktree, run `./scripts/link-env.sh` to set up the symlinks.
- Shared files: `~/.config/reef/server.env` (Reef-Server) and `~/.config/reef/web.env.local` (Reef-Web).
- To add a new env var, edit the shared file directly — it takes effect in all worktrees immediately.

## Server (Reef-Server)

- **Python 3.12 + FastAPI** with uvicorn/gunicorn
- Auth: Verifies Supabase JWTs (RS256) via JWKS endpoint — no secret needed
- WebSocket: Single connection per user, token passed as query param `?token=`
- Deploy: Docker Compose + Caddy reverse proxy on Hetzner (`api.studyreef.com`)
- Do NOT run `docker compose up` or `uvicorn` without explicit user permission.

## iOS (Reef-iOS)

- **3D border clipping**: Cards with 3D shadow offsets (e.g. `DocumentCardView` uses 4pt, `DashboardCard` uses 3pt) will get clipped by parent `clipShape`. Any `ScrollView` or container holding these cards must add `.padding([.trailing, .bottom], N)` on the grid/content to leave room for the shadow offset. Check this whenever adding new grids with 3D-bordered cards.
- **fullScreenCover safe area on iPad**: `.background().ignoresSafeArea()` does NOT reliably color the camera housing region on real iPad hardware (works on simulator). The UIKit container views behind the fullScreenCover have opaque black backgrounds. Fix: use a `UIViewRepresentable` that walks up `superview` chain and sets `backgroundColor` on all ancestors. See `ContainerBackgroundSetter` in `DocumentCanvasView.swift`.
- **3D shadows over UIKit views**: `.background().offset()` renders behind UIKit `UIViewRepresentable` views (e.g., PDFView). Use ZStack siblings for the shadow layer instead. See `CanvasCardModifier`.
- **iPad device screenshots**: Use `pymobiledevice3` (`pipx install pymobiledevice3`). Requires `sudo pymobiledevice3 remote start-tunnel`, then `pymobiledevice3 developer dvt screenshot --rsd <host> <port> /path/to/output.png`.
- **Bundle ID**: `com.studyreef.app` (not `com.reef.study`).
- **Popups/modals**: Always use screen-centered overlay popups in the root `DashboardView` ZStack — never `.sheet()` or `.overlay{}` on child views. Pattern: dimmed `Color.black.opacity(0.3)` backdrop with `.ignoresSafeArea()` + `.onTapGesture` to dismiss, popup view with `.transition(.scale(scale: 0.95).combined(with: .opacity))`, and `.animation(.spring(duration: 0.2), value:)` on the ZStack. Popup styling: white background, `RoundedRectangle(cornerRadius: 16)` clip, 2pt black stroke, 4pt offset 3D shadow, `.frame(maxWidth: 400)`. See `TutorQuizPopup` and `DeleteConfirmSheet` for reference.
