# Push-to-Talk Voice Messages Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add push-to-talk voice capture from the iPad mic button, send audio to the server via WebSocket, transcribe with Groq Whisper, store in database, and display on the dashboard.

**Architecture:** iOS records audio locally with AVAudioRecorder, sends the complete WAV file over a new `/ws/voice` WebSocket. Server accumulates the binary data, transcribes with Groq Whisper, inserts into the existing `stroke_logs` table as `event_type: "voice"`. Dashboard picks up voice entries via existing polling and renders them with a new badge type.

**Tech Stack:** Swift/AVFoundation (iOS), FastAPI/WebSocket (server), Groq Whisper API via OpenAI SDK (transcription), Next.js/React (dashboard)

---

### Task 1: Groq Transcription Client (Server)

**Files:**
- Create: `Reef-Server/lib/groq_transcribe.py`

**Step 1: Create the Groq transcription module**

```python
"""Groq Whisper transcription client."""

import os
import tempfile
from openai import OpenAI

_client: OpenAI | None = None


def _get_client() -> OpenAI:
    global _client
    if _client is None:
        api_key = os.getenv("GROQ_API_KEY")
        if not api_key:
            raise RuntimeError("GROQ_API_KEY not set")
        _client = OpenAI(api_key=api_key, base_url="https://api.groq.com/openai/v1")
    return _client


def transcribe(audio_bytes: bytes) -> str:
    """Transcribe audio bytes using Groq Whisper.

    Args:
        audio_bytes: Raw WAV audio data.

    Returns:
        Transcribed text string.
    """
    client = _get_client()
    with tempfile.NamedTemporaryFile(suffix=".wav", delete=True) as tmp:
        tmp.write(audio_bytes)
        tmp.flush()
        tmp.seek(0)
        result = client.audio.transcriptions.create(
            model="whisper-large-v3-turbo",
            file=tmp,
        )
    return result.text
```

**Step 2: Verify GROQ_API_KEY is in the environment**

Check that `GROQ_API_KEY` is set in `Reef-Server/.env` or `docker-compose.yml`. If not, add it.

**Step 3: Commit**

```bash
git add Reef-Server/lib/groq_transcribe.py
git commit -m "feat(server): add Groq Whisper transcription client"
```

---

### Task 2: Voice WebSocket Endpoint (Server)

**Files:**
- Create: `Reef-Server/api/voice.py`
- Modify: `Reef-Server/api/index.py:37-41` (add router import) and `:78-82` (register router)

**Step 1: Create the voice WebSocket endpoint**

```python
"""
WebSocket endpoint for voice message transcription.

Protocol:
  Client sends:  {"type": "voice_start", "session_id": "...", "user_id": "...", "page": 1}
  Client sends:  binary audio data (WAV)
  Client sends:  {"type": "voice_end"}
  Server sends:  {"type": "ack", "transcription": "..."}
"""

import asyncio
import json

from fastapi import APIRouter, WebSocket, WebSocketDisconnect

from lib.database import get_pool
from lib.groq_transcribe import transcribe

router = APIRouter()


@router.websocket("/ws/voice")
async def ws_voice(ws: WebSocket):
    """Receive audio from iPad, transcribe with Groq, store in DB."""
    await ws.accept()

    try:
        while True:
            # Wait for voice_start
            raw = await ws.receive_text()
            msg = json.loads(raw)

            if msg.get("type") != "voice_start":
                await ws.send_json({"type": "error", "detail": "Expected voice_start"})
                continue

            session_id = msg.get("session_id", "")
            user_id = msg.get("user_id", "")
            page = msg.get("page", 0)

            # Accumulate binary audio chunks until voice_end
            audio_buffer = bytearray()
            while True:
                ws_msg = await ws.receive()
                if "text" in ws_msg:
                    inner = json.loads(ws_msg["text"])
                    if inner.get("type") == "voice_end":
                        break
                elif "bytes" in ws_msg:
                    audio_buffer.extend(ws_msg["bytes"])

            if not audio_buffer:
                await ws.send_json({"type": "error", "detail": "No audio received"})
                continue

            # Transcribe in a thread (blocking OpenAI SDK call)
            text = await asyncio.to_thread(transcribe, bytes(audio_buffer))

            # Store in DB
            pool = get_pool()
            if pool:
                async with pool.acquire() as conn:
                    await conn.execute(
                        """
                        INSERT INTO stroke_logs
                            (session_id, page, strokes, event_type, message, user_id)
                        VALUES ($1, $2, '[]'::jsonb, 'voice', $3, $4)
                        """,
                        session_id,
                        page,
                        text,
                        user_id,
                    )

            await ws.send_json({"type": "ack", "transcription": text})

    except WebSocketDisconnect:
        pass
    except Exception as e:
        try:
            await ws.send_json({"type": "error", "detail": str(e)})
        except Exception:
            pass
```

