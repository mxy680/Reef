# Delayed Speak Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add a `delayed_speak` action so the reasoning model can queue non-urgent feedback that only fires after 10 seconds of student inactivity.

**Architecture:** Server-side 10-second timer in `mathpix_client.py`. When the model returns `delayed_speak`, the message is held in `_pending_delayed` dict. New strokes cancel it (via `schedule_reasoning`). After 10s idle, it's pushed as a normal `speak` SSE event. iOS sees no change.

**Tech Stack:** Python asyncio (Task timers), pytest, monkeypatch, FakePool/FakeConn test helpers

---

## Design

### Problem

The reasoning model interrupts students who pause to think mid-step. For example, a student splitting an integral into two parts pauses after writing the first part, and the tutor says "you still need to do the second part" before the student has finished thinking.

### Solution

Add a third action `delayed_speak` alongside `speak` and `silent`. When the model returns `delayed_speak`, the server holds the message for 10 seconds. If the student writes new strokes during that window, the message is discarded (new reasoning will fire anyway). If 10 seconds pass with no activity, the message is pushed as a normal `speak` event.

### Data Flow

```
Model returns "delayed_speak" + message
  → log to reasoning_logs immediately
  → store in _pending_delayed dict with 10s asyncio.Task

If new strokes arrive before 10s:
  → schedule_reasoning cancels _pending_delayed task
  → message discarded, new reasoning cycle starts

If 10s passes with no activity:
  → timer fires → push_reasoning(session_id, "speak", message)
  → iOS receives normal SSE, plays TTS
```

---

## Task 1: Add `_pending_delayed` dict + cleanup

**Files:**
- Modify: `Reef-Server/lib/mathpix_client.py:37-43` (module-level dicts)
- Modify: `Reef-Server/lib/mathpix_client.py:89-101` (`invalidate_session`)
- Modify: `Reef-Server/lib/mathpix_client.py:115-141` (`cleanup_sessions`)
- Test: `Reef-Server/tests/unit/test_mathpix_client.py`

**Step 1: Write the failing tests**

Add to `tests/unit/test_mathpix_client.py`:

```python
from lib.mathpix_client import _pending_delayed

class TestPendingDelayedCleanup:
    def test_invalidate_session_cancels_pending_delayed(self):
        key = ("sid", 1)
        delayed_task = asyncio.ensure_future(asyncio.sleep(100))
        _pending_delayed[key] = delayed_task
        try:
            invalidate_session("sid", 1)
            assert key not in _pending_delayed
            assert delayed_task.cancelling() > 0
        finally:
            _pending_delayed.pop(key, None)
            delayed_task.cancel()

    def test_cleanup_sessions_cancels_all_pending_delayed(self):
        key1 = ("sid", 1)
        key2 = ("sid", 2)
        other = ("other", 1)
        t1 = asyncio.ensure_future(asyncio.sleep(100))
        t2 = asyncio.ensure_future(asyncio.sleep(100))
        t3 = asyncio.ensure_future(asyncio.sleep(100))
        _pending_delayed[key1] = t1
        _pending_delayed[key2] = t2
        _pending_delayed[other] = t3
        try:
            cleanup_sessions("sid")
            assert key1 not in _pending_delayed
            assert key2 not in _pending_delayed
            assert other in _pending_delayed
            assert t1.cancelling() > 0
            assert t2.cancelling() > 0
        finally:
            _pending_delayed.pop(key1, None)
            _pending_delayed.pop(key2, None)
            _pending_delayed.pop(other, None)
            t1.cancel()
            t2.cancel()
            t3.cancel()
```

**Step 2: Run tests to verify they fail**

Run: `cd Reef-Server && uv run python -m pytest tests/unit/test_mathpix_client.py::TestPendingDelayedCleanup -v`
Expected: FAIL with `ImportError: cannot import name '_pending_delayed'`

**Step 3: Implement**

In `lib/mathpix_client.py`, add after `_erase_snapshots` (line 43):

```python
# (session_id, page) → pending delayed-speak asyncio.Task
_pending_delayed: dict[tuple[str, int], asyncio.Task] = {}

DELAYED_SPEAK_SECONDS = 10.0
```

In `invalidate_session`, add after the `_erase_snapshots.pop` line (after line 93):

```python
    d_task = _pending_delayed.pop(key, None)
    if d_task:
        d_task.cancel()
```

