#!/usr/bin/env bash
# ==============================================================================
# TheLogger ProVideos — Post-Processing Engine
# ==============================================================================
# Applies professional cinematic effects to raw simulator recordings:
#   1. Trim (remove springboard / test teardown)
#   2. Scale to working resolution
#   3. Speed ramps (variable playback speed per segment)
#   4. Cinematic zoom moments (crop + scale with anchor points)
#   5. Ken Burns (slow drift zoom for polish)
#   6. Flash/pulse effects on key interactions
#   7. Text overlays (title cards, captions)
#   8. Vignette + color grade
#   9. Background music mixing
#  10. Device framing (premium iPhone bezel)
#  11. Background (gradient or solid color)
#  12. Final encode (Twitter-optimized + production master)
#
# Usage: ./process.sh <workflow.yaml> [input.mov]
# Output: Processed files in output/processed/ and output/final/
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROVIDEO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
RAW_DIR="$PROVIDEO_ROOT/output/raw"
PROC_DIR="$PROVIDEO_ROOT/output/processed"
FINAL_DIR="$PROVIDEO_ROOT/output/final"
ASSETS_DIR="$PROVIDEO_ROOT/assets"

# ─── Colors ───────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; MAGENTA='\033[0;35m'
NC='\033[0m'; BOLD='\033[1m'

log()  { echo -e "${CYAN}[process]${NC} $1"; }
ok()   { echo -e "${GREEN}[   OK  ]${NC} $1"; }
warn() { echo -e "${YELLOW}[  WARN ]${NC} $1"; }
err()  { echo -e "${RED}[ ERROR ]${NC} $1" >&2; }
step() { echo -e "\n${BOLD}${MAGENTA}━━━ $1 ━━━${NC}"; }

# ─── Globals ──────────────────────────────────────────────────────────────────
CURRENT_FILE=""
STEP_NUM=0
WORK_W=0
WORK_H=0
WORK_FPS=30

# ─── Parse Workflow ───────────────────────────────────────────────────────────
parse_workflow() {
    local yaml="$1"
    [[ -f "$yaml" ]] || { err "Workflow not found: $yaml"; exit 1; }

    OUTPUT_FILENAME=$(yq -r '.output.filename // "video"' "$yaml")
    BG_COLOR=$(yq -r '.output.background_color // "#0A0D1E"' "$yaml")
    INCLUDE_FRAME=$(yq -r '.output.include_device_frame // true' "$yaml")
    TWITTER_OPT=$(yq -r '.output.twitter_optimized // true' "$yaml")

    # Trim
    TRIM_START=$(yq -r '.effects.trim_start // 0' "$yaml")
    TRIM_END=$(yq -r '.effects.trim_end // 0' "$yaml")

    # Music
    MUSIC_ENABLED=$(yq -r '.effects.music // false' "$yaml")
    MUSIC_VOLUME=$(yq -r '.effects.music_volume // 0.2' "$yaml")
    MUSIC_FILE=$(yq -r '.effects.music_file // ""' "$yaml")

    # Ken Burns (slow drift zoom)
    KB_ENABLED=$(yq -r '.effects.ken_burns.enabled // false' "$yaml")
    KB_SCALE_START=$(yq -r '.effects.ken_burns.scale_start // 1.0' "$yaml")
    KB_SCALE_END=$(yq -r '.effects.ken_burns.scale_end // 1.05' "$yaml")

    # Vignette
    VIGNETTE_ENABLED=$(yq -r '.effects.vignette // false' "$yaml")

    # Color grade
    COLOR_GRADE=$(yq -r '.effects.color_grade // "none"' "$yaml")

    log "Processing: ${BOLD}$OUTPUT_FILENAME${NC}"
}

# ─── Utility Functions ────────────────────────────────────────────────────────
next_step() {
    STEP_NUM=$(( STEP_NUM + 1 ))
    NEXT_STEP_OUT="$PROC_DIR/${OUTPUT_FILENAME}_fx_step${STEP_NUM}.mp4"
}

get_duration() {
    ffprobe -v quiet -show_entries format=duration -of csv=p=0 "$1" 2>/dev/null
}

