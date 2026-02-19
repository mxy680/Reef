# Reef

## Directory Map

```
Reef/
├── Reef-Server/    — Python FastAPI backend (submodule) → see Reef-Server/CLAUDE.md
├── Reef-iOS/       — iPad SwiftUI app (submodule) → see Reef-iOS/CLAUDE.md
├── dashboard/      — Next.js debug dashboard (gitignored, local only)
├── test-ios/       — Appium iOS Simulator testing (helper script + venv)
├── docs/plans/     — Design docs and implementation plans
├── mathpix/        — Mathpix test scripts (one-off)
└── tts-demo/       — TTS experiment (unused)
```

## iOS (Reef-iOS)

- SourceKit errors about macOS unavailability (AVAudioSession, UIColor, etc.) are noise — this is an iPad-only app
- SourceKit "Cannot find X in scope" for types like KeychainService, CanvasViewMode, FileStorageService are indexing issues, not real errors
- Swift struct initializer arguments MUST match declaration order — check the struct's property list before adding new parameters
- `AIService` is `@MainActor` singleton; stroke data sent via fire-and-forget REST POSTs (no WebSocket)
- Debug base URL: local IP (check `AIService.swift`), release: `https://api.studyreef.com`
- **SSE gotcha**: `URLSession.AsyncBytes.lines` does NOT reliably yield empty lines at HTTP chunk boundaries. Don't wait for the `\n\n` terminator to dispatch events — dispatch on `data:` line instead (see `docs/2026-02-18-sse-ios-buffering-fix.md`)

## Server (Reef-Server)

- Always restart the local dev server after making changes to Reef-Server code
- `reasoning_logs` table must be cleared alongside `stroke_logs` on any delete/clear operation
- Transcription is whole-page: all visible strokes sent to Mathpix in one request, result stored in `page_transcriptions`. No clustering.
- Reasoning output sent to iOS via SSE `event: reasoning` with `tts_id` for audio — only when action is "speak"
- Server→client push uses SSE (`GET /api/events`), not WebSockets. Voice uses REST POST (`/api/voice/question`). TTS uses chunked HTTP (`GET /api/tts/stream/{tts_id}`)

## Dashboard

- **NEVER use `lsof -ti:<port> | xargs kill`** — this kills Firefox and other apps. To restart the dashboard, kill the specific `next dev` process by PID (`pgrep -f "next dev"`) or Ctrl+C the background task
- Dashboard `.env.local` must use `http://localhost:8000` — NOT external URLs. Browser CORS blocks cross-origin requests
- Always verify changes work by checking the browser console for errors, not just that the page loads
- Event deltas (per-log snapshots) are immutable once recorded — never overwrite with live data
- Diagrams show `[diagram]` in timeline/table, not raw TikZ
- `resetPromptState()` must clear ALL state: transcriptions, usage, problemContext, eventDeltas

## Appium iOS Testing (test-ios/)

- Helper script: `python3 test-ios/appium_helper.py <command>`
- Commands: `start`, `snapshot`, `screenshot <file>`, `tap <id>`, `type <id> <text>`, `swipe <dir>`, `stop`
- `start` boots the iPad Pro 11" simulator, launches Appium, and creates a session — run once per testing session
- `snapshot` returns the XML UI tree (equivalent to Playwright's `browser_snapshot`)
- Uses a venv at `test-ios/.venv` for the Appium Python client — the script auto-switches to it
- Appium 2.19.0 with xcuitest driver 7.35.1; state saved in `test-ios/.appium_state.json`
- App must be built for simulator first: `xcodebuild -project Reef-iOS/Reef.xcodeproj -scheme Reef -configuration Debug -derivedDataPath Reef-iOS/DerivedData -sdk iphonesimulator -arch arm64 build`
- System dialogs (e.g. Apple sign-in) are outside the app's view hierarchy and won't appear in `snapshot`
- Always `stop` when done to kill Appium server and free the session

## Submodules

- Commit inside each submodule first, then `git add <submodule>` in parent repo
- `dashboard/` is gitignored — changes there are local only, don't try to `git add` it
