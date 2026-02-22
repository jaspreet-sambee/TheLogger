#!/bin/bash
#
# scheduled-posting.sh
# Queue videos for scheduled posting to Twitter
#
# Usage: ./scheduled-posting.sh <day>
# Where day is: monday, wednesday, friday, weekend
#

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BASE_DIR="$(dirname "$SCRIPT_DIR")"
OUTPUT_DIR="$BASE_DIR/output"
WORKFLOWS_DIR="$BASE_DIR/workflows"
POST_SCRIPT="$SCRIPT_DIR/post-to-twitter.sh"

DAY=${1:-$(date +%A | tr '[:upper:]' '[:lower:]')}

log_info "Scheduled posting for: $DAY"

# Define posting schedule
case $DAY in
    monday)
        VIDEO="template-workflow"
        MESSAGE="Start your week strong with workout templates 💪"
        ;;
    wednesday)
        VIDEO="quicklog-strip"
        MESSAGE="Mid-week motivation: Log sets faster than ever ⚡"
        ;;
    friday)
        VIDEO="pr-celebration"
        MESSAGE="Finish the week with a new PR! 🏆"
        ;;
    saturday|sunday|weekend)
        VIDEO="live-activity"
        MESSAGE="Weekend feature: Log sets from your lock screen 📱"
        ;;
    *)
        log_info "No scheduled post for $DAY"
        exit 0
        ;;
esac

VIDEO_FILE="$OUTPUT_DIR/${VIDEO}_twitter.mp4"
WORKFLOW_FILE="$WORKFLOWS_DIR/${VIDEO}.yaml"

# Check if video exists
if [ ! -f "$VIDEO_FILE" ]; then
    log_info "Video not found. Recording..."
    "$BASE_DIR/record-demo" "$VIDEO"
fi

# Post to Twitter
log_info "Posting: $MESSAGE"
"$POST_SCRIPT" "$VIDEO_FILE" "$WORKFLOW_FILE"

log_success "Scheduled post complete!"