has_audio() {
    local count
    count=$(ffprobe -v quiet -select_streams a -show_entries stream=codec_type -of csv=p=0 "$1" 2>/dev/null | wc -l)
    [[ $count -gt 0 ]]
}

ensure_even() {
    local val=$1
    # Handle both integer and float inputs
    val=$(python3 -c "print(int($val))")
    echo $(( val - (val % 2) ))
}

# Float comparison using python3 (bc may not be available on macOS)
float_gt() {
    python3 -c "import sys; sys.exit(0 if $1 > $2 else 1)"
}

float_lt() {
    python3 -c "import sys; sys.exit(0 if $1 < $2 else 1)"
}

# ─── Step 1: Trim + Scale ────────────────────────────────────────────────────
apply_trim_and_scale() {
    local input="$1"

    if [[ "$TRIM_START" == "0" && "$TRIM_END" == "0" ]]; then
        # No trim needed, but still detect resolution
        local info
        info=$(ffprobe -v quiet -select_streams v:0 \
            -show_entries stream=width,height,r_frame_rate \
            -of csv=p=0 "$input")
        WORK_W=$(echo "$info" | cut -d, -f1)
        WORK_H=$(echo "$info" | cut -d, -f2)

        # Scale down Retina if needed
        if [[ $WORK_H -gt 1400 ]]; then
            step "Scaling from ${WORK_W}x${WORK_H} to working resolution"
            WORK_H=1280
            WORK_W=$(ensure_even $(python3 -c "print(int(1280 * $WORK_W / $(echo "$info" | cut -d, -f2)))"))
            WORK_H=$(ensure_even $WORK_H)

            local out
            next_step; out="$NEXT_STEP_OUT"
            ffmpeg -y -i "$input" \
                -vf "scale=${WORK_W}:${WORK_H}:flags=lanczos,fps=${WORK_FPS}" \
                -c:v libx264 -preset fast -crf 16 -pix_fmt yuv420p \
                -an "$out" 2>/dev/null
            CURRENT_FILE="$out"
            ok "Scaled to ${WORK_W}x${WORK_H}"
        else
            CURRENT_FILE="$input"
        fi
        return
    fi

    step "Trimming: start=${TRIM_START}s, end=${TRIM_END}s"

    local duration
    duration=$(get_duration "$input")
    local end_time
    end_time=$(python3 -c "print(max(0, $duration - $TRIM_END))")

    local info
    info=$(ffprobe -v quiet -select_streams v:0 \
        -show_entries stream=width,height \
        -of csv=p=0 "$input")
    local src_w src_h
    src_w=$(echo "$info" | cut -d, -f1)
    src_h=$(echo "$info" | cut -d, -f2)

    # Target working resolution
    if [[ $src_h -gt 1400 ]]; then
        WORK_H=1280
        WORK_W=$(ensure_even $(python3 -c "print(int(1280 * $src_w / $src_h))"))
    else
        WORK_W=$src_w
        WORK_H=$src_h
    fi
    WORK_W=$(ensure_even $WORK_W)
    WORK_H=$(ensure_even $WORK_H)

    local out
    next_step; out="$NEXT_STEP_OUT"
    ffmpeg -y -ss "$TRIM_START" -to "$end_time" -i "$input" \
        -vf "scale=${WORK_W}:${WORK_H}:flags=lanczos,fps=${WORK_FPS}" \
        -c:v libx264 -preset fast -crf 16 -pix_fmt yuv420p \
        -an "$out" 2>/dev/null

    CURRENT_FILE="$out"
    local new_dur
    new_dur=$(get_duration "$out")
    ok "Trimmed & scaled: ${WORK_W}x${WORK_H}, ${new_dur}s"
}

