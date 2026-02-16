# Replace Tutor Pipeline with Stroke Logging

## Summary

Delete the entire tutor mode pipeline (clustering, transcription, reasoning, TTS) and replace it with a WebSocket endpoint that streams raw stroke data from iOS to the server, which logs strokes to Postgres with datetime and full coordinates.

## What Gets Deleted

### Server
- `api/tutoring.py` — 3-stage pipeline (transcribe, reason, TTS)
- `api/transcribe.py` — Groq transcription endpoint
- `api/clustering.py` — DBSCAN clustering WebSocket
- `lib/models/feedback.py` — TutoringFeedback model
- Router registrations in `api/index.py` for tutoring, transcribe, clustering

### iOS
- `StrokeClusterManager.swift` — cluster tracking
- Tutoring pipeline code in `AIService.swift` (cluster socket, tutor request, related models)
- Pipeline trigger logic, feedback handling, audio playback in `DrawingOverlayView.swift`

## What Replaces It

### Server — WebSocket endpoint `ws/strokes`
- Accepts messages with full PKStrokePoint data
- Logs each batch to Postgres `stroke_logs` table
- Acknowledges with `{"type": "ack"}`

### Database Schema

```sql
CREATE TABLE IF NOT EXISTS stroke_logs (
    id SERIAL PRIMARY KEY,
    session_id TEXT NOT NULL,
    page INT NOT NULL,
    received_at TIMESTAMPTZ DEFAULT NOW(),
    strokes JSONB NOT NULL
)
```

### Message Format (iOS -> Server)

```json
{
  "type": "strokes",
  "session_id": "uuid",
  "page": 1,
  "strokes": [
    {
      "points": [
        {"x": 100.5, "y": 200.3, "t": 1707900000.123, "force": 0.8, "altitude": 1.2, "azimuth": 0.5}
      ]
    }
  ]
}
```

### iOS — Simplified WebSocket Sender
- On stroke change, extract full PKStrokePoint data from new strokes
- Send over WebSocket with session_id, page number, and point arrays
- No clustering, no pipeline trigger, no feedback handling
