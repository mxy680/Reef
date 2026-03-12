#!/usr/bin/env bash
# Creates GitHub issues for all findings in the Reef-iOS security audit.
# Requires: gh auth login (GitHub CLI authenticated)
# Usage: ./scripts/create-audit-issues.sh

set -euo pipefail

REPO="mxy680/Reef"
LABEL="security"

# Create the security label if it doesn't exist
gh label create "$LABEL" --repo "$REPO" --color "D73A4A" --description "Security vulnerability or hardening" 2>/dev/null || true
gh label create "ios" --repo "$REPO" --color "5319E7" --description "Reef-iOS" 2>/dev/null || true

create_issue() {
  local title="$1"
  local body="$2"
  local priority="$3"

  local labels="$LABEL,ios,$priority"

  echo "Creating: $title"
  gh issue create --repo "$REPO" --title "$title" --label "$labels" --body "$body"
}

# --- Critical ---

create_issue \
  "[iOS/Security] ATS disabled — NSAllowsArbitraryLoads is true" \
  "$(cat <<'EOF'
## Severity: Critical

**File:** `Info.plist:47-51`

App Transport Security is completely disabled, allowing plaintext HTTP and bypassing certificate validation. Network attackers (e.g. public WiFi) can intercept all traffic including auth tokens.

### Fix
Set `NSAllowsArbitraryLoads` to `false`. Add per-domain exceptions only for local development (e.g. `localhost`).

_From security audit (2026-03-12)_
EOF
)" "critical"

create_issue \
  "[iOS/Security] Force unwrap crash in createBlankPage()" \
  "$(cat <<'EOF'
## Severity: Critical

**File:** `Reef/Views/Canvas/CanvasViewModel.swift:117`
**Code:** `return PDFDocument(data: data)!.page(at: 0)!`

Double force unwrap during page add/delete. If PDF renderer output is unparseable, app crashes and unsaved work is lost.

### Fix
Use guard-let with error fallback.

_From security audit (2026-03-12)_
EOF
)" "critical"

create_issue \
  "[iOS/Security] fatalError on missing Supabase config" \
  "$(cat <<'EOF'
## Severity: Critical

**File:** `Reef/Config/Supabase.swift:10`

Missing `SUPABASE_URL` or `SUPABASE_ANON_KEY` crashes the app on launch with no user feedback.

### Fix
Show a graceful error screen or disable server features.

_From security audit (2026-03-12)_
EOF
)" "critical"

# --- High ---

create_issue \
  "[iOS/Security] JWT token exposed in WebSocket URL query parameter" \
  "$(cat <<'EOF'
## Severity: High

**File:** `Reef/Services/ReefAPI.swift:126`

Access token passed as `?token=` in WebSocket URL. Combined with ATS disabled, token could be intercepted. URLs may be logged by proxies/CDNs.

### Mitigation
Keep token lifetimes short. Fix ATS to ensure WSS is always used.

_From security audit (2026-03-12)_
EOF
)" "high"

create_issue \
  "[iOS/Security] No WebSocket reconnection logic" \
  "$(cat <<'EOF'
## Severity: High

**File:** `Reef/Services/ReefAPI.swift:152-169`

When WebSocket disconnects (network change, server restart, token expiry), no reconnection is attempted. App silently loses real-time updates.

### Fix
Implement reconnection with exponential backoff and notify UI of connection state.

_From security audit (2026-03-12)_
EOF
)" "high"

create_issue \
  "[iOS/Security] WebSocket messages never processed" \
  "$(cat <<'EOF'
## Severity: High

**File:** `Reef/Services/ReefAPI.swift:158-163`

Incoming messages are `print()`-ed but never parsed or dispatched. WebSocket is effectively dead code. Also leaks message contents to debug logs.

_From security audit (2026-03-12)_
EOF
)" "high"

create_issue \
  "[iOS/Security] URLSession leak on WebSocket reconnect" \
  "$(cat <<'EOF'
## Severity: High

**File:** `Reef/Services/ReefAPI.swift:130`

New `URLSession` created per `connectWebSocket()` call but never invalidated. `URLSession` retains its delegate — repeated connections leak memory.

### Fix
Reuse a single session or call `finishTasksAndInvalidate()` on the old one.

_From security audit (2026-03-12)_
EOF
)" "high"

