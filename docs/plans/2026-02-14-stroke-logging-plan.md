# Stroke Logging Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Delete the tutor mode pipeline and replace it with a WebSocket that streams raw PencilKit strokes to the server, which logs them to Postgres with datetime and coordinates.

**Architecture:** The server gets a new `api/strokes.py` with a WebSocket endpoint at `ws/strokes`. iOS extracts full PKStrokePoint data (x, y, timestamp, force, altitude, azimuth) on each drawing change and sends it over WebSocket. The server inserts each batch into a `stroke_logs` table in Postgres.

**Tech Stack:** FastAPI WebSocket, asyncpg, PencilKit, URLSession WebSocket

---

### Task 1: Delete server-side tutor pipeline files

**Files:**
- Delete: `Reef-Server/api/tutoring.py`
- Delete: `Reef-Server/api/transcribe.py`
- Delete: `Reef-Server/api/clustering.py`
- Delete: `Reef-Server/lib/models/feedback.py`

**Step 1: Delete the files**

```bash
cd /Users/markshteyn/projects/Reef/Reef-Server
rm api/tutoring.py api/transcribe.py api/clustering.py lib/models/feedback.py
```

**Step 2: Commit**

```bash
git add -A && git commit -m "chore: delete tutor pipeline files (tutoring, transcribe, clustering, feedback)"
```

---

### Task 2: Clean up server index.py — remove deleted router imports

**Files:**
- Modify: `Reef-Server/api/index.py:37-84`

**Step 1: Remove imports and router registrations for deleted modules**

In `api/index.py`, remove these lines:

```python
# Line 38 — delete:
from api.clustering import router as clustering_router
# Line 40 — delete:
from api.transcribe import router as transcribe_router
# Line 41 — delete:
from api.tutoring import router as tutoring_router
```

And remove these router registrations:

```python
# Line 81 — delete:
app.include_router(clustering_router)
# Line 83 — delete:
app.include_router(transcribe_router)
# Line 84 — delete:
app.include_router(tutoring_router)
```

Keep `tts_router` — it's a separate WebSocket TTS endpoint (Modal Kokoro), not part of the tutor pipeline.

**Step 2: Verify the server starts**

```bash
cd /Users/markshteyn/projects/Reef/Reef-Server
python -c "from api.index import app; print('OK')"
```

Expected: `OK` (no import errors)

**Step 3: Commit**

```bash
git add api/index.py && git commit -m "chore: remove deleted pipeline routers from index"
```

---

### Task 3: Add stroke_logs table to database init

**Files:**
- Modify: `Reef-Server/lib/database.py:19-28`

**Step 1: Add the stroke_logs table creation**

After the existing `CREATE TABLE IF NOT EXISTS user_profiles` block (line 20-28), add:

```python
        await conn.execute("""
            CREATE TABLE IF NOT EXISTS stroke_logs (
                id SERIAL PRIMARY KEY,
                session_id TEXT NOT NULL,
                page INT NOT NULL,
                received_at TIMESTAMPTZ DEFAULT NOW(),
                strokes JSONB NOT NULL
            )
        """)
```

Also update the print message on line 29 to:

```python
    print("[DB] Connected and tables ready")
```

**Step 2: Verify import still works**

```bash
cd /Users/markshteyn/projects/Reef/Reef-Server
python -c "from lib.database import init_db; print('OK')"
```

**Step 3: Commit**

```bash
git add lib/database.py && git commit -m "feat: add stroke_logs table to database init"
```

---

### Task 4: Create server-side stroke logging WebSocket endpoint

**Files:**
- Create: `Reef-Server/api/strokes.py`
- Modify: `Reef-Server/api/index.py` (add new router)

**Step 1: Create `api/strokes.py`**

