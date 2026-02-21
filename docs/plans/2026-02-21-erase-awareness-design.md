# Erase-Aware Reasoning Context Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Give the reasoning model visibility into what the student erased, so it can detect patterns like erasing correct work and replacing it with something wrong.

**Architecture:** On each erase event, snapshot the current `page_transcriptions.text` into an in-memory deque (max 3). `build_context` includes these snapshots in a "Previously Erased Work" section between "Student's Current Work" and "Original Problem". System prompt instructs the model when to act on erase context.

**Tech Stack:** Python (FastAPI, asyncpg), collections.deque

---

### Task 1: Add `_erase_snapshots` dict and cleanup

**Files:**
- Modify: `Reef-Server/lib/mathpix_client.py:1-40` (imports + module-level dicts)
- Modify: `Reef-Server/lib/mathpix_client.py:85-96` (invalidate_session)
- Modify: `Reef-Server/lib/mathpix_client.py:110-132` (cleanup_sessions)
- Test: `Reef-Server/tests/unit/test_mathpix_client.py`

**Step 1: Write failing tests**

Add to `tests/unit/test_mathpix_client.py`:

```python
from lib.mathpix_client import _erase_snapshots
from collections import deque


class TestEraseSnapshotCleanup:
    def test_invalidate_session_clears_erase_snapshots(self):
        key = ("sid", 1)
        _erase_snapshots[key] = deque(["old work"], maxlen=3)
        try:
            invalidate_session("sid", 1)
            assert key not in _erase_snapshots
        finally:
            _erase_snapshots.pop(key, None)

    def test_cleanup_sessions_clears_all_pages(self):
        key1 = ("sid", 1)
        key2 = ("sid", 2)
        other = ("other", 1)
        _erase_snapshots[key1] = deque(["work1"], maxlen=3)
        _erase_snapshots[key2] = deque(["work2"], maxlen=3)
        _erase_snapshots[other] = deque(["keep"], maxlen=3)
        try:
            cleanup_sessions("sid")
            assert key1 not in _erase_snapshots
            assert key2 not in _erase_snapshots
            assert other in _erase_snapshots
        finally:
            _erase_snapshots.pop(key1, None)
            _erase_snapshots.pop(key2, None)
            _erase_snapshots.pop(other, None)
```

**Step 2: Run tests to verify they fail**

Run: `cd Reef-Server && uv run python -m pytest tests/unit/test_mathpix_client.py::TestEraseSnapshotCleanup -v`
Expected: FAIL — `_erase_snapshots` does not exist

**Step 3: Implement**

In `lib/mathpix_client.py`:

1. Add `from collections import deque` to the imports (line ~12)

2. After the `_reasoning_tasks` dict (line ~39), add:
```python
# (session_id, page) → deque of pre-erase transcription texts (max 3, newest last)
_erase_snapshots: dict[tuple[str, int], deque[str]] = {}
```

3. In `invalidate_session` (after `_last_stroke_hash.pop`), add:
```python
_erase_snapshots.pop(key, None)
```

4. In `cleanup_sessions` (after the hash_keys cleanup loop, before the print), add:
```python
snap_keys = [k for k in _erase_snapshots if k[0] == session_id]
for key in snap_keys:
    _erase_snapshots.pop(key, None)
```

**Step 4: Run tests to verify they pass**

Run: `cd Reef-Server && uv run python -m pytest tests/unit/test_mathpix_client.py::TestEraseSnapshotCleanup -v`
Expected: PASS

**Step 5: Run full test suite**

Run: `cd Reef-Server && uv run python -m pytest tests/ -q`
Expected: All tests pass

**Step 6: Commit**

```bash
cd Reef-Server && git add lib/mathpix_client.py tests/unit/test_mathpix_client.py
git commit -m "feat: add _erase_snapshots dict with cleanup"
```

---

### Task 2: Capture pre-erase transcription snapshot

**Files:**
- Modify: `Reef-Server/lib/mathpix_client.py:182-205` (_debounced_transcribe, early section)
- Test: `Reef-Server/tests/unit/test_mathpix_client.py`

**Step 1: Write failing test**

Add to `tests/unit/test_mathpix_client.py`:

