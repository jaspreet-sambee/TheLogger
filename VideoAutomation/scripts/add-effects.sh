#!/bin/bash
# add-effects.sh - Apply cinematic effects to demo videos
# Usage: ./add-effects.sh <input.mov> <workflow.yaml> <output.mp4>
#
# Reads the `effects:` block from a workflow YAML and applies:
#   - Speed ramp (setpts filter on trimmed segments + concat)
#   - Zoom moments (segment trim + crop/pad + scale + concat)
#     NOTE: zoompan with conditional expressions is broken in ffmpeg 8.0.
#           We use the trim-segment approach instead.
#   - Flash on tap (eq brightness spike via enable expression)
#   - Text overlays (drawtext — requires ffmpeg-full: brew install ffmpeg-full)
#   - Background music (amix at low volume with fade-out)

set -e

# ─────────────────────────────────────────
# Colors and logging
# ─────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info()    { echo -e "${BLUE}[EFFECTS]${NC} $1"; }
log_success() { echo -e "${GREEN}[EFFECTS]${NC} $1"; }
log_warn()    { echo -e "${YELLOW}[EFFECTS]${NC} $1"; }
log_error()   { echo -e "${RED}[EFFECTS]${NC} $1"; }

# ─────────────────────────────────────────
# Arguments
# ─────────────────────────────────────────
INPUT_VIDEO="$1"
WORKFLOW_FILE="$2"
OUTPUT_VIDEO="$3"

if [ -z "$INPUT_VIDEO" ] || [ -z "$WORKFLOW_FILE" ] || [ -z "$OUTPUT_VIDEO" ]; then
    echo "Usage: ./add-effects.sh <input.mov> <workflow.yaml> <output.mp4>"
    exit 1
fi

if [ ! -f "$INPUT_VIDEO" ]; then
    log_error "Input video not found: $INPUT_VIDEO"
    exit 1
fi

if [ ! -f "$WORKFLOW_FILE" ]; then
    log_error "Workflow file not found: $WORKFLOW_FILE"
    exit 1
fi

# ─────────────────────────────────────────
# Check for effects block
# ─────────────────────────────────────────
EFFECTS_DEFINED=$(yq e '.effects' "$WORKFLOW_FILE" 2>/dev/null || echo "null")
if [ "$EFFECTS_DEFINED" = "null" ] || [ -z "$EFFECTS_DEFINED" ]; then
    log_info "No effects defined in workflow - passing through unchanged"
    cp "$INPUT_VIDEO" "$OUTPUT_VIDEO"
    exit 0
fi

# ─────────────────────────────────────────
# Parse effects configuration
# ─────────────────────────────────────────
HAS_MUSIC=$(yq e '.effects.music // false' "$WORKFLOW_FILE")
MUSIC_VOLUME=$(yq e '.effects.music_volume // 0.25' "$WORKFLOW_FILE")
HAS_SPEED_RAMP=$(yq e '.effects.speed_ramp != null' "$WORKFLOW_FILE")

ZOOM_COUNT=$(yq e '.effects.zoom_moments | length' "$WORKFLOW_FILE" 2>/dev/null || echo "0")
TEXT_COUNT=$(yq e '.effects.text_overlays | length' "$WORKFLOW_FILE" 2>/dev/null || echo "0")
FLASH_COUNT=$(yq e '.effects.flash_moments | length' "$WORKFLOW_FILE" 2>/dev/null || echo "0")

ZOOM_COUNT="${ZOOM_COUNT:-0}"
TEXT_COUNT="${TEXT_COUNT:-0}"
FLASH_COUNT="${FLASH_COUNT:-0}"
[[ "$ZOOM_COUNT" =~ ^[0-9]+$ ]] || ZOOM_COUNT=0
[[ "$TEXT_COUNT" =~ ^[0-9]+$ ]] || TEXT_COUNT=0
[[ "$FLASH_COUNT" =~ ^[0-9]+$ ]] || FLASH_COUNT=0

# ─────────────────────────────────────────
# Check filter availability
# ─────────────────────────────────────────
DRAWTEXT_AVAILABLE=false
if ffmpeg -filters 2>/dev/null | grep -q "drawtext"; then
    DRAWTEXT_AVAILABLE=true
fi

# ─────────────────────────────────────────
# Probe source video
# ─────────────────────────────────────────
VIDEO_DURATION=$(ffprobe -v error -show_entries format=duration \
    -of default=noprint_wrappers=1:nokey=1 "$INPUT_VIDEO" 2>/dev/null)
