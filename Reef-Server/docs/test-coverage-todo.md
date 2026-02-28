# Test Coverage Todo

81 tests today (52 unit, 21 integration, 8 API). This document catalogs every testable surface and organizes missing coverage into three tiers.

---

## Current Coverage (81 tests)

### Unit (52 tests)

| File | Tests | What it covers |
|------|------:|----------------|
| `test_question_to_latex.py` | 27 | `_fix_json_latex_escapes`, `_sanitize_text`, `_render_figures`, `_render_part`, `question_to_latex`, `quiz_question_to_latex` |
| `test_make_strict.py` | 7 | `_make_strict` — flat, nested, array, `$ref`, `anyOf`, `$defs`, immutability |
| `test_split_sentences.py` | 7 | `_split_sentences` — delimiters, empty, whitespace, trailing punct |
| `test_flush_sentences.py` | 6 | `_flush_sentences` — sentence boundaries, empty, trailing space, `?` boundary |
| `test_get_user_id.py` | 5 | `_get_user_id` — bearer parsing, invalid prefix, empty, whitespace |

### Integration (21 tests)

| File | Tests | What it covers |
|------|------:|----------------|
| `test_strokes_api.py` | 6 | `POST /api/strokes/connect` (insert, metadata, eviction), `POST /api/strokes`, `POST /api/strokes/clear`, `POST /api/strokes/disconnect` |
| `test_users_api.py` | 6 | `PUT/GET/DELETE /users/profile` — CRUD, upsert coalesce, 404, 401 |
| `test_tts_registry.py` | 6 | `register_tts`, `register_tts_stream`, `cleanup_stale_tts` |
| `test_events_api.py` | 3 | `publish_event` fanout — 0, 1, N subscribers |

### API (8 tests)

| File | Tests | What it covers |
|------|------:|----------------|
| `test_api.py` | 8 | `GET /health` (2), `POST /ai/embed?mode=mock` (6) — single, batch, normalization, validation |

---

## Tier 1 — DB-only / Pure (no external services)

Tests that can run today with just PostgreSQL. No mocking infrastructure needed.

### Endpoints

#### `GET /api/stroke-logs` — stroke history retrieval
- [ ] Filter by `session_id` returns only that session's logs
- [ ] Filter by `page` within a session
- [ ] `limit` caps row count
- [ ] Default ordering (newest first)
- [ ] Empty result when session has no logs
- [ ] Response includes joined `page_transcriptions` data when present

#### `DELETE /api/stroke-logs` — log cleanup
- [ ] Delete by `session_id` removes only that session
- [ ] Delete all (no filter) clears everything
- [ ] Cascades to `page_transcriptions` for deleted sessions
- [ ] Cascades to `reasoning_logs` for deleted sessions
- [ ] Returns count of deleted rows

#### `GET /api/reasoning-logs` — tutor feedback history
- [ ] Retrieve logs for a session with usage aggregation (token counts, cost)
- [ ] Empty session returns empty list
- [ ] `limit` caps row count
- [ ] Logs include `action`, `message`, `source`, `question_text` fields

#### `GET /api/page-transcription` — Mathpix transcription retrieval
- [ ] Retrieve transcription for existing session+page
- [ ] Returns `latex`, `text`, `confidence`, `content_type`
- [ ] `line_data` JSON parses correctly
- [ ] Missing page returns 404 or empty

#### `DELETE /ai/documents/{filename}` — document cleanup
- [ ] Delete existing document returns success
- [ ] 404 for nonexistent filename
- [ ] CASCADE deletes associated `questions` rows
- [ ] CASCADE deletes associated `answer_keys` rows

#### `POST /api/strokes/disconnect` — additional cases
- [x] Basic disconnect (already tested)
- [ ] Disconnect nonexistent session is a no-op (no error)

#### `GET /api/reasoning-preview` — context preview
- [ ] Returns structured context sections (system prompt + data)
- [ ] Empty page returns minimal context
- [ ] Includes problem + answer key when session has cached question

### Pure lib functions

#### `lib/mock_responses.py` → `get_mock_embedding()`
- [ ] Returns `count` vectors of `dimensions` length
- [ ] Each vector is L2-normalized (norm ≈ 1.0)
- [ ] Default: 1 vector, 384 dimensions
- [ ] Different calls produce different vectors (randomness)

#### `lib/stroke_renderer.py` → `render_strokes()`
- [ ] Empty strokes list returns valid PNG bytes (blank image)
- [ ] Single stroke renders without error
- [ ] Multiple strokes render correctly
- [ ] Output starts with PNG magic bytes (`\x89PNG`)
- [ ] Image width is 512px

#### `lib/region_extractor.py` → `_collect_expected_labels()`
- [ ] Flat parts: `[{label:"a"}, {label:"b"}]` → `["a", "b"]`
- [ ] Nested parts: `[{label:"a", parts:[{label:"i"},{label:"ii"}]}]` → `["a", "a.i", "a.ii"]`
- [ ] Deep nesting: three levels produce dot-notation labels
- [ ] Empty parts list returns empty list