# ─── Step 2: Speed Ramps ─────────────────────────────────────────────────────
apply_speed_ramps() {
    local yaml="$1"
    local ramp_count
    ramp_count=$(yq -r '.effects.speed_ramps | length // 0' "$yaml" 2>/dev/null)

    if [[ "$ramp_count" == "0" || "$ramp_count" == "null" ]]; then
        # Check single speed_ramp (backward compat)
        local single_start
        single_start=$(yq -r '.effects.speed_ramp.start // ""' "$yaml")
        if [[ -z "$single_start" || "$single_start" == "null" ]]; then
            return
        fi
        ramp_count=1
    fi

    step "Applying speed ramps ($ramp_count segments)"

    local input="$CURRENT_FILE"
    local out
    next_step; out="$NEXT_STEP_OUT"

    # Build complex filtergraph for speed ramps
    # For simplicity with multiple ramps, process sequentially
    local current="$input"

    if [[ "$ramp_count" == "1" ]]; then
        local rs re speed
        rs=$(yq -r '.effects.speed_ramp.start // .effects.speed_ramps[0].start' "$yaml")
        re=$(yq -r '.effects.speed_ramp.end // .effects.speed_ramps[0].end' "$yaml")
        speed=$(yq -r '.effects.speed_ramp.speed // .effects.speed_ramps[0].speed' "$yaml")

        local duration
        duration=$(get_duration "$current")

        # Three segments: before | ramped | after
        local tmp_dir="$PROC_DIR/tmp_ramp_$$"
        mkdir -p "$tmp_dir"

        # Segment 1: before ramp (normal speed)
        if float_gt "$rs" 0.1; then
            ffmpeg -y -ss 0 -to "$rs" -i "$current" \
                -c:v libx264 -preset fast -crf 16 -pix_fmt yuv420p -an \
                "$tmp_dir/seg1.mp4" 2>/dev/null
        fi

        # Segment 2: ramp zone (sped up)
        ffmpeg -y -ss "$rs" -to "$re" -i "$current" \
            -vf "setpts=PTS/${speed}" \
            -c:v libx264 -preset fast -crf 16 -pix_fmt yuv420p -an \
            "$tmp_dir/seg2.mp4" 2>/dev/null

        # Segment 3: after ramp (normal speed)
        if float_lt "$re" "$(python3 -c "print($duration - 0.5)")"; then
            ffmpeg -y -ss "$re" -i "$current" \
                -c:v libx264 -preset fast -crf 16 -pix_fmt yuv420p -an \
                "$tmp_dir/seg3.mp4" 2>/dev/null
        fi

        # Concat segments
        local concat_list="$tmp_dir/concat.txt"
        : > "$concat_list"
        for seg in "$tmp_dir"/seg*.mp4; do
            [[ -f "$seg" ]] && echo "file '$seg'" >> "$concat_list"
        done

        ffmpeg -y -f concat -safe 0 -i "$concat_list" \
            -c:v libx264 -preset fast -crf 16 -pix_fmt yuv420p \
            -vf "fps=${WORK_FPS}" -an \
            "$out" 2>/dev/null

        rm -rf "$tmp_dir"
    fi

    CURRENT_FILE="$out"
    local new_dur
    new_dur=$(get_duration "$out")
    ok "Speed ramp applied (new duration: ${new_dur}s)"
}

