# Comprehensive Reef iOS Test Plan

**Created:** 2026-02-19
**Architecture:** Integration tests hit `localhost:8000` (real Reef-Server). Pure-logic unit tests stay as-is. UI tests use Appium.

## Setup

### Running the Server
```
cd Reef-Server && python -m uvicorn app.main:app --host 0.0.0.0 --port 8000
```

### Running Tests
```
xcodebuild -project Reef.xcodeproj -scheme Reef \
  -destination 'platform=iOS Simulator,name=iPad Pro 11-inch (M4)' \
  test 2>&1 | grep -E '(passed|failed|error:)'
```

### UI Tests (Appium)
```
python3 test-ios/appium_helper.py start
# Then run test scripts
python3 test-ios/appium_helper.py stop
```

## A. Pure Unit Tests (no server needed) — 78 tests

| Suite | Count | What it tests |
|-------|-------|---------------|
| TextChunkerTests | 30 | Chunk sizing, header detection, page breaks, Unicode, empty input |
| ModelTests | 37 | Note computed properties, Quiz scoring, ExamAttempt pass/fail, Tutor static data |
| SSEParserTests | 11 | SSE line parsing, event types, JSON parsing, malformed input |

## B. Server Integration Tests — require localhost:8000

### B1. AIService Embedding (9 tests)
| Test | What it proves |
|------|----------------|
| embed single text returns 384-dim vector | Server returns correct embedding dimensions |
| embed batch returns correct count | Batch processing works end-to-end |
| embed with normalize returns unit vectors | L2 norm ≈ 1.0 |
| embed with mock mode returns fast response | Mock mode works for CI |
| embed empty text array | Edge case handling |
| embed very long text succeeds | No truncation/timeout issues |
| embed special characters | Unicode, math symbols encoding |
| cosine similarity of identical texts ≈ 1.0 | Semantic identity |
| cosine similarity of unrelated texts < 0.5 | Semantic distance |

### B2. EmbeddingService (12 tests)
| Test | What it proves |
|------|----------------|
| embed success returns 384-dim vector | Server-backed embedding works |
| embed empty text throws emptyInput | Local validation |
| embed whitespace-only throws emptyInput | Local validation |
| embed trims whitespace before sending | Preprocessing |
| embedBatch success returns vectors | Batch processing |
| embedBatch filters empty strings with zero vectors | Mixed input handling |
| embedBatch all empty returns zero vectors | Edge case |
| cosine similarity of identical real embeddings ≈ 1.0 | Real semantic identity |
| cosine similarity of related texts > unrelated | Semantic relevance ranking |
| cosine similarity math functions work | Vector math correctness |
| embedding dimension is 384 | Static constant |
| embedding version is 2 | Static constant |

### B3. RAGService (9 tests)
| Test | What it proves |
|------|----------------|
| indexDocument chunks and stores in real SQLite | Full indexing pipeline |
| indexDocument short text skips indexing | Min chunk size guard |
| getContext returns formatted prompt with real embeddings | Full retrieval pipeline |
| getContext no results for unrelated query | Semantic filtering |
| getContext respects token budget | Token budget enforcement |
| deleteDocument removes from index | Deletion works |
| deleteCourse removes all documents in course | Cascade delete |
| isDocumentIndexed returns true after indexing | Status check |
| isDocumentIndexed returns false for unknown document | Negative case |

### B4. ServerAPI (8 tests)
| Test | What it proves |
|------|----------------|
| stroke connect and disconnect lifecycle | Session lifecycle |
| log strokes returns ok | Stroke submission |
| log strokes with empty strokes array | Edge case |
| clear strokes returns ok | Page clearing |
| SSE connection established | Event stream opens |
| create and get profile round-trip | Profile CRUD |
| get profile for unknown user returns 404 | Error handling |
| delete stroke logs for session | Log cleanup |

## C. Local Integration Tests (no server needed)

### C1. VectorStore (12 tests — existing, unchanged)
Testing SQLite write/read cycle, similarity threshold, deletion, chunk count, thread safety.

### C2. KeychainService (5 tests)
| Test | What it proves |
|------|----------------|
| save and retrieve user ID | Keychain round-trip |
| delete clears key | Single key deletion |
| overwrite existing value | Update works |
| deleteAll clears all keys | Bulk deletion |
| get nonexistent key returns nil | Missing key handling |

### C3. PreferencesManager (5 tests)
| Test | What it proves |
|------|----------------|
| reasoning model default is Gemini Pro | Default value |
| set and get feedback detail level | UserDefaults round-trip |
| quiz default question count | Default value |
| question type toggle | Set mutation |
| selected time limit convenience getter | Computed property |

### C4. FileStorageService (4 tests)
| Test | What it proves |
|------|----------------|
| save and load file round-trip | File I/O round-trip |
| delete file removes from storage | Cleanup |
| getFileURL returns expected path | Path construction |
| save and delete quiz question file | Quiz file lifecycle |

## D. UI Tests (Appium — future)

These test real user flows on the iPad simulator. Not yet implemented.

### D1. Authentication
- PreAuthView shows Apple Sign-In button
- After sign-in, HomeView appears

### D2. Navigation
- Sidebar shows Home, My Reef, Analytics, Tutors, Settings
- Tapping course opens CourseDetailView
- Tabs switch between Notes, Quizzes, Exams

### D3. Document Management
- FAB opens upload options sheet
- Upload PDF appears in notes list
- Delete note removes from list

### D4. Canvas
- Tapping note opens canvas
- Tool selection changes active tool
- Undo/redo works after drawing
- Text box creation and editing

### D5. Voice
- Hold-to-talk records and sends
- Voice response plays audio

### D6. AI Feedback
- Drawing triggers AI feedback
- RecognitionFeedbackView shows results

### D7. Quiz Flow
- Generate quiz from course
- Quiz appears in quizzes list

### D8. Settings
- AI Settings shows reasoning model picker
- Change feedback level persists

### D9. Tutors
- Tutors grid shows all 16 tutors
- Selecting tutor persists choice

### D10. Analytics
- Analytics view shows charts
- Weekly activity displays data

## Test Counts

| Category | Tests | Server Required |
|----------|-------|-----------------|
| A. Pure Unit | 78 | No |
| B. Server Integration | 38 | Yes (localhost:8000) |
| C. Local Integration | 26 | No |
| D. UI (Appium) | ~30 | Yes (+ simulator) |
| **Total** | **~172** | |

## Graceful Degradation

Integration tests that require the server use `try #require(await IntegrationTestConfig.serverIsReachable())` at the start of each test. When the server is down, these tests fail with a clear "Server not available" message rather than cryptic network errors. Pure unit and local integration tests always pass regardless of server state.
