#!/bin/bash
# Add production quality to recorded videos:
# - Device bezel/frame
# - Neutral background with padding
# - Professional presentation

set -e

INPUT_VIDEO=$1
OUTPUT_VIDEO=$2

if [ -z "$INPUT_VIDEO" ] || [ -z "$OUTPUT_VIDEO" ]; then
    echo "Usage: ./add-production-quality.sh <input.mov> <output.mp4>"
    exit 1
fi

if [ ! -f "$INPUT_VIDEO" ]; then
    echo "Error: Input video not found: $INPUT_VIDEO"
    exit 1
fi

# Configuration for iPhone 17 Pro presentation
DEVICE_FRAME_PADDING=40     # Padding around device (like a case)
CANVAS_SIDE_PADDING=180     # Extra padding on left/right for neutral background
FRAME_COLOR="#1c1c1e"       # Dark frame color (Apple-like)
BG_COLOR="#f5f5f7"          # Light neutral background

echo "[INFO] Creating production-quality video..."

# Apply transformations:
# 1. Add dark frame padding (simulates device bezel)
# 2. Add neutral background canvas with side padding
# 3. Optimize for display

ffmpeg -y -i "$INPUT_VIDEO" -vf "\
  pad=iw+${DEVICE_FRAME_PADDING}*2:ih+${DEVICE_FRAME_PADDING}*2:${DEVICE_FRAME_PADDING}:${DEVICE_FRAME_PADDING}:color=${FRAME_COLOR},\
  pad=iw+${CANVAS_SIDE_PADDING}*2:ih:(ow-iw)/2:(oh-ih)/2:color=${BG_COLOR},\
  format=yuv420p" \
  -c:v libx264 \
  -preset slow \
  -crf 18 \
  -movflags +faststart \
  -an \
  "$OUTPUT_VIDEO" 2>&1 | grep -v "deprecated pixel format"

# Get video info
DURATION=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$OUTPUT_VIDEO" 2>/dev/null | cut -d. -f1)
FILE_SIZE=$(ls -lh "$OUTPUT_VIDEO" | awk '{print $5}')
RESOLUTION=$(ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=s=x:p=0 "$OUTPUT_VIDEO" 2>/dev/null)

echo ""
echo "[SUCCESS] Production video created!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Output: $OUTPUT_VIDEO"
echo "  Duration: ${DURATION}s"
echo "  Size: $FILE_SIZE"
echo "  Resolution: $RESOLUTION"
echo "  Format: H.264/MP4 (Production Quality)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