```python
"""
WebSocket endpoint for real-time stroke logging.

iOS streams full PKStrokePoint data per page; server logs
each batch to the stroke_logs table in Postgres.
"""

import json

from fastapi import APIRouter, WebSocket, WebSocketDisconnect

from lib.database import get_pool

router = APIRouter()


@router.websocket("/ws/strokes")
async def strokes_websocket(ws: WebSocket):
    await ws.accept()

    try:
        while True:
            raw = await ws.receive_text()
            msg = json.loads(raw)

            if msg.get("type") != "strokes":
                continue

            session_id = msg.get("session_id", "")
            page = msg.get("page", 1)
            strokes = msg.get("strokes", [])

            pool = get_pool()
            if pool:
                async with pool.acquire() as conn:
                    await conn.execute(
                        """
                        INSERT INTO stroke_logs (session_id, page, strokes)
                        VALUES ($1, $2, $3::jsonb)
                        """,
                        session_id,
                        page,
                        json.dumps(strokes),
                    )

            await ws.send_text(json.dumps({"type": "ack"}))

    except WebSocketDisconnect:
        pass
    except Exception as e:
        print(f"[strokes_ws] error: {e}")
        try:
            await ws.close(code=1011, reason=str(e)[:120])
        except Exception:
            pass
```

**Step 2: Register the router in `api/index.py`**

Add import (after the `tts_router` import):

```python
from api.strokes import router as strokes_router
```

Add registration (after `app.include_router(tts_router)`):

```python
app.include_router(strokes_router)
```

**Step 3: Verify import**

```bash
cd /Users/markshteyn/projects/Reef/Reef-Server
python -c "from api.index import app; print('OK')"
```

**Step 4: Commit**

```bash
git add api/strokes.py api/index.py && git commit -m "feat: add ws/strokes WebSocket endpoint for stroke logging"
```

---

### Task 5: Delete iOS StrokeClusterManager.swift

**Files:**
- Delete: `Reef-iOS/Reef/Services/StrokeClusterManager.swift`

**Step 1: Delete the file**

```bash
rm /Users/markshteyn/projects/Reef/Reef-iOS/Reef/Services/StrokeClusterManager.swift
```

**Step 2: Commit**

```bash
cd /Users/markshteyn/projects/Reef/Reef-iOS
git add -A && git commit -m "chore: delete StrokeClusterManager (replaced by stroke streaming)"
```

---

### Task 6: Gut AIService.swift — remove tutor/cluster code, add stroke WebSocket

**Files:**
- Modify: `Reef-iOS/Reef/Services/AIService.swift`

**Step 1: Remove tutor pipeline and cluster WebSocket code**

Delete these sections from `AIService.swift`:

1. Lines 64-69: WebSocket state properties (`clusterSocket`, `clusterCallback`, `reconnectAttempts`, `maxReconnectAttempts`)
2. Lines 138-207: Transcription section (`// MARK: - Transcription` through `TranscriptionResponse`)
3. Lines 209-324: Tutor Pipeline section (`// MARK: - Tutor Pipeline` through the closing brace of `requestTutorFeedback`)
4. Lines 326-423: Cluster WebSocket section (`// MARK: - Cluster WebSocket` through `listenForClusterMessages`)

**Step 2: Add stroke WebSocket code**

Replace the deleted sections with a new `// MARK: - Stroke WebSocket` section:

```swift
// MARK: - Stroke WebSocket

private var strokeSocket: URLSessionWebSocketTask?
private var strokeReconnectAttempts: Int = 0
private static let maxStrokeReconnectAttempts = 5

/// Connects to the stroke logging WebSocket endpoint.
func connectStrokeSocket() {
    guard strokeSocket == nil else { return }
    #if DEBUG
    let wsURL = baseURL.replacingOccurrences(of: "https://", with: "wss://") + "/ws/strokes"
    #else
    let wsURL = "wss://api.studyreef.com/ws/strokes"
    #endif
    guard let url = URL(string: wsURL) else { return }
    let task = session.webSocketTask(with: url)
    strokeSocket = task
    task.resume()
    strokeReconnectAttempts = 0
    listenForStrokeAcks()
}

/// Disconnects the stroke WebSocket.
func disconnectStrokeSocket() {
    strokeSocket?.cancel(with: .normalClosure, reason: nil)
    strokeSocket = nil
}

/// Sends stroke point data for a page to the server for logging.
func sendStrokes(sessionId: String, page: Int, strokes: [[[String: Double]]]) {
    if strokeSocket == nil {
        connectStrokeSocket()
    }
    guard let socket = strokeSocket else { return }

    let payload: [String: Any] = [
        "type": "strokes",
        "session_id": sessionId,
        "page": page,
        "strokes": strokes.map { points in
            ["points": points]
        }
    ]

    guard let data = try? JSONSerialization.data(withJSONObject: payload),
          let text = String(data: data, encoding: .utf8) else { return }

    socket.send(.string(text)) { [weak self] error in
        if error != nil {
            DispatchQueue.main.async {
                self?.strokeSocket?.cancel(with: .abnormalClosure, reason: nil)
                self?.strokeSocket = nil
            }
        }
    }
}

/// Receive loop for ack messages (keeps connection alive).
private func listenForStrokeAcks() {
    guard let socket = strokeSocket else { return }
    socket.receive { [weak self] result in
        switch result {
        case .success:
            DispatchQueue.main.async {
                self?.listenForStrokeAcks()
            }
        case .failure:
            guard let self = self else { return }
            DispatchQueue.main.async {
                self.strokeSocket = nil
                self.strokeReconnectAttempts += 1
                if self.strokeReconnectAttempts <= Self.maxStrokeReconnectAttempts {
                    let delay = min(pow(2.0, Double(self.strokeReconnectAttempts)), 30.0)
                    DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                        self.connectStrokeSocket()
                    }
                }
            }
        }
    }
}
```

