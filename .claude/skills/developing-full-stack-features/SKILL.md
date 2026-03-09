---
name: developing-full-stack-features
description: Use when building a feature that spans both Reef-Server (Python/FastAPI) and Reef-iOS (Swift/SwiftUI), requiring coordinated API contract, implementation, and submodule commits.
---

# Developing Full-Stack Features

## Workflow

1. **Define API contract** — agree on endpoint path, method, request/response shapes
2. **Implement server side** — Pydantic models, router, business logic
3. **Restart server** — it does NOT hot-reload (see `deploying-reef-server` skill)
4. **Implement iOS side** — Codable structs, AIService method, UI integration
5. **Test end-to-end** — curl the endpoint, then test from iPad/simulator
6. **Commit in order** — server submodule first, iOS second, parent last

## Server File Locations

| What | Where |
|------|-------|
| Pydantic models | `Reef-Server/lib/models/` + update `__init__.py` (imports AND `__all__`) |
| Business logic | `Reef-Server/lib/` (new or existing module) |
| Router | `Reef-Server/api/<name>.py` using `APIRouter()` |
| Register router | `Reef-Server/api/index.py`: import (line ~37-42) + `app.include_router()` (line ~81-86) |

## iOS File Locations

| What | Where |
|------|-------|
| Codable structs | `Reef-iOS/Reef/Models/` |
| AIService methods | `Reef-iOS/Reef/Services/AIService.swift` |
| Views | `Reef-iOS/Reef/Views/` |
| Other services | `Reef-iOS/Reef/Services/` |

## iOS Networking Patterns

| Pattern | When | Example |
|---------|------|---------|
| `async throws` → `URLSession.data(for:)` | Need the response (awaited) | Fetching data, POST with result |
| `postJSON(path:body:)` | Fire-and-forget, no response needed | Sending stroke data (AIService:138) |
| `URLSessionWebSocketTask` | Streaming/real-time | Voice WebSocket (AIService:191) |

WebSocket URL construction: `baseURL.replacingOccurrences(of: "https://", with: "wss://") + "/ws/<name>"`

## Submodule Commit Order

```bash
# 1. Commit inside server submodule
cd Reef-Server && git add -A && git commit -m "feat: ..."

# 2. Commit inside iOS submodule
cd Reef-iOS && git add -A && git commit -m "feat: ..."

# 3. Update parent repo
cd Reef && git add Reef-Server Reef-iOS && git commit -m "feat: ..."
```

Always commit server first so the API is available before iOS depends on it.
