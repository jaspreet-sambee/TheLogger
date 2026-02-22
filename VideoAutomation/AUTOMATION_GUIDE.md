# Video Automation & Twitter Posting Guide

Complete guide for recording and posting TheLogger demo videos to X/Twitter.

## Quick Start

### 1. One-Time Setup

```bash
# Install dependencies
brew install ffmpeg yq jq
gem install twurl

# Set up Twitter API (one time)
# 1. Go to https://developer.twitter.com/en/portal/dashboard
# 2. Create a new app
# 3. Get your API keys

# Authorize twurl
twurl authorize --consumer-key YOUR_KEY --consumer-secret YOUR_SECRET
```

### 2. Record Videos

```bash
# Record single demo
./VideoAutomation/record-demo new-workout

# Record all demos at once
./VideoAutomation/scripts/batch-record.sh all

# Record specific demos
./VideoAutomation/scripts/batch-record.sh quicklog-strip pr-celebration live-activity
```

### 3. Post to Twitter

```bash
# Post a video (with confirmation)
./VideoAutomation/scripts/post-to-twitter.sh \
  VideoAutomation/output/new-workout_twitter.mp4 \
  VideoAutomation/workflows/new-workout.yaml

# The script will:
# - Show you the tweet preview
# - Ask for confirmation
# - Upload video to Twitter
# - Post tweet with caption & hashtags
# - Open tweet in browser
```

## Available Demo Workflows

| Workflow | Description | Duration | Best Time |
|----------|-------------|----------|-----------|
| `new-workout` | Complete workout flow | 20s | Launch day |
| `quicklog-strip` | Ultra-fast set logging | 15s | Peak hours (6-8pm) |
| `template-workflow` | Start from template | 12s | Monday mornings |
| `pr-celebration` | PR achievement | 10s | Motivational (evenings) |
| `live-activity` | Lock screen logging | 18s | iOS feature highlights |
| `progress-chart` | Progress visualization | 15s | Mid-week motivation |
| `rest-timer` | Smart rest periods | 12s | Tip of the day |

## Content Strategy

### Weekly Posting Schedule

**Monday** (Motivation + productivity)
- Template workflow
- "Start your week strong" messaging

**Wednesday** (Mid-week tip)
- QuickLogStrip or Progress Chart
- "Track your progress" focus

**Friday** (Achievement)
- PR Celebration
- "Finish strong" messaging

**Weekends** (Feature highlights)
- Live Activity or Rest Timer
- More casual, feature-focused

### Best Posting Times (Fitness Audience)

- **Morning**: 6:00-8:00 AM (pre-workout)
- **Lunch**: 12:00-1:00 PM (meal prep crowd)
- **Evening**: 6:00-8:00 PM (post-work gym crowd)
- **Avoid**: Late night (10pm+), very early morning

## Advanced Workflows

### Automated Daily Posting

Create a cron job or launchd agent:

```bash
# crontab -e
0 18 * * 1 /path/to/post-scheduled-video.sh monday
0 18 * * 3 /path/to/post-scheduled-video.sh wednesday
0 18 * * 5 /path/to/post-scheduled-video.sh friday
```

### Batch Record + Queue Posting

```bash
# 1. Record all videos at once
./VideoAutomation/scripts/batch-record.sh all

# 2. Queue them for scheduled posting
# (See scheduled-posting.sh below)
```

### A/B Testing Captions

Edit workflow YAML to test different captions:

```yaml
output:
  caption: "Option A: Feature-focused"
  # vs
  caption: "Option B: Benefit-focused"
```

Record both, post at different times, compare engagement.

## Twitter API Setup (Detailed)

### Step 1: Get API Access

1. Go to https://developer.twitter.com/en/portal/dashboard
2. Create a new Project + App
3. Set up **OAuth 1.0a** permissions
4. Generate API keys:
   - API Key (Consumer Key)
   - API Secret (Consumer Secret)
   - Access Token
   - Access Token Secret

### Step 2: Configure twurl

```bash
# Install twurl
gem install twurl

# Authorize (interactive)
twurl authorize \
  --consumer-key YOUR_API_KEY \
  --consumer-secret YOUR_API_SECRET

# This will open a browser - authorize the app
# Then paste the PIN back into terminal
```

### Step 3: Test

```bash
# Test API access
twurl "/2/tweets" -X POST \
  -H "Content-Type: application/json" \
  -d '{"text":"Test tweet from TheLogger automation!"}'
```

