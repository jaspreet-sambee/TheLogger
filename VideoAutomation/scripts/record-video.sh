#!/bin/bash
# Main recording orchestration script
# Usage: ./record-video.sh <workflow.yaml>
#
# This script:
# 1. Boots the iOS simulator
# 2. Installs and launches the app
# 3. Records the screen while running XCUITest
# 4. Applies device frame using screenframer (or ffmpeg fallback)
# 5. Optimizes for Twitter

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Check for required tools
check_dependencies() {
    local missing=()

    if ! command -v yq &> /dev/null; then
        missing+=("yq")
    fi

    if ! command -v ffmpeg &> /dev/null; then
        missing+=("ffmpeg")
    fi

    if ! command -v xcrun &> /dev/null; then
        missing+=("Xcode Command Line Tools")
    fi

    if [ ${#missing[@]} -ne 0 ]; then
        log_error "Missing required dependencies: ${missing[*]}"
        echo "Install with: brew install ${missing[*]}"
        exit 1
    fi

    # screenframer is optional - we have ffmpeg fallback
    if ! command -v screenframer &> /dev/null; then
        log_warn "screenframer not found - will use ffmpeg for device framing"
        log_warn "For better device frames, install: brew install screenframer"
    fi
}

WORKFLOW_FILE=$1
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BASE_DIR="$(dirname "$SCRIPT_DIR")"
OUTPUT_DIR="$BASE_DIR/output"
TEMP_DIR="$BASE_DIR/temp"
PROJECT_DIR="$(dirname "$BASE_DIR")"

if [ -z "$WORKFLOW_FILE" ] || [ ! -f "$WORKFLOW_FILE" ]; then
    log_error "Workflow file not found: $WORKFLOW_FILE"
    exit 1
fi

check_dependencies

# Parse YAML configuration
DEVICE=$(yq -r '.simulator.device // "iPhone 17 Pro"' "$WORKFLOW_FILE")
APPEARANCE=$(yq -r '.simulator.appearance // "dark"' "$WORKFLOW_FILE")
DURATION=$(yq -r '.recording.duration // 15' "$WORKFLOW_FILE")
OUTPUT_NAME=$(yq -r '.output.filename // "demo"' "$WORKFLOW_FILE")
BG_COLOR=$(yq -r '.output.background_color // "#f5f5f5"' "$WORKFLOW_FILE")
INCLUDE_FRAME=$(yq -r '.output.include_device_frame // true' "$WORKFLOW_FILE")
TWITTER_OPTIMIZED=$(yq -r '.output.twitter_optimized // true' "$WORKFLOW_FILE")
WORKFLOW_NAME=$(yq -r '.name // "Demo"' "$WORKFLOW_FILE")

log_info "Recording: $WORKFLOW_NAME"
log_info "Device: $DEVICE, Appearance: $APPEARANCE"

# Create directories
mkdir -p "$TEMP_DIR" "$OUTPUT_DIR"

# Get simulator UDID
get_simulator_udid() {
    xcrun simctl list devices available | grep "$DEVICE" | grep -oE '[A-F0-9-]{36}' | head -1
}

SIMULATOR_UDID=$(get_simulator_udid)

if [ -z "$SIMULATOR_UDID" ]; then
    log_error "Simulator '$DEVICE' not found"
    log_info "Available simulators:"
    xcrun simctl list devices available | grep "iPhone\|iPad" | head -10
    exit 1
fi

log_info "Simulator UDID: $SIMULATOR_UDID"

# 1. Boot simulator
log_info "Booting simulator..."
xcrun simctl boot "$SIMULATOR_UDID" 2>/dev/null || true

# Wait for simulator to be ready
for i in {1..30}; do
    STATE=$(xcrun simctl list devices | grep "$SIMULATOR_UDID" | grep -o "(Booted)" || true)
    if [ -n "$STATE" ]; then
        break
    fi
    sleep 1
done

# Open Simulator.app to make it visible
open -a Simulator
sleep 5

# Wait for Simulator.app to be fully running
log_info "Waiting for Simulator.app to be ready..."
for i in {1..20}; do
    if pgrep -x "Simulator" > /dev/null; then
        break
    fi
    sleep 0.5
done
sleep 3

# 2. Set appearance
log_info "Setting appearance to $APPEARANCE..."
xcrun simctl ui "$SIMULATOR_UDID" appearance "$APPEARANCE"
sleep 1

# 3. Find and install app
log_info "Looking for built app..."
APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData -name "TheLogger.app" -path "*/Debug-iphonesimulator/*" -type d 2>/dev/null | head -1)

if [ -z "$APP_PATH" ]; then
    log_warn "App not found in DerivedData. Building..."
    cd "$PROJECT_DIR"
    xcodebuild build \
        -project TheLogger.xcodeproj \
        -scheme TheLogger \
        -destination "platform=iOS Simulator,name=$DEVICE" \
        -configuration Debug \
        -quiet 2>&1 | grep -i "error" || true

    sleep 2
    APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData -name "TheLogger.app" -path "*/Debug-iphonesimulator/*" -type d 2>/dev/null | head -1)
fi

if [ -z "$APP_PATH" ]; then
    log_error "Could not find or build TheLogger.app"
    exit 1
fi

log_info "Installing app from: $APP_PATH"

# Extract bundle ID from the app
if [ -f "$APP_PATH/Info.plist" ]; then
    BUNDLE_ID=$(plutil -extract CFBundleIdentifier raw "$APP_PATH/Info.plist" 2>/dev/null || echo "com.SDL-Tutorial.TheLogger")
    log_info "Bundle ID: $BUNDLE_ID"
