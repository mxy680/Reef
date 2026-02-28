#!/usr/bin/env bash
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
BOLD='\033[1m'
NC='\033[0m'

ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

usage() {
    echo "Usage: ./run.sh [server|web|all]"
    echo ""
    echo "  server  Start Reef-Server (FastAPI on :8000)"
    echo "  web     Start Reef-Web (Next.js on :3000)"
    echo "  all     Start both (default)"
    exit 1
}

cleanup() {
    echo ""
    printf "${RED}Shutting down...${NC}\n"
    kill 0 2>/dev/null
    wait 2>/dev/null
    exit 0
}
trap cleanup SIGINT SIGTERM

start_server() {
    printf "${GREEN}▶${NC} ${BOLD}Reef-Server${NC} → http://localhost:8000\n"
    cd "$ROOT/Reef-Server"
    uv run uvicorn api.index:app --reload --host 0.0.0.0 --port 8000
}

start_web() {
    printf "${GREEN}▶${NC} ${BOLD}Reef-Web${NC} → http://localhost:3000\n"
    cd "$ROOT/Reef-Web"
    pnpm dev
}

MODE="${1:-all}"

case "$MODE" in
    server)
        start_server
        ;;
    web)
        start_web
        ;;
    all)
        start_server &
        start_web &
        wait
        ;;
    *)
        usage
        ;;
esac
