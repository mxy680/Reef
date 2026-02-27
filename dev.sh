#!/bin/bash
# Auto-restart wrapper for next dev
# Use this instead of 'pnpm dev' when Claude Code is editing files.
# Claude Code's Edit/Write tools cause the dev server to exit cleanly;
# this wrapper detects that and restarts automatically.

cd "$(dirname "$0")"
PORT=3000

cleanup() {
  echo ""
  echo "Stopping dev server..."
  rm -f .next/dev/lock
  # Kill any orphaned next processes on our port
  lsof -ti:$PORT 2>/dev/null | xargs kill -9 2>/dev/null
  pkill -P $$ 2>/dev/null
  echo "Dev server stopped."
  exit 0
}
trap cleanup INT TERM EXIT

while true; do
  # Clean up stale state before starting
  rm -f .next/dev/lock
  lsof -ti:$PORT 2>/dev/null | xargs kill -9 2>/dev/null
  sleep 0.5

  npx next dev --webpack -p $PORT
  EXIT=$?

  echo ""
  echo "[dev server exited with code $EXIT — restarting in 1s...]"
  echo ""
  sleep 1
done
