# Reef Server

## Deployment

- **Hetzner server**: `178.156.139.74`
- **SSH user**: `deploy`
- **Deploy command**: `./deploy.sh deploy@178.156.139.74`
- **Remote directory**: `/opt/reef`
- **Runtime**: Docker Compose

## Local Development

- **Start server**: `export $(grep -v '^#' .env | xargs) && uv run uvicorn api.index:app --host 0.0.0.0 --port 8000 --timeout-keep-alive 180` (must export .env manually — no dotenv autoloading)
- **Stop server**: `pkill -f uvicorn` (NEVER use `lsof -t :8000 | xargs kill` — it kills browsers too)
- **Run Python**: use `uv run python` (dependencies managed by uv, not global pip)
- **DB not required locally**: stroke-logs endpoints return 503 without DATABASE_URL, but WebSocket endpoints work fine
- **Mathpix optional**: transcription silently skipped if `MATHPIX_APP_ID/KEY` missing

## File Map — `api/`

| File | Endpoints | Purpose |
|------|-----------|---------|
| `index.py` | `/health`, `/ai/embed`, `/ai/annotate`, `/ai/group-problems`, `/ai/reconstruct`, `/ai/generate-quiz`, `/ai/documents/{filename}` | Main app + PDF reconstruction pipeline + quiz generation |
| `strokes.py` | `POST /api/strokes/connect`, `POST /api/strokes`, `POST /api/strokes/clear`, `POST /api/strokes/disconnect`, `GET /api/stroke-logs`, `DELETE /api/stroke-logs`, `GET /api/reasoning-logs`, `GET /api/page-transcription` | Stroke logging, transcription state |
| `voice.py` | `POST /api/voice/transcribe`, `POST /api/voice/question` | Voice transcription (Groq Whisper) + async question reasoning |
| `events.py` | `GET /api/events?session_id=...` (SSE) | Server→client push events (reasoning, TTS notifications) |
| `tts_stream.py` | `GET /api/tts/stream/{tts_id}` | Chunked HTTP PCM audio streaming (DeepInfra Kokoro) |
| `tts.py` | `WebSocket /ws/tts` | Streaming text-to-speech via Modal Kokoro (unused by iOS) |
| `reasoning.py` | (no endpoints) | `push_reasoning()` helper — registers TTS + publishes SSE event |
| `users.py` | `PUT/GET/DELETE /users/profile` | User profile management (Apple user ID) |

Each module uses `router = APIRouter()`, registered in `index.py` via `app.include_router()`.

## File Map — `lib/`

| File | Purpose |
|------|---------|
| `database.py` | PostgreSQL connection pool (asyncpg) + table initialization |
| `mathpix_client.py` | Handwriting transcription sessions (Mathpix API) + debounced whole-page transcribe + reason |
| `groq_transcribe.py` | Groq Whisper voice-to-text via OpenAI SDK |
| `llm_client.py` | OpenAI-compatible API wrapper (OpenRouter, Groq) + structured output |
| `tts_client.py` | Modal Kokoro TTS HTTP client (streaming PCM chunks) |
| `reasoning.py` | Adaptive tutoring feedback — decides speak/silent, produces TTS-ready coaching |
| `latex_compiler.py` | Tectonic LaTeX → PDF compilation with embedded images |
| `question_to_latex.py` | Converts structured Question objects → LaTeX body content |
| `embedding_client.py` | Modal MiniLM-L6-v2 embeddings (384-dim) |
| `surya_client.py` | Modal Surya layout detection (PDF → bounding boxes) |
| `region_extractor.py` | Extract answer region coordinates from compiled PDFs |
| `stroke_renderer.py` | Render stroke paths as SVG/PNG |
| `mock_responses.py` | Mock embeddings for testing |

## File Map — `lib/models/`

| File | Classes |
|------|---------|
| `embed.py` | `EmbedRequest`, `EmbedResponse` — text embedding API |
| `question.py` | `Part`, `Question`, `QuestionBatch` — structured question representation |
| `group_problems.py` | `ProblemGroup`, `GroupProblemsResponse` — PDF problem grouping |
| `quiz.py` | `QuizGenerationRequest`, `QuizQuestionResponse` — quiz generation |
| `user.py` | `UserProfileRequest`, `UserProfileResponse` — user profiles |

## Database Tables

All defined in `lib/database.py` → `init_db()`.

| Table | Purpose |
|-------|---------|
| `user_profiles` | Apple user accounts (apple_user_id PK, display_name, email) |
| `stroke_logs` | Raw stroke events from iOS (session_id, page, strokes JSONB, event_type) |
| `page_transcriptions` | Per-page Mathpix transcription (session_id, page, latex, text, confidence, line_data) |
| `reasoning_logs` | Tutor feedback history (action speak/silent, message, token counts, estimated_cost) |
| `documents` | Uploaded PDFs (filename, page_count, total_problems) |
| `questions` | Extracted homework problems (document_id FK, number, label, text, parts JSONB, bboxes JSONB) |
| `answer_keys` | Solution keys (question_id FK, part_label, answer) |
| `question_figures` | Figure images from PDF reconstruction (question_id FK, filename, image_b64) |
| `session_question_cache` | Cache: session → current question (session_id PK, question_id) |

## Key Data Flows

### Stroke Pipeline (draw → transcribe → reason)

```
iOS POST /api/strokes → stroke_logs table
  ↓ schedule_transcribe() (500ms debounce)
  ↓ hash visible strokes — skip Mathpix if unchanged
  ↓ Mathpix /v3/strokes (all visible strokes) → upsert page_transcriptions
  ↓ schedule_reasoning() (2.5s debounce)
  ↓ build_context() + reasoning model → speak/silent decision
  ↓ if "speak": register TTS text → publish SSE event with tts_id
  ↓ iOS fetches GET /api/tts/stream/{tts_id} → chunked PCM audio
```