**Step 2: Register the router in index.py**

In `Reef-Server/api/index.py`, add the import at line 40 (after the clustering import):

```python
from api.voice import router as voice_router
```

And register it at line 82 (after `app.include_router(clustering_router)`):

```python
app.include_router(voice_router)
```

**Step 3: Commit**

```bash
git add Reef-Server/api/voice.py Reef-Server/api/index.py
git commit -m "feat(server): add /ws/voice WebSocket endpoint with Groq transcription"
```

---

### Task 3: Voice Badge on Dashboard

**Files:**
- Modify: `dashboard/app/page.tsx:319-327` (badge and strokes column)

**Step 1: Add "voice" badge variant and display transcription text**

In `dashboard/app/page.tsx`, update the badge logic at line 320. Replace the existing Badge line:

```tsx
<Badge variant={log.event_type === "erase" ? "destructive" : log.event_type === "system" ? "outline" : "secondary"} className="text-[10px] px-1.5 py-0">
```

With:

```tsx
<Badge variant={log.event_type === "erase" ? "destructive" : log.event_type === "system" ? "outline" : log.event_type === "voice" ? "default" : "secondary"} className={`text-[10px] px-1.5 py-0 ${log.event_type === "voice" ? "bg-violet-600 hover:bg-violet-600" : ""}`}>
```

Then update the Strokes column at line 324-327. Replace:

```tsx
<TableCell className="tabular-nums">
  {log.event_type === "system"
    ? <span className="text-muted-foreground text-xs">{log.message}</span>
    : log.event_type === "erase" ? log.deleted_count : log.stroke_count}
</TableCell>
```

With:

```tsx
<TableCell className="tabular-nums">
  {log.event_type === "system" || log.event_type === "voice"
    ? <span className="text-muted-foreground text-xs">{log.message}</span>
    : log.event_type === "erase" ? log.deleted_count : log.stroke_count}
</TableCell>
```

**Step 2: Commit**

```bash
git add dashboard/app/page.tsx
git commit -m "feat(dashboard): display voice messages with purple badge"
```

---

### Task 4: VoiceRecordingService (iOS)

**Files:**
- Create: `Reef-iOS/Reef/Services/VoiceRecordingService.swift`

**Step 1: Create the voice recording service**

