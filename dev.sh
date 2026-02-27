#!/bin/bash
# Auto-restart wrapper for next dev
# Use this instead of 'pnpm dev' when Claude Code is editing files.
# Claude Code's Edit/Write tools cause the dev server to exit cleanly;
# this wrapper detects that and restarts automatically.

cd "$(dirname "$0")"

cleanup() {
  rm -f .next/dev/lock
  pkill -P $$ 2>/dev/null
  echo ""
  echo "Dev server stopped."
  exit 0
}
trap cleanup INT TERM

while true; do
  rm -f .next/dev/lock
  npx next dev --webpack
  EXIT=$?
  if [ $EXIT -eq 130 ] || [ $EXIT -eq 137 ]; then
    cleanup
  fi
  echo ""
  echo "[dev server exited with code $EXIT — restarting in 1s...]"
  echo ""
  sleep 1
done