## Video Specifications

All videos are automatically optimized for Twitter:

| Setting | Value | Why |
|---------|-------|-----|
| Format | MP4 (H.264) | Twitter requirement |
| Resolution | 720x1280 (9:16) | Portrait mobile |
| Codec | libx264 | Best compatibility |
| Max Size | <512MB | Twitter limit |
| Duration | 10-20s | Attention span |
| Frame Rate | 30 fps | Smooth playback |
| Audio | None | Silent autoplay |

## Creating New Demo Workflows

### 1. Create Workflow YAML

```yaml
name: "My New Demo"
description: "What this demo shows"

simulator:
  device: "iPhone 17 Pro"
  appearance: "dark"  # or "light"

recording:
  duration: 15  # fallback duration

output:
  filename: "my-new-demo"
  twitter_optimized: true
  include_device_frame: true
  background_color: "#000000"  # hex color
  caption: "Your tweet caption here"
  hashtags: ["fitness", "workout", "progress"]
```

### 2. Add UI Test

In `TheLoggerUITests/DemoScenarios.swift`:

```swift
func testMyNewDemoDemo() {
    // Your demo workflow
    startWorkoutAndLogSet(exercise: "Squat", weight: "315", reps: "5")
    // ... more steps
    sleep(2)
}
```

### 3. Record & Post

```bash
# Record
./VideoAutomation/record-demo my-new-demo

# Post
./VideoAutomation/scripts/post-to-twitter.sh \
  VideoAutomation/output/my-new-demo_twitter.mp4 \
  VideoAutomation/workflows/my-new-demo.yaml
```

## Troubleshooting

### Video recording fails

```bash
# Diagnose
./VideoAutomation/scripts/test-launch.sh

# Common fixes:
- Boot simulator first: open -a Simulator
- Build app first: xcodebuild build ...
- Check Console.app for errors
```

### Twitter posting fails

```bash
# Check API access
twurl "/2/tweets" -X GET

# Re-authorize if needed
twurl authorize --consumer-key YOUR_KEY --consumer-secret YOUR_SECRET

# Check video size
ls -lh VideoAutomation/output/*.mp4
# Must be < 512MB
```

### UI Test doesn't run

```bash
# Run test manually in Xcode first
# Check accessibility identifiers are set
# Increase sleep() delays if needed
```

## Content Ideas

### Feature Showcases
- QuickLogStrip speed
- Live Activity convenience
- PR celebrations
- Progress tracking
- Template efficiency
- Rest timer accuracy

### Use Cases
- Powerlifting progression
- Bodybuilding volume tracking
- CrossFit WOD logging
- Calisthenics progress
- Home gym workouts

### Before/After Comparisons
- Old way (paper) vs TheLogger
- Manual entry vs QuickLogStrip
- No tracking vs progress charts

### Tips & Tricks
- Hidden features
- Keyboard shortcuts
- Pro tips
- Settings optimization

## Analytics & Optimization

Track these metrics:

- **Impressions**: Total views
- **Engagement Rate**: Likes + RTs + Replies / Impressions
- **Best Time**: When posts perform best
- **Best Content**: Which demos get most engagement

Use Twitter Analytics to identify:
- Which features resonate most
- Optimal posting times
- Hashtag effectiveness
- Audience demographics

## Legal & Guidelines

- ✅ Use your own app footage
- ✅ Original music or no music
- ✅ Accurate feature descriptions
- ✅ Honest marketing claims
- ❌ No misleading comparisons
- ❌ No copyrighted content
- ❌ No competitor bashing

## Automation Tips

1. **Batch record weekly**: Record all demos Sunday night, post throughout week
2. **Seasonal content**: Back-to-gym (January), beach body (May), etc.
3. **Engagement**: Respond to comments/questions within 1 hour
4. **Cross-post**: Repurpose for Instagram Reels, TikTok
5. **Analytics**: Review weekly, adjust strategy monthly

## Support & Resources

- Twitter API Docs: https://developer.twitter.com/en/docs
- twurl GitHub: https://github.com/twitter/twurl
- ffmpeg Docs: https://ffmpeg.org/documentation.html
- Apple Simulator: https://developer.apple.com/documentation/xcode/running-your-app-in-simulator

---

**Questions?** Check existing workflow YAMLs for examples or run `./test-launch.sh` to diagnose issues.
