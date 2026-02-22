#!/bin/bash
#
# post-to-twitter.sh
# Automatically post videos to X/Twitter using the Twitter API
#
# Requirements:
# - Twitter API credentials (get from https://developer.twitter.com)
# - twurl (Twitter CLI): gem install twurl
#
# Setup:
# 1. Get API keys from https://developer.twitter.com/en/portal/dashboard
# 2. Run: twurl authorize --consumer-key YOUR_KEY --consumer-secret YOUR_SECRET
# 3. Set environment variables or use .env file
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

# Check for required tools
if ! command -v twurl &> /dev/null; then
    log_error "twurl not found. Install with: gem install twurl"
    exit 1
fi

if ! command -v jq &> /dev/null; then
    log_error "jq not found. Install with: brew install jq"
    exit 1
fi

if ! command -v yq &> /dev/null; then
    log_error "yq not found. Install with: brew install yq"
    exit 1
fi

# Configuration
VIDEO_FILE=$1
WORKFLOW_FILE=$2

if [ -z "$VIDEO_FILE" ] || [ ! -f "$VIDEO_FILE" ]; then
    log_error "Video file not found: $VIDEO_FILE"
    echo "Usage: $0 <video_file.mp4> <workflow.yaml>"
    exit 1
fi

if [ -z "$WORKFLOW_FILE" ] || [ ! -f "$WORKFLOW_FILE" ]; then
    log_warn "Workflow file not provided, using defaults"
    CAPTION="Check out TheLogger - the fastest workout tracking app for iOS!"
    HASHTAGS=""
else
    # Parse workflow for caption and hashtags
    CAPTION=$(yq -r '.output.caption // "TheLogger - Fast workout tracking for iOS"' "$WORKFLOW_FILE")
    HASHTAGS_ARRAY=$(yq -r '.output.hashtags[]? // empty' "$WORKFLOW_FILE" | tr '\n' ' ')

    # Format hashtags
    if [ -n "$HASHTAGS_ARRAY" ]; then
        HASHTAGS=$(echo "$HASHTAGS_ARRAY" | sed 's/ / #/g' | sed 's/^/#/')
    fi
fi

# Construct tweet text
TWEET_TEXT="${CAPTION}

${HASHTAGS}"

log_info "Preparing to post to Twitter..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Video: $VIDEO_FILE"
echo "Tweet:"
echo "$TWEET_TEXT"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Confirm before posting
read -p "Post this tweet? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    log_warn "Cancelled by user"
    exit 0
fi

# Step 1: Upload media
log_info "Uploading video to Twitter..."

MEDIA_UPLOAD=$(twurl -X POST -H upload.twitter.com \
    "/1.1/media/upload.json" \
    --file "$VIDEO_FILE" \
    --file-field "media")

MEDIA_ID=$(echo "$MEDIA_UPLOAD" | jq -r '.media_id_string')

if [ -z "$MEDIA_ID" ] || [ "$MEDIA_ID" = "null" ]; then
    log_error "Media upload failed"
    echo "$MEDIA_UPLOAD" | jq '.'
    exit 1
fi

log_success "Media uploaded: $MEDIA_ID"

# Step 2: Post tweet with media
log_info "Posting tweet..."

TWEET_RESPONSE=$(twurl -X POST "/2/tweets" \
    -H "Content-Type: application/json" \
    -d "{
        \"text\": $(echo "$TWEET_TEXT" | jq -Rs .),
        \"media\": {
            \"media_ids\": [\"$MEDIA_ID\"]
        }
    }")

TWEET_ID=$(echo "$TWEET_RESPONSE" | jq -r '.data.id')

if [ -z "$TWEET_ID" ] || [ "$TWEET_ID" = "null" ]; then
    log_error "Tweet posting failed"
    echo "$TWEET_RESPONSE" | jq '.'
    exit 1
fi

TWEET_URL="https://twitter.com/user/status/$TWEET_ID"

log_success "Tweet posted successfully!"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Tweet URL: $TWEET_URL"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Open tweet in browser
open "$TWEET_URL"
