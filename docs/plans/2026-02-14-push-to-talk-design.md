# Push-to-Talk Voice Messages

## Overview

Add push-to-talk voice capture to the iPad canvas toolbar. The mic button toggles recording on/off. Audio is sent to the server via WebSocket, transcribed with Groq Whisper, stored in the database, and displayed on the dashboard.

## Architecture

```
iPad (mic button)  ->  Record audio locally (AVAudioRecorder)
                   ->  Send audio binary via WebSocket to /ws/voice
                   ->  Server transcribes with Groq Whisper
                   ->  Stores transcription in stroke_logs (event_type: "voice")
                   ->  Dashboard polls and shows it in the table
```

## Decisions

- **Approach**: Batch send via new WebSocket (record locally, send complete audio on stop)
- **Audio format**: WAV (Whisper-compatible, no encoding overhead)
- **Transcription**: Groq Whisper (`whisper-large-v3-turbo`) server-side
- **Storage**: Text only in `stroke_logs` table, `event_type: "voice"`, transcription in `message` field
- **Dashboard**: Same table, new "voice" badge type

## iOS Changes

### 1. Info.plist

Add `NSMicrophoneUsageDescription` for microphone permission.

### 2. VoiceRecordingService

New service wrapping `AVAudioRecorder`:
- Records to temp `.wav` file (Linear PCM, 16kHz, mono, 16-bit — Whisper optimal)
- `startRecording()` — requests mic permission if needed, starts recording
- `stopRecording() -> Data` — stops recording, returns audio file data
- Handles permission denied gracefully

### 3. Mic Button Toggle (CanvasToolbar + CanvasView)

Wire `onAIActionSelected("ask")` in CanvasView:
- First click: start recording, mic button shows recording state (red tint or pulsing indicator)
- Second click: stop recording, send audio via WebSocket
- Add `isRecording` state to manage toggle behavior

### 4. Voice WebSocket in AIService

New WebSocket connection to `/ws/voice`:
- Lazy connection (connect on first use)
- Protocol:
  1. Send JSON: `{"type": "voice_start", "session_id": "...", "user_id": "...", "page": 1}`
  2. Send binary: complete audio data
  3. Send JSON: `{"type": "voice_end"}`
  4. Receive JSON: `{"type": "ack", "transcription": "..."}`

## Server Changes

### 5. api/voice.py — WebSocket Endpoint

New `/ws/voice` endpoint:
- Receives `voice_start` (session metadata), binary audio data, `voice_end` (trigger)
- Accumulates binary chunks into a buffer
- On `voice_end`: transcribe with Groq, insert into `stroke_logs`
- Insert with: `event_type: "voice"`, `message: <transcription>`, `strokes: '[]'`
- Send ack with transcription back to client

### 6. lib/groq_transcribe.py — Groq Whisper Client

Thin wrapper:
- Uses OpenAI SDK with `base_url="https://api.groq.com/openai/v1"` and `GROQ_API_KEY`
- `async def transcribe(audio_bytes: bytes) -> str`
- Model: `whisper-large-v3-turbo`
- Writes bytes to temp file for API upload, cleans up after

### 7. Register Router

Add `from api.voice import router as voice_router` and `app.include_router(voice_router)` in `api/index.py`.

## Dashboard Changes

### 8. Voice Badge and Display

In `app/page.tsx`:
- Add "voice" to badge variants (purple/indigo color)
- When `event_type === "voice"`, show `message` (transcription text) in the Strokes column instead of stroke count
- No structural changes — existing 200ms polling picks up new entries automatically

## Message Protocol

### iOS to Server (WebSocket)

```json
{"type": "voice_start", "session_id": "uuid", "user_id": "apple_id", "page": 1}
```
```
<binary audio data (WAV)>
```
```json
{"type": "voice_end"}
```

### Server to iOS (WebSocket)

```json
{"type": "ack", "transcription": "The student said..."}
```

### Database Record

```sql
INSERT INTO stroke_logs (session_id, page, strokes, event_type, message, user_id)
VALUES ($1, $2, '[]'::jsonb, 'voice', $3, $4)
```