VIDEO_WIDTH=$(ffprobe -v error -select_streams v:0 \
    -show_entries stream=width \
    -of default=noprint_wrappers=1:nokey=1 "$INPUT_VIDEO" 2>/dev/null)
VIDEO_HEIGHT=$(ffprobe -v error -select_streams v:0 \
    -show_entries stream=height \
    -of default=noprint_wrappers=1:nokey=1 "$INPUT_VIDEO" 2>/dev/null)
HAS_AUDIO=$(ffprobe -v error -select_streams a:0 \
    -show_entries stream=codec_type \
    -of default=noprint_wrappers=1:nokey=1 "$INPUT_VIDEO" 2>/dev/null)

VIDEO_WIDTH="${VIDEO_WIDTH:-393}"
VIDEO_HEIGHT="${VIDEO_HEIGHT:-852}"

log_info "Source: ${VIDEO_WIDTH}x${VIDEO_HEIGHT} | ${VIDEO_DURATION}s"
log_info "Effects: zoom=$ZOOM_COUNT text=$TEXT_COUNT flash=$FLASH_COUNT music=$HAS_MUSIC speed_ramp=$HAS_SPEED_RAMP"

if [ "$DRAWTEXT_AVAILABLE" = "false" ] && [ "$TEXT_COUNT" -gt 0 ]; then
    log_warn "drawtext not in this ffmpeg build — text overlays will be skipped"
    log_warn "To enable text overlays: brew install ffmpeg-full"
fi

# ─────────────────────────────────────────
# Working resolution
# ─────────────────────────────────────────
# Simulator records at full Retina resolution (e.g. 1206x2622).
# Scale to 1280-tall for effects processing.
WORK_FPS=30
if [ "$VIDEO_HEIGHT" -gt 1400 ] 2>/dev/null; then
    WORK_W=$(awk "BEGIN { w=int(1280 * $VIDEO_WIDTH / $VIDEO_HEIGHT); print (w%2==0)?w:w-1 }")
    WORK_H=1280
    log_info "Working resolution: ${WORK_W}x${WORK_H} @ ${WORK_FPS}fps"
else
    WORK_W="$VIDEO_WIDTH"
    WORK_H="$VIDEO_HEIGHT"
fi

# ─────────────────────────────────────────
# Temp file helpers
# ─────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ASSETS_DIR="$(dirname "$SCRIPT_DIR")/assets"
MUSIC_FILE="$ASSETS_DIR/music/gym-lofi.mp3"

WORK_DIR=$(dirname "$OUTPUT_VIDEO")
BASENAME=$(basename "$OUTPUT_VIDEO" | sed 's/\.[^.]*$//')
STEP=0

# Calling next_temp inside $() runs in a subshell — STEP increment is lost.
# Instead, always call advance_step then use $STEP_OUT directly.
advance_step() {
    STEP=$((STEP + 1))
    STEP_OUT="${WORK_DIR}/${BASENAME}_fx_step${STEP}.mp4"
}

cleanup_temps() {
    for f in "${WORK_DIR}/${BASENAME}_fx_step"*.mp4; do
        [ -f "$f" ] && rm -f "$f"
    done
}

CURRENT_FILE="$INPUT_VIDEO"

# ═════════════════════════════════════════
# STEP 0: Trim Start / End
# ═════════════════════════════════════════
# Strips the iOS springboard from the beginning and end of recordings.
# Timestamps in all subsequent YAML keys (speed_ramp, zoom_moments, etc.)
# are in post-trim space.
TRIM_START=$(yq e '.effects.trim_start // 0' "$WORKFLOW_FILE")
TRIM_END=$(yq e '.effects.trim_end // 0' "$WORKFLOW_FILE")

if awk "BEGIN { exit !($TRIM_START > 0 || $TRIM_END > 0) }"; then
    log_info "Trimming: remove first ${TRIM_START}s, last ${TRIM_END}s..."
    advance_step

    TRIM_TO=""
    if awk "BEGIN { exit !($TRIM_END > 0) }"; then
        TRIM_TO=$(awk "BEGIN { printf \"%.3f\", $VIDEO_DURATION - $TRIM_END }")
        ffmpeg -y -i "$CURRENT_FILE" \
            -ss "$TRIM_START" -to "$TRIM_TO" \
            -c:v libx264 -preset fast -crf 18 \
            "$STEP_OUT" 2>/dev/null
    else
        ffmpeg -y -i "$CURRENT_FILE" \
            -ss "$TRIM_START" \
            -c:v libx264 -preset fast -crf 18 \
            "$STEP_OUT" 2>/dev/null
    fi

    CURRENT_FILE="$STEP_OUT"
    # Update VIDEO_DURATION so subsequent steps (speed ramp, zoom) use correct bounds
    VIDEO_DURATION=$(ffprobe -v error -show_entries format=duration \
        -of default=noprint_wrappers=1:nokey=1 "$CURRENT_FILE" 2>/dev/null)
    log_success "Trimmed → ${VIDEO_DURATION}s"
