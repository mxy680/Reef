#!/usr/bin/env bash
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BOLD='\033[1m'
NC='\033[0m'

info()  { printf "${GREEN}✓${NC} %s\n" "$1"; }
warn()  { printf "${YELLOW}!${NC} %s\n" "$1"; }
fail()  { printf "${RED}✗${NC} %s\n" "$1"; exit 1; }
step()  { printf "\n${BOLD}%s${NC}\n" "$1"; }

ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

# ── Prerequisites ──────────────────────────────────────────────

step "Checking prerequisites..."

command -v git   >/dev/null || fail "git not found"
command -v node  >/dev/null || fail "node not found (install via brew install node)"
command -v pnpm  >/dev/null || fail "pnpm not found (install via npm install -g pnpm)"
command -v uv    >/dev/null || fail "uv not found (install via brew install uv)"

info "git $(git --version | awk '{print $3}')"
info "node $(node --version)"
info "pnpm $(pnpm --version)"
info "uv $(uv --version | awk '{print $2}')"

# Xcode is optional — only needed for iOS builds
if command -v xcodebuild >/dev/null; then
    info "xcode $(xcodebuild -version 2>/dev/null | head -1)"
else
    warn "Xcode not found — iOS builds will be unavailable"
fi

# ── Submodules ─────────────────────────────────────────────────

step "Initializing submodules..."

git submodule update --init --recursive 2>&1 || {
    warn "Some submodules failed to init (this is OK if Reef-iOS is a private repo)"
}

for sub in Reef-Server Reef-Web Reef-iOS; do
    if [ -d "$ROOT/$sub/.git" ] || [ -f "$ROOT/$sub/.git" ]; then
        info "$sub checked out"
    else
        warn "$sub not available"
    fi
done

# ── Reef-Server (Python/FastAPI) ───────────────────────────────

if [ -d "$ROOT/Reef-Server" ] && [ -f "$ROOT/Reef-Server/pyproject.toml" ]; then
    step "Setting up Reef-Server..."

    cd "$ROOT/Reef-Server"
    uv sync
    info "Python dependencies installed"

    if [ ! -f .env ]; then
        cp .env.example .env
        warn "Created .env from .env.example — fill in your API keys"
    else
        info ".env already exists"
    fi

    cd "$ROOT"
fi

# ── Reef-Web (Next.js) ────────────────────────────────────────

if [ -d "$ROOT/Reef-Web" ] && [ -f "$ROOT/Reef-Web/package.json" ]; then
    step "Setting up Reef-Web..."

    cd "$ROOT/Reef-Web"
    pnpm install
    info "Node dependencies installed"

    cd "$ROOT"
fi

# ── Done ───────────────────────────────────────────────────────

step "Setup complete!"
echo ""
echo "  Start the server:  cd Reef-Server && uv run uvicorn api.index:app --reload"
echo "  Start the web app: cd Reef-Web && pnpm dev"
echo "  Run server tests:  cd Reef-Server && uv run python -m pytest tests/ -q"
echo ""
