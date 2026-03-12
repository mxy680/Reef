# Reef-iOS Security Audit

**Date**: 2026-03-12
**Scope**: Full review of Reef-iOS Swift codebase for security vulnerabilities, bugs, and reliability issues

## Critical

### 1. ATS Disabled — `NSAllowsArbitraryLoads` is `true`
- **File**: `Info.plist:47-51`
- **Issue**: App Transport Security is completely disabled, allowing plaintext HTTP and bypassing certificate validation. Network attackers (e.g. public WiFi) can intercept all traffic including auth tokens.
- **Fix**: Set `NSAllowsArbitraryLoads` to `false`. Add per-domain exceptions only for local development (e.g. `localhost`).

### 2. Force Unwrap Crash in `createBlankPage()`
- **File**: `Reef/Views/Canvas/CanvasViewModel.swift:117`
- **Code**: `return PDFDocument(data: data)!.page(at: 0)!`
- **Issue**: Double force unwrap during page add/delete. If PDF renderer output is unparseable, app crashes and unsaved work is lost.
- **Fix**: Use guard-let with error fallback.

### 3. `fatalError` on Missing Supabase Config
- **File**: `Reef/Config/Supabase.swift:10`
- **Issue**: Missing `SUPABASE_URL` or `SUPABASE_ANON_KEY` crashes the app on launch with no user feedback.
- **Fix**: Show a graceful error screen or disable server features.

## High

### 4. JWT Token in WebSocket URL Query Parameter
- **File**: `Reef/Services/ReefAPI.swift:126`
- **Issue**: Access token passed as `?token=` in WebSocket URL. Combined with ATS disabled (#1), token could be intercepted. URLs may be logged by proxies/CDNs.
- **Mitigation**: Keep token lifetimes short. Fix ATS (#1) to ensure WSS is always used.

### 5. No WebSocket Reconnection Logic
- **File**: `Reef/Services/ReefAPI.swift:152-169`
- **Issue**: When WebSocket disconnects (network change, server restart, token expiry), no reconnection is attempted. App silently loses real-time updates.
- **Fix**: Implement reconnection with exponential backoff and notify UI of connection state.

### 6. WebSocket Messages Never Processed
- **File**: `Reef/Services/ReefAPI.swift:158-163`
- **Issue**: Incoming messages are `print()`-ed but never parsed or dispatched. WebSocket is effectively dead code. Also leaks message contents to debug logs.

### 7. URLSession Leak on WebSocket Reconnect
- **File**: `Reef/Services/ReefAPI.swift:130`
- **Issue**: New `URLSession` created per `connectWebSocket()` call but never invalidated. `URLSession` retains its delegate — repeated connections leak memory.
- **Fix**: Reuse a single session or call `finishTasksAndInvalidate()` on the old one.

### 8. KaTeX WebView — JavaScript Injection Vector
- **File**: `Reef/Design/Components/KaTeXView.swift:119`
- **Issue**: LaTeX text is JSON-encoded and interpolated into JavaScript source. While `textContent` assignment prevents HTML injection, the JSON string is spliced directly into `<script>`. Defense relies entirely on `JSONEncoder` producing valid JSON.
- **Fix**: Pass data via `WKScriptMessage` post-load instead of string interpolation.

### 9. Silent Save Failure — Data Loss Without Warning
- **File**: `Reef/Views/Canvas/CanvasViewModel.swift:50-52`
- **Issue**: PDF save errors are `print()`-ed only. User has no indication their work wasn't persisted.
- **Fix**: Surface error to UI (toast, alert, or dirty indicator).

## Medium

### 10. Force Unwrap in ContentView
- **File**: `Reef/ContentView.swift:11`
- **Code**: `DocumentCanvasView(document: canvasDocument!)`
- **Issue**: Guarded by `if canvasDocument != nil` but fragile — use `if let` binding.

### 11. Dev Mode Auto-Login with Hardcoded Credentials
- **File**: `Reef/Auth/AuthManager.swift:206-216`
- **Issue**: DEBUG builds auto-bypass authentication with hardcoded email. `devLogin()` is called automatically when session restore fails (line 68). If a debug build reaches testers, they get full access without auth.

### 12. Unbounded Undo Stack
- **File**: `Reef/Views/Canvas/CanvasViewModel.swift:57`
- **Issue**: Every page operation pushes a full PDF snapshot onto an unbounded `[Data]` array. Large documents can exhaust memory.
- **Fix**: Cap stack size (e.g. 20 entries) and evict oldest.

### 13. Share Link Clipboard Exposure
- **File**: `Reef/Views/Dashboard/Documents/DocumentsViewModel.swift:203-204`
- **Issue**: 7-day signed URLs copied to system clipboard, accessible by any app. No warning about expiry or that anyone with the link can access the document.

### 14. Missing Bounds Check in CanvasStrokeCollector
- **File**: `Reef/Views/Canvas/CanvasStrokeCollector.swift:58-59`
- **Issue**: `questionPages[questionIndex]` and `questionRegions[questionIndex]` accessed without verifying index is in bounds. Out-of-range index = crash.
- **Fix**: Add `guard questionIndex < questionPages.count, questionIndex < questionRegions.count`.

### 15. Drawings Stored Unencrypted
- **File**: `Reef/Services/DrawingStorageService.swift:14`
- **Issue**: PencilKit drawings and tutor progress stored as plaintext in Documents directory. Accessible via iTunes File Sharing and unencrypted backups.
- **Fix**: Use `NSFileProtectionComplete` or Application Support with `isExcludedFromBackup`.

### 16. Signed URL Expiry Too Long
- **File**: `Reef/Services/DocumentService.swift:250`
- **Issue**: Download URLs valid for 1 hour; share URLs valid for 7 days. If leaked, documents accessible without auth for that window.

## Low

### 17. `try!` on Regex Compilation
- **File**: `Reef/Design/Components/MathText.swift:21`
- **Issue**: Static regex crash on invalid pattern. Low risk since pattern is a compile-time constant.

### 18. No Client-Side Email Validation
- **File**: `Reef/Auth/AuthManager.swift:191`
- **Issue**: Email sent to Supabase OTP without format validation.

### 19. Generic Error Messages
- **Files**: `DocumentsViewModel.swift` (lines 128, 140, 163, etc.)
- **Issue**: "Something went wrong" for all errors — users can't distinguish network vs auth vs server issues.

### 20. Polling Timer Lifetime
- **File**: `Reef/Views/Dashboard/Documents/DocumentsViewModel.swift:62`
- **Issue**: Timer uses `[weak self]` correctly but could continue if view model is retained elsewhere.

### 21. Unbounded In-Memory Cache
- **File**: `Reef/Services/AnswerKeyService.swift:28`
- **Issue**: `[String: AnswerKeyResult]` cache never evicts entries. Use `NSCache` instead.

### 22. Temp PDF Files Never Cleaned Up
- **File**: `Reef/Services/DocumentService.swift:306-311`
- **Issue**: Downloaded PDFs written to temp dir but never explicitly deleted.

## Priority Fixes

1. **Disable `NSAllowsArbitraryLoads`** — blocks MITM attacks
2. **Fix force unwraps** in `createBlankPage()`, `ContentView`, `CanvasStrokeCollector`
3. **Surface save errors** to user in canvas
4. **Implement WebSocket reconnection** with backoff
5. **Cap undo stack** to prevent OOM
