#!/usr/bin/env bash
# ==============================================================================
# TheLogger ProVideos — Master Producer
# ==============================================================================
# End-to-end video production: Record → Process → Output
#
# Usage:
#   ./produce.sh <workflow.yaml>           # Full pipeline (record + process)
#   ./produce.sh --process-only <workflow>  # Process existing raw recording
#   ./produce.sh --batch                    # Record & process ALL workflows
#   ./produce.sh --batch --process-only     # Process all existing raw recordings
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROVIDEO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# ─── Colors ───────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; MAGENTA='\033[0;35m'
NC='\033[0m'; BOLD='\033[1m'

banner() {
    echo ""
    echo -e "${BOLD}${BLUE}╔══════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}${BLUE}║     TheLogger ProVideos — Production Pipeline   ║${NC}"
    echo -e "${BOLD}${BLUE}╚══════════════════════════════════════════════════╝${NC}"
    echo ""
}

log()  { echo -e "${CYAN}[produce]${NC} $1"; }
ok()   { echo -e "${GREEN}[  DONE ]${NC} $1"; }
err()  { echo -e "${RED}[ ERROR ]${NC} $1" >&2; }

# ─── Single Workflow ──────────────────────────────────────────────────────────
produce_single() {
    local yaml="$1"
    local process_only="${2:-false}"
    local name
    name=$(yq -r '.name // "Unknown"' "$yaml")

    echo -e "\n${BOLD}${MAGENTA}▶ Producing: $name${NC}"
    echo -e "${MAGENTA}  Workflow:  $yaml${NC}\n"

    local start_time
    start_time=$(date +%s)

    # Step 1: Record (unless process-only)
    if [[ "$process_only" != "true" ]]; then
        log "Phase 1/2: Recording..."
        if bash "$SCRIPT_DIR/record.sh" "$yaml"; then
            ok "Recording complete"
        else
            err "Recording failed for: $yaml"
            return 1
        fi
    else
        log "Skipping recording (process-only mode)"
    fi

    # Step 2: Process
    log "Phase 2/2: Processing..."
    if bash "$SCRIPT_DIR/process.sh" "$yaml"; then
        ok "Processing complete"
    else
        err "Processing failed for: $yaml"
        return 1
    fi

    local elapsed=$(( $(date +%s) - start_time ))
    ok "Produced '$name' in ${elapsed}s"
}

# ─── Batch Mode ───────────────────────────────────────────────────────────────
produce_batch() {
    local process_only="${1:-false}"
    local workflows=("$PROVIDEO_ROOT"/workflows/*.yaml)
    local total=${#workflows[@]}
    local success=0 failed=0

    log "Batch producing $total workflows"
    echo ""

    for ((i=0; i<total; i++)); do
        local yaml="${workflows[$i]}"
        echo -e "${BOLD}[$(( i + 1 ))/$total]${NC}"

        if produce_single "$yaml" "$process_only"; then
            ((success++))
        else
            ((failed++))
        fi

        # Brief pause between recordings to let simulator settle
        [[ "$process_only" != "true" && $i -lt $((total - 1)) ]] && sleep 3
    done

    echo ""
    echo -e "${BOLD}━━━ Batch Summary ━━━${NC}"
    echo -e "  Total:   $total"
    echo -e "  ${GREEN}Success: $success${NC}"
    [[ $failed -gt 0 ]] && echo -e "  ${RED}Failed:  $failed${NC}"
    echo ""

    # Show all final outputs
    echo -e "${BOLD}Final videos:${NC}"
    ls -lh "$PROVIDEO_ROOT/output/final/"*.mp4 2>/dev/null || echo "  (none)"

    return $failed
}

# ─── Main ─────────────────────────────────────────────────────────────────────
main() {
    banner

    local mode="single"
    local process_only="false"
    local workflow=""

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --batch)
                mode="batch"
                shift
                ;;
            --process-only)
                process_only="true"
                shift
                ;;
            --help|-h)
                echo "Usage:"
                echo "  $0 <workflow.yaml>              Record + process a single workflow"
                echo "  $0 --process-only <workflow>     Process existing raw recording"
                echo "  $0 --batch                       Produce all workflows"
                echo "  $0 --batch --process-only        Process all existing recordings"
                exit 0
                ;;
            *)
                workflow="$1"
                shift
                ;;
        esac
    done

    if [[ "$mode" == "batch" ]]; then
        produce_batch "$process_only"
    else
        [[ -n "$workflow" ]] || { err "Usage: $0 <workflow.yaml>"; exit 1; }
        produce_single "$workflow" "$process_only"
    fi
}

main "$@"