#### Pydantic model validation

**`Part`**:
- [ ] `answer_space_cm` rejects values < 0
- [ ] `answer_space_cm` rejects values > 6
- [ ] `answer_space_cm` defaults to 3.0
- [ ] Recursive `parts` field accepts nested Part objects

**`Question`**:
- [ ] Requires `number` and `text`
- [ ] `figures` defaults to empty list
- [ ] `parts` defaults to empty list

**`QuestionBatch`**:
- [ ] Accepts list of Question objects
- [ ] Rejects empty questions list (if validated)

**`QuizGenerationRequest`**:
- [ ] `num_questions` rejects < 1
- [ ] `num_questions` rejects > 10
- [ ] `difficulty` accepts "easy", "medium", "hard"
- [ ] `question_types` defaults to `["open_ended"]`

**`ProblemGroup`**:
- [ ] `problem_number` 0 is valid (header/title)
- [ ] `label` defaults to empty string

**`GroupProblemsResponse`**:
- [ ] Requires `problems`, `total_annotations`, `total_problems`, `page_count`

---

## Tier 2 — Single-service mocking

Each test mocks one external service but exercises real business logic.

### Groq (voice endpoints)

#### `POST /api/voice/transcribe`
- [ ] Mock `groq_transcribe.transcribe()`: happy path returns transcription text
- [ ] Empty/silent audio returns empty string
- [ ] DB logging: creates `stroke_logs` entry with `event_type='voice'`
- [ ] Response includes `transcription` and `session_id`

#### `POST /api/voice/question`
- [ ] Mock transcribe + reasoning: returns transcription immediately
- [ ] Async reasoning fires in background (verify task created)
- [ ] Response shape: `{transcription, session_id}`

#### `lib/groq_transcribe.py` → `transcribe()`
- [ ] Mock OpenAI client: verify model is `whisper-large-v3-turbo`
- [ ] Returns transcription text from mock response
- [ ] Handles API error gracefully

### DeepInfra (TTS stream)

#### `GET /api/tts/stream/{tts_id}`
- [ ] Mock DeepInfra HTTP: text-based entry streams PCM chunks
- [ ] Returns correct headers (`X-Sample-Rate: 24000`, `X-Channels: 1`, `X-Sample-Width: 2`)
- [ ] 404 for missing/unknown `tts_id`
- [ ] 404 for already-consumed `tts_id`
- [ ] Queue-based entry: sentences arrive via queue, streamed in order
- [ ] None sentinel in queue signals end of stream

### Modal (TTS WebSocket — deprecated)

#### `WebSocket /ws/tts`
- [ ] Mock `stream_tts()`: synthesize message → `tts_start` + binary chunks + `tts_end`
- [ ] Error in TTS sends error message to client
- [ ] Empty text returns error

### Modal (TTS client)

#### `lib/tts_client.py` → `stream_tts()`
- [ ] Mock HTTP POST to Modal endpoint: yields PCM chunks (bytes)
- [ ] Audio format: 24kHz, mono, 16-bit
- [ ] Empty text returns no chunks
- [ ] Missing `MODAL_TTS_URL` env var handled gracefully

### Modal (embeddings, prod mode)

#### `POST /ai/embed?mode=prod`
- [ ] Mock `EmbeddingService.embed()`: verify response shape matches `EmbedResponse`
- [ ] Correct dimensions (384) and count
- [ ] Normalization flag passed through

### Mathpix (transcription pipeline)

#### `lib/mathpix_client.py`
- [ ] Mock httpx: `create_session()` returns `MathpixSession` with token + expiry
- [ ] `get_or_create_session()` — cache hit reuses existing session
- [ ] `get_or_create_session()` — cache miss creates new session
- [ ] `invalidate_session()` removes session from cache, cancels pending tasks
- [ ] `schedule_transcribe()` debounce: second call within 500ms cancels first
- [ ] `schedule_transcribe()` skip-if-unchanged: same stroke hash → no Mathpix call
- [ ] Content type detection: diagram response → "other", chemistry → "chemistry"
- [ ] `cleanup_sessions()` removes all pages for a session

### LLM client

#### `lib/llm_client.py` → `LLMClient.generate()`
- [ ] Mock OpenAI client: text-only prompt sends single user message
- [ ] With images: base64-encodes and adds image_url content blocks
- [ ] With `response_schema`: calls `_make_strict()` and sets `response_format`
- [ ] `system_message` adds system role message
- [ ] `temperature` passed through to API call
- [ ] Returns `.choices[0].message.content`

#### `lib/llm_client.py` → `LLMClient.generate_stream()`
- [ ] Yields text chunks from streaming response
- [ ] Empty chunks (None content) are skipped

#### `lib/llm_client.py` → `LLMClient.agenerate_stream()`
- [ ] Async version yields same chunks as sync

### Reasoning

