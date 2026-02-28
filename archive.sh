#!/usr/bin/env bash
set -euo pipefail

GREEN='\033[0;32m'
BOLD='\033[1m'
NC='\033[0m'

ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
NAME="reef-${TIMESTAMP}"
OUT="${ROOT}/${NAME}.tar.gz"

echo "Archiving Reef project..."

# Use git archive for the parent repo, then append each submodule
git archive --format=tar --prefix="${NAME}/" HEAD > "/tmp/${NAME}.tar"

git submodule foreach --quiet '
    if [ -d "$toplevel/$sm_path/.git" ] || [ -f "$toplevel/$sm_path/.git" ]; then
        cd "$toplevel/$sm_path"
        git archive --format=tar --prefix="'"${NAME}"'/$sm_path/" HEAD > "/tmp/'"${NAME}"'-sub.tar"
        tar --concatenate --file="/tmp/'"${NAME}"'.tar" "/tmp/'"${NAME}"'-sub.tar"
        rm "/tmp/'"${NAME}"'-sub.tar"
    fi
'

gzip -f "/tmp/${NAME}.tar"
mv "/tmp/${NAME}.tar.gz" "$OUT"

SIZE="$(du -h "$OUT" | cut -f1)"
printf "${GREEN}✓${NC} ${BOLD}%s${NC} (%s)\n" "$OUT" "$SIZE"
