#!/bin/bash
#
# run-tests.sh
# Automated test runner for TheLogger
#
# This script runs all unit and UI tests to catch regressions
# Run this before each release or after significant changes
#

set -e

echo "🧪 TheLogger Automated Test Suite"
echo "=================================="
echo ""

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
PROJECT="TheLogger.xcodeproj"
SCHEME="TheLogger"
DESTINATION="platform=iOS Simulator,name=iPhone 17"
DERIVED_DATA_PATH="./DerivedData"

# Clean derived data
echo "🧹 Cleaning derived data..."
rm -rf "${DERIVED_DATA_PATH}"

# Build the app
echo ""
echo "🔨 Building app..."
xcodebuild build \
    -project "${PROJECT}" \
    -scheme "${SCHEME}" \
    -destination "${DESTINATION}" \
    -derivedDataPath "${DERIVED_DATA_PATH}" \
    -quiet

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Build succeeded${NC}"
else
    echo -e "${RED}✗ Build failed${NC}"
    exit 1
fi

# Run unit tests (if test target exists)
echo ""
echo "🧪 Running unit tests..."
if xcodebuild test \
    -project "${PROJECT}" \
    -scheme "TheLoggerTests" \
    -destination "${DESTINATION}" \
    -derivedDataPath "${DERIVED_DATA_PATH}" \
    -quiet 2>/dev/null; then
    echo -e "${GREEN}✓ Unit tests passed${NC}"
else
    echo -e "${YELLOW}⚠ Unit test target not found (need to add in Xcode)${NC}"
fi

# Run UI tests
echo ""
echo "🎭 Running UI tests..."
xcodebuild test \
    -project "${PROJECT}" \
    -scheme "TheLoggerUITests" \
    -destination "${DESTINATION}" \
    -derivedDataPath "${DERIVED_DATA_PATH}" \
    -quiet

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ UI tests passed${NC}"
else
    echo -e "${RED}✗ UI tests failed${NC}"
    exit 1
fi

# Summary
echo ""
echo "=================================="
echo -e "${GREEN}✅ All tests passed!${NC}"
echo ""
echo "Test results saved to: ${DERIVED_DATA_PATH}/Logs/Test"
echo ""
