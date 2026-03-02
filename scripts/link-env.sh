#!/bin/bash
# Symlink .env files from the shared config directory.
# Run this after creating a new worktree or checkout.
#
# Usage: ./scripts/link-env.sh

SHARED_DIR="$HOME/.config/reef"

if [ ! -d "$SHARED_DIR" ]; then
  echo "Error: $SHARED_DIR does not exist. Create it and add your .env files first."
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

# Reef-Server
if [ -f "$SHARED_DIR/server.env" ]; then
  rm -f "$REPO_ROOT/Reef-Server/.env"
  ln -s "$SHARED_DIR/server.env" "$REPO_ROOT/Reef-Server/.env"
  echo "Linked Reef-Server/.env -> $SHARED_DIR/server.env"
else
  echo "Warning: $SHARED_DIR/server.env not found, skipping Reef-Server"
fi

# Reef-Web
if [ -f "$SHARED_DIR/web.env.local" ]; then
  rm -f "$REPO_ROOT/Reef-Web/.env.local"
  ln -s "$SHARED_DIR/web.env.local" "$REPO_ROOT/Reef-Web/.env.local"
  echo "Linked Reef-Web/.env.local -> $SHARED_DIR/web.env.local"
else
  echo "Warning: $SHARED_DIR/web.env.local not found, skipping Reef-Web"
fi

echo "Done."
