#!/bin/bash
# Simple test script to verify app can launch
# Usage: ./test-launch.sh

set -e

DEVICE="iPhone 17 Pro"
PROJECT_DIR="/Users/jaspreet/Documents/MyApps/TheLogger"

echo "Finding simulator..."
SIMULATOR_UDID=$(xcrun simctl list devices available | grep "$DEVICE" | grep -oE '[A-F0-9-]{36}' | head -1)

if [ -z "$SIMULATOR_UDID" ]; then
    echo "Error: Simulator '$DEVICE' not found"
    exit 1
fi

echo "Simulator UDID: $SIMULATOR_UDID"

echo "Booting simulator..."
xcrun simctl boot "$SIMULATOR_UDID" 2>/dev/null || echo "Already booted"

echo "Opening Simulator.app..."
open -a Simulator
sleep 5

echo "Finding app..."
APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData -name "TheLogger.app" -path "*/Debug-iphonesimulator/*" -type d 2>/dev/null | head -1)

if [ -z "$APP_PATH" ]; then
    echo "App not found, building..."
    cd "$PROJECT_DIR"
    xcodebuild build \
        -project TheLogger.xcodeproj \
        -scheme TheLogger \
        -destination "platform=iOS Simulator,name=$DEVICE" \
        -configuration Debug

    APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData -name "TheLogger.app" -path "*/Debug-iphonesimulator/*" -type d 2>/dev/null | head -1)
fi

if [ -z "$APP_PATH" ]; then
    echo "Error: Could not find or build app"
    exit 1
fi

echo "App found at: $APP_PATH"

# Extract bundle ID
if [ -f "$APP_PATH/Info.plist" ]; then
    BUNDLE_ID=$(plutil -extract CFBundleIdentifier raw "$APP_PATH/Info.plist" 2>/dev/null || echo "com.SDL-Tutorial.TheLogger")
else
    BUNDLE_ID="com.SDL-Tutorial.TheLogger"
fi

echo "Bundle ID: $BUNDLE_ID"

echo "Installing app..."
xcrun simctl install "$SIMULATOR_UDID" "$APP_PATH"
sleep 3

echo "Verifying installation..."
if xcrun simctl get_app_container "$SIMULATOR_UDID" "$BUNDLE_ID" 2>/dev/null; then
    echo "✓ App installed successfully"
else
    echo "✗ App installation verification failed"
    exit 1
fi

echo "Terminating any running instance..."
xcrun simctl terminate "$SIMULATOR_UDID" "$BUNDLE_ID" 2>/dev/null || true
sleep 1

echo "Launching app..."
if xcrun simctl launch "$SIMULATOR_UDID" "$BUNDLE_ID"; then
    echo "✓ App launched successfully"
else
    echo "✗ App launch failed"
    echo ""
    echo "Debugging info:"
    echo "- Try opening the app manually in the simulator"
    echo "- Check Console.app for crash logs"
    echo "- Verify the app builds and runs in Xcode"
    exit 1
fi

echo ""
echo "Success! The app should now be visible in the simulator."
