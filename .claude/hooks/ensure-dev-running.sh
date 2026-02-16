#!/bin/bash
# Stop hook: ensure the Reef dev server and dashboard are running before Claude exits.

INPUT=$(cat)

# Prevent infinite loops if the hook itself triggers a stop
if [ "$(echo "$INPUT" | jq -r '.stop_hook_active')" = "true" ]; then
  exit 0
fi

PROJECT_DIR="$(echo "$INPUT" | jq -r '.cwd')"
SERVER_DIR="$PROJECT_DIR/Reef-Server"
DASHBOARD_DIR="$PROJECT_DIR/dashboard"
MISSING=()

# Check if uvicorn (Reef-Server) is running
if ! pgrep -f "uvicorn api.index:app" > /dev/null 2>&1; then
  MISSING+=("Reef-Server (uvicorn not running)")
fi

# Check if Next.js dashboard dev server is running
if ! pgrep -f "next dev.*dashboard\|next-server.*dashboard" > /dev/null 2>&1; then
  # Also check by port 3000
  if ! lsof -iTCP:3000 -sTCP:LISTEN > /dev/null 2>&1; then
    MISSING+=("Dashboard (next dev not running on :3000)")
  fi
fi

if [ ${#MISSING[@]} -gt 0 ]; then
  REASON="Dev services not running: ${MISSING[*]}. Start them before exiting."
  echo "{\"decision\": \"block\", \"reason\": \"$REASON\"}"
  exit 0
fi

exit 0
