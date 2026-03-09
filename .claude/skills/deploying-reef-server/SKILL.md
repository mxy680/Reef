---
name: deploying-reef-server
description: Use when restarting the local Reef dev server after code changes, deploying to Hetzner production, or verifying/rolling back a deployment.
---

# Deploying Reef-Server

> **CRITICAL: The server does NOT hot-reload. You MUST restart after every code change. This is the #1 source of "it's not working" bugs.**

## Local Dev

| Action | Command |
|--------|---------|
| Start | `cd Reef-Server && uvicorn api.index:app --reload --host 0.0.0.0 --port 8000` |
| Stop | `pkill -f "uvicorn api.index:app"` (NEVER use `lsof -ti:8000 \| xargs kill` — kills browsers) |
| Health check | `curl http://localhost:8000/health` |

`--reload` enables file-watching locally, but if you run via Docker or background process, you must manually restart.

## Production Deploy

```bash
cd Reef-Server
./deploy.sh deploy@178.156.139.74
```

**What `deploy.sh` does:**
1. `rsync -az --delete` to `/opt/reef` (excludes: `.venv`, `.git`, `.env`, `data/`, `tests/`, `__pycache__`, `.pytest_cache`)
2. `docker compose build app && docker compose up -d`
3. `docker compose ps` (status check)
4. `sleep 5` then health check via `curl -sf http://localhost:8000/health` inside container

## Verify Deployment

```bash
ssh deploy@178.156.139.74 "cd /opt/reef && docker compose ps"
ssh deploy@178.156.139.74 "cd /opt/reef && docker compose logs --tail=50 app"
ssh deploy@178.156.139.74 "cd /opt/reef && docker compose exec app curl -sf http://localhost:8000/health"
```

## Rollback

1. `git revert <bad-commit>` in Reef-Server
2. Re-run `./deploy.sh deploy@178.156.139.74`

## Infrastructure Reference

| Item | Value |
|------|-------|
| Server IP | `178.156.139.74` |
| SSH user | `deploy` |
| Remote dir | `/opt/reef` |
| Runtime | Docker Compose (`app` service) |
| Internal port | `8000` |