create_issue \
  "[iOS/Security] KaTeX WebView — JavaScript injection vector" \
  "$(cat <<'EOF'
## Severity: High

**File:** `Reef/Design/Components/KaTeXView.swift:119`

LaTeX text is JSON-encoded and interpolated into JavaScript source. While `textContent` assignment prevents HTML injection, the JSON string is spliced directly into `<script>`. Defense relies entirely on `JSONEncoder` producing valid JSON.

### Fix
Pass data via `WKScriptMessage` post-load instead of string interpolation.

_From security audit (2026-03-12)_
EOF
)" "high"

create_issue \
  "[iOS/Security] Silent save failure — data loss without warning" \
  "$(cat <<'EOF'
## Severity: High

**File:** `Reef/Views/Canvas/CanvasViewModel.swift:50-52`

PDF save errors are `print()`-ed only. User has no indication their work wasn't persisted.

### Fix
Surface error to UI (toast, alert, or dirty indicator).

_From security audit (2026-03-12)_
EOF
)" "high"

# --- Medium ---

create_issue \
  "[iOS/Security] Force unwrap in ContentView" \
  "$(cat <<'EOF'
## Severity: Medium

**File:** `Reef/ContentView.swift:11`
**Code:** `DocumentCanvasView(document: canvasDocument!)`

Guarded by `if canvasDocument != nil` but fragile — use `if let` binding instead.

_From security audit (2026-03-12)_
EOF
)" "medium"

create_issue \
  "[iOS/Security] Dev mode auto-login with hardcoded credentials" \
  "$(cat <<'EOF'
## Severity: Medium

**File:** `Reef/Auth/AuthManager.swift:206-216`

DEBUG builds auto-bypass authentication with hardcoded email. `devLogin()` is called automatically when session restore fails (line 68). If a debug build reaches testers, they get full access without auth.

_From security audit (2026-03-12)_
EOF
)" "medium"

create_issue \
  "[iOS/Security] Unbounded undo stack — potential OOM" \
  "$(cat <<'EOF'
## Severity: Medium

**File:** `Reef/Views/Canvas/CanvasViewModel.swift:57`

Every page operation pushes a full PDF snapshot onto an unbounded `[Data]` array. Large documents can exhaust memory.

### Fix
Cap stack size (e.g. 20 entries) and evict oldest.

_From security audit (2026-03-12)_
EOF
)" "medium"

create_issue \
  "[iOS/Security] Share link clipboard exposure" \
  "$(cat <<'EOF'
## Severity: Medium

**File:** `Reef/Views/Dashboard/Documents/DocumentsViewModel.swift:203-204`

7-day signed URLs copied to system clipboard, accessible by any app. No warning about expiry or that anyone with the link can access the document.

_From security audit (2026-03-12)_
EOF
)" "medium"

create_issue \
  "[iOS/Security] Missing bounds check in CanvasStrokeCollector" \
  "$(cat <<'EOF'
## Severity: Medium

**File:** `Reef/Views/Canvas/CanvasStrokeCollector.swift:58-59`

`questionPages[questionIndex]` and `questionRegions[questionIndex]` accessed without verifying index is in bounds. Out-of-range index = crash.

### Fix
Add `guard questionIndex < questionPages.count, questionIndex < questionRegions.count`.

_From security audit (2026-03-12)_
EOF
)" "medium"

create_issue \
  "[iOS/Security] Drawings stored unencrypted" \
  "$(cat <<'EOF'
## Severity: Medium

**File:** `Reef/Services/DrawingStorageService.swift:14`

PencilKit drawings and tutor progress stored as plaintext in Documents directory. Accessible via iTunes File Sharing and unencrypted backups.

### Fix
Use `NSFileProtectionComplete` or Application Support with `isExcludedFromBackup`.

_From security audit (2026-03-12)_
EOF
)" "medium"

create_issue \
  "[iOS/Security] Signed URL expiry too long" \
  "$(cat <<'EOF'
## Severity: Medium

**File:** `Reef/Services/DocumentService.swift:250`

Download URLs valid for 1 hour; share URLs valid for 7 days. If leaked, documents accessible without auth for that window.

_From security audit (2026-03-12)_
EOF
)" "medium"

create_issue \
  "[iOS/Security] Untracked auth state Task — no cancellation" \
  "$(cat <<'EOF'
