# Diagram Tool Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add a diagram tool to the iOS app that bypasses Mathpix and sends stroke renderings directly to the Qwen VL reasoning model.

**Architecture:** iOS sends `content_mode: "diagram"` with stroke POSTs. Server skips Mathpix for diagram-mode strokes, upserts an empty transcription, and triggers reasoning with a rendered PNG. The existing `build_context` empty-text path already handles image rendering — no reasoning changes needed.

**Tech Stack:** Swift/SwiftUI (iOS), Python/FastAPI (server), PencilKit, Pillow

---

### Task 1: Server — Accept `content_mode` in stroke POST

**Files:**
- Modify: `Reef-Server/api/strokes.py:42-49` (StrokesRequest model)
- Modify: `Reef-Server/api/strokes.py:100-130` (strokes_post handler)
- Test: `Reef-Server/tests/integration/test_strokes_api.py`

**Step 1: Write the failing test**

Add to `tests/integration/test_strokes_api.py`, in a new `TestContentMode` class:

```python
class TestContentMode:
    def test_content_mode_stored_in_active_sessions(self, client):
        sid = _sid()
        client.post("/api/strokes/connect", json={"session_id": sid})

        client.post("/api/strokes", json={
            "session_id": sid,
            "page": 1,
            "strokes": [{"x": [1], "y": [2]}],
            "event_type": "draw",
            "content_mode": "diagram",
        })
        assert _active_sessions[sid]["content_mode"] == "diagram"

    def test_content_mode_defaults_to_math(self, client):
        sid = _sid()
        client.post("/api/strokes/connect", json={"session_id": sid})

        client.post("/api/strokes", json={
            "session_id": sid,
            "page": 1,
            "strokes": [{"x": [1], "y": [2]}],
            "event_type": "draw",
        })
        assert _active_sessions[sid]["content_mode"] == "math"

    def test_content_mode_not_overwritten_by_none(self, client):
        sid = _sid()
        client.post("/api/strokes/connect", json={"session_id": sid})

        # Set to diagram
        client.post("/api/strokes", json={
            "session_id": sid,
            "page": 1,
            "strokes": [{"x": [1], "y": [2]}],
            "content_mode": "diagram",
        })
        assert _active_sessions[sid]["content_mode"] == "diagram"

        # Send without content_mode — should keep "diagram"
        client.post("/api/strokes", json={
            "session_id": sid,
            "page": 1,
            "strokes": [{"x": [3], "y": [4]}],
        })
        assert _active_sessions[sid]["content_mode"] == "diagram"
```

**Step 2: Run test to verify it fails**

Run: `cd Reef-Server && uv run python -m pytest tests/integration/test_strokes_api.py::TestContentMode -v`
Expected: FAIL — `content_mode` key missing from `_active_sessions`

**Step 3: Write minimal implementation**

In `api/strokes.py`, add `content_mode` to the Pydantic model:

```python
class StrokesRequest(BaseModel):
    session_id: str
    user_id: str = ""
    page: int = 1
    strokes: list = []
    event_type: str = "draw"
    deleted_count: int = 0
    part_label: Optional[str] = None
    content_mode: Optional[str] = None    # "math" (default) or "diagram"
```

In `strokes_connect`, initialize `content_mode` in session state:

```python
_active_sessions[req.session_id] = {
    "document_name": req.document_name or "",
    "question_number": req.question_number,
    "last_seen": datetime.now(timezone.utc).isoformat(),
    "active_part": None,
    "content_mode": "math",
}
```

In `strokes_post`, after the existing `part_label` update block (~line 127), add:

```python
if req.content_mode is not None:
    _active_sessions[req.session_id]["content_mode"] = req.content_mode
```

**Step 4: Run test to verify it passes**

Run: `cd Reef-Server && uv run python -m pytest tests/integration/test_strokes_api.py::TestContentMode -v`
Expected: PASS

**Step 5: Run full test suite**

Run: `cd Reef-Server && uv run python -m pytest tests/ -q`
Expected: All tests pass (no regressions)

**Step 6: Commit**