# ─── Step 3: Cinematic Zoom Moments ──────────────────────────────────────────
apply_zoom_moments() {
    local yaml="$1"
    local zoom_count
    zoom_count=$(yq -r '.effects.zoom_moments | length // 0' "$yaml" 2>/dev/null)

    [[ "$zoom_count" == "0" || "$zoom_count" == "null" ]] && return 0

    step "Applying $zoom_count cinematic zoom moments"

    local input="$CURRENT_FILE"
    local duration
    duration=$(get_duration "$input")

    # Build a complex zoompan-style filtergraph using crop+scale segments
    local tmp_dir="$PROC_DIR/tmp_zoom_$$"
    mkdir -p "$tmp_dir"

    # Collect all zoom events and sort by time
    local events=()
    for ((i=0; i<zoom_count; i++)); do
        local t s d anchor
        t=$(yq -r ".effects.zoom_moments[$i].time" "$yaml")
        s=$(yq -r ".effects.zoom_moments[$i].scale // 1.2" "$yaml")
        d=$(yq -r ".effects.zoom_moments[$i].duration // 1.5" "$yaml")
        anchor=$(yq -r ".effects.zoom_moments[$i].anchor // \"center\"" "$yaml")

        # Ease in/out duration (smooth transition)
        local ease
        ease=$(yq -r ".effects.zoom_moments[$i].ease // 0.3" "$yaml")

        events+=("$t|$s|$d|$anchor|$ease")
        log "  Zoom $((i+1)): t=${t}s, scale=${s}x, dur=${d}s, anchor=$anchor"
    done

    # Sort events by time
    IFS=$'\n' sorted=($(sort -t'|' -k1 -n <<<"${events[*]}")); unset IFS

    # Build segments: normal → zoom → normal → zoom → ...
    local seg_idx=0
    local cursor=0
    local concat_list="$tmp_dir/concat.txt"
    : > "$concat_list"

    for event in "${sorted[@]}"; do
        IFS='|' read -r t s d anchor ease <<< "$event"

        local zoom_start zoom_end
        zoom_start="$t"
        zoom_end=$(python3 -c "print($t + $d)")

        # Normal segment before this zoom
        if float_lt "$cursor" "$(python3 -c "print($zoom_start - 0.05)")"; then
            local seg="$tmp_dir/seg_${seg_idx}.mp4"
            ffmpeg -y -ss "$cursor" -to "$zoom_start" -i "$input" \
                -c:v libx264 -preset fast -crf 16 -pix_fmt yuv420p -an \
                "$seg" 2>/dev/null
            echo "file '$seg'" >> "$concat_list"
            seg_idx=$(( seg_idx + 1 ))
        fi

        # Zoom segment: crop + scale
        local seg="$tmp_dir/seg_${seg_idx}.mp4"
        local cw ch cx cy

        if python3 -c "import sys; sys.exit(0 if $s >= 1.0 else 1)"; then
            # Zoom IN: crop smaller region, upscale
            cw=$(ensure_even $(python3 -c "print(int($WORK_W / $s))"))
            ch=$(ensure_even $(python3 -c "print(int($WORK_H / $s))"))

            case "$anchor" in
                center)
                    cx=$(( (WORK_W - cw) / 2 ))
                    cy=$(( (WORK_H - ch) / 2 ))
                    ;;
                bottom|bottom_center)
                    cx=$(( (WORK_W - cw) / 2 ))
                    cy=$(( WORK_H - ch ))
                    ;;
                top)
                    cx=$(( (WORK_W - cw) / 2 ))
                    cy=0
                    ;;
                right)
                    cx=$(( WORK_W - cw ))
                    cy=$(( (WORK_H - ch) / 2 ))
                    ;;
                *)
                    cx=$(( (WORK_W - cw) / 2 ))
                    cy=$(( (WORK_H - ch) / 2 ))
                    ;;
            esac

            ffmpeg -y -ss "$zoom_start" -to "$zoom_end" -i "$input" \
                -vf "crop=${cw}:${ch}:${cx}:${cy},scale=${WORK_W}:${WORK_H}:flags=lanczos" \
                -c:v libx264 -preset fast -crf 16 -pix_fmt yuv420p -an \
                "$seg" 2>/dev/null
        else
            # Zoom OUT: shrink + pad
            local sw sh
            sw=$(ensure_even $(python3 -c "print(int($WORK_W * $s))"))
            sh=$(ensure_even $(python3 -c "print(int($WORK_H * $s))"))

            ffmpeg -y -ss "$zoom_start" -to "$zoom_end" -i "$input" \
                -vf "scale=${sw}:${sh}:flags=lanczos,pad=${WORK_W}:${WORK_H}:(ow-iw)/2:(oh-ih)/2:black" \
                -c:v libx264 -preset fast -crf 16 -pix_fmt yuv420p -an \
                "$seg" 2>/dev/null
        fi

        echo "file '$seg'" >> "$concat_list"
        seg_idx=$(( seg_idx + 1 ))
        cursor="$zoom_end"
    done

    # Final normal segment after last zoom
    if float_lt "$cursor" "$(python3 -c "print($duration - 0.1)")"; then
        local seg="$tmp_dir/seg_${seg_idx}.mp4"
        ffmpeg -y -ss "$cursor" -i "$input" \
            -c:v libx264 -preset fast -crf 16 -pix_fmt yuv420p -an \
            "$seg" 2>/dev/null
        echo "file '$seg'" >> "$concat_list"
    fi

    # Concat all segments
    local out
    next_step; out="$NEXT_STEP_OUT"
    ffmpeg -y -f concat -safe 0 -i "$concat_list" \
        -c:v libx264 -preset fast -crf 16 -pix_fmt yuv420p \
        -vf "fps=${WORK_FPS}" -an \
        "$out" 2>/dev/null

    rm -rf "$tmp_dir"
    CURRENT_FILE="$out"
    ok "Zoom moments applied"
}