**Step 3: Commit**

```bash
cd /Users/markshteyn/projects/Reef/Reef-iOS
git add Reef/Services/AIService.swift && git commit -m "feat: replace cluster/tutor WebSocket with stroke logging WebSocket"
```

---

### Task 7: Simplify DrawingOverlayView.swift — remove pipeline, add stroke streaming

**Files:**
- Modify: `Reef-iOS/Reef/Views/Canvas/DrawingOverlayView.swift`

This is the largest change. The Coordinator class needs to be gutted of all pipeline, clustering, audio, and feedback logic, and replaced with simple stroke streaming.

**Step 1: Remove imports**

Remove `AVFoundation` import (line 13). The `CoreImage` imports can stay (used by dark mode filter in `CanvasContainerView`).

**Step 2: Remove Coordinator pipeline state properties**

Remove these from the Coordinator class (lines 179-207):

- `transcriptionTask` (line 180)
- `clusterManagers` dictionary (line 183)
- `audioPlayer`, `audioQueue`, `isPlayingAudio` (lines 192-194)
- `debounceTask`, `inactivityTask`, `currentTutorTask`, `tutorHistory` (lines 197-200)
- `lastDrawingChangeTime` (line 203)
- `activeStrokeBoundsUnion` (line 207)
- `webSocketConnected` (line 221)

**Step 3: Add stroke streaming state to Coordinator**

Replace the removed properties with:

```swift
// Stroke streaming
private var strokeSessionId: String = UUID().uuidString
private var strokeSocketConnected: Bool = false
private var previousStrokeKeys: Set<StrokeBoundsKey> = []
```

Note: We keep `StrokeBoundsKey` as a simple local struct (since we deleted the file). Actually — we don't need `StrokeBoundsKey` anymore. We'll track strokes by count instead. Replace with:

```swift
// Stroke streaming
private var strokeSessionId: String = UUID().uuidString
private var strokeSocketConnected: Bool = false
private var lastSentStrokeCount: [ObjectIdentifier: Int] = [:]
```

**Step 4: Remove deleted helper methods from Coordinator**

Delete these methods entirely:

- `getClusterManager(for:)` (lines 224-232)
- `ensureWebSocketConnected()` (lines 243-250)
- `triggerPipeline(_:)` (lines 253-265)
- `cancelActivePipeline()` (lines 268-275)
- `handleClusterResponse(page:clusters:)` (lines 278-385)
- `playTutorAudio(_:)` (lines 388-391)
- `playNextAudioIfNeeded()` (lines 394-407)
- `audioPlayerDidFinishPlaying(_:successfully:)` (lines 409-412)

**Step 5: Add stroke extraction and sending helper**

Add this helper method to the Coordinator:

```swift
/// Extracts full PKStrokePoint data from new strokes and sends to server.
private func sendNewStrokes(from canvasView: PKCanvasView) {
    if !strokeSocketConnected {
        strokeSocketConnected = true
        AIService.shared.connectStrokeSocket()
    }

    let key = ObjectIdentifier(canvasView)
    let allStrokes = canvasView.drawing.strokes
    let previousCount = lastSentStrokeCount[key] ?? 0

    guard allStrokes.count > previousCount else { return }
    let newStrokes = allStrokes[previousCount...]
    lastSentStrokeCount[key] = allStrokes.count

    let pageNum = getPageIndex(for: canvasView)

    let strokeData: [[[String: Double]]] = newStrokes.map { stroke in
        stroke.path.map { point in
            [
                "x": Double(point.location.x),
                "y": Double(point.location.y),
                "t": point.timeOffset,
                "force": Double(point.force),
                "altitude": Double(point.altitude),
                "azimuth": Double(point.azimuth)
            ]
        }
    }

    AIService.shared.sendStrokes(
        sessionId: strokeSessionId,
        page: pageNum,
        strokes: strokeData
    )
}
```

**Step 6: Simplify `canvasViewDrawingDidChange`**

Replace the current method body (lines 414-519) with:

```swift
func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
    updateUndoRedoState(canvasView)

    // Skip if we triggered this via shape replacement
    guard !isReplacingStroke else { return }

    // Shape autosnap — only for Diagram tool with autosnap enabled
    let currentStrokeCount = canvasView.drawing.strokes.count
    if currentTool == .diagram,
       diagramAutosnap,
       currentStrokeCount > previousStrokeCount,
       let newStroke = canvasView.drawing.strokes.last,
       let replacement = ShapeDetector.detect(stroke: newStroke) {

        isReplacingStroke = true
        var strokes = canvasView.drawing.strokes
        strokes[strokes.count - 1] = replacement
        canvasView.drawing = PKDrawing(strokes: strokes)
        previousStrokeCount = canvasView.drawing.strokes.count
        DispatchQueue.main.async { self.isReplacingStroke = false }

        // Trigger debounced save
        drawingChangeTask?.cancel()
        drawingChangeTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 500_000_000)
            if !Task.isCancelled {
                self.container?.saveAllDrawings()
                self.onDrawingChanged(canvasView.drawing)
            }
        }

        // Send new strokes after shape replacement
        sendNewStrokes(from: canvasView)
        return
    }

    previousStrokeCount = currentStrokeCount

    // Debounced save callback (500ms)
    drawingChangeTask?.cancel()
    drawingChangeTask = Task { @MainActor in
        try? await Task.sleep(nanoseconds: 500_000_000)
        if !Task.isCancelled {
            self.container?.saveAllDrawings()
            self.onDrawingChanged(canvasView.drawing)
        }
    }

    // Stream new strokes to server
    sendNewStrokes(from: canvasView)
}
```

**Step 7: Simplify `canvasViewDidEndUsingTool`**

Replace the current method body (lines 526-549) with:

```swift
func canvasViewDidEndUsingTool(_ canvasView: PKCanvasView) {
    updateUndoRedoState(canvasView)
}
```

**Step 8: Remove `canvasViewDidBeginUsingTool`**

Delete the method (lines 521-524) — it only cancelled the debounce timer.

**Step 9: Remove AVAudioPlayerDelegate conformance**

Change the Coordinator class declaration (line 169) from:

```swift
class Coordinator: NSObject, PKCanvasViewDelegate, AVAudioPlayerDelegate {
```

to:

```swift
class Coordinator: NSObject, PKCanvasViewDelegate {
```

**Step 10: Commit**

```bash
cd /Users/markshteyn/projects/Reef/Reef-iOS
git add Reef/Views/Canvas/DrawingOverlayView.swift && git commit -m "feat: replace pipeline trigger with simple stroke streaming"
```

---

### Task 8: Verify everything builds and run manual smoke test

**Step 1: Verify server starts without errors**

```bash
cd /Users/markshteyn/projects/Reef/Reef-Server
python -c "from api.index import app; print([r.path for r in app.routes])"
```

Expected: Routes list includes `/ws/strokes` and does NOT include `/ws/cluster`, `/ai/tutor`, or `/ai/transcribe`.

**Step 2: Verify iOS builds**

Open Xcode and build the Reef-iOS project. Fix any compilation errors.

**Step 3: Final commit**

```bash
cd /Users/markshteyn/projects/Reef
git add Reef-Server Reef-iOS && git commit -m "feat: replace tutor pipeline with stroke logging"
```