```python
class TestEraseSnapshotCapture:
    async def test_erase_event_captures_pre_erase_text(self, monkeypatch):
        """When the most recent stroke event is an erase, the current
        page_transcriptions.text should be snapshotted before Mathpix runs."""
        from collections import deque
        from tests.helpers import FakePool

        # FakeConn needs fetchrow support for this test
        class SnapshotConn:
            def __init__(self):
                self.calls = []
                self.fetchrow_result = {"text": "x^2 + 3x = 0"}
                self.fetch_result = [
                    {"id": 1, "strokes": "[]", "event_type": "draw"},
                    {"id": 2, "strokes": "[]", "event_type": "erase"},
                ]

            async def execute(self, query, *args):
                self.calls.append(("execute", query, *args))

            async def fetchrow(self, query, *args):
                self.calls.append(("fetchrow", query, *args))
                return self.fetchrow_result

            async def fetch(self, query, *args):
                self.calls.append(("fetch", query, *args))
                return self.fetch_result

        class SnapshotPool:
            def __init__(self):
                self.conn = SnapshotConn()
            def acquire(self):
                from tests.helpers import _FakeAcquireCtx
                return _FakeAcquireCtx(self.conn)

        pool = SnapshotPool()
        monkeypatch.setattr("lib.mathpix_client.get_pool", lambda: pool)
        monkeypatch.setattr("lib.mathpix_client.DEBOUNCE_SECONDS", 0)

        # Mock _active_sessions — math mode (not diagram)
        monkeypatch.setattr("api.strokes._active_sessions", {"sid": {"content_mode": "math"}})

        # No Mathpix credentials — will skip to reasoning after snapshot
        monkeypatch.delenv("MATHPIX_APP_ID", raising=False)
        monkeypatch.delenv("MATHPIX_APP_KEY", raising=False)

        # Track reasoning scheduling
        monkeypatch.setattr(
            "lib.mathpix_client.schedule_reasoning",
            lambda sid, page: None,
        )

        # Clear any existing snapshots
        from lib.mathpix_client import _erase_snapshots
        key = ("sid", 1)
        _erase_snapshots.pop(key, None)

        try:
            from lib.mathpix_client import _debounced_transcribe
            await _debounced_transcribe("sid", 1)

            # Should have captured the pre-erase text
            assert key in _erase_snapshots
            assert list(_erase_snapshots[key]) == ["x^2 + 3x = 0"]
        finally:
            _erase_snapshots.pop(key, None)

    async def test_no_snapshot_when_no_erase(self, monkeypatch):
        """When the most recent event is a draw (not erase), no snapshot is taken."""
        class DrawOnlyConn:
            def __init__(self):
                self.calls = []
                self.fetch_result = [
                    {"id": 1, "strokes": "[]", "event_type": "draw"},
                    {"id": 2, "strokes": "[]", "event_type": "draw"},
                ]
            async def execute(self, query, *args):
                self.calls.append(("execute", query, *args))
            async def fetchrow(self, query, *args):
                return None
            async def fetch(self, query, *args):
                return self.fetch_result

        class DrawOnlyPool:
            def __init__(self):
                self.conn = DrawOnlyConn()
            def acquire(self):
                from tests.helpers import _FakeAcquireCtx
                return _FakeAcquireCtx(self.conn)

        monkeypatch.setattr("lib.mathpix_client.get_pool", lambda: DrawOnlyPool())
        monkeypatch.setattr("lib.mathpix_client.DEBOUNCE_SECONDS", 0)
        monkeypatch.setattr("api.strokes._active_sessions", {"sid": {"content_mode": "math"}})
        monkeypatch.delenv("MATHPIX_APP_ID", raising=False)
        monkeypatch.delenv("MATHPIX_APP_KEY", raising=False)
        monkeypatch.setattr("lib.mathpix_client.schedule_reasoning", lambda sid, page: None)

        from lib.mathpix_client import _erase_snapshots, _debounced_transcribe
        key = ("sid", 1)
        _erase_snapshots.pop(key, None)

        try:
            await _debounced_transcribe("sid", 1)
            assert key not in _erase_snapshots
        finally:
            _erase_snapshots.pop(key, None)
```

**Step 2: Run tests to verify they fail**

Run: `cd Reef-Server && uv run python -m pytest tests/unit/test_mathpix_client.py::TestEraseSnapshotCapture -v`
Expected: FAIL — no snapshot capture logic exists

**Step 3: Implement**

