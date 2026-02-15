# Reef

## Project Structure

- `Reef-Server/` — Python FastAPI backend (git submodule)
- `Reef-iOS/` — iPad app in Swift/SwiftUI (git submodule)
- `dashboard/` — Next.js debug dashboard (gitignored, local only)
- `docs/plans/` — Design docs and implementation plans

## iOS (Reef-iOS)

- SourceKit errors about macOS unavailability (AVAudioSession, UIColor, etc.) are noise — this is an iPad-only app
- SourceKit "Cannot find X in scope" for types like KeychainService, CanvasViewMode, FileStorageService are indexing issues, not real errors
- Swift struct initializer arguments MUST match declaration order — check the struct's property list before adding new parameters
- `AIService` is `@MainActor` singleton; WebSocket send callbacks run off main thread
- Debug base URL: `http://172.20.87.11:8000` (Tailscale), release: `https://api.studyreef.com`

## Server

- Always restart the local dev server after making changes to Reef-Server code
- `clusters` table must be cleared alongside `stroke_logs` on any delete/clear operation
- Token usage is tracked in-memory per session via `_session_usage` in `stroke_clustering.py` — resets on server restart
- API response includes `cluster_order` (sorted by centroid_y for reading order), `problem_context`, and `usage`
- Transcription uses Gemini 3 Flash Preview via OpenRouter (single-stage, replaced Groq Maverick+Llama 3.3)
- Reasoning uses Gemini 2.5 Flash Preview via OpenRouter — free-form text output for TTS (adaptive coaching, not structured JSON)
- Reasoning triggers after transcription completes (sequence-counter debounce with 2.5s delay in `_cluster_then_reason`)
- Reasoning output sent to iOS via WebSocket `{"type": "reasoning", "message": "..."}` — only when action is "speak"
- `reasoning_logs` table must be cleared alongside `stroke_logs` and `clusters` on any delete/clear operation
- Document upload stores questions + bounding boxes in `documents`/`questions` tables, generates answer keys via parallel Gemini calls into `answer_keys` table

## Dashboard

- Event deltas (per-log snapshots) are immutable once recorded — never overwrite with live data
- Diagrams show `[diagram in C{n}]` in timeline/table, not raw TikZ
- `resetPromptState()` must clear ALL state: transcriptions, contentTypes, clusterOrder, usage, problemContext, eventDeltas

## Submodules

- Commit inside each submodule first, then `git add <submodule>` in parent repo
- `dashboard/` is gitignored — changes there are local only, don't try to `git add` it