```swift
//
//  VoiceRecordingService.swift
//  Reef
//

import AVFoundation

/// Manages microphone recording for push-to-talk voice messages.
class VoiceRecordingService: NSObject, AVAudioRecorderDelegate {
    static let shared = VoiceRecordingService()

    private var audioRecorder: AVAudioRecorder?
    private var recordingURL: URL?

    /// Whether currently recording.
    private(set) var isRecording: Bool = false

    private override init() {
        super.init()
    }

    /// Start recording audio. Requests microphone permission if needed.
    /// - Returns: `true` if recording started successfully.
    @discardableResult
    func startRecording() -> Bool {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.record, mode: .default)
            try session.setActive(true)
        } catch {
            print("[VoiceRecording] Failed to set up audio session: \(error)")
            return false
        }

        // Request permission
        var permissionGranted = false
        let semaphore = DispatchSemaphore(value: 0)
        AVAudioApplication.requestRecordPermission { granted in
            permissionGranted = granted
            semaphore.signal()
        }
        semaphore.wait()

        guard permissionGranted else {
            print("[VoiceRecording] Microphone permission denied")
            return false
        }

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("wav")

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatLinearPCM),
            AVSampleRateKey: 16000,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false,
        ]

        do {
            let recorder = try AVAudioRecorder(url: url, settings: settings)
            recorder.delegate = self
            recorder.record()
            audioRecorder = recorder
            recordingURL = url
            isRecording = true
            print("[VoiceRecording] Started recording to \(url.lastPathComponent)")
            return true
        } catch {
            print("[VoiceRecording] Failed to start recording: \(error)")
            return false
        }
    }

    /// Stop recording and return the audio data.
    /// - Returns: WAV audio data, or `nil` if not recording.
    func stopRecording() -> Data? {
        guard let recorder = audioRecorder, isRecording else { return nil }

        recorder.stop()
        isRecording = false

        defer {
            // Clean up temp file
            if let url = recordingURL {
                try? FileManager.default.removeItem(at: url)
            }
            audioRecorder = nil
            recordingURL = nil
        }

        guard let url = recordingURL else { return nil }
        let data = try? Data(contentsOf: url)
        print("[VoiceRecording] Stopped recording, \(data?.count ?? 0) bytes")
        return data
    }
}
```

**Step 2: Add microphone usage description to Info.plist**

In `Reef-iOS/Info.plist`, add the `NSMicrophoneUsageDescription` key before the closing `</dict>`:

```xml
<key>NSMicrophoneUsageDescription</key>
<string>Reef uses the microphone to record voice messages for your study sessions.</string>
```

**Step 3: Commit**

```bash
git add Reef-iOS/Reef/Services/VoiceRecordingService.swift Reef-iOS/Info.plist
git commit -m "feat(ios): add VoiceRecordingService and microphone permission"
```

---

### Task 5: Voice WebSocket in AIService (iOS)

**Files:**
- Modify: `Reef-iOS/Reef/Services/AIService.swift:132-259` (add voice WebSocket methods after stroke WebSocket section)

**Step 1: Add voice WebSocket methods to AIService**

Add the following after the `listenForStrokeAcks()` method (before the closing `}` of the class at line 261):

```swift
// MARK: - Voice WebSocket

private var voiceSocket: URLSessionWebSocketTask?

/// Connect to the voice transcription WebSocket.
func connectVoiceSocket() {
    guard voiceSocket == nil else { return }
    let wsURL = baseURL
        .replacingOccurrences(of: "https://", with: "wss://")
        .replacingOccurrences(of: "http://", with: "ws://")
        + "/ws/voice"
    guard let url = URL(string: wsURL) else { return }
    let task = session.webSocketTask(with: url)
    voiceSocket = task
    task.resume()
}

/// Disconnect the voice WebSocket.
func disconnectVoiceSocket() {
    voiceSocket?.cancel(with: .normalClosure, reason: nil)
    voiceSocket = nil
}

/// Send recorded audio data for transcription.
/// - Parameters:
///   - audioData: WAV audio bytes
///   - sessionId: Current document session ID
///   - page: Current page number
func sendVoiceMessage(audioData: Data, sessionId: String, page: Int) {
    if voiceSocket == nil {
        connectVoiceSocket()
    }
    guard let socket = voiceSocket else { return }

    let userId = KeychainService.get(.userIdentifier) ?? ""

    // 1. Send voice_start
    let startPayload: [String: Any] = [
        "type": "voice_start",
        "session_id": sessionId,
        "user_id": userId,
        "page": page
    ]
    guard let startData = try? JSONSerialization.data(withJSONObject: startPayload),
          let startText = String(data: startData, encoding: .utf8) else { return }

    socket.send(.string(startText)) { [weak self] error in
        if let error = error {
            print("[VoiceWS] Failed to send voice_start: \(error)")
            return
        }

        // 2. Send binary audio data
        socket.send(.data(audioData)) { error in
            if let error = error {
                print("[VoiceWS] Failed to send audio data: \(error)")
                return
            }

            // 3. Send voice_end
            let endPayload = ["type": "voice_end"]
            guard let endData = try? JSONSerialization.data(withJSONObject: endPayload),
                  let endText = String(data: endData, encoding: .utf8) else { return }

            socket.send(.string(endText)) { error in
                if let error = error {
                    print("[VoiceWS] Failed to send voice_end: \(error)")
                    return
                }

                // 4. Listen for ack with transcription
                socket.receive { result in
                    switch result {
                    case .success(let message):
                        if case .string(let text) = message,
                           let data = text.data(using: .utf8),
                           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                           let transcription = json["transcription"] as? String {
                            print("[VoiceWS] Transcription: \(transcription)")
                        }
                    case .failure(let error):
                        print("[VoiceWS] Failed to receive ack: \(error)")
                        DispatchQueue.main.async {
                            self?.voiceSocket = nil
                        }
                    }
                }
            }
        }
    }
}
```

