#!/bin/bash
# Create a new git worktree and auto-link env files.
#
# Usage: ./scripts/new-worktree.sh <path> [branch]
#   path   — where to create the worktree (e.g. ../worktrees/my-feature)
#   branch — optional new branch name (creates it if given)

set -e

if [ -z "$1" ]; then
  echo "Usage: $0 <path> [branch]"
  exit 1
fi

WORKTREE_PATH="$1"
BRANCH="$2"

if [ -n "$BRANCH" ]; then
  git worktree add "$WORKTREE_PATH" -b "$BRANCH"
else
  git worktree add "$WORKTREE_PATH"
fi

# Run link-env.sh in the new worktree
LINK_SCRIPT="$WORKTREE_PATH/scripts/link-env.sh"
if [ -x "$LINK_SCRIPT" ]; then
  "$LINK_SCRIPT"
else
  echo "Warning: $LINK_SCRIPT not found or not executable, skipping env linking"
fi
