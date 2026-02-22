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

# 3. Build app + test bundle BEFORE starting recording
# This prevents compile time from appearing in the video.
# xcodebuild test-without-building will reuse these build products.
log_info "Building app and test bundle (this takes a minute on first run)..."
cd "$PROJECT_DIR"
if ! xcodebuild build-for-testing \
    -project TheLogger.xcodeproj \
    -scheme TheLogger \
    -destination "platform=iOS Simulator,id=$SIMULATOR_UDID" \
    -configuration Debug \
    -quiet 2>&1; then
    log_error "Build failed. Fix compilation errors and retry."
    exit 1
fi
log_success "Build complete. Starting recording now."
sleep 2

# 4. Start recording
RAW_VIDEO="$TEMP_DIR/${OUTPUT_NAME}_raw.mov"
log_info "Starting screen recording..."

# Remove stale file from a previous run — simctl refuses to overwrite
rm -f "$RAW_VIDEO"

# Start recording in background
xcrun simctl io "$SIMULATOR_UDID" recordVideo --codec hevc "$RAW_VIDEO" &
RECORD_PID=$!
sleep 2

# 5. Run XCUITest scenario
log_info "Running demo scenario via XCUITest..."

# Extract test method name from workflow filename
# Convert: new-workout -> testNewWorkoutDemo
# Uses awk for proper case conversion (BSD sed doesn't support \u and \U)
TEST_METHOD="test$(echo "$OUTPUT_NAME" | awk -F'-' '{for(i=1;i<=NF;i++){$i=toupper(substr($i,1,1)) substr($i,2)}} 1' OFS='')Demo"

cd "$PROJECT_DIR"

# Run the specific UI test using previously-built products (no compile time in video)
# -parallel-testing-enabled NO prevents simulator cloning
xcodebuild test-without-building \
    -project TheLogger.xcodeproj \
    -scheme TheLogger \
    -destination "platform=iOS Simulator,id=$SIMULATOR_UDID" \
    -only-testing:"TheLoggerUITests/DemoScenarios/$TEST_METHOD" \
    -parallel-testing-enabled NO \
    -enableCodeCoverage NO \
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

# 8. Apply cinematic effects (zoom, text, flash, music, speed ramp)
EFFECTS_VIDEO="$TEMP_DIR/${OUTPUT_NAME}_effects.mp4"
EFFECTS_DEFINED=$(yq e '.effects' "$WORKFLOW_FILE" 2>/dev/null || echo "null")

if [ "$EFFECTS_DEFINED" != "null" ] && [ -n "$EFFECTS_DEFINED" ]; then
    log_info "Applying cinematic effects..."
    "$SCRIPT_DIR/add-effects.sh" "$RAW_VIDEO" "$WORKFLOW_FILE" "$EFFECTS_VIDEO"
    PROCESS_SOURCE="$EFFECTS_VIDEO"
else
    log_info "No effects defined - skipping effects step"
    PROCESS_SOURCE="$RAW_VIDEO"
fi

# 9. Phone frame + pastel background
# The phone content is scaled to 65% width, placed on a dark bezel, and centered
# on the YAML background_color (pastel).  All other workflows can override
# include_device_frame: false to skip this and output full-bleed.
FRAMED_VIDEO="$TEMP_DIR/${OUTPUT_NAME}_framed.mp4"

# Probe source FPS so the infinite `color` source matches the video rate
SRC_FPS=$(ffprobe -v error -select_streams v:0 \
    -show_entries stream=r_frame_rate \
    -of default=noprint_wrappers=1:nokey=1 \
    "$PROCESS_SOURCE" 2>/dev/null \
    | awk -F'/' '{ if ($2>0) printf "%.0f",$1/$2; else print 30 }')
SRC_FPS="${SRC_FPS:-30}"