## Severity: Medium

**File:** `Reef/Auth/AuthManager.swift:47-59`

The `authStateChanges` async sequence is consumed in a fire-and-forget `Task {}` with no stored reference. It can't be cancelled on logout or deallocation. Nested `Task { await ReefAPI.shared.connectWebSocket() }` calls inside are also untracked.

### Fix
Store the Task reference and cancel it during sign-out.

_From security audit (2026-03-12)_
EOF
)" "medium"

create_issue \
  "[iOS/Security] MainActor.assumeIsolated in KVO callback" \
  "$(cat <<'EOF'
## Severity: Medium

**File:** `Reef/Design/Components/KaTeXView.swift:167`

`MainActor.assumeIsolated` is used inside a KVO observation closure. If WebKit ever calls this from a background thread, this is undefined behavior. The `userContentController(didReceive:)` handler (line 176) correctly uses `Task { @MainActor in }` instead — the KVO callback should do the same.

_From security audit (2026-03-12)_
EOF
)" "medium"

create_issue \
  "[iOS/Security] nonisolated(unsafe) on DateFormatter" \
  "$(cat <<'EOF'
## Severity: Medium

**File:** `Reef/Models/Document.swift:71-74`

`nonisolated(unsafe)` disables thread safety checks on a static `ISO8601DateFormatter`. While `ISO8601DateFormatter` is likely thread-safe, the `nonisolated(unsafe)` annotation suppresses all compiler isolation checks, which could mask real issues if the code evolves.

_From security audit (2026-03-12)_
EOF
)" "medium"

create_issue \
  "[iOS/Security] WebSocket receive Task not cancellable" \
  "$(cat <<'EOF'
## Severity: Medium

**File:** `Reef/Services/ReefAPI.swift:135`
**Code:** `Task { await receiveLoop() }`

The receive loop Task is not stored, so `disconnectWebSocket()` can't cancel it. The loop relies on the `isConnected` flag, but `ws.receive()` blocks until a message arrives — so the loop won't check the flag until the next message. If `connectWebSocket()` is called again before the old loop exits, two loops run concurrently on different tasks.

_From security audit (2026-03-12)_
EOF
)" "medium"

# --- Low ---

create_issue \
  "[iOS/Security] try! on regex compilation" \
  "$(cat <<'EOF'
## Severity: Low

**File:** `Reef/Design/Components/MathText.swift:21`

Static regex crash on invalid pattern. Low risk since pattern is a compile-time constant.

_From security audit (2026-03-12)_
EOF
)" "low"

create_issue \
  "[iOS/Security] No client-side email validation" \
  "$(cat <<'EOF'
## Severity: Low

**File:** `Reef/Auth/AuthManager.swift:191`

Email sent to Supabase OTP without format validation.

_From security audit (2026-03-12)_
EOF
)" "low"

create_issue \
  "[iOS/Security] Generic error messages" \
  "$(cat <<'EOF'
## Severity: Low

**Files:** `DocumentsViewModel.swift` (lines 128, 140, 163, etc.)

"Something went wrong" for all errors — users can't distinguish network vs auth vs server issues.

_From security audit (2026-03-12)_
EOF
)" "low"

create_issue \
  "[iOS/Security] Polling timer lifetime" \
  "$(cat <<'EOF'
## Severity: Low

**File:** `Reef/Views/Dashboard/Documents/DocumentsViewModel.swift:62`

Timer uses `[weak self]` correctly but could continue if view model is retained elsewhere.

_From security audit (2026-03-12)_
EOF
)" "low"

create_issue \
  "[iOS/Security] Unbounded in-memory cache" \
  "$(cat <<'EOF'
## Severity: Low

**File:** `Reef/Services/AnswerKeyService.swift:28`

`[String: AnswerKeyResult]` cache never evicts entries. Use `NSCache` instead.

_From security audit (2026-03-12)_
EOF
)" "low"

create_issue \
  "[iOS/Security] Temp PDF files never cleaned up" \
  "$(cat <<'EOF'
## Severity: Low

**File:** `Reef/Services/DocumentService.swift:306-311`

Downloaded PDFs written to temp dir but never explicitly deleted.

_From security audit (2026-03-12)_
EOF
)" "low"

echo ""
echo "Done! Created 26 issues."