# ─── Step 4: Ken Burns (Slow Drift Zoom) ─────────────────────────────────────
apply_ken_burns() {
    [[ "$KB_ENABLED" == "true" ]] || return 0

    step "Applying Ken Burns drift zoom (${KB_SCALE_START}x → ${KB_SCALE_END}x)"

    local input="$CURRENT_FILE"
    local out
    next_step; out="$NEXT_STEP_OUT"
    local duration
    duration=$(get_duration "$input")
    local total_frames
    total_frames=$(python3 -c "print(int($duration * $WORK_FPS))")

    # Use zoompan for smooth continuous zoom
    # zoompan requires knowing the zoom range
    local zstart zend
    zstart=$(python3 -c "print(int($KB_SCALE_START * 100))")
    zend=$(python3 -c "print(int($KB_SCALE_END * 100))")

    ffmpeg -y -i "$input" \
        -vf "zoompan=z='${KB_SCALE_START}+(${KB_SCALE_END}-${KB_SCALE_START})*on/${total_frames}':x='iw/2-(iw/zoom/2)':y='ih/2-(ih/zoom/2)':d=1:s=${WORK_W}x${WORK_H}:fps=${WORK_FPS}" \
        -c:v libx264 -preset fast -crf 16 -pix_fmt yuv420p -an \
        "$out" 2>/dev/null

    CURRENT_FILE="$out"
    ok "Ken Burns drift applied"
}

