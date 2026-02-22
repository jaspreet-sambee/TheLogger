#!/bin/bash
#
# batch-record.sh
# Record multiple demo videos in one go
#
# Usage: ./batch-record.sh [workflow1] [workflow2] ...
# Or: ./batch-record.sh all  (records all workflows)
#

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WORKFLOWS_DIR="$(dirname "$SCRIPT_DIR")/workflows"
RECORD_SCRIPT="$SCRIPT_DIR/record-video.sh"

# Get list of workflows to record
if [ "$1" = "all" ]; then
    WORKFLOWS=($(ls "$WORKFLOWS_DIR"/*.yaml 2>/dev/null | xargs -n1 basename))
elif [ $# -eq 0 ]; then
    log_error "No workflows specified"
    echo "Usage: $0 <workflow1> <workflow2> ..."
    echo "   or: $0 all"
    echo ""
    echo "Available workflows:"
    ls "$WORKFLOWS_DIR"/*.yaml 2>/dev/null | xargs -n1 basename | sed 's/^/  - /'
    exit 1
else
    WORKFLOWS=("$@")
fi

log_info "Batch recording ${#WORKFLOWS[@]} workflows"
echo ""

# Track results
SUCCESSFUL=()
FAILED=()

# Record each workflow
for workflow in "${WORKFLOWS[@]}"; do
    # Remove .yaml extension if present
    workflow_name="${workflow%.yaml}"

    log_info "Recording workflow: $workflow_name"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    WORKFLOW_FILE="$WORKFLOWS_DIR/${workflow_name}.yaml"

    if [ ! -f "$WORKFLOW_FILE" ]; then
        log_warn "Workflow file not found: $WORKFLOW_FILE"
        FAILED+=("$workflow_name")
        continue
    fi

    # Record with timeout (in case it hangs)
    if timeout 300 bash "$RECORD_SCRIPT" "$WORKFLOW_FILE"; then
        log_success "✓ $workflow_name completed"
        SUCCESSFUL+=("$workflow_name")
    else
        log_error "✗ $workflow_name failed"
        FAILED+=("$workflow_name")
    fi

    echo ""

    # Brief pause between recordings
    sleep 3
done

# Summary
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Batch Recording Summary"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "  Successful: ${#SUCCESSFUL[@]}"
for workflow in "${SUCCESSFUL[@]}"; do
    echo "    ✓ $workflow"
done

if [ ${#FAILED[@]} -gt 0 ]; then
    echo ""
    echo "  Failed: ${#FAILED[@]}"
    for workflow in "${FAILED[@]}"; do
        echo "    ✗ $workflow"
    done
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if [ ${#FAILED[@]} -eq 0 ]; then
    log_success "All recordings completed successfully!"
    exit 0
else
    log_warn "Some recordings failed. Check logs above."
    exit 1
fi
