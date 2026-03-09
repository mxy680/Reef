---
name: startup
description: Use when the user asks to start, run, or boot up the Reef local development environment — server and/or dashboard.
---

# Starting Reef Dev Environment

> **Start both services: server and dashboard. Verify each one works before moving on.**

## Procedure

Run these steps in order. Each step must pass verification before continuing.

### 1. Reef-Server (port 8000)

First check if already running:
```bash
pgrep -f "uvicorn api.index" && echo "ALREADY RUNNING" || echo "NOT RUNNING"
```

If not running, start it in the background:
```bash
cd Reef-Server && export $(grep -v '^#' .env | xargs) && nohup uv run uvicorn api.index:app --host 0.0.0.0 --port 8000 --timeout-keep-alive 180 > /tmp/reef-server.log 2>&1 &
```

**CRITICAL:** You MUST `export .env` — there is no dotenv autoloading. Without it, `DATABASE_URL` is missing and DB endpoints return 503.

**Verify (wait 3s first):**
```bash
sleep 3 && curl -sf http://localhost:8000/health
```

The `/health` endpoint confirms the server started. To verify DB connectivity:
```bash
curl -s "http://localhost:8000/api/stroke-logs?limit=1"
```
Must return JSON with `"logs"`, NOT `"Database not available"`.

### 2. Dashboard (port 3100)

First check if already running:
```bash
pgrep -f "next dev" && echo "ALREADY RUNNING" || echo "NOT RUNNING"
```

If not running, start it in the background:
```bash
cd dashboard && nohup npx next dev --port 3100 > /tmp/reef-dashboard.log 2>&1 &
```

**Verify (wait 5s for Next.js compile):**
```bash
sleep 5 && curl -sf http://localhost:3100 > /dev/null && echo "Dashboard OK" || echo "Dashboard FAILED"
```

### 3. SSH Tunnel (iPad → local server)

Opens a reverse tunnel so `dev.studyreef.com` (iPad debug builds) routes to your local server.

First check if already running:
```bash
pgrep -f "ssh -R 8001" && echo "ALREADY RUNNING" || echo "NOT RUNNING"
```

If not running:
```bash
ssh -R 8001:localhost:8000 deploy@178.156.139.74 -N -f
```

**Verify:**
```bash
ssh deploy@178.156.139.74 "curl -sf http://localhost:8001/health"
```

Must return the health JSON. If it fails, the tunnel didn't bind — check if something else is using port 8001 on Hetzner.

## Stopping Services

| Service | Stop Command |
|---------|-------------|
| Server | `pkill -f "uvicorn api.index"` |
| Dashboard | `kill $(pgrep -f "next dev")` |
| SSH Tunnel | `pkill -f "ssh -R 8001"` |

## Gotchas

| Mistake | Consequence | Fix |
|---------|-------------|-----|
| Start server without `export .env` | DB endpoints 503, health still passes | Restart with env exported |
| Dashboard `.env.local` set to external URL | CORS blocks all API calls | Must be `http://localhost:8000` |
| `lsof -ti:<port> \| xargs kill` | Kills Firefox and other apps | Use `pkill -f "uvicorn api.index"` or `kill $(pgrep -f "next dev")` |

## Quick Reference

| Service | URL | Log File |
|---------|-----|----------|
| Server | `http://localhost:8000` | `/tmp/reef-server.log` |
| Dashboard | `http://localhost:3100` | `/tmp/reef-dashboard.log` |
| SSH Tunnel | `dev.studyreef.com` → local:8000 | (none) |