In `lib/mathpix_client.py`, in `_debounced_transcribe`, after the diagram-mode early return block and before the `try: _get_credentials()` block (~line 206), add the erase snapshot capture:

```python
    # Erase snapshot: if most recent stroke event is an erase, capture pre-erase text
    pool = get_pool()
    if pool:
        async with pool.acquire() as conn:
            last_event = await conn.fetch(
                """
                SELECT event_type FROM stroke_logs
                WHERE session_id = $1 AND page = $2 AND event_type IN ('draw', 'erase')
                ORDER BY received_at DESC LIMIT 1
                """,
                session_id, page,
            )
            if last_event and last_event[0]["event_type"] == "erase":
                tx_row = await conn.fetchrow(
                    "SELECT text FROM page_transcriptions WHERE session_id = $1 AND page = $2",
                    session_id, page,
                )
                if tx_row and tx_row["text"]:
                    key = (session_id, page)
                    if key not in _erase_snapshots:
                        _erase_snapshots[key] = deque(maxlen=3)
                    _erase_snapshots[key].append(tx_row["text"])
                    print(f"[mathpix] ({session_id}, page={page}): captured pre-erase snapshot")
```

**Important:** This block must go AFTER the diagram-mode check (which may also return early) and BEFORE the `try: _get_credentials()` block. The `pool = get_pool()` variable is reused — but note the existing code also calls `get_pool()` later, so assign to a different name or restructure. Actually, looking at the code, `pool` is assigned at line 213 later in a `try` block. The simplest approach: put this in its own `try/except` or just use a fresh pool reference. Since `get_pool()` returns the same singleton, this is fine.

**Step 4: Run tests to verify they pass**

Run: `cd Reef-Server && uv run python -m pytest tests/unit/test_mathpix_client.py::TestEraseSnapshotCapture -v`
Expected: PASS

**Step 5: Run full test suite**

Run: `cd Reef-Server && uv run python -m pytest tests/ -q`
Expected: All tests pass

**Step 6: Commit**

```bash
cd Reef-Server && git add lib/mathpix_client.py tests/unit/test_mathpix_client.py
git commit -m "feat: capture pre-erase transcription snapshot"
```

---

### Task 3: Include erase snapshots in `build_context`

**Files:**
- Modify: `Reef-Server/lib/reasoning.py:199-258` (build_context, after "Student's Current Work")
- Modify: `Reef-Server/lib/reasoning.py:377-506` (build_context_structured, matching section)
- Test: `Reef-Server/tests/unit/test_reasoning_helpers.py`

**Step 1: Write failing test**

Add to `tests/unit/test_reasoning_helpers.py`:

```python
from collections import deque
from lib.mathpix_client import _erase_snapshots


class TestEraseContextInBuildContext:
    def test_erase_snapshots_included_in_context(self, monkeypatch):
        """build_context should include Previously Erased Work section
        when _erase_snapshots has entries."""
        import asyncio
        from tests.helpers import FakePool

        # Need a conn that returns transcription + no question + no history
        class ContextConn:
            async def fetchrow(self, query, *args):
                if "page_transcriptions" in query:
                    return {"latex": "x=1", "text": "x=1"}
                if "session_question_cache" in query:
                    return None
                return None
            async def fetch(self, query, *args):
                return []
            async def fetchval(self, query, *args):
                return 0

        class ContextPool:
            def acquire(self):
                from tests.helpers import _FakeAcquireCtx
                return _FakeAcquireCtx(ContextConn())

        monkeypatch.setattr("lib.reasoning.get_pool", lambda: ContextPool())
        monkeypatch.setattr("api.strokes._active_sessions", {"sid": {}})

        key = ("sid", 1)
        _erase_snapshots[key] = deque(["x^2 + 3x = 0", "x^2 = -3x"], maxlen=3)

        try:
            from lib.reasoning import build_context
            ctx = asyncio.get_event_loop().run_until_complete(
                build_context("sid", 1)
            )
            assert "Previously Erased Work" in ctx.text
            assert "x^2 + 3x = 0" in ctx.text
            assert "x^2 = -3x" in ctx.text
            # Most recent should come first
            assert ctx.text.index("x^2 = -3x") < ctx.text.index("x^2 + 3x = 0")
        finally:
            _erase_snapshots.pop(key, None)

    def test_no_section_when_no_erases(self, monkeypatch):
        """build_context should NOT include erase section when no snapshots exist."""
        import asyncio
        from tests.helpers import FakePool

        class ContextConn:
            async def fetchrow(self, query, *args):
                if "page_transcriptions" in query:
                    return {"latex": "x=1", "text": "x=1"}
                return None
            async def fetch(self, query, *args):
                return []
            async def fetchval(self, query, *args):
                return 0

        class ContextPool:
            def acquire(self):
                from tests.helpers import _FakeAcquireCtx
                return _FakeAcquireCtx(ContextConn())

        monkeypatch.setattr("lib.reasoning.get_pool", lambda: ContextPool())
        monkeypatch.setattr("api.strokes._active_sessions", {"sid": {}})

        key = ("sid", 1)
        _erase_snapshots.pop(key, None)

        from lib.reasoning import build_context
        ctx = asyncio.get_event_loop().run_until_complete(
            build_context("sid", 1)
        )
        assert "Previously Erased Work" not in ctx.text
```

