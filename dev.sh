#!/bin/bash
# Auto-restart wrapper for next dev
# Use this instead of 'pnpm dev' when Claude Code is editing files.
# Claude Code's Edit/Write tools cause the dev server to exit cleanly;
# this wrapper detects that and restarts automatically.

cd "$(dirname "$0")"

while true; do
  npx next dev --webpack
  EXIT=$?
  if [ $EXIT -eq 130 ] || [ $EXIT -eq 137 ]; then
    # Ctrl+C (SIGINT=130) or SIGKILL=137 — user wants to stop
    echo ""
    echo "Dev server stopped."
    exit 0
  fi
  echo ""
  echo "[dev server exited with code $EXIT — restarting in 1s...]"
  echo ""
  sleep 1
done
