# Erase-Aware Reasoning Context

**Date**: 2026-02-21
**Status**: Approved

## Problem

The reasoning model has no visibility into what the student erased. When an erase event fires, the visibility resolution replaces all prior strokes, and `build_context` only assembles the current canvas state. The model cannot detect patterns like erasing correct work and replacing it with something wrong, or second-guessing the same step repeatedly.

## Solution

Capture the current `page_transcriptions.text` as an in-memory snapshot each time an erase event triggers re-transcription. Include the last 2-3 snapshots in the reasoning context so the model can compare erased work against current work.

## Data Structure

New in-memory dict in `mathpix_client.py`:

```python
from collections import deque

# (session_id, page) -> deque of transcription texts (max 3, newest last)
_erase_snapshots: dict[tuple[str, int], deque[str]] = {}
```

## Capture Flow

In `_debounced_transcribe`, before sending to Mathpix (or before the diagram-mode early return):

1. Fetch all stroke events for this (session_id, page), check if the most recent event is an erase
2. If so, fetch the current `page_transcriptions.text` from the DB (the pre-erase state)
3. If the text is non-empty, append to `_erase_snapshots[(session_id, page)]` (deque maxlen=3)
4. Proceed with normal transcription (which overwrites with post-erase state)

## Context Assembly

In `build_context`, after "Student's Current Work" and before "Original Problem", check `_erase_snapshots`. If entries exist, add:

```
## Previously Erased Work (most recent first)
The student wrote and then erased the following:

1. (most recent erase)
\frac{d}{dx} x^2 = x

2. (earlier erase)
\frac{d}{dx} x^2 = 3x
```

Also update `build_context_structured` with a matching section for the dashboard preview.

## Cleanup

- `invalidate_session(session_id, page)` — pop from `_erase_snapshots`
- `cleanup_sessions(session_id)` — pop all pages for that session
- `deque(maxlen=3)` handles the cap automatically

## System Prompt

Add to `SYSTEM_PROMPT`:

```
## Erased work context

You may see a "Previously Erased Work" section showing what the student wrote
before erasing. Use this to detect:
- Student erasing correct work and replacing it with something wrong
- Student second-guessing themselves repeatedly on the same step
- Student erasing your suggested correction instead of fixing the error

Do NOT comment on erased work unprompted unless the erasure introduced or
worsened an error. Erasing and rewriting is normal — only flag it when it
leads to a mistake.
```

## Database

No schema changes. Snapshots are ephemeral in-memory state, scoped to the active session. Lost on server restart (acceptable — erase context is only useful during the active session).

## Cost Impact

Minimal. Each snapshot is a short text string (the same transcription text already in the context). Adding 2-3 erased transcriptions adds a few hundred tokens at most.
