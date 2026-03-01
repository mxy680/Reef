# Reef

## Directory Map

```
Reef/
├── Reef-iOS/       — iPad SwiftUI app (iOS 18.2+, Supabase auth)
├── Reef-Server/    — Python FastAPI backend → see Reef-Server/CLAUDE.md
├── Reef-Web/       — Next.js landing page + document processing
└── docs/plans/     — Design docs (gitignored, local only)
```

## Web (Reef-Web)

- **NEVER kill processes on port 3000** (or any port) — the user runs their own dev server and browser. Only make code changes; don't start/stop/restart servers.
- Framer components use `WithFramerBreakpoints` with `variants` prop for responsive rendering (Phone/Tablet/Desktop). The `defaultResponsiveVariants` in Framer files are empty `{}` — pass variants from `page.tsx`.
- Framer components have fixed pixel widths (350px, 600px, 1200px etc.) that must be overridden with `!important` in `globals.css` for mobile.
- No Tailwind — all styling is plain CSS with custom properties in `globals.css`.

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