In `cleanup_sessions`, add after the erase snapshots cleanup block (after line 139):

```python
    # Clean up pending delayed-speak tasks for this session
    delayed_keys = [k for k in _pending_delayed if k[0] == session_id]
    for key in delayed_keys:
        d_task = _pending_delayed.pop(key, None)
        if d_task:
            d_task.cancel()
```

**Step 4: Run tests to verify they pass**

Run: `cd Reef-Server && uv run python -m pytest tests/unit/test_mathpix_client.py::TestPendingDelayedCleanup -v`
Expected: PASS

**Step 5: Commit**

```bash
cd Reef-Server && git add lib/mathpix_client.py tests/unit/test_mathpix_client.py
git commit -m "feat: add _pending_delayed dict with cleanup in invalidate/cleanup_sessions"
```

---

## Task 2: Cancel pending delayed in `schedule_reasoning`

**Files:**
- Modify: `Reef-Server/lib/mathpix_client.py:147-155` (`schedule_reasoning`)
- Test: `Reef-Server/tests/unit/test_mathpix_client.py`

**Step 1: Write the failing test**

Add to `tests/unit/test_mathpix_client.py`:

```python
from lib.mathpix_client import schedule_reasoning, _pending_delayed

class TestScheduleReasoningCancelsDelayed:
    async def test_schedule_reasoning_cancels_pending_delayed(self, monkeypatch):
        """When new reasoning is scheduled, any pending delayed-speak should be cancelled."""
        key = ("sid", 1)
        delayed_task = asyncio.ensure_future(asyncio.sleep(100))
        _pending_delayed[key] = delayed_task

        # Stub _debounced_reasoning so schedule_reasoning doesn't actually run reasoning
        async def fake_debounced(sid, page):
            await asyncio.sleep(100)

        monkeypatch.setattr("lib.mathpix_client._debounced_reasoning", fake_debounced)

        try:
            schedule_reasoning("sid", 1)
            assert key not in _pending_delayed
            assert delayed_task.cancelling() > 0
        finally:
            _pending_delayed.pop(key, None)
            _reasoning_tasks.pop(key, None)
            delayed_task.cancel()
            task = _reasoning_tasks.get(key)
            if task:
                task.cancel()
```

**Step 2: Run test to verify it fails**

Run: `cd Reef-Server && uv run python -m pytest tests/unit/test_mathpix_client.py::TestScheduleReasoningCancelsDelayed -v`
Expected: FAIL (delayed_task still in dict, not cancelled)

**Step 3: Implement**

In `schedule_reasoning`, add at the start of the function (after line 149, before cancelling reasoning task):

```python
    # Cancel any pending delayed-speak for this key
    d_task = _pending_delayed.pop(key, None)
    if d_task:
        d_task.cancel()
```

**Step 4: Run tests to verify they pass**

Run: `cd Reef-Server && uv run python -m pytest tests/unit/test_mathpix_client.py::TestScheduleReasoningCancelsDelayed -v`
Expected: PASS

**Step 5: Commit**

```bash
cd Reef-Server && git add lib/mathpix_client.py tests/unit/test_mathpix_client.py
git commit -m "feat: cancel pending delayed-speak when new reasoning is scheduled"
```

---

## Task 3: Handle `delayed_speak` action in `_debounced_reasoning`

**Files:**
- Modify: `Reef-Server/lib/mathpix_client.py:158-169` (`_debounced_reasoning`)
- Test: `Reef-Server/tests/unit/test_mathpix_client.py`

**Step 1: Write the failing tests**

Add to `tests/unit/test_mathpix_client.py`:

```python
class TestDebouncedReasoningDelayedSpeak:
    async def test_delayed_speak_starts_timer(self, monkeypatch):
        """When model returns delayed_speak, a timer task should be stored in _pending_delayed."""
        monkeypatch.setattr("lib.mathpix_client.REASONING_DEBOUNCE_SECONDS", 0)
        monkeypatch.setattr("lib.mathpix_client.DELAYED_SPEAK_SECONDS", 100)  # long so it doesn't fire

        async def fake_run_reasoning(sid, page):
            return {"action": "delayed_speak", "message": "Are you still thinking?"}

        monkeypatch.setattr("lib.reasoning.run_reasoning", fake_run_reasoning)

        pushed = []

        async def fake_push(sid, action, message):
            pushed.append((sid, action, message))

        monkeypatch.setattr("api.reasoning.push_reasoning", fake_push)

        key = ("sid", 1)
        _pending_delayed.pop(key, None)

        try:
            from lib.mathpix_client import _debounced_reasoning
            await _debounced_reasoning("sid", 1)

            # Should NOT have pushed immediately
            assert len(pushed) == 0
            # Should have a pending task
            assert key in _pending_delayed
            assert not _pending_delayed[key].done()
        finally:
            task = _pending_delayed.pop(key, None)
            if task:
                task.cancel()

    async def test_delayed_speak_fires_after_delay(self, monkeypatch):
        """After DELAYED_SPEAK_SECONDS, the message should be pushed as 'speak'."""
        monkeypatch.setattr("lib.mathpix_client.REASONING_DEBOUNCE_SECONDS", 0)
        monkeypatch.setattr("lib.mathpix_client.DELAYED_SPEAK_SECONDS", 0.1)  # 100ms for test speed

        async def fake_run_reasoning(sid, page):
            return {"action": "delayed_speak", "message": "Still working on that?"}

        monkeypatch.setattr("lib.reasoning.run_reasoning", fake_run_reasoning)

        pushed = []

        async def fake_push(sid, action, message):
            pushed.append((sid, action, message))

        monkeypatch.setattr("api.reasoning.push_reasoning", fake_push)

        key = ("sid", 1)
        _pending_delayed.pop(key, None)

        try:
            from lib.mathpix_client import _debounced_reasoning
            await _debounced_reasoning("sid", 1)

            # Not pushed yet
            assert len(pushed) == 0

            # Wait for delay to fire
            await asyncio.sleep(0.2)

            assert len(pushed) == 1
            assert pushed[0] == ("sid", "speak", "Still working on that?")
            assert key not in _pending_delayed
        finally:
            task = _pending_delayed.pop(key, None)
            if task:
                task.cancel()

    async def test_speak_still_pushes_immediately(self, monkeypatch):
        """Regular speak action should still push immediately (no delay)."""
        monkeypatch.setattr("lib.mathpix_client.REASONING_DEBOUNCE_SECONDS", 0)

        async def fake_run_reasoning(sid, page):
            return {"action": "speak", "message": "Check that sign."}

        monkeypatch.setattr("lib.reasoning.run_reasoning", fake_run_reasoning)

        pushed = []

        async def fake_push(sid, action, message):
            pushed.append((sid, action, message))

        monkeypatch.setattr("api.reasoning.push_reasoning", fake_push)

        key = ("sid", 1)
        try:
            from lib.mathpix_client import _debounced_reasoning
            await _debounced_reasoning("sid", 1)

            assert len(pushed) == 1
            assert pushed[0] == ("sid", "speak", "Check that sign.")
            assert key not in _pending_delayed
        finally:
            task = _pending_delayed.pop(key, None)
            if task:
                task.cancel()
```

**Step 2: Run tests to verify they fail**