```bash
cd Reef-Server && git add api/strokes.py tests/integration/test_strokes_api.py
git commit -m "feat: accept content_mode in stroke POST for diagram tool"
```

---

### Task 2: Server — Skip Mathpix for diagram mode strokes

**Files:**
- Modify: `Reef-Server/lib/mathpix_client.py:171-179` (schedule_transcribe)
- Modify: `Reef-Server/lib/mathpix_client.py:182-337` (_debounced_transcribe)
- Test: `Reef-Server/tests/unit/test_mathpix_client.py`

**Step 1: Write the failing test**

Add to `tests/unit/test_mathpix_client.py`:

```python
from lib.mathpix_client import schedule_transcribe, _debounce_tasks, _reasoning_tasks


class TestDiagramModeSkipsMathpix:
    """When content_mode is 'diagram', transcription should skip Mathpix
    and go straight to reasoning with an empty page_transcription."""

    async def test_diagram_mode_skips_mathpix_upserts_empty(self, monkeypatch):
        """Diagram mode should upsert page_transcriptions with empty text
        and schedule reasoning without calling Mathpix."""
        from tests.helpers import FakePool

        pool = FakePool()
        monkeypatch.setattr("lib.mathpix_client.get_pool", lambda: pool)

        # Mock _active_sessions to return diagram mode
        mock_sessions = {"sid": {"content_mode": "diagram"}}
        monkeypatch.setattr("lib.mathpix_client._active_sessions", mock_sessions)

        # Track reasoning scheduling
        reasoning_scheduled = []
        original_schedule = None

        def fake_schedule_reasoning(session_id, page):
            reasoning_scheduled.append((session_id, page))

        monkeypatch.setattr(
            "lib.mathpix_client.schedule_reasoning",
            fake_schedule_reasoning,
        )

        # Import and call the internal function directly
        from lib.mathpix_client import _debounced_transcribe
        # Monkeypatch sleep to be instant
        monkeypatch.setattr("lib.mathpix_client.DEBOUNCE_SECONDS", 0)
        monkeypatch.setattr("asyncio.sleep", lambda _: asyncio.sleep(0))

        await _debounced_transcribe("sid", 1)

        # Should have upserted empty transcription
        assert len(pool.conn.calls) == 1
        query = pool.conn.calls[0][0]
        assert "page_transcriptions" in query
        assert "INSERT" in query

        # Should have scheduled reasoning
        assert ("sid", 1) in reasoning_scheduled
```

**Step 2: Run test to verify it fails**

Run: `cd Reef-Server && uv run python -m pytest tests/unit/test_mathpix_client.py::TestDiagramModeSkipsMathpix -v`
Expected: FAIL — no `_active_sessions` attribute or diagram path doesn't exist

**Step 3: Write minimal implementation**

In `lib/mathpix_client.py`, at the top of `_debounced_transcribe()` (after the sleep and pop), add the diagram-mode early return. The function needs access to `_active_sessions`:

```python
async def _debounced_transcribe(session_id: str, page: int) -> None:
    await asyncio.sleep(DEBOUNCE_SECONDS)
    _debounce_tasks.pop((session_id, page), None)

    # Diagram mode: skip Mathpix, upsert empty transcription, schedule reasoning
    from api.strokes import _active_sessions
    info = _active_sessions.get(session_id, {})
    if info.get("content_mode") == "diagram":
        pool = get_pool()
        if pool:
            async with pool.acquire() as conn:
                await conn.execute(
                    """
                    INSERT INTO page_transcriptions (session_id, page, latex, text, confidence, updated_at)
                    VALUES ($1, $2, '', '', 0, NOW())
                    ON CONFLICT (session_id, page) DO UPDATE SET
                        latex = '', text = '', confidence = 0, updated_at = NOW()
                    """,
                    session_id, page,
                )
        print(f"[mathpix] ({session_id}, page={page}): diagram mode, skipped Mathpix")
        schedule_reasoning(session_id, page)
        return

    # ... rest of existing function unchanged ...
```

**Note:** The import of `_active_sessions` is inside the function to avoid circular imports (same pattern as `lib/reasoning.py:218`).

**Step 4: Run test to verify it passes**

