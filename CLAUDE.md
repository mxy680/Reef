# Reef

## Workflow

- After finishing any implementation, always run the full test suite before reporting completion:
  `xcodebuild -project Reef-iOS/Reef.xcodeproj -scheme Reef -destination 'platform=iOS Simulator,name=iPad Pro 11-inch (M4)' test 2>&1 | grep -E '(passed|failed|error:)'`

## Directory Map

```
Reef/
├── Reef-Server/    — Python FastAPI backend (submodule) → see Reef-Server/CLAUDE.md
├── Reef-iOS/       — iPad SwiftUI app (submodule) → see Reef-iOS/CLAUDE.md
├── Reef-Web/       — Next.js landing page (submodule)
├── Reef-Document/  — Document processing (submodule)
├── test-ios/       — Appium iOS Simulator testing (helper script + venv)
└── docs/plans/     — Design docs (gitignored, local only)
```

## iOS (Reef-iOS)

- SourceKit errors about macOS unavailability (AVAudioSession, UIColor, etc.) are noise — this is an iPad-only app
- SourceKit "Cannot find X in scope" for types like KeychainService, CanvasViewMode, FileStorageService are indexing issues, not real errors
- Swift struct initializer arguments MUST match declaration order — check the struct's property list before adding new parameters
- `AIService` is `@MainActor` singleton; stroke data sent via fire-and-forget REST POSTs (no WebSocket)
- Debug base URL: `https://dev.studyreef.com` (Hetzner host:8001), release: `https://api.studyreef.com` (Hetzner Docker prod) — see `ServerConfig.swift`
- **SSH tunnel must bind `0.0.0.0`**: `ssh -R 0.0.0.0:8001:localhost:8000 deploy@178.156.139.74 -N -f` — Caddy is in Docker, reaches host via bridge IP `172.18.0.1`, so `localhost` binding causes 502s
- **SSE gotcha**: `URLSession.AsyncBytes.lines` does NOT reliably yield empty lines at HTTP chunk boundaries. Don't wait for the `\n\n` terminator to dispatch events — dispatch on `data:` line instead (see `docs/2026-02-18-sse-ios-buffering-fix.md`)
- **Active part detection**: `DrawingOverlayView.Coordinator.detectActivePart(for:)` maps canvas Y → PDF Y using `regionData.pageHeights`. Canvas bounds ≈ PDF points (2x render / 2x screen scale = 1:1). `SubquestionRegion.page` is 0-indexed, `getPageIndex` returns 1-based

## Server (Reef-Server)

- Always restart the local dev server after making changes to Reef-Server code — do this BEFORE running tests, not after
- **Reasoning model**: Qwen3 VL 235B via OpenRouter (`qwen/qwen3-vl-235b-a22b-instruct`) with structured JSON output + streaming early-exit. Uses `OPENROUTER_API_KEY`. Single model for both text and image reasoning. GPT-4o (`openai/gpt-4o`) used as timeout fallback for voice questions only. See `docs/plans/2026-02-25-model-benchmark.json`.
- **Streaming early-exit**: `run_reasoning()` streams responses and detects "silent" action from partial JSON, breaking immediately (~70-80% of calls). 8s hard timeout defaults to silent. Provider routing (`sort: latency`) mitigates OpenRouter GPU lottery.
- `reasoning_logs` table must be cleared alongside `stroke_logs` on any delete/clear operation
- Transcription is whole-page: all visible strokes sent to Mathpix in one request, result stored in `page_transcriptions`. No clustering.
- Reasoning output sent to iOS via SSE `event: reasoning` with `tts_id` for audio — only when action is "speak"
- Server→client push uses SSE (`GET /api/events`), not WebSockets. Voice uses REST POST (`/api/voice/question`). TTS uses chunked HTTP (`GET /api/tts/stream/{tts_id}`)
- **Per-part reasoning**: `_active_sessions` stores `active_part` (from iOS `part_label`). `build_context` scopes answer keys to the active part, shows earlier parts as reference, hides later parts. `_get_part_order` / `_is_later_part` helpers in `lib/reasoning.py`
- **Diagram tool**: `_active_sessions` stores `content_mode` ("math" or "diagram"). When "diagram", `_debounced_transcribe` skips Mathpix entirely, upserts empty `page_transcriptions`, and schedules reasoning directly. `build_context` renders strokes to PNG via `stroke_renderer.py` and sends to Qwen VL as an image. iOS sends `content_mode: "diagram"` in stroke POST when diagram tool is selected (`CanvasTool.diagram`).
- **Erase awareness**: `_erase_snapshots` in `mathpix_client.py` (deque, max 3) captures pre-erase `page_transcriptions.text` each time an erase event is detected. `build_context` includes these in a "Previously Erased Work" section so the reasoning model can detect patterns like erasing correct work. Ephemeral in-memory state, cleaned up by `invalidate_session`/`cleanup_sessions`.
- **Delay-based speak**: `_pending_speak` in `mathpix_client.py` holds speak messages with `delay_ms > 0`. If new strokes arrive (triggering `schedule_reasoning`), the pending message is cancelled. After the delay, it's pushed as a normal `speak` SSE. Model returns structured JSON `{"action": "speak"|"silent", "message": "...", "delay_ms": N}`. iOS sees no change — only `speak` events reach the client.

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
