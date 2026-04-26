#!/usr/bin/env bash
# ==============================================================================
# TheLogger ProVideos — Recording Engine
# ==============================================================================
# Records iOS Simulator video driven by XCUITest demo scenarios.
# Handles simulator boot, app build, recording, and raw capture output.
#
# Usage: ./record.sh <workflow.yaml>
# Output: Raw .mov file in output/raw/
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
PROVIDEO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
RAW_OUTPUT="$PROVIDEO_ROOT/output/raw"

# ─── Colors ───────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; NC='\033[0m'; BOLD='\033[1m'

log()  { echo -e "${CYAN}[record]${NC} $1"; }
ok()   { echo -e "${GREEN}[  OK  ]${NC} $1"; }
warn() { echo -e "${YELLOW}[ WARN ]${NC} $1"; }
err()  { echo -e "${RED}[ERROR ]${NC} $1" >&2; }
step() { echo -e "\n${BOLD}${BLUE}━━━ $1 ━━━${NC}"; }

# ─── Dependency Check ─────────────────────────────────────────────────────────
check_deps() {
    local missing=()
    command -v yq        >/dev/null 2>&1 || missing+=(yq)
    command -v ffmpeg     >/dev/null 2>&1 || missing+=(ffmpeg)
    command -v xcrun      >/dev/null 2>&1 || missing+=(xcrun)
    command -v xcodebuild >/dev/null 2>&1 || missing+=(xcodebuild)

    if [[ ${#missing[@]} -gt 0 ]]; then
        err "Missing dependencies: ${missing[*]}"
        echo "  Install with: brew install ${missing[*]}"
        exit 1
    fi
}

# ─── Parse Workflow YAML ──────────────────────────────────────────────────────
parse_workflow() {
    local yaml="$1"
    [[ -f "$yaml" ]] || { err "Workflow file not found: $yaml"; exit 1; }

    WORKFLOW_NAME=$(yq -r '.name // "Untitled"' "$yaml")
    DEVICE=$(yq -r '.simulator.device // "iPhone 17 Pro"' "$yaml")
    APPEARANCE=$(yq -r '.simulator.appearance // "dark"' "$yaml")
    RECORDING_DURATION=$(yq -r '.recording.duration // 30' "$yaml")
    RECORDING_SETTLE=$(yq -r '.recording.settle_time // 2' "$yaml")
    OUTPUT_FILENAME=$(yq -r '.output.filename // "recording"' "$yaml")
    TEST_METHOD=$(yq -r '.recording.test_method // ""' "$yaml")

    # Auto-derive test method from filename if not explicit
    if [[ -z "$TEST_METHOD" || "$TEST_METHOD" == "null" ]]; then
        local base
        base=$(basename "$yaml" .yaml)
        # Convert kebab-case to PascalCase: "quick-logging" → "QuickLogging"
        TEST_METHOD="test$(echo "$base" | awk -F'-' '{for(i=1;i<=NF;i++){$i=toupper(substr($i,1,1)) substr($i,2)}} 1' OFS='')Demo"
    fi

    log "Workflow:    ${BOLD}$WORKFLOW_NAME${NC}"
    log "Device:      $DEVICE"
    log "Appearance:  $APPEARANCE"
    log "Test method: $TEST_METHOD"
    log "Output:      $OUTPUT_FILENAME"
}

# ─── Simulator Management ─────────────────────────────────────────────────────
get_simulator_udid() {
    local udid
    udid=$(xcrun simctl list devices available -j \
        | python3 -c "
import json, sys
data = json.load(sys.stdin)
# First pass: prefer already-booted device
for runtime, devices in data.get('devices', {}).items():
    for d in devices:
        if d['name'] == '$DEVICE' and d['state'] == 'Booted':
            print(d['udid']); sys.exit(0)
# Second pass: any matching device
for runtime, devices in data.get('devices', {}).items():
    for d in devices:
        if d['name'] == '$DEVICE':
            print(d['udid']); sys.exit(0)
print(''); sys.exit(1)
" 2>/dev/null) || true

    if [[ -z "$udid" ]]; then
        err "Simulator '$DEVICE' not found"
        log "Available devices:"
        xcrun simctl list devices available | grep -E "^\s" | head -20
        exit 1
    fi
    echo "$udid"
}

boot_simulator() {
    local udid="$1"
    local state
    state=$(xcrun simctl list devices -j | python3 -c "
import json, sys
data = json.load(sys.stdin)
for runtime, devices in data.get('devices', {}).items():
    for d in devices:
        if d['udid'] == '$udid':
            print(d['state']); sys.exit(0)
" 2>/dev/null)

    if [[ "$state" == "Booted" ]]; then
        ok "Simulator already booted"
    else
        log "Booting simulator..."
        xcrun simctl boot "$udid" 2>/dev/null || true
        # Wait for boot
        local waited=0
        while [[ $waited -lt 45 ]]; do
            state=$(xcrun simctl list devices -j | python3 -c "
import json, sys
data = json.load(sys.stdin)
for runtime, devices in data.get('devices', {}).items():
    for d in devices:
        if d['udid'] == '$udid':
            print(d['state']); sys.exit(0)
" 2>/dev/null)
            [[ "$state" == "Booted" ]] && break
            sleep 1
            waited=$(( waited + 1 ))
        done
        [[ "$state" == "Booted" ]] || { err "Simulator failed to boot after 45s"; exit 1; }
        ok "Simulator booted"
    fi

    # Open Simulator.app and bring to front
    open -a Simulator
    sleep 3  # Give Simulator.app time to fully render

    # Set appearance
    xcrun simctl ui "$udid" appearance "$APPEARANCE"
    ok "Appearance set to $APPEARANCE"
}

# ─── Build App ────────────────────────────────────────────────────────────────
build_app() {
    step "Building app & tests (pre-record)"
    local dest="platform=iOS Simulator,id=$SIM_UDID"

    # Build with explicit configuration
    xcodebuild build-for-testing \
        -project "$PROJECT_ROOT/TheLogger.xcodeproj" \
        -scheme TheLogger \
        -destination "$dest" \
        -configuration Debug \
        -quiet \
        2>&1 | tail -10

    local build_exit=${PIPESTATUS[0]}
    if [[ $build_exit -ne 0 ]]; then
        err "Build failed (exit code: $build_exit)"
        err "Try running: xcodebuild build-for-testing -project TheLogger.xcodeproj -scheme TheLogger -destination 'platform=iOS Simulator,id=$SIM_UDID'"
        exit 1
    fi

    ok "Build complete"
}

# ─── Record Video ─────────────────────────────────────────────────────────────
record_video() {
    local output_path="$RAW_OUTPUT/${OUTPUT_FILENAME}_raw.mov"
    local record_pid

    step "Recording simulator"

    # Remove stale recording if exists
    rm -f "$output_path"

    # Start recording in background
    xcrun simctl io "$SIM_UDID" recordVideo \
        --codec hevc \
        --force \
        "$output_path" &
    record_pid=$!

    # CRITICAL: Wait for recording to fully initialize before driving UI
    sleep 2
    ok "Recording started (PID: $record_pid)"

    # Run XCUITest to drive the UI
    log "Running test: $TEST_METHOD"
    local dest="platform=iOS Simulator,id=$SIM_UDID"
    local test_target="TheLoggerUITests"
    local test_class="DemoScenarios"
    local full_test="${test_target}/${test_class}/${TEST_METHOD}"

    log "Test path: $full_test"

    # Use a temp file for xcodebuild output so we can check the real exit code
    # (piping to tail always returns 0, masking failures)
    local test_log="$PROVIDEO_ROOT/output/raw/${OUTPUT_FILENAME}_test.log"

    set +e  # Temporarily disable errexit for test execution
    xcodebuild test-without-building \
        -project "$PROJECT_ROOT/TheLogger.xcodeproj" \
        -scheme TheLogger \
        -destination "$dest" \
        -only-testing:"$full_test" \
        -parallel-testing-enabled NO \
        -enableCodeCoverage NO \
        > "$test_log" 2>&1
    local test_exit=$?
    set -e

    if [[ $test_exit -eq 0 ]]; then
        ok "Test completed successfully"
        # Show last few lines for confirmation
        tail -5 "$test_log"
    else
        warn "Test failed or not found (exit code: $test_exit)"
        warn "Last 15 lines of test output:"
        tail -15 "$test_log"
        warn ""
        warn "Falling back to timer recording for ${RECORDING_DURATION}s..."
        warn "The video will show whatever is currently on the simulator screen."
        sleep "$RECORDING_DURATION"
    fi

    # Settle time — let animations complete
    log "Settling for ${RECORDING_SETTLE}s..."
    sleep "$RECORDING_SETTLE"

    # Stop recording gracefully
    kill -INT "$record_pid" 2>/dev/null || true
    wait "$record_pid" 2>/dev/null || true
    sleep 1

    if [[ -f "$output_path" ]]; then
        local size
        size=$(du -h "$output_path" | cut -f1)
        local duration
        duration=$(ffprobe -v quiet -show_entries format=duration -of csv=p=0 "$output_path" 2>/dev/null | cut -d. -f1)
        ok "Raw recording saved: $output_path ($size, ${duration}s)"

        # Also report if test log suggests issues
        if grep -q "Test Suite.*failed" "$test_log" 2>/dev/null; then
            warn "NOTE: Test log indicates test failures — video may not show expected interactions"
        fi

        echo "$output_path"
    else
        err "Recording file not created!"
        err "Check if simulator is running and visible"
        exit 1
    fi
}

# ─── Main ─────────────────────────────────────────────────────────────────────
main() {
    local workflow="${1:?Usage: $0 <workflow.yaml>}"

    step "TheLogger ProVideos — Recording Engine"
    check_deps
    parse_workflow "$workflow"

    mkdir -p "$RAW_OUTPUT"

    SIM_UDID=$(get_simulator_udid)
    log "Simulator UDID: $SIM_UDID"

    boot_simulator "$SIM_UDID"
    build_app
    record_video
}

main "$@"