### PDF Reconstruction Pipeline

```
POST /ai/reconstruct (PDF file)
  ↓ PyMuPDF render (192 DPI for Surya, 384 DPI for crops)
  ↓ Modal Surya layout detection → bounding boxes
  ↓ Gemini 3 Flash: group problems by annotation indices
  ↓ Gemini 3 Flash: extract questions per group (structured JSON)
  ↓ question_to_latex() → tectonic compile → per-problem PDFs
  ↓ parallel Gemini: generate answer keys
  ↓ merge PDFs → return final PDF + optional split mode
```

### Voice Transcription

```
iOS POST /api/voice/transcribe (multipart: audio + session_id + page)
  ↓ Groq Whisper transcribe → stroke_logs (event_type='voice')
  ↓ return {"transcription": "..."}

iOS POST /api/voice/question (multipart: audio + session_id + page)
  ↓ Groq Whisper transcribe → return transcription immediately
  ↓ async: run_question_reasoning() → push_reasoning()
  ↓ SSE event: {"action": "speak", "message": "...", "tts_id": "..."}
  ↓ iOS fetches GET /api/tts/stream/{tts_id} → chunked PCM audio
```

## External Services

| Service | Purpose | File |
|---------|---------|------|
| **OpenRouter** (Gemini 3 Flash Preview) | PDF grouping, question extraction, answer keys, quiz gen, LaTeX fixing | `api/index.py` |
| **Mathpix** | Handwriting transcription (whole-page, 5-min session TTL) | `lib/mathpix_client.py` |
| **Groq** (Whisper + reasoning model) | Voice transcription + adaptive tutoring | `lib/groq_transcribe.py`, `lib/reasoning.py` |
| **Modal** (GPU endpoints) | Surya layout (T4), Kokoro TTS (T4), MiniLM embeddings (CPU) | `lib/surya_client.py`, `lib/tts_client.py`, `lib/embedding_client.py` |
| **DeepInfra** (Kokoro 82M) | TTS for reasoning feedback | `api/reasoning.py` |

Modal deployments live in `modal/` — deploy with `modal deploy modal/<file>.py`.

## Environment Variables

```
OPENROUTER_API_KEY          # Gemini 3 Flash for PDF/quiz generation
DEEPINFRA_API_KEY           # Kokoro TTS (DeepInfra)
MATHPIX_APP_ID              # Handwriting transcription (optional)
MATHPIX_APP_KEY
GROQ_API_KEY                # Whisper voice transcription + reasoning model
ENVIRONMENT                 # "development" or "production"
DATABASE_URL                # PostgreSQL asyncpg format (optional locally)
MODAL_SURYA_URL             # Modal Surya layout detection endpoint
MODAL_TTS_URL               # Modal Kokoro TTS endpoint
MODAL_EMBED_URL             # Modal MiniLM embeddings endpoint
```

## Testing

- **Run all tests**: `uv run python -m pytest tests/ -q`
- **Unit only**: `uv run python -m pytest tests/unit/ -q` (fast, no DB needed)
- **Integration only**: `uv run python -m pytest tests/integration/ -q` (requires local PostgreSQL on localhost:5432)
- **E2E mode**: `REEF_TEST_MODE=e2e uv run python -m pytest tests/ -q` (real API calls, skips if keys missing)
- **Test count**: 193 tests (112 unit, 81 integration)
- **Fixtures**: `tests/integration/conftest.py` — creates/drops `reef_test` DB, provides `client` (TestClient with lifespan), `db` (direct asyncpg conn), `clean_state` (clears in-memory dicts)
- **Test fixtures**: `tests/fixtures/` — recorded API responses (JSON, SSE, binary PCM) for contract mode
- **Test helpers**: `tests/helpers.py` — `FakePool`/`FakeConn` (plain Python, not MagicMock), `load_fixture()`, response builders (`make_chat_completion`, `make_sse_stream`, `make_embed_response`)
- **Async gotcha**: Never `await` app-level async functions (build_context, run_reasoning) directly from `@pytest.mark.anyio` tests — the app's asyncpg pool is on the TestClient's event loop, not the test's. Instead: test through HTTP endpoints, or `monkeypatch.setattr` `build_context`/`get_pool` and use `asyncio.run()` in sync tests.
- **No unittest.mock**: Zero `unittest.mock` imports. Use `respx` (httpx interceptor for OpenAI SDK, Mathpix), `responses` (requests interceptor for Modal TTS/Embeddings), and `monkeypatch.setattr` (pytest-native) sparingly for function replacement.
- **Toggle**: `REEF_TEST_MODE` env var (`contract` default, `e2e` for real APIs). Contract mode sets placeholder API keys in `tests/conftest.py`.

## Implementation Notes

- **Debouncing**: transcription 500ms, reasoning 2.5s — both use asyncio.Task cancellation in `mathpix_client.py`
- **Skip-if-unchanged**: SHA-256 hash of visible stroke set avoids redundant Mathpix calls
- **Erase events reset canvas**: stroke_logs with event_type='erase' replaces all visible strokes
- **Content type detection**: from Mathpix line_data — "chemistry" if diagram+chemistry subtype, "diagram" if diagram, "math" default, fallback to "diagram" if error/low confidence
- **LaTeX fixing**: one retry attempt via Gemini if tectonic compile fails
- **Orphaned figures**: automatically assigned to nearest problem by centroid distance
- **WebSocket /ws/reasoning**: server-push only — iOS does NOT send data on this socket