# ── Phone frame dimensions ──────────────────────────────────────────────────
# Canvas (Twitter portrait)
CW=720; CH=1280
# Phone screen at 65% canvas width, maintaining 9:16 aspect ratio
PW=468; PH=832
# Bezel: side / top (camera pill) / bottom (home bar)
BS=16; BT=44; BB=28
BW=$((PW + BS*2)); BH=$((PH + BT + BB))   # 500 × 904
# Center bezel in canvas
BX=$(( (CW - BW) / 2 )); BY=$(( (CH - BH) / 2 ))   # 110 × 188
# Phone content top-left inside bezel
PX=$((BX + BS)); PY=$((BY + BT))           # 126 × 232
# Camera pill
CAMW=72; CAMH=16
CAMX=$((PX + (PW - CAMW)/2)); CAMY=$((BY + 14))
# Home indicator
INDW=100; INDH=4
INDX=$((PX + (PW - INDW)/2)); INDY=$((PY + PH + 12))
# ───────────────────────────────────────────────────────────────────────────

BEZEL_COLOR="0x1a1a2e"
FFMPEG_BG="${BG_COLOR/#\#/0x}"

apply_phone_frame() {
    local src="$1" dst="$2"
    # Corner radius simulation: cut R×R squares at each bezel corner in BG color
    # (ffmpeg drawbox lacks a built-in radius option in this build)
    local R=20
    local COR_TR_X=$((BX+BW-R)) COR_BL_Y=$((BY+BH-R))
    ffmpeg -y -i "$src" \
        -filter_complex "
            color=c=${FFMPEG_BG}:size=${CW}x${CH}:rate=${SRC_FPS}[bg];
            [bg]drawbox=x=${BX}:y=${BY}:w=${BW}:h=${BH}:color=${BEZEL_COLOR}:t=fill[b1];
            [b1]drawbox=x=${BX}:y=${BY}:w=${R}:h=${R}:color=${FFMPEG_BG}:t=fill[b2];
            [b2]drawbox=x=${COR_TR_X}:y=${BY}:w=${R}:h=${R}:color=${FFMPEG_BG}:t=fill[b3];
            [b3]drawbox=x=${BX}:y=${COR_BL_Y}:w=${R}:h=${R}:color=${FFMPEG_BG}:t=fill[b4];
            [b4]drawbox=x=${COR_TR_X}:y=${COR_BL_Y}:w=${R}:h=${R}:color=${FFMPEG_BG}:t=fill[b5];
            [b5]drawbox=x=${CAMX}:y=${CAMY}:w=${CAMW}:h=${CAMH}:color=#2a2a3e:t=fill[cam];
            [cam]drawbox=x=${INDX}:y=${INDY}:w=${INDW}:h=${INDH}:color=white@0.35:t=fill[ind];
            [0:v]scale=${PW}:${PH}:flags=lanczos:force_original_aspect_ratio=disable[phone];
            [ind][phone]overlay=x=${PX}:y=${PY}:shortest=1,format=yuv420p[out]
        " \
        -map "[out]" -map "0:a?" \
        -c:v libx264 -preset fast -crf 18 \
        -c:a copy \
        "$dst" 2>/dev/null
}

if [ "$INCLUDE_FRAME" = "true" ]; then
    if command -v screenframer &> /dev/null; then
        log_info "Applying device frame with screenframer..."
        screenframer \
            -t "iPhone 17 Pro,black" \
            -w 720 \
            -c "$BG_COLOR" \
            "$PROCESS_SOURCE" "$FRAMED_VIDEO" 2>/dev/null || {
                log_warn "screenframer failed — using ffmpeg phone frame"
                apply_phone_frame "$PROCESS_SOURCE" "$FRAMED_VIDEO"
            }
    else
        log_info "Building phone frame + pastel background (${CW}x${CH})..."
        apply_phone_frame "$PROCESS_SOURCE" "$FRAMED_VIDEO" || {
            log_warn "Phone frame failed — falling back to full-bleed"
            ffmpeg -y -i "$PROCESS_SOURCE" \
                -vf "scale=${CW}:${CH}:force_original_aspect_ratio=decrease,pad=${CW}:${CH}:(ow-iw)/2:(oh-ih)/2:color=${FFMPEG_BG},format=yuv420p" \
                -c:v libx264 -preset fast -crf 18 \
                -map "0:a?" -c:a copy \
                "$FRAMED_VIDEO" 2>/dev/null
        }
    fi
