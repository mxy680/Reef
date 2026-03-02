# Reef Server

## Rules

- Do NOT run `docker compose up`, `uvicorn`, or any server start command without explicit user permission.
- All endpoints except `/health` require Supabase JWT authentication.
- WebSocket auth uses query param `?token=<jwt>`, not headers.
- Single worker mode — WebSocket state is in-process.

## Stack

- Python 3.12, FastAPI, uvicorn, gunicorn
- PyJWT + JWKS (RS256) for Supabase token verification — keys fetched from `SUPABASE_URL/auth/v1/.well-known/jwks.json`
- Docker + Caddy for Hetzner deployment at api.studyreef.com

## Testing

```bash
cd Reef-Server
python -m pytest tests/
```
