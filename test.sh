#!/usr/bin/env bash
#
# Run all Reef tests — Server (Python) + iOS (Swift).
#
# Usage:
#   ./test.sh              # both suites
#   ./test.sh server       # server only
#   ./test.sh ios          # iOS only
#   REEF_TEST_MODE=e2e ./test.sh server   # server with real APIs
#
set -euo pipefail
cd "$(dirname "$0")"

RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
DIM='\033[2m'
RESET='\033[0m'

SUITE="${1:-all}"
FAILURES=0

# ── Server tests ──────────────────────────────────────────

run_server() {
    echo -e "\n${CYAN}═══ Reef-Server (pytest) ═══${RESET}"
    echo -e "${DIM}Mode: ${REEF_TEST_MODE:-contract}${RESET}\n"

    if (cd Reef-Server && uv run python -m pytest tests/ -q 2>&1); then
        echo -e "\n${GREEN}✓ Server tests passed${RESET}"
    else
        echo -e "\n${RED}✗ Server tests failed${RESET}"
        FAILURES=$((FAILURES + 1))
    fi
}

# ── iOS tests ─────────────────────────────────────────────

run_ios() {
    echo -e "\n${CYAN}═══ Reef-iOS (xcodebuild) ═══${RESET}\n"

    local DERIVED_DATA="Reef-iOS/DerivedData"
    local DESTINATION='platform=iOS Simulator,name=iPad Pro 11-inch (M4)'
    local LOG_FILE
    LOG_FILE="$(mktemp /tmp/reef-ios-test.XXXXXX.log)"

    # Run xcodebuild and tee to log file
    set +e
    xcodebuild \
        -project Reef-iOS/Reef.xcodeproj \
        -scheme Reef \
        -destination "$DESTINATION" \
        -derivedDataPath "$DERIVED_DATA" \
        -resultBundlePath "/tmp/reef-test-results" \
        test 2>&1 | tee "$LOG_FILE" | grep -E '(Test Suite|Test Case|passed|failed|error:|\*\* TEST)'
    local EXIT_CODE=${PIPESTATUS[0]}
    set -e

    if [ $EXIT_CODE -eq 0 ]; then
        echo -e "\n${GREEN}✓ iOS tests passed${RESET}"
    else
        echo -e "\n${RED}✗ iOS tests failed${RESET}"
        echo -e "${DIM}Full log: $LOG_FILE${RESET}"
        FAILURES=$((FAILURES + 1))
    fi
}

# ── Main ──────────────────────────────────────────────────

case "$SUITE" in
    server)  run_server ;;
    ios)     run_ios ;;
    all)     run_server; run_ios ;;
    *)
        echo "Usage: $0 [server|ios|all]"
        exit 1
        ;;
esac

echo ""
if [ $FAILURES -eq 0 ]; then
    echo -e "${GREEN}All test suites passed.${RESET}"
else
    echo -e "${RED}${FAILURES} suite(s) failed.${RESET}"
    exit 1
fi