# ─── Step 5: Flash + Text + Vignette (Combined Filter) ───────────────────────
apply_visual_effects() {
    local yaml="$1"

    # Collect all filter components
    local filters=()

    # Flash moments
    local flash_count
    flash_count=$(yq -r '.effects.flash_moments | length // 0' "$yaml" 2>/dev/null)
    if [[ "$flash_count" != "0" && "$flash_count" != "null" ]]; then
        local flash_expr=""
        for ((i=0; i<flash_count; i++)); do
            local ft fd
            ft=$(yq -r ".effects.flash_moments[$i].time" "$yaml")
            fd=$(yq -r ".effects.flash_moments[$i].duration // 0.1" "$yaml")
            local fe
            fe=$(python3 -c "print($ft + $fd)")

            if [[ -n "$flash_expr" ]]; then
                flash_expr="${flash_expr}+if(between(t\\,${ft}\\,${fe})\\,0.4\\,0)"
            else
                flash_expr="if(between(t\\,${ft}\\,${fe})\\,0.4\\,0)"
            fi
        done
        filters+=("eq=brightness=${flash_expr}")
        log "  Flash effects: $flash_count moments"
    fi

    # Vignette
    if [[ "$VIGNETTE_ENABLED" == "true" ]]; then
        filters+=("vignette=PI/5")
        log "  Vignette: enabled"
    fi

    # Color grade
    case "$COLOR_GRADE" in
        warm)
            filters+=("colorbalance=rs=0.05:gs=-0.02:bs=-0.05:rm=0.03:gm=0:bm=-0.03")
            log "  Color grade: warm"
            ;;
        cool)
            filters+=("colorbalance=rs=-0.03:gs=0:bs=0.05:rm=-0.02:gm=0.01:bm=0.03")
            log "  Color grade: cool"
            ;;
        cinematic)
            filters+=("curves=preset=cross_process" "eq=contrast=1.05:saturation=0.9")
            log "  Color grade: cinematic"
            ;;
        *)
            ;;
    esac

    # Text overlays
    local text_count
    text_count=$(yq -r '.effects.text_overlays | length // 0' "$yaml" 2>/dev/null)
    local has_drawtext=false
    ffmpeg -filters 2>/dev/null | grep -q drawtext && has_drawtext=true
    if [[ "$text_count" != "0" && "$text_count" != "null" && "$has_drawtext" == "true" ]]; then
        # Find a suitable font
        local font=""
        for f in "/System/Library/Fonts/SFNS.ttf" \
                 "/System/Library/Fonts/SFNSText.ttf" \
                 "/System/Library/Fonts/Helvetica.ttc" \
                 "/Library/Fonts/Arial.ttf"; do
            [[ -f "$f" ]] && { font="$f"; break; }
        done

        for ((i=0; i<text_count; i++)); do
            local txt ts te pos fontsize shadow_alpha
            txt=$(yq -r ".effects.text_overlays[$i].text" "$yaml")
            ts=$(yq -r ".effects.text_overlays[$i].start" "$yaml")
            te=$(yq -r ".effects.text_overlays[$i].end" "$yaml")
            pos=$(yq -r ".effects.text_overlays[$i].position // \"bottom\"" "$yaml")
            fontsize=$(yq -r ".effects.text_overlays[$i].fontsize // 48" "$yaml")
            shadow_alpha=$(yq -r ".effects.text_overlays[$i].shadow_alpha // 0.7" "$yaml")

            # Escape text for ffmpeg
            txt=$(echo "$txt" | sed "s/'/'\\\\''/g" | sed 's/:/\\:/g')

            local y_expr
            case "$pos" in
                top)    y_expr="y=80" ;;
                center) y_expr="y=(h-text_h)/2" ;;
                bottom) y_expr="y=h-160" ;;
                *)      y_expr="y=h-160" ;;
            esac

            local dt_filter="drawtext=text='${txt}':fontfile=${font}:fontsize=${fontsize}:fontcolor=white:${y_expr}:x=(w-text_w)/2:shadowcolor=black@${shadow_alpha}:shadowx=2:shadowy=2:enable='between(t,${ts},${te})'"
            filters+=("$dt_filter")
            log "  Text: \"$(echo "$txt" | head -c 30)...\" at ${ts}s-${te}s ($pos)"
        done
    elif [[ "$text_count" != "0" && "$text_count" != "null" && "$has_drawtext" != "true" ]]; then
        warn "Text overlays skipped — ffmpeg missing drawtext filter (install with: brew install ffmpeg --with-freetype)"
    fi

    # Apply all visual filters if any
    if [[ ${#filters[@]} -eq 0 ]]; then
        return
    fi

    step "Applying visual effects (${#filters[@]} filters)"

    local input="$CURRENT_FILE"
    local out
    next_step; out="$NEXT_STEP_OUT"

    local filter_chain
    filter_chain=$(IFS=','; echo "${filters[*]}")

    ffmpeg -y -i "$input" \
        -vf "$filter_chain" \
        -c:v libx264 -preset fast -crf 16 -pix_fmt yuv420p -an \
        "$out" 2>/dev/null

    CURRENT_FILE="$out"
    ok "Visual effects applied"
}

# ─── Step 6: Background Music ────────────────────────────────────────────────
apply_music() {
    [[ "$MUSIC_ENABLED" == "true" ]] || return 0

    # Find music file
    local music=""
    if [[ -n "$MUSIC_FILE" && "$MUSIC_FILE" != "null" && -f "$ASSETS_DIR/music/$MUSIC_FILE" ]]; then
        music="$ASSETS_DIR/music/$MUSIC_FILE"
    else
        # Find first available music file
        for ext in mp3 m4a wav; do
            local f
            f=$(find "$ASSETS_DIR/music" -name "*.$ext" -type f 2>/dev/null | head -1)
            [[ -n "$f" ]] && { music="$f"; break; }
        done
    fi

    if [[ -z "$music" ]]; then
        warn "No music file found in $ASSETS_DIR/music/"
        return
    fi

    step "Mixing background music (vol: ${MUSIC_VOLUME})"

    local input="$CURRENT_FILE"
    local out
    next_step; out="$NEXT_STEP_OUT"
    local duration
    duration=$(get_duration "$input")
    local fade_start
    fade_start=$(python3 -c "print(max(0, $duration - 2.0))")

    if has_audio "$input"; then
        # Mix with existing audio
        ffmpeg -y -i "$input" -i "$music" \
            -filter_complex "[1:a]volume=${MUSIC_VOLUME},afade=t=out:st=${fade_start}:d=2[music];[0:a][music]amix=inputs=2:duration=first[out]" \
            -map 0:v -map "[out]" \
            -c:v copy -c:a aac -b:a 192k \
            "$out" 2>/dev/null
    else
        # Add music as sole audio
        ffmpeg -y -i "$input" -i "$music" \
            -filter_complex "[1:a]volume=${MUSIC_VOLUME},afade=t=out:st=${fade_start}:d=2[music]" \
            -map 0:v -map "[music]" \
            -c:v copy -c:a aac -b:a 192k \
            -shortest \
            "$out" 2>/dev/null
    fi

    CURRENT_FILE="$out"
    ok "Music mixed: $(basename "$music")"
}

# ─── Step 7: Device Frame + Background ───────────────────────────────────────
apply_device_frame() {
    [[ "$INCLUDE_FRAME" == "true" ]] || return 0

    step "Applying premium device frame"

    local input="$CURRENT_FILE"
    local out
    next_step; out="$NEXT_STEP_OUT"

    # ── Canvas & Phone Geometry ──
    # Twitter-optimized portrait canvas
    local CANVAS_W=720 CANVAS_H=1280

    # Phone dimensions (premium sizing — larger phone, less wasted space)
    local PHONE_W=480 PHONE_H=1040  # ~67% of canvas width

    # Bezel dimensions (thinner = more premium)
    local BEZEL_SIDE=10 BEZEL_TOP=36 BEZEL_BOTTOM=22
    local BEZEL_W=$((PHONE_W + 2 * BEZEL_SIDE))
    local BEZEL_H=$((PHONE_H + BEZEL_TOP + BEZEL_BOTTOM))

    # Center the bezel on canvas
    local BX=$(( (CANVAS_W - BEZEL_W) / 2 ))
    local BY=$(( (CANVAS_H - BEZEL_H) / 2 ))

    # Phone content position (inside bezel)
    local PX=$((BX + BEZEL_SIDE))
    local PY=$((BY + BEZEL_TOP))

    # Camera pill (Dynamic Island)
    local PILL_W=80 PILL_H=20
    local PILL_X=$(( BX + (BEZEL_W - PILL_W) / 2 ))
    local PILL_Y=$(( BY + 8 ))

    # Home indicator
    local HOME_W=110 HOME_H=4
    local HOME_X=$(( BX + (BEZEL_W - HOME_W) / 2 ))
    local HOME_Y=$(( BY + BEZEL_H - BEZEL_BOTTOM + 8 ))

    # Convert hex color: #RRGGBB → 0xRRGGBB
    local bg_hex="${BG_COLOR//#/0x}"

    # Build the ffmpeg filtergraph
    local has_audio_flag=""
    has_audio "$input" && has_audio_flag="yes"

    local audio_map=""
    local audio_codec=""
    if [[ "$has_audio_flag" == "yes" ]]; then
        audio_map="-map [out]:v -map 0:a"
        audio_codec="-c:a copy"
    else
        audio_map="-map [out]:v"
        audio_codec="-an"
    fi

    # Premium bezel color (near-black with slight blue tint)
    local BEZEL_COLOR="0x1C1C2E"
    local CORNER_R=24

    ffmpeg -y -i "$input" \
        -filter_complex "
            color=c=${bg_hex}:s=${CANVAS_W}x${CANVAS_H}:r=${WORK_FPS}[bg];
            color=c=${BEZEL_COLOR}:s=${BEZEL_W}x${BEZEL_H}:r=${WORK_FPS}[bezel_base];
            [bezel_base]drawbox=x=0:y=0:w=${BEZEL_W}:h=${BEZEL_H}:c=${BEZEL_COLOR}:t=fill[bezel];
            [bezel]drawbox=x=$(( (BEZEL_W - PILL_W) / 2 )):y=8:w=${PILL_W}:h=${PILL_H}:c=0x000000:t=fill[bezel_pill];
            [0:v]scale=${PHONE_W}:${PHONE_H}:flags=lanczos:force_original_aspect_ratio=disable[phone];
            [bg][bezel_pill]overlay=x=${BX}:y=${BY}:shortest=1[bg_bezel];
            [bg_bezel][phone]overlay=x=${PX}:y=${PY}:shortest=1[framed];
            [framed]drawbox=x=${HOME_X}:y=${HOME_Y}:w=${HOME_W}:h=${HOME_H}:c=0xffffff@0.35:t=fill[out]
        " \
        $audio_map \
        -c:v libx264 -preset slow -crf 16 -pix_fmt yuv420p \
        $audio_codec \
        -shortest \
        "$out" 2>/dev/null

    CURRENT_FILE="$out"
    ok "Device frame applied (${CANVAS_W}x${CANVAS_H})"
}

# ─── Step 8: Final Encode ────────────────────────────────────────────────────
final_encode() {
    step "Final encoding"

    local input="$CURRENT_FILE"

    # Twitter-optimized version
    if [[ "$TWITTER_OPT" == "true" ]]; then
        local twitter_out="$FINAL_DIR/${OUTPUT_FILENAME}_twitter.mp4"
        log "Encoding Twitter version (720x1280, CRF 18)..."

        local audio_opts="-an"
        has_audio "$input" && audio_opts="-c:a aac -b:a 128k"

        ffmpeg -y -i "$input" \
            -vf "scale=720:1280:force_original_aspect_ratio=decrease,pad=720:1280:(ow-iw)/2:(oh-ih)/2:black" \
            -c:v libx264 -preset slow -crf 18 -pix_fmt yuv420p \
            -movflags +faststart \
            $audio_opts \
            "$twitter_out" 2>/dev/null

        local size
        size=$(du -h "$twitter_out" | cut -f1)
        ok "Twitter: $twitter_out ($size)"
    fi

    # Production master
    local prod_out="$FINAL_DIR/${OUTPUT_FILENAME}_production.mp4"
    log "Encoding production master (CRF 14)..."

    local audio_opts="-an"
    has_audio "$input" && audio_opts="-c:a aac -b:a 256k"

    ffmpeg -y -i "$input" \
        -c:v libx264 -preset slower -crf 14 -pix_fmt yuv420p \
        -movflags +faststart \
        $audio_opts \
        "$prod_out" 2>/dev/null

    local size
    size=$(du -h "$prod_out" | cut -f1)
    ok "Production: $prod_out ($size)"

    CURRENT_FILE="$prod_out"
}

# ─── Cleanup ──────────────────────────────────────────────────────────────────
cleanup_temp() {
    log "Cleaning temporary files..."
    rm -f "$PROC_DIR"/${OUTPUT_FILENAME}_fx_step*.mp4
    ok "Cleaned up"
}

# ─── Main ─────────────────────────────────────────────────────────────────────
main() {
    local yaml="${1:?Usage: $0 <workflow.yaml> [input.mov]}"
    local input="${2:-}"

    step "TheLogger ProVideos — Post-Processing Engine"

    parse_workflow "$yaml"
    mkdir -p "$PROC_DIR" "$FINAL_DIR"

    # Find input file
    if [[ -z "$input" ]]; then
        input="$RAW_DIR/${OUTPUT_FILENAME}_raw.mov"
    fi
    [[ -f "$input" ]] || { err "Input not found: $input"; exit 1; }

    log "Input: $input"
    local orig_dur
    orig_dur=$(get_duration "$input")
    log "Duration: ${orig_dur}s"

    # Processing pipeline
    apply_trim_and_scale "$input"
    apply_speed_ramps "$yaml"
    apply_zoom_moments "$yaml"
    apply_ken_burns
    apply_visual_effects "$yaml"
    apply_music
    apply_device_frame
    final_encode
    cleanup_temp

    echo ""
    echo -e "${BOLD}${GREEN}━━━ Processing Complete ━━━${NC}"
    echo -e "  Final files in: ${BOLD}$FINAL_DIR/${NC}"
    ls -lh "$FINAL_DIR"/${OUTPUT_FILENAME}*.mp4 2>/dev/null
}

main "$@"