fi

# ═════════════════════════════════════════
# STEP 1: Speed Ramp
# ═════════════════════════════════════════
if [ "$HAS_SPEED_RAMP" = "true" ]; then
    RAMP_START=$(yq e '.effects.speed_ramp.start' "$WORKFLOW_FILE")
    RAMP_END=$(yq e '.effects.speed_ramp.end' "$WORKFLOW_FILE")
    RAMP_SPEED=$(yq e '.effects.speed_ramp.speed' "$WORKFLOW_FILE")
    RAMP_END_SAFE=$(awk "BEGIN { d=$VIDEO_DURATION; e=$RAMP_END; print (e < d) ? e : d - 0.1 }")

    log_info "Speed ramp: ${RAMP_START}s-${RAMP_END}s at ${RAMP_SPEED}x..."
    advance_step

    ffmpeg -y -i "$CURRENT_FILE" \
        -filter_complex "
            [0:v]trim=0:${RAMP_START},setpts=PTS-STARTPTS[v1];
            [0:v]trim=${RAMP_START}:${RAMP_END_SAFE},setpts=PTS/(${RAMP_SPEED})[v2];
            [0:v]trim=${RAMP_END_SAFE},setpts=PTS-STARTPTS[v3];
            [v1][v2][v3]concat=n=3:v=1:a=0[outv]
        " \
        -map "[outv]" \
        -c:v libx264 -preset fast -crf 18 \
        "$STEP_OUT" 2>/dev/null

    CURRENT_FILE="$STEP_OUT"
    log_success "Speed ramp applied"
fi

# ═════════════════════════════════════════
# STEP 2a: Zoom Moments
# ═════════════════════════════════════════
# ffmpeg 8.0 broke conditional expressions in zoompan's z parameter (-22 Invalid argument).
# We use a segment trim + crop/pad + scale + concat approach instead.
if [ "$ZOOM_COUNT" -gt 0 ]; then
    log_info "Applying $ZOOM_COUNT zoom moment(s) via segment trim+crop+concat..."
    advance_step

    FC=""
    SEG_LABELS=""
    SEG_N=0
    PREV_T="0"

    for (( i=0; i<ZOOM_COUNT; i++ )); do
        ZM_TIME=$(yq e ".effects.zoom_moments[$i].time"                    "$WORKFLOW_FILE")
        ZM_SCALE=$(yq e ".effects.zoom_moments[$i].scale"                  "$WORKFLOW_FILE")
        ZM_DUR=$(yq e ".effects.zoom_moments[$i].duration"                 "$WORKFLOW_FILE")
        ZM_ANCHOR=$(yq e ".effects.zoom_moments[$i].anchor // \"center\""  "$WORKFLOW_FILE")
        ZM_END=$(awk "BEGIN { printf \"%.3f\", $ZM_TIME + $ZM_DUR }")

        # Before-segment (scale to working resolution, constant fps)
        if awk "BEGIN { exit !($ZM_TIME > $PREV_T) }"; then
            FC+="[0:v]trim=start=${PREV_T}:end=${ZM_TIME},setpts=PTS-STARTPTS,scale=${WORK_W}:${WORK_H},fps=${WORK_FPS}[seg${SEG_N}]; "
            SEG_LABELS+="[seg${SEG_N}]"
            SEG_N=$((SEG_N + 1))
        fi

        # Zoom segment: compute crop (zoom in) or pad (zoom out) dimensions
        CW=$(awk "BEGIN { w=int(${WORK_W} / ${ZM_SCALE}); print (w%2==0)?w:w-1 }")
        CH=$(awk "BEGIN { h=int(${WORK_H} / ${ZM_SCALE}); print (h%2==0)?h:h-1 }")

        case "$ZM_ANCHOR" in
            "bottom"|"bottom_center")
                CX=$(awk "BEGIN { printf \"%.0f\", (${WORK_W} - ${CW}) / 2 }")
                CY=$(awk "BEGIN { printf \"%.0f\", ${WORK_H} - ${CH} }")
                ;;
            "right")
                CX=$(awk "BEGIN { printf \"%.0f\", ${WORK_W} - ${CW} }")
                CY=$(awk "BEGIN { printf \"%.0f\", (${WORK_H} - ${CH}) / 2 }")
                ;;
            *)  # center
                CX=$(awk "BEGIN { printf \"%.0f\", (${WORK_W} - ${CW}) / 2 }")
                CY=$(awk "BEGIN { printf \"%.0f\", (${WORK_H} - ${CH}) / 2 }")
                ;;
        esac

        if awk "BEGIN { exit !($ZM_SCALE >= 1.0) }"; then
            # Zoom in: crop smaller region then upscale
            ZOOM_FILTER="scale=${WORK_W}:${WORK_H},fps=${WORK_FPS},crop=${CW}:${CH}:${CX}:${CY},scale=${WORK_W}:${WORK_H}"
        else
            # Zoom out: shrink and pad with black
            PAD_W=$(awk "BEGIN { w=int(${WORK_W} / ${ZM_SCALE}); print (w%2==0)?w:w-1 }")
            PAD_H=$(awk "BEGIN { h=int(${WORK_H} / ${ZM_SCALE}); print (h%2==0)?h:h-1 }")
            ZOOM_FILTER="scale=${WORK_W}:${WORK_H},fps=${WORK_FPS},pad=${PAD_W}:${PAD_H}:(ow-iw)/2:(oh-ih)/2:color=black,scale=${WORK_W}:${WORK_H}"
        fi

        FC+="[0:v]trim=start=${ZM_TIME}:end=${ZM_END},setpts=PTS-STARTPTS,${ZOOM_FILTER}[seg${SEG_N}]; "
        SEG_LABELS+="[seg${SEG_N}]"
        SEG_N=$((SEG_N + 1))
        PREV_T="$ZM_END"
    done

    # Final segment after last zoom
    FC+="[0:v]trim=start=${PREV_T},setpts=PTS-STARTPTS,scale=${WORK_W}:${WORK_H},fps=${WORK_FPS}[seg${SEG_N}]; "
    SEG_LABELS+="[seg${SEG_N}]"
    SEG_N=$((SEG_N + 1))

    FC+="${SEG_LABELS}concat=n=${SEG_N}:v=1:a=0[outv]"

    ffmpeg -y -i "$CURRENT_FILE" \
        -filter_complex "$FC" \
        -map "[outv]" \
        -c:v libx264 -preset fast -crf 18 \
        "$STEP_OUT" 2>/dev/null

    CURRENT_FILE="$STEP_OUT"
    log_success "Zoom moments applied ($SEG_N segments)"