Run: `cd Reef-Server && uv run python -m pytest tests/unit/test_mathpix_client.py::TestDebouncedReasoningDelayedSpeak -v`
Expected: FAIL (push_reasoning currently doesn't handle `delayed_speak`)

**Step 3: Implement**

Replace the `_debounced_reasoning` function in `lib/mathpix_client.py`:

```python
async def _debounced_reasoning(session_id: str, page: int) -> None:
    await asyncio.sleep(REASONING_DEBOUNCE_SECONDS)
    _reasoning_tasks.pop((session_id, page), None)

    try:
        from lib.reasoning import run_reasoning
        from api.reasoning import push_reasoning

        result = await run_reasoning(session_id, page)
        action = result["action"]
        message = result["message"]

        if action == "delayed_speak":
            key = (session_id, page)
            # Cancel any existing pending delayed
            existing = _pending_delayed.pop(key, None)
            if existing:
                existing.cancel()
            _pending_delayed[key] = asyncio.create_task(
                _fire_delayed_speak(session_id, page, message)
            )
        else:
            await push_reasoning(session_id, action, message)
    except Exception as e:
        print(f"[reasoning] error for ({session_id}, page={page}): {e}")


async def _fire_delayed_speak(session_id: str, page: int, message: str) -> None:
    """Wait DELAYED_SPEAK_SECONDS then push the message as 'speak'."""
    await asyncio.sleep(DELAYED_SPEAK_SECONDS)
    _pending_delayed.pop((session_id, page), None)
    try:
        from api.reasoning import push_reasoning
        await push_reasoning(session_id, "speak", message)
        print(f"[reasoning] delayed speak fired for ({session_id}, page={page}): {message[:60]}")
    except Exception as e:
        print(f"[reasoning] delayed speak error for ({session_id}, page={page}): {e}")
```

**Step 4: Run tests to verify they pass**

Run: `cd Reef-Server && uv run python -m pytest tests/unit/test_mathpix_client.py::TestDebouncedReasoningDelayedSpeak -v`
Expected: PASS

**Step 5: Commit**

```bash
cd Reef-Server && git add lib/mathpix_client.py tests/unit/test_mathpix_client.py
git commit -m "feat: handle delayed_speak action in _debounced_reasoning with 10s timer"
```

---

## Task 4: Update system prompt and response schema

**Files:**
- Modify: `Reef-Server/lib/reasoning.py:34-131` (SYSTEM_PROMPT)
- Modify: `Reef-Server/lib/reasoning.py:160-171` (RESPONSE_SCHEMA)

**Step 1: Update RESPONSE_SCHEMA**

In `lib/reasoning.py`, change the `enum` in `RESPONSE_SCHEMA` (line 165):

```python
"enum": ["speak", "silent", "delayed_speak"],
```

**Step 2: Update SYSTEM_PROMPT**

Replace the "Output format" section at the end of `SYSTEM_PROMPT` (line 127-131):

```python
## Output format

- action: "silent", "speak", or "delayed_speak"
- message: When silent, a brief internal note. When speaking, your coaching message.

### Action guide
- **silent**: Nothing to say. Correct work, partial work, pauses, copying — all silent. When in doubt, silent.
- **speak**: Urgent feedback that should be delivered immediately. Use for clear errors, positive reinforcement after corrections, and garbled transcription requests.
- **delayed_speak**: Non-urgent observation. Use when you have something to say but the student may still be mid-step. The message will only be delivered if the student stays idle for 10 seconds. If they keep writing, it's discarded. Use this for observations like "you still need the second term" or "don't forget to check the boundary condition" — things that are helpful but not urgent.\
```

**Step 3: Update the "When to SPEAK" section**

Also update the section header and trigger list (around lines 71-80). Change the header from:

```
## When to SPEAK — exactly 4 triggers
```

to:

```
## When to SPEAK or DELAYED_SPEAK — exactly 4 triggers
```

And add a note after the 4 triggers (after "When in doubt, silent."):

```
When you decide to speak, choose the urgency:
- **speak** for triggers 1 (errors), 2 (corrections), and 4 (garbled text) — these need immediate delivery.
- **delayed_speak** for nudges, reminders about incomplete steps, or gentle observations — anything where interrupting the student's train of thought would be worse than waiting 10 seconds.
```

**Step 4: Run existing tests to make sure nothing broke**

Run: `cd Reef-Server && uv run python -m pytest tests/unit/test_reasoning_helpers.py -v`
Expected: PASS (these tests don't depend on prompt content)

**Step 5: Commit**

```bash
cd Reef-Server && git add lib/reasoning.py
git commit -m "feat: add delayed_speak to system prompt and response schema"
```

---

## Task 5: Run full test suite + bump submodule

**Files:**
- Modify: `Reef/CLAUDE.md` (update Erase awareness → delayed_speak note)
- Run: full test suite

**Step 1: Run the full server test suite**

Run: `cd Reef-Server && uv run python -m pytest tests/ -q`
Expected: All tests pass (219+ tests)

**Step 2: Update CLAUDE.md in parent repo**

Add to the **Server (Reef-Server)** section in `/Users/markshteyn/projects/Reef/CLAUDE.md`:

```
- **Delayed speak**: `_pending_delayed` in `mathpix_client.py` holds non-urgent reasoning messages for 10s. If new strokes arrive (triggering `schedule_reasoning`), the pending message is cancelled. After 10s idle, it's pushed as a normal `speak` SSE. Model chooses `speak` (urgent) vs `delayed_speak` (non-urgent) vs `silent`. iOS sees no change — only `speak` events reach the client.
```

**Step 3: Bump submodule + commit in parent repo**

```bash
cd /Users/markshteyn/projects/Reef
git add Reef-Server
git add -f CLAUDE.md
git commit -m "chore: bump Reef-Server (delayed speak feature)"
```