#### `lib/reasoning.py` → `build_context()`
- [ ] Mock DB: no transcription → minimal context (just system prompt)
- [ ] With page transcription → includes LaTeX/text in context
- [ ] With problem + answer key (via `session_question_cache`) → includes structured problem
- [ ] With reasoning history → includes prior feedback
- [ ] Fallback to `session_question_cache` when no document match

#### `lib/reasoning.py` → `run_reasoning()`
- [ ] Mock `build_context` + LLM: empty transcription returns `{"action": "silent"}`
- [ ] Speak decision: LLM returns `{"action": "speak", "message": "..."}` → logged to DB
- [ ] DB insert includes token counts and estimated cost
- [ ] Source field set correctly ("observation" vs "question")

#### `lib/reasoning.py` → `run_question_reasoning()`
- [ ] Mock `build_context` + LLM: always returns `{"action": "speak"}`
- [ ] DB insert with `source='question'` and `question_text` field
- [ ] Token counts and cost logged

#### `lib/reasoning.py` → `run_question_reasoning_streaming()`
- [ ] Mock LLM streaming: sentence boundary detection pushes to queue
- [ ] `None` sentinel sent at end of stream
- [ ] Partial sentence buffered until next boundary

### Reasoning preview

#### `GET /api/reasoning-preview`
- [ ] Mock `build_context_structured()`: returns system prompt + structured sections
- [ ] Returns list of `{title, content}` dicts
- [ ] Empty page returns minimal sections

### SSE events

#### `GET /api/events`
- [ ] SSE stream connects with `session_id` query param
- [ ] Receives `reasoning` events published for that session
- [ ] Does not receive events for other sessions
- [ ] 25s keepalive comments sent during idle
- [ ] Missing `session_id` returns error

---

## Tier 3 — Multi-service / E2E flows

Require mocking 2+ services or live infrastructure.

### PDF pipeline (Surya + Gemini + tectonic + DB)

#### `POST /ai/reconstruct`
- [ ] Mock Surya layout + Gemini extraction + tectonic: full pipeline produces PDF
- [ ] Split mode: separates questions into individual PDFs
- [ ] Debug mode: returns intermediate data (bboxes, raw extractions)
- [ ] Orphan figure rescue: unassigned figures attached to nearest problem
- [ ] LaTeX fix retry: compilation failure → Gemini fix → retry once
- [ ] DB insert: creates `documents`, `questions`, `answer_keys` rows
- [ ] Multi-page PDF handled correctly

#### `POST /ai/group-problems`
- [ ] Mock Surya + Gemini: annotations grouped into `ProblemGroup` objects
- [ ] Problem number 0 for headers/titles
- [ ] Response matches `GroupProblemsResponse` schema

#### `POST /ai/annotate`
- [ ] Mock Surya: bounding box annotation returns layout boxes
- [ ] Multi-page PDF: each page gets separate layout results
- [ ] Confidence scores included in response

### Quiz generation (Gemini + tectonic)

#### `POST /ai/generate-quiz`
- [ ] Mock Gemini structured output + tectonic: produces quiz PDF
- [ ] Difficulty levels affect prompt
- [ ] `num_questions` respected (1-10)
- [ ] LaTeX fix retry on compilation failure
- [ ] Response: list of `QuizQuestionResponse` with base64 PDFs

### Full stroke pipeline (Mathpix + Groq + DeepInfra)

#### Connect → strokes → transcription → reasoning → SSE → TTS
- [ ] POST strokes triggers debounced Mathpix transcription
- [ ] Transcription triggers debounced reasoning
- [ ] Reasoning result pushed via SSE `event: reasoning`
- [ ] SSE event includes `tts_id` when action is "speak"
- [ ] `GET /api/tts/stream/{tts_id}` serves the audio

#### Voice question → transcription → reasoning → SSE → TTS
- [ ] `POST /api/voice/question` triggers async reasoning
- [ ] Streaming reasoning pushes sentences to TTS queue
- [ ] SSE notifies client with `tts_id`

### LaTeX compiler

#### `lib/latex_compiler.py` → `compile_latex()`
- [ ] Needs tectonic binary: simple LaTeX compiles to PDF bytes
- [ ] With `image_data`: images written to work dir, referenced in LaTeX
- [ ] Invalid LaTeX: raises error with log output
- [ ] Missing tectonic: raises clear error at init

### Region extractor (full pipeline)

#### `lib/region_extractor.py` → `extract_question_regions()`
- [ ] Needs compiled PDF bytes: extracts bold part labels with y-coordinates
- [ ] Multi-page question: regions span across page boundaries
- [ ] Question with no parts: single region for entire question
- [ ] `page_heights` array matches PDF page count

---

## Summary

| Tier | Items | Can run today? |
|------|------:|----------------|
| **1 — DB-only / Pure** | ~35 test cases | Yes (PostgreSQL only) |
| **2 — Single mock** | ~50 test cases | Yes (with targeted mocks) |
| **3 — Multi-service** | ~20 test cases | Needs mock infrastructure |
| **Already covered** | 81 tests | Running |
| **Total when complete** | ~185 tests | — |