Run: `cd Reef-Server && uv run python -m pytest tests/unit/test_mathpix_client.py::TestDiagramModeSkipsMathpix -v`
Expected: PASS

**Step 5: Run full test suite**

Run: `cd Reef-Server && uv run python -m pytest tests/ -q`
Expected: All tests pass

**Step 6: Commit**

```bash
cd Reef-Server && git add lib/mathpix_client.py tests/unit/test_mathpix_client.py
git commit -m "feat: skip Mathpix for diagram mode, upsert empty transcription"
```

---

### Task 3: Server — Update system prompt

**Files:**
- Modify: `Reef-Server/lib/reasoning.py:109-118` (SYSTEM_PROMPT image context section)
- Test: `Reef-Server/tests/unit/test_reasoning_helpers.py` (check prompt contains expected text)

**Step 1: Update the system prompt**

In `lib/reasoning.py`, find the `## Image context` section of `SYSTEM_PROMPT` (around line 109) and replace:

```python
# Old:
- **Student drawing**: a rendered image of the student's strokes when their work is a diagram that couldn't be transcribed to text.

# New:
- **Student drawing**: a rendered image of the student's strokes when they are using the diagram tool or their work couldn't be transcribed to text.
```

**Step 2: Verify no test regressions**

Run: `cd Reef-Server && uv run python -m pytest tests/ -q`
Expected: All tests pass

**Step 3: Commit**

```bash
cd Reef-Server && git add lib/reasoning.py
git commit -m "feat: update system prompt for diagram tool context"
```

---

### Task 4: iOS — Add `contentMode` to `AIService.sendStrokes()`

**Files:**
- Modify: `Reef-iOS/Reef/Services/AIService.swift:179-189` (sendStrokes method)

**Step 1: Add parameter and include in request body**

In `AIService.swift`, update the `sendStrokes` method signature to accept `contentMode`:

```swift
func sendStrokes(sessionId: String, page: Int, strokes: [[[String: Double]]], eventType: String = "draw", deletedCount: Int = 0, partLabel: String? = nil, contentMode: String? = nil) {
    var body: [String: Any] = [
        "session_id": sessionId,
        "user_id": KeychainService.get(.userIdentifier) ?? "",
        "page": page,
        "strokes": strokes.map { ["points": $0] },
        "event_type": eventType
    ]
    if deletedCount > 0 { body["deleted_count"] = deletedCount }
    if let part = partLabel { body["part_label"] = part }
    if let mode = contentMode { body["content_mode"] = mode }
    postJSON(path: "/api/strokes", body: body)
}
```

**Step 2: Build to verify no compiler errors**

Run: `xcodebuild -project Reef-iOS/Reef.xcodeproj -scheme Reef -destination 'platform=iOS Simulator,name=iPad Pro 11-inch (M4)' build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED (existing callers use default `nil` — backward compatible)

**Step 3: Commit**

```bash
cd Reef-iOS && git add Reef/Services/AIService.swift
git commit -m "feat: add contentMode parameter to sendStrokes"
```

---

### Task 5: iOS — Add diagram case to `CanvasTool` enum

**Files:**
- Modify: `Reef-iOS/Reef/Views/Canvas/CanvasToolbar.swift:12-19` (CanvasTool enum)

**Step 1: Add diagram case**

In `CanvasToolbar.swift`, add `diagram` to the `CanvasTool` enum:

```swift
enum CanvasTool: Equatable {
    case pen
    case highlighter
    case eraser
    case lasso
    case textBox
    case pan
    case diagram
}
```

**Step 2: Build to find all switch exhaustiveness errors**

Run: `xcodebuild -project Reef-iOS/Reef.xcodeproj -scheme Reef -destination 'platform=iOS Simulator,name=iPad Pro 11-inch (M4)' build 2>&1 | grep -E '(error:|BUILD)'`

Fix any switch exhaustiveness errors by adding `case .diagram:` alongside `case .pen:` in existing switch statements (diagram draws the same way as pen — it's just a mode flag). Check:
- `DrawingOverlayView.swift` — tool-to-PKInkingTool mapping
- `CanvasToolbar.swift` — secondary toolbar options
- `CanvasView.swift` — tool state management

For each switch, diagram should behave like pen (same PKInkingTool, same drawing behavior). The only difference is the `content_mode` sent to the server.

**Step 3: Build successfully**

Run: `xcodebuild -project Reef-iOS/Reef.xcodeproj -scheme Reef -destination 'platform=iOS Simulator,name=iPad Pro 11-inch (M4)' build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