else
    cp "$PROCESS_SOURCE" "$FRAMED_VIDEO"
fi

# 10. Optimize for Twitter
FINAL_VIDEO="$OUTPUT_DIR/${OUTPUT_NAME}_twitter.mp4"

# Convert hex to ffmpeg color format (remove #)
FFMPEG_COLOR="${BG_COLOR/#\#/0x}"

log_info "Optimizing for Twitter (720x1280, H.264)..."

# Detect whether the effects video has audio (music track)
FRAMED_HAS_AUDIO=$(ffprobe -v error -select_streams a:0 \
    -show_entries stream=codec_type \
    -of default=noprint_wrappers=1:nokey=1 \
    "$FRAMED_VIDEO" 2>/dev/null || true)

if [ "$TWITTER_OPTIMIZED" = "true" ]; then
    if [ -n "$FRAMED_HAS_AUDIO" ]; then
        # Preserve audio track (music from effects step)
        ffmpeg -y -i "$FRAMED_VIDEO" \
            -vf "scale=720:1280:force_original_aspect_ratio=decrease,pad=720:1280:(ow-iw)/2:(oh-ih)/2:color=$FFMPEG_COLOR,format=yuv420p" \
            -c:v libx264 \
            -preset slow \
            -crf 18 \
            -c:a aac -b:a 128k \
            -movflags +faststart \
            "$FINAL_VIDEO" \
            2>/dev/null
    else
        ffmpeg -y -i "$FRAMED_VIDEO" \
            -vf "scale=720:1280:force_original_aspect_ratio=decrease,pad=720:1280:(ow-iw)/2:(oh-ih)/2:color=$FFMPEG_COLOR,format=yuv420p" \
            -c:v libx264 \
            -preset slow \
            -crf 18 \
            -movflags +faststart \
            -an \
            "$FINAL_VIDEO" \
            2>/dev/null
    fi
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

# 11. High-quality re-encode of the framed video (production master)
# The framed video is already 720×1280 with the phone frame baked in.
# This step re-encodes at slow preset for maximum quality.
PRODUCTION_VIDEO="$OUTPUT_DIR/${OUTPUT_NAME}_production.mp4"
log_info "Creating production quality master..."

PROD_HAS_AUDIO=$(ffprobe -v error -select_streams a:0 \
    -show_entries stream=codec_type \
    -of default=noprint_wrappers=1:nokey=1 \
    "$FRAMED_VIDEO" 2>/dev/null || true)

if [ -n "$PROD_HAS_AUDIO" ]; then
    ffmpeg -y -i "$FRAMED_VIDEO" \
        -vf "format=yuv420p" \
        -c:v libx264 -preset slow -crf 16 \
        -c:a aac -b:a 192k \
        -movflags +faststart \
        "$PRODUCTION_VIDEO" 2>/dev/null
else
    ffmpeg -y -i "$FRAMED_VIDEO" \
        -vf "format=yuv420p" \
        -c:v libx264 -preset slow -crf 16 \
        -movflags +faststart -an \
        "$PRODUCTION_VIDEO" 2>/dev/null
fi

PROD_FILE_SIZE=$(ls -lh "$PRODUCTION_VIDEO" 2>/dev/null | awk '{print $5}' || echo "?")
PROD_RESOLUTION=$(ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=s=x:p=0 "$PRODUCTION_VIDEO" 2>/dev/null)

log_success "Production master created!"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Production: $PRODUCTION_VIDEO"
echo "  Duration: ${DURATION_SECS}s"
echo "  Size: $PROD_FILE_SIZE"
echo "  Resolution: $PROD_RESOLUTION"
echo "  Format: H.264/MP4 (CRF 16, high quality)"
echo "  Features: Phone frame + pastel background"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# 12. Cleanup temp files
log_info "Cleaning up temporary files..."
rm -rf "$TEMP_DIR"

# Open output folder
open "$OUTPUT_DIR"

log_success "Done! Video is ready for Twitter."
