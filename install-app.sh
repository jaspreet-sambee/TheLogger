#!/bin/bash
#
# install-app.sh - Install TheLogger to iOS Simulator
#
# Usage:
#   ./install-app.sh              # Install to first booted simulator
#   ./install-app.sh "iPhone 17"  # Install to specific device

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
DERIVED_DATA="$HOME/Library/Developer/Xcode/DerivedData/TheLogger-gjxssrqutzkxvbeydaucloowttoi"
APP_PATH="$DERIVED_DATA/Build/Products/Debug-iphonesimulator/TheLogger.app"
BUNDLE_ID="SDL-Tutorial.TheLogger"

echo "🏗️  Building TheLogger..."

# Build the app
xcodebuild build \
  -project "$PROJECT_DIR/TheLogger.xcodeproj" \
  -scheme TheLogger \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -derivedDataPath "$DERIVED_DATA" \
  > /dev/null 2>&1

if [ $? -ne 0 ]; then
    echo -e "${RED}❌ Build failed${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Build succeeded${NC}"

# Find simulator device
DEVICE_NAME="${1:-}"
if [ -z "$DEVICE_NAME" ]; then
    # Find first booted simulator
    DEVICE_ID=$(xcrun simctl list devices | grep "Booted" | head -1 | grep -o '[A-Z0-9]\{8\}-[A-Z0-9]\{4\}-[A-Z0-9]\{4\}-[A-Z0-9]\{4\}-[A-Z0-9]\{12\}')
    DEVICE_NAME=$(xcrun simctl list devices | grep "$DEVICE_ID" | sed 's/(.*//' | xargs)
else
    # Find device by name
    DEVICE_ID=$(xcrun simctl list devices | grep "$DEVICE_NAME" | grep -o '[A-Z0-9]\{8\}-[A-Z0-9]\{4\}-[A-Z0-9]\{4\}-[A-Z0-9]\{4\}-[A-Z0-9]\{12\}' | head -1)
fi

if [ -z "$DEVICE_ID" ]; then
    echo -e "${RED}❌ No simulator found${NC}"
    echo "Available simulators:"
    xcrun simctl list devices available | grep "iPhone"
    exit 1
fi

echo "📱 Installing to: $DEVICE_NAME ($DEVICE_ID)"

# Check if app exists
if [ ! -d "$APP_PATH" ]; then
    echo -e "${RED}❌ App not found at: $APP_PATH${NC}"
    exit 1
fi

# Install app
xcrun simctl install "$DEVICE_ID" "$APP_PATH"

if [ $? -ne 0 ]; then
    echo -e "${RED}❌ Installation failed${NC}"
    exit 1
fi

echo -e "${GREEN}✅ App installed successfully${NC}"

# Launch app
echo "🚀 Launching TheLogger..."
xcrun simctl launch "$DEVICE_ID" "$BUNDLE_ID" > /dev/null 2>&1

if [ $? -ne 0 ]; then
    echo -e "${YELLOW}⚠️  App installed but launch failed. Try opening manually from simulator.${NC}"
    exit 1
fi

echo -e "${GREEN}✅ App launched successfully!${NC}"
echo ""
echo "📊 To view logs:"
echo "   xcrun simctl spawn $DEVICE_ID log stream --predicate 'process == \"TheLogger\"'"