fi

# ═════════════════════════════════════════
# STEP 2b: Flash + Text Overlays
# ═════════════════════════════════════════
VFILTER_PARTS=()

# If zoom step did not run, pre-scale to working resolution here
if [ "$ZOOM_COUNT" -eq 0 ] && [ "$VIDEO_HEIGHT" -gt 1400 ] 2>/dev/null; then
    VFILTER_PARTS+=("scale=${WORK_W}:${WORK_H},fps=${WORK_FPS}")
fi

# Brightness flash
if [ "$FLASH_COUNT" -gt 0 ]; then
    log_info "Building flash effects for $FLASH_COUNT moment(s)..."
    BRIGHT_EXPR="0"
    for (( i=0; i<FLASH_COUNT; i++ )); do
        FL_TIME=$(yq e ".effects.flash_moments[$i].time"    "$WORKFLOW_FILE")
        FL_DUR=$(yq e ".effects.flash_moments[$i].duration" "$WORKFLOW_FILE")
        FL_END=$(awk "BEGIN { printf \"%.3f\", $FL_TIME + $FL_DUR }")
        BRIGHT_EXPR="if(between(t,${FL_TIME},${FL_END}),0.5,${BRIGHT_EXPR})"
    done
    VFILTER_PARTS+=("eq=brightness='${BRIGHT_EXPR}'")
fi