**Step 4: Commit**

```bash
cd Reef-iOS && git add Reef/Views/Canvas/CanvasToolbar.swift Reef/Views/Canvas/DrawingOverlayView.swift Reef/Views/Canvas/CanvasView.swift
git commit -m "feat: add diagram case to CanvasTool enum"
```

---

### Task 6: iOS — Add diagram tool button to toolbar UI

**Files:**
- Modify: `Reef-iOS/Reef/Views/Canvas/CanvasToolbar.swift:422-464` (center section tool buttons)

**Step 1: Add diagram button**

In the toolbar's center section (around line 437, alongside pen/eraser/lasso/pan buttons), add a diagram tool button. Use SF Symbol `scribble.variable` or `pencil.and.outline` for the icon:

```swift
// Diagram tool button — add after existing tool buttons
ToolbarButton(
    icon: "scribble.variable",
    isSelected: selectedTool == .diagram,
    action: { selectedTool = .diagram }
)
.help("Diagram")
```

Follow the exact same pattern as the existing pen/eraser buttons for styling, selection highlight, etc.

**Step 2: Build and verify**

Run: `xcodebuild -project Reef-iOS/Reef.xcodeproj -scheme Reef -destination 'platform=iOS Simulator,name=iPad Pro 11-inch (M4)' build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

**Step 3: Commit**

```bash
cd Reef-iOS && git add Reef/Views/Canvas/CanvasToolbar.swift
git commit -m "feat: add diagram tool button to canvas toolbar"
```

---

### Task 7: iOS — Wire `contentMode` through DrawingOverlayView to sendStrokes

**Files:**
- Modify: `Reef-iOS/Reef/Views/Canvas/DrawingOverlayView.swift:291-330` (stroke sending in Coordinator)
- Modify: `Reef-iOS/Reef/Views/Canvas/CanvasView.swift` (pass tool selection to overlay)

**Step 1: Pass content mode based on selected tool**

In `DrawingOverlayView.Coordinator`, where `sendNewStrokes()` calls `AIService.shared.sendStrokes()` (around line 324), compute the content mode from the current tool and pass it:

```swift
let contentMode = currentTool == .diagram ? "diagram" : nil

AIService.shared.sendStrokes(
    sessionId: strokeSessionId,
    page: pageNum,
    strokes: strokeData,
    partLabel: currentActivePart,
    contentMode: contentMode
)
```

Verify that `currentTool` is already tracked in the Coordinator (it is — line ~300 in existing code). The tool state is already synced from the parent via `updateUIView`.

**Step 2: Build and verify**

Run: `xcodebuild -project Reef-iOS/Reef.xcodeproj -scheme Reef -destination 'platform=iOS Simulator,name=iPad Pro 11-inch (M4)' build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

**Step 3: Commit**

```bash
cd Reef-iOS && git add Reef/Views/Canvas/DrawingOverlayView.swift Reef/Views/Canvas/CanvasView.swift
git commit -m "feat: wire content_mode=diagram through stroke sending"
```

---

### Task 8: Full integration test

**Step 1: Run full server test suite**

Run: `cd Reef-Server && uv run python -m pytest tests/ -q`
Expected: All 193+ tests pass

**Step 2: Run iOS build + tests**

Run: `xcodebuild -project Reef-iOS/Reef.xcodeproj -scheme Reef -destination 'platform=iOS Simulator,name=iPad Pro 11-inch (M4)' test 2>&1 | grep -E '(passed|failed|error:)'`
Expected: All tests pass

**Step 3: Commit submodule bumps in parent repo**

```bash
cd /Users/markshteyn/projects/Reef
git add Reef-Server Reef-iOS
git commit -m "chore: bump submodules (diagram tool)"
```