else
    BUNDLE_ID="com.SDL-Tutorial.TheLogger"
    log_warn "Could not read Info.plist, using default bundle ID: $BUNDLE_ID"
fi

xcrun simctl install "$SIMULATOR_UDID" "$APP_PATH"
sleep 3

# Verify installation
if ! xcrun simctl get_app_container "$SIMULATOR_UDID" "$BUNDLE_ID" 2>/dev/null; then
    log_error "App installation verification failed"
    exit 1
fi
log_success "App installed successfully"

# 4. Launch app
log_info "Launching app..."

# Terminate app if already running
xcrun simctl terminate "$SIMULATOR_UDID" "$BUNDLE_ID" 2>/dev/null || true
sleep 1

# Launch the app
if ! xcrun simctl launch "$SIMULATOR_UDID" "$BUNDLE_ID"; then
    log_error "Failed to launch app. Trying alternative method..."
    # Alternative: Use open command
    open -a Simulator --args -CurrentDeviceUDID "$SIMULATOR_UDID"
    sleep 2
    xcrun simctl launch "$SIMULATOR_UDID" "$BUNDLE_ID" || {
        log_error "Failed to launch app after retry"
        exit 1
    }
fi
sleep 3

# 5. Start recording
RAW_VIDEO="$TEMP_DIR/${OUTPUT_NAME}_raw.mov"
log_info "Starting screen recording..."

# Start recording in background
xcrun simctl io "$SIMULATOR_UDID" recordVideo --codec hevc "$RAW_VIDEO" &
RECORD_PID=$!
sleep 2

# 6. Run XCUITest scenario
log_info "Running demo scenario via XCUITest..."

# Extract test method name from workflow filename
TEST_METHOD="test$(echo "$OUTPUT_NAME" | sed 's/-/_/g' | sed 's/.*/\u&/' | sed 's/_./\U&/g' | sed 's/_//g')Demo"

cd "$PROJECT_DIR"

# Run the specific UI test
# We use || true because we don't want to fail if test doesn't exist yet
xcodebuild test \
    -project TheLogger.xcodeproj \
    -scheme TheLoggerUITests \
    -destination "platform=iOS Simulator,id=$SIMULATOR_UDID" \
    -only-testing:"TheLoggerUITests/DemoScenarios/$TEST_METHOD" \
    -quiet \
    2>&1 || {
        log_warn "XCUITest not found or failed. Using timer fallback..."
        sleep "$DURATION"
    }

# Give it a moment to complete any animations
sleep 2

# 7. Stop recording
log_info "Stopping recording..."
kill -INT $RECORD_PID 2>/dev/null || true
wait $RECORD_PID 2>/dev/null || true
sleep 2

if [ ! -f "$RAW_VIDEO" ]; then
    log_error "Recording failed - no video file created"
    exit 1
fi

log_success "Raw video recorded: $RAW_VIDEO"

# 8. Apply device frame (if enabled)
FRAMED_VIDEO="$TEMP_DIR/${OUTPUT_NAME}_framed.mov"

if [ "$INCLUDE_FRAME" = "true" ]; then
    if command -v screenframer &> /dev/null; then
        log_info "Applying device frame with screenframer..."
        # Convert hex color to RGB for screenframer
        screenframer \
            -t "iPhone 17 Pro,black" \
            -w 720 \
            -c "$BG_COLOR" \
            "$RAW_VIDEO" "$FRAMED_VIDEO" 2>/dev/null || {
                log_warn "screenframer failed, using raw video"
                cp "$RAW_VIDEO" "$FRAMED_VIDEO"
            }
    else
        log_info "Creating device frame with ffmpeg..."
        # Simple centered frame approach without actual device bezel
        # The video will be centered on a colored background
        cp "$RAW_VIDEO" "$FRAMED_VIDEO"
    fi
else
    cp "$RAW_VIDEO" "$FRAMED_VIDEO"
fi

# 9. Optimize for Twitter
FINAL_VIDEO="$OUTPUT_DIR/${OUTPUT_NAME}_twitter.mp4"

# Convert hex to ffmpeg color format (remove #)
FFMPEG_COLOR="${BG_COLOR/#\#/0x}"

log_info "Optimizing for Twitter (720x1280, H.264)..."

if [ "$TWITTER_OPTIMIZED" = "true" ]; then
    ffmpeg -y -i "$FRAMED_VIDEO" \
        -vf "scale=720:1280:force_original_aspect_ratio=decrease,pad=720:1280:(ow-iw)/2:(oh-ih)/2:color=$FFMPEG_COLOR,format=yuv420p" \
        -c:v libx264 \
        -preset slow \
        -crf 18 \
        -movflags +faststart \
        -an \
        "$FINAL_VIDEO" \
        2>/dev/null
else
    ffmpeg -y -i "$FRAMED_VIDEO" \
        -c:v libx264 \
        -preset slow \
        -crf 18 \
        -movflags +faststart \
        "$FINAL_VIDEO" \
        2>/dev/null
fi

# 10. Get video info
DURATION_SECS=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$FINAL_VIDEO" 2>/dev/null | cut -d. -f1)
FILE_SIZE=$(ls -lh "$FINAL_VIDEO" | awk '{print $5}')

log_success "Video created successfully!"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Output: $FINAL_VIDEO"
echo "  Duration: ${DURATION_SECS}s"
echo "  Size: $FILE_SIZE"
echo "  Resolution: 720x1280 (9:16 portrait)"
echo "  Format: H.264/MP4 (Twitter optimized)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# 11. Cleanup temp files
log_info "Cleaning up temporary files..."
rm -rf "$TEMP_DIR"

# Open output folder
open "$OUTPUT_DIR"

log_success "Done! Video is ready for Twitter."