# Text overlays (requires ffmpeg-full for drawtext filter)
if [ "$TEXT_COUNT" -gt 0 ] && [ "$DRAWTEXT_AVAILABLE" = "true" ]; then
    log_info "Building $TEXT_COUNT text overlay(s)..."
    FONT_PATH=""
    for candidate in \
        "/System/Library/Fonts/SFNSText.ttf" \
        "/System/Library/Fonts/SFNS.ttf" \
        "/System/Library/Fonts/Helvetica.ttc" \
        "/Library/Fonts/Arial.ttf" \
        "/System/Library/Fonts/Supplemental/Arial.ttf"; do
        if [ -f "$candidate" ]; then
            FONT_PATH="$candidate"
            break
        fi
    done

    if [ -z "$FONT_PATH" ]; then
        log_warn "No system font found - text overlays skipped"
    else
        log_info "Using font: $FONT_PATH"
        for (( i=0; i<TEXT_COUNT; i++ )); do
            OV_TEXT=$(yq e ".effects.text_overlays[$i].text"                  "$WORKFLOW_FILE")
            OV_START=$(yq e ".effects.text_overlays[$i].start"                "$WORKFLOW_FILE")
            OV_END=$(yq e ".effects.text_overlays[$i].end"                    "$WORKFLOW_FILE")
            OV_POS=$(yq e ".effects.text_overlays[$i].position // \"bottom\"" "$WORKFLOW_FILE")
            case "$OV_POS" in
                "top")    OV_Y="80" ;;
                "center") OV_Y="(h-text_h)/2" ;;
                *)        OV_Y="h-160" ;;
            esac
            OV_TEXT_SAFE=$(printf '%s' "$OV_TEXT" | sed "s/'/\\\\\\''/g")
            VFILTER_PARTS+=("drawtext=text='${OV_TEXT_SAFE}':fontfile='${FONT_PATH}':fontsize=52:fontcolor=white:x=(w-text_w)/2:y=${OV_Y}:enable='between(t,${OV_START},${OV_END})':shadowcolor=black@0.8:shadowx=2:shadowy=2")
        done
    fi
fi

# Apply combined video filter
if [ ${#VFILTER_PARTS[@]} -gt 0 ]; then
    VFILTER=$(printf '%s,' "${VFILTER_PARTS[@]}")
    VFILTER="${VFILTER%,}"

    advance_step
    log_info "Applying flash/text filters..."

    ffmpeg -y -i "$CURRENT_FILE" \
        -vf "$VFILTER" \
        -c:v libx264 -preset fast -crf 18 \
        "$STEP_OUT" 2>/dev/null

    CURRENT_FILE="$STEP_OUT"
    log_success "Flash/text filters applied"
fi

# ═════════════════════════════════════════
# STEP 3: Background Music
# ═════════════════════════════════════════
if [ "$HAS_MUSIC" = "true" ]; then
    if [ ! -f "$MUSIC_FILE" ]; then
        log_warn "Music file not found: $MUSIC_FILE"
        log_warn "Add a CC0 lo-fi MP3 at: $MUSIC_FILE"
        log_warn "Sources: https://pixabay.com  or  https://freemusicarchive.org"
    else
        log_info "Mixing background music at volume ${MUSIC_VOLUME}..."
        advance_step

        VID_DUR=$(ffprobe -v error -show_entries format=duration \
            -of default=noprint_wrappers=1:nokey=1 "$CURRENT_FILE" 2>/dev/null)
        FADE_START=$(awk "BEGIN { v=$VID_DUR - 2.0; print (v > 0) ? v : 0 }")

        if [ -n "$HAS_AUDIO" ]; then
            ffmpeg -y -i "$CURRENT_FILE" -i "$MUSIC_FILE" \
                -filter_complex \
                    "[1:a]volume=${MUSIC_VOLUME},afade=t=out:st=${FADE_START}:d=2[music];
                     [0:a][music]amix=inputs=2:duration=first[outa]" \
                -map 0:v -map "[outa]" \
                -c:v copy -c:a aac -b:a 128k \
                -shortest "$STEP_OUT" 2>/dev/null
        else
            ffmpeg -y -i "$CURRENT_FILE" -i "$MUSIC_FILE" \
                -filter_complex \
                    "[1:a]volume=${MUSIC_VOLUME},afade=t=out:st=${FADE_START}:d=2[outa]" \
                -map 0:v -map "[outa]" \
                -c:v copy -c:a aac -b:a 128k \
                -shortest "$STEP_OUT" 2>/dev/null
        fi

        CURRENT_FILE="$STEP_OUT"
        log_success "Music mixed in (fade-out at ${FADE_START}s)"
    fi
fi

# ═════════════════════════════════════════
# Finalize
# ═════════════════════════════════════════
if [ "$CURRENT_FILE" = "$INPUT_VIDEO" ]; then
    cp "$INPUT_VIDEO" "$OUTPUT_VIDEO"
else
    mv "$CURRENT_FILE" "$OUTPUT_VIDEO"
fi

cleanup_temps

FINAL_DURATION=$(ffprobe -v error -show_entries format=duration \
    -of default=noprint_wrappers=1:nokey=1 "$OUTPUT_VIDEO" 2>/dev/null | cut -d. -f1)
FINAL_SIZE=$(ls -lh "$OUTPUT_VIDEO" | awk '{print $5}')

log_success "Effects applied: $OUTPUT_VIDEO"
log_info   "  Duration: ${FINAL_DURATION}s | Size: ${FINAL_SIZE}"
