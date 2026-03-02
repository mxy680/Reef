#!/usr/bin/env bash
set -euo pipefail

REMOTE="${1:-deploy@178.156.139.74}"
REMOTE_DIR="/opt/reef"
LOCAL_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "==> Deploying Reef-Server to $REMOTE:$REMOTE_DIR"

# 1. Sync files (exclude dev/local artifacts)
echo "==> Syncing files..."
rsync -az --delete \
  --exclude '.venv' \
  --exclude '.git' \
  --exclude '.env' \
  --exclude 'data/' \
  --exclude 'tests/' \
  --exclude '__pycache__' \
  --exclude '.pytest_cache' \
  --exclude '*.pyc' \
  --exclude '.env.example' \
  "$LOCAL_DIR/" "$REMOTE:$REMOTE_DIR/"

# 2. Build and restart
echo "==> Building and restarting containers..."
ssh "$REMOTE" "cd $REMOTE_DIR && docker compose build server && docker compose up -d --force-recreate server"

# 3. Status check
echo "==> Container status:"
ssh "$REMOTE" "cd $REMOTE_DIR && docker compose ps"

# 4. Health check (wait for startup)
echo "==> Waiting for health check..."
sleep 5
if ssh "$REMOTE" "curl -sf http://localhost:80/health"; then
  echo ""
  echo "==> Deploy successful!"
else
  echo ""
  echo "==> Health check failed. Check logs with:"
  echo "    ssh $REMOTE 'cd $REMOTE_DIR && docker compose logs --tail=50 server'"
  exit 1
fi