**Step 2: Commit**

```bash
git add Reef-iOS/Reef/Services/AIService.swift
git commit -m "feat(ios): add voice WebSocket to AIService"
```

---

### Task 6: Wire Mic Button to Recording (iOS)

**Files:**
- Modify: `Reef-iOS/Reef/Views/Canvas/CanvasView.swift:110-191` (add recording state + wire callback)
- Modify: `Reef-iOS/Reef/Views/Canvas/CanvasToolbar.swift:118,654-663` (add isRecording prop + visual state)

**Step 1: Add isRecording state and callback to CanvasView**

In `CanvasView.swift`, add a new `@State` property after the existing states (around line 50):

```swift
// Voice recording state
@State private var isRecording: Bool = false
```

Then in the `CanvasToolbar(...)` initializer call (starting line 114), add the new properties. After line 190 (`textColor: $textColor`), add:

```swift
,
isRecording: isRecording,
onAIActionSelected: { action in
    if action == "ask" {
        if isRecording {
            // Stop recording and send
            isRecording = false
            if let audioData = VoiceRecordingService.shared.stopRecording() {
                let sessionId = note?.id.uuidString ?? quiz?.id.uuidString ?? ""
                AIService.shared.sendVoiceMessage(
                    audioData: audioData,
                    sessionId: sessionId,
                    page: 0
                )
            }
        } else {
            // Start recording
            if VoiceRecordingService.shared.startRecording() {
                isRecording = true
            }
        }
    }
}
```

**Step 2: Update CanvasToolbar to accept and use isRecording**

In `CanvasToolbar.swift`, add a new property after `isAssignmentProcessing` (line 143):

```swift
var isRecording: Bool = false
```

Then update the mic button (lines 654-663) to show recording state:

```swift
// Mic
ToolbarButton(
    icon: isRecording ? "mic.fill" : "mic.fill",
    isSelected: isRecording,
    isDisabled: aiDisabled,
    showProcessingIndicator: isRecording || (!isDocumentAIReady || isAssignmentProcessing),
    processingIndicatorColor: isRecording ? .red : (isAssignmentProcessing ? .blue : .yellow),
    colorScheme: colorScheme,
    action: { onAIActionSelected("ask") }
)
```

**Step 3: Commit**

```bash
git add Reef-iOS/Reef/Views/Canvas/CanvasView.swift Reef-iOS/Reef/Views/Canvas/CanvasToolbar.swift
git commit -m "feat(ios): wire mic button to push-to-talk recording and WebSocket send"
```

---

### Task 7: Deploy and Test End-to-End

**Step 1: Deploy server changes**

```bash
cd Reef-Server && ./deploy.sh deploy@178.156.139.74
```

**Step 2: Test the full flow**

1. Open the dashboard in a browser
2. On iPad, open a document in assignment mode
3. Click the mic button — verify it shows recording state (red indicator)
4. Speak a sentence
5. Click mic again — verify recording stops, indicator clears
6. Check dashboard — verify a new row appears with event_type "voice" (purple badge) and the transcribed text in the Strokes column

**Step 3: Final commit with any fixes**

```bash
git add -A
git commit -m "feat: push-to-talk voice messages — end-to-end"
```
