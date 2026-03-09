---
name: adding-api-endpoints
description: Use when adding a new REST or WebSocket endpoint to Reef-Server, including Pydantic models, router creation, business logic, database tables, and registration in index.py.
---

# Adding API Endpoints

## Checklist

- [ ] Pydantic models in `lib/models/<name>.py`
- [ ] Update `lib/models/__init__.py` — add import line AND update `__all__` list
- [ ] Router in `api/<name>.py` with `APIRouter()`
- [ ] Register in `api/index.py` — import + `app.include_router()`
- [ ] Business logic in `lib/` if non-trivial
- [ ] DB table in `lib/database.py` → `init_db()` if needed
- [ ] Restart server and test with curl

## Pydantic Model Template

```python
# lib/models/my_feature.py
from pydantic import BaseModel

class MyRequest(BaseModel):
    field: str

class MyResponse(BaseModel):
    result: str
```

Then in `lib/models/__init__.py`, add BOTH:
```python
from .my_feature import MyRequest, MyResponse  # with other imports
# AND add to __all__:
__all__ = [
    ...,
    "MyRequest",
    "MyResponse",
]
```

## Router Template

```python
# api/my_feature.py
from fastapi import APIRouter

router = APIRouter()

@router.post("/my-feature")
async def my_feature_endpoint(req: MyRequest) -> MyResponse:
    ...
```

## Registration in `api/index.py`

```python
# Line ~37-42: Add import
from api.my_feature import router as my_feature_router

# Line ~81-86: Add registration
app.include_router(my_feature_router)
```

## DB Table (if needed)

Add `CREATE TABLE IF NOT EXISTS` in `lib/database.py` inside `init_db()`, after existing table definitions. Use `asyncpg` — the pool is created earlier in the same function.

## Existing Routers Reference

| Router | File | Pattern |
|--------|------|---------|
| `users` | `api/users.py` | REST CRUD |
| `strokes` | `api/strokes.py` | Fire-and-forget POST + REST queries |
| `clustering` | `api/clustering.py` | REST request/response |
| `tts` | `api/tts.py` | REST (text-to-speech) |
| `voice` | `api/voice.py` | WebSocket binary audio (`/ws/voice`) |
| `reasoning` | `api/reasoning.py` | WebSocket streaming JSON (`/ws/reasoning`) |

## Test

```bash
# Restart server first!
curl -X POST http://localhost:8000/my-feature \
  -H "Content-Type: application/json" \
  -d '{"field": "value"}'
```
