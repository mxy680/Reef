#!/usr/bin/env bash
set -euo pipefail

GREEN='\033[0;32m'
BOLD='\033[1m'
NC='\033[0m'

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

printf "${GREEN}▶${NC} ${BOLD}Reef-Web${NC} → http://localhost:3000\n"
cd "$ROOT/Reef-Web"
pnpm dev
