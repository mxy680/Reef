---
name: mathpix-strokes-session-api
description: "Mathpix Strokes API session management: two-step auth, app_token, complete stroke sets per call"
user-invocable: false
origin: auto-extracted
---

# Mathpix Strokes API Session Management

**Extracted:** 2026-03-20
**Context:** Real-time handwriting-to-LaTeX transcription using Mathpix /v3/strokes endpoint

## Problem
The Mathpix Strokes API has a non-obvious two-step session flow that differs from their simpler image API. Sending strokes with `app_id`/`app_key` directly works but bills per request. Sessions bill once for 5 minutes.

## Solution

### Step 1: Create session
```
POST https://api.mathpix.com/v3/app-tokens
Header: app_key: <APP_KEY>   (NOT app_id — only app_key)
Body: {"include_strokes_session_id": true, "expires": 300}
→ Returns: {app_token, strokes_session_id, app_token_expires_at}
```

### Step 2: Send strokes with session
```
POST https://api.mathpix.com/v3/strokes
Header: app_token: <APP_TOKEN>   (NOT app_id/app_key)
Body: {
  "strokes": {"strokes": {"x": [[...], [...]], "y": [[...], [...]]}},
  "strokes_session_id": "<SESSION_ID>"
}
```

### Key gotchas
- **Auth header differs**: sessions use `app_token`, non-sessions use `app_id` + `app_key`
- **Session creation only needs `app_key`** (no `app_id`)
- **Strokes are NOT accumulated server-side**: each call sends the COMPLETE set of strokes, Mathpix processes whatever you send fresh. No need to reset sessions when switching questions.
- **Response does NOT contain `strokes_session_id`**: the session ID only comes from `/v3/app-tokens`, not from `/v3/strokes` responses
- **x/y format**: arrays of arrays — each inner array is one continuous stroke's coordinates
- **Session expires**: 30-300 seconds (max 5 min). Billed on first stroke, not on token creation.
- **Payload structure is double-nested**: `strokes.strokes.{x, y}` (not `strokes.{x, y}`)

## When to Use
- Building real-time handwriting transcription features
- Integrating Mathpix strokes API into any iOS/server pipeline
- Debugging why Mathpix returns stale/combined results (check session reuse)
