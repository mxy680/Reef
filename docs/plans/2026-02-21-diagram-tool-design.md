# Diagram Tool Design

**Date**: 2026-02-21
**Status**: Approved

## Problem

Mathpix sometimes returns high-confidence but meaningless LaTeX for student drawings (circuits, graphs, free-body diagrams). The current diagram detection gate (`confidence < 0.8 || !is_handwritten || error`) doesn't catch these, so the reasoning model receives garbage text instead of the actual image.

## Solution

Add a **Diagram Tool** to the iOS app. When active, strokes bypass Mathpix entirely and are sent directly to the Qwen VL reasoning model as a rendered PNG image. The student explicitly chooses whether they are writing math or drawing a diagram — no auto-classification needed.

## Data Flow

```
Student taps Diagram Tool in iOS toolbar
  |
iOS POST /api/strokes { strokes, page, content_mode: "diagram" }
  | INSERT stroke_logs (unchanged)
  | Skip Mathpix entirely
  | Upsert page_transcriptions with text="", content_type="diagram"
  | schedule_reasoning() (2.5s debounce)
  |
build_context():
  - Render all visible strokes -> PNG (512px, existing renderer)
  - Attach PNG to images[]
  - Text section: "[See attached image of student's drawing]"
  - Problem, answer key, history: unchanged
  |
Qwen VL processes image + context -> speak/silent decision
  |
SSE push to iOS (unchanged)
```

Math mode is completely unchanged — Mathpix transcription pipeline operates as before.

## iOS Changes

- New tool in the drawing toolbar (alongside pen, eraser, undo, etc.)
- When diagram tool is active, strokes POST includes `content_mode: "diagram"`
- Tool selection is per-page local state
- Student can freely switch between math pen and diagram tool

## Server Changes

### `api/strokes.py`

- Read `content_mode` from POST body (default: `"math"`)
- Store in `_active_sessions[session_id]["content_mode"]`

### `lib/mathpix_client.py`

- `schedule_transcribe()`: check `content_mode` from `_active_sessions`
- If `"diagram"`: skip Mathpix call, upsert `page_transcriptions` with `text=""` and `content_type="diagram"`, then call `schedule_reasoning()` directly
- Add stroke hash check before reasoning for diagram mode (same SHA-256 approach as Mathpix path) to avoid redundant reasoning calls on unchanged strokes

### `lib/reasoning.py`

- `build_context()`: no changes needed — the existing empty-text path already renders strokes to PNG and attaches as image

### `lib/stroke_renderer.py`

- No changes needed. Already renders strokes to PNG at 512px width.

## System Prompt

Minor tweak to the "Image context" section in `SYSTEM_PROMPT`:

```
- **Student drawing**: a rendered image of the student's strokes when they are
  using the diagram tool or their work couldn't be transcribed to text.
```

## Database

No schema changes. `page_transcriptions` already handles empty text. `stroke_logs` stores raw strokes regardless of mode. `content_mode` is ephemeral session state in `_active_sessions`, not persisted.

## Edge Cases

**Wrong mode**: Trust the student. If they write equations with the diagram tool, the VL model still sees the image and can reason about it (just without Mathpix text assistance). They can switch modes freely.

**Empty strokes**: Same as today — if no visible strokes exist, skip reasoning.

## Cost Impact

- **Saved**: Mathpix API calls for diagrams (which were producing garbage anyway)
- **Added**: ~1000-2000 image input tokens per reasoning call at $0.20/M = ~$0.0003. Negligible, and already paid in the current diagram fallback path.
- **Net**: Slight cost reduction.