**Step 2: Run tests to verify they fail**

Run: `cd Reef-Server && uv run python -m pytest tests/unit/test_reasoning_helpers.py::TestEraseContextInBuildContext -v`
Expected: FAIL — no "Previously Erased Work" section in output

**Step 3: Implement**

In `lib/reasoning.py`, in `build_context`, after the "Student's Current Work" section (after line 256, before the `# 2. Original problem` comment at line 258), add:

```python
        # 1b. Previously erased work
        from lib.mathpix_client import _erase_snapshots
        erased = _erase_snapshots.get((session_id, page))
        if erased:
            lines = []
            for i, text in enumerate(reversed(erased), 1):
                lines.append(f"{i}. {text}")
            parts.append(
                "## Previously Erased Work (most recent first)\n"
                "The student wrote and then erased the following:\n\n"
                + "\n\n".join(lines)
            )
```

In `build_context_structured`, after the "Student Drawing" section (around line 405), add:

```python
        from lib.mathpix_client import _erase_snapshots
        erased = _erase_snapshots.get((session_id, page))
        if erased:
            lines = []
            for i, text in enumerate(reversed(erased), 1):
                lines.append(f"{i}. {text}")
            sections.append({
                "title": "Previously Erased Work (most recent first)",
                "content": "\n\n".join(lines),
            })
```

**Step 4: Run tests to verify they pass**

Run: `cd Reef-Server && uv run python -m pytest tests/unit/test_reasoning_helpers.py::TestEraseContextInBuildContext -v`
Expected: PASS

**Step 5: Run full test suite**

Run: `cd Reef-Server && uv run python -m pytest tests/ -q`
Expected: All tests pass

**Step 6: Commit**

```bash
cd Reef-Server && git add lib/reasoning.py tests/unit/test_reasoning_helpers.py
git commit -m "feat: include erased work in reasoning context"
```

---

### Task 4: Update system prompt

**Files:**
- Modify: `Reef-Server/lib/reasoning.py:109-119` (SYSTEM_PROMPT, before output format section)

**Step 1: Add erased work guidance to system prompt**

In `lib/reasoning.py`, find the `## Image context` section (line ~109) and add a new section AFTER it and BEFORE `## Output format` (line ~115):

```python
## Erased work context

You may see a "Previously Erased Work" section showing what the student wrote \
before erasing. Use this to detect:
- Student erasing correct work and replacing it with something wrong
- Student second-guessing themselves repeatedly on the same step
- Student erasing your suggested correction instead of fixing the error

Do NOT comment on erased work unprompted unless the erasure introduced or \
worsened an error. Erasing and rewriting is normal — only flag it when it \
leads to a mistake.
```

**Step 2: Verify no regressions**

Run: `cd Reef-Server && uv run python -m pytest tests/ -q`
Expected: All tests pass

**Step 3: Commit**

```bash
cd Reef-Server && git add lib/reasoning.py
git commit -m "feat: add erased work guidance to system prompt"
```

---

### Task 5: Full integration test + submodule bump

**Step 1: Run full server test suite**

Run: `cd Reef-Server && uv run python -m pytest tests/ -q`
Expected: All tests pass

**Step 2: Commit submodule bump in parent repo**

```bash
cd /Users/markshteyn/projects/Reef
git add Reef-Server
git commit -m "chore: bump Reef-Server (erase-aware reasoning)"
```
