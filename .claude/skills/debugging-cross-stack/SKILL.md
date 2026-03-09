---
name: debugging-cross-stack
description: Use when debugging issues between Reef-iOS and Reef-Server, including connection failures, 422 errors, WebSocket drops, missing env vars, or features not working after code changes.
---

# Debugging Cross-Stack Issues

## Isolation Flowchart

```
Is the server healthy?
  curl http://localhost:8000/health
    ├─ No  → Server bug. Check logs, restart, check env vars.
    └─ Yes → curl the specific endpoint
                ├─ Fails → Server bug in that endpoint.
                └─ Works → iOS bug (networking, decoding, UI).
```

## Quick Diagnosis

| Check | Command |
|-------|---------|
| Server health | `curl http://localhost:8000/health` |
| Server logs | Check uvicorn terminal output |
| Endpoint test | `curl -X POST http://localhost:8000/<path> -H "Content-Type: application/json" -d '{...}'` |
| Prod health | `ssh deploy@178.156.139.74 "cd /opt/reef && docker compose exec app curl -sf http://localhost:8000/health"` |
| Prod logs | `ssh deploy@178.156.139.74 "cd /opt/reef && docker compose logs --tail=100 app"` |

## Common Failures

### 1. Server not restarted (most common!)
**Symptom:** Code changes have no effect, old behavior persists.
**Fix:** Restart the server. It does NOT hot-reload in Docker/background mode.

### 2. Wrong base URL in AIService.swift
**Symptom:** iOS can't connect at all, timeout errors.
**Fix:** Check `AIService.swift:57-61`. Debug URL should be the Mac's local IP (`http://<ip>:8000`). Get it with `ipconfig getifaddr en0`. Release is `https://api.studyreef.com`.

### 3. JSON encode/decode mismatch
**Symptom:** 422 Unprocessable Entity from server.
**Fix:** Server expects `snake_case` (Pydantic). iOS sends `camelCase` by default. Use `JSONEncoder.KeyEncodingStrategy.convertToSnakeCase` or match field names manually in Codable structs.

### 4. Missing environment variables
**Symptom:** 500 errors on specific endpoints, server starts fine.
**Key vars:** `OPENAI_API_KEY`, `ANTHROPIC_API_KEY`, `MATHPIX_APP_ID`, `MATHPIX_APP_KEY`, `DATABASE_URL`
**Fix:** Check `.env` file in `Reef-Server/`.

### 5. WebSocket connection drops
**Symptom:** Voice/reasoning stops mid-stream, no error shown.
**Fix:** Check server logs for exceptions. WebSocket URL must use `wss://` (built from `baseURL` at AIService:191). Verify the `/ws/voice` or `/ws/reasoning` path matches the server router.

### 6. CORS issues
**Symptom:** Dashboard fetch fails, iOS works fine.
**Fix:** iOS ignores CORS. This only affects the browser dashboard. Check CORS middleware in `api/index.py`.

### 7. Database not available
**Symptom:** 503 on stroke/clustering endpoints, other endpoints work.
**Fix:** Check `DATABASE_URL` in `.env`, verify PostgreSQL is running.

## REST vs WebSocket Debugging

| Aspect | REST | WebSocket |
|--------|------|-----------|
| Test tool | `curl` | `websocat` or browser console |
| Error format | HTTP status + JSON body | Connection close or server log |
| Common issue | 422 (schema mismatch) | Silent drop (exception in handler) |
| Debug approach | Check request body vs Pydantic model | Check server logs for traceback |
