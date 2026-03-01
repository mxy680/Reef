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

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

step "Checking prerequisites..."

command -v git   >/dev/null || fail "git not found"
command -v node  >/dev/null || fail "node not found (install via brew install node)"
command -v pnpm  >/dev/null || fail "pnpm not found (install via npm install -g pnpm)"

info "git $(git --version | awk '{print $3}')"
info "node $(node --version)"
info "pnpm $(pnpm --version)"

if command -v xcodebuild >/dev/null; then
    info "xcode $(xcodebuild -version 2>/dev/null | head -1)"
else
    warn "Xcode not found — iOS builds will be unavailable"
fi

if [ -d "$ROOT/Reef-Web" ] && [ -f "$ROOT/Reef-Web/package.json" ]; then
    step "Setting up Reef-Web..."
    cd "$ROOT/Reef-Web"
    pnpm install
    info "Node dependencies installed"
    cd "$ROOT"
fi

if [ -d "$ROOT/Reef-iOS/Reef.xcodeproj" ]; then
    step "Opening Reef-iOS in Xcode..."
    open "$ROOT/Reef-iOS/Reef.xcodeproj"
    info "Opened Reef.xcodeproj"
else
    warn "Reef-iOS project not found — skipping Xcode"
fi

step "Setup complete!"
echo ""
echo "  Start the web app: cd Reef-Web && pnpm dev"
echo ""
