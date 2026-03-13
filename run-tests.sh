#!/bin/bash
#
# run-tests.sh
# Test runner for TheLogger
#
# Usage:
#   ./run-tests.sh           — run unit tests only (fast, ~10s)
#   ./run-tests.sh --all     — run unit + UI tests (~5 min)
#   ./run-tests.sh --unit    — unit tests only
#   ./run-tests.sh --ui      — UI tests only
#

set -e

PROJECT="TheLogger.xcodeproj"
SCHEME="TheLogger"
DESTINATION="platform=iOS Simulator,name=iPhone 17"

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
NC='\033[0m'

RUN_UNIT=true
RUN_UI=false

for arg in "$@"; do
    case $arg in
        --all) RUN_UNIT=true; RUN_UI=true ;;
        --unit) RUN_UNIT=true; RUN_UI=false ;;
        --ui) RUN_UNIT=false; RUN_UI=true ;;
    esac
done

echo ""
echo -e "${BOLD}TheLogger Test Suite${NC}"
echo "====================="

UNIT_PASS=0
UNIT_FAIL=0
UI_PASS=0
UI_FAIL=0

# ── Unit Tests ──────────────────────────────────────────────────────────────
if [ "$RUN_UNIT" = true ]; then
    echo ""
    echo "Running unit tests..."

    UNIT_OUTPUT=$(xcodebuild test \
        -project "${PROJECT}" \
        -scheme "${SCHEME}" \
        -destination "${DESTINATION}" \
        -only-testing:TheLoggerTests \
        2>&1)

    UNIT_PASS=$(echo "$UNIT_OUTPUT" | grep -c "passed on" || true)
    UNIT_FAIL=$(echo "$UNIT_OUTPUT" | grep -c "failed on" || true)

    if [ "$UNIT_FAIL" -eq 0 ]; then
        echo -e "${GREEN}  Unit tests: ${UNIT_PASS} passed, 0 failed${NC}"
    else
        echo -e "${RED}  Unit tests: ${UNIT_PASS} passed, ${UNIT_FAIL} FAILED${NC}"
        echo ""
        echo "Failures:"
        echo "$UNIT_OUTPUT" | grep "failed on"
        echo ""
    fi
fi

# ── UI Tests ─────────────────────────────────────────────────────────────────
if [ "$RUN_UI" = true ]; then
    echo ""
    echo "Running UI tests..."

    UI_OUTPUT=$(xcodebuild test \
        -project "${PROJECT}" \
        -scheme "${SCHEME}" \
        -destination "${DESTINATION}" \
        -only-testing:TheLoggerUITests \
        2>&1)

    UI_PASS=$(echo "$UI_OUTPUT" | grep -c "passed on" || true)
    UI_FAIL=$(echo "$UI_OUTPUT" | grep -c "failed on" || true)

    if [ "$UI_FAIL" -eq 0 ]; then
        echo -e "${GREEN}  UI tests: ${UI_PASS} passed, 0 failed${NC}"
    else
        echo -e "${RED}  UI tests: ${UI_PASS} passed, ${UI_FAIL} FAILED${NC}"
        echo ""
        echo "Failures:"
        echo "$UI_OUTPUT" | grep "failed on"
        echo ""
    fi
fi

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
echo "====================="
TOTAL_FAIL=$((UNIT_FAIL + UI_FAIL))
TOTAL_PASS=$((UNIT_PASS + UI_PASS))

if [ "$TOTAL_FAIL" -eq 0 ]; then
    echo -e "${GREEN}${BOLD}All tests passed (${TOTAL_PASS} total)${NC}"
    echo ""
    exit 0
else
    echo -e "${RED}${BOLD}${TOTAL_FAIL} test(s) failed${NC}"
    echo ""
    exit 1
fi
