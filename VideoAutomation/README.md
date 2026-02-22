# Video Automation for TheLogger

Automated system for recording demo videos of TheLogger app for social media (Twitter/X).

## Prerequisites

Install required tools:

```bash
# Required
brew install ffmpeg yq jq
gem install twurl

# Optional (but recommended)
brew install screenframer  # For device frames
```

## Quick Start

### Recording Videos

```bash
# Record single demo
./VideoAutomation/record-demo new-workout

# Record ALL demos at once
./VideoAutomation/scripts/batch-record.sh all

# Record specific demos
./VideoAutomation/scripts/batch-record.sh quicklog-strip pr-celebration
```

### Posting to Twitter

```bash
# Set up Twitter API (one-time)
gem install twurl
twurl authorize --consumer-key YOUR_KEY --consumer-secret YOUR_SECRET

# Post a video
./VideoAutomation/scripts/post-to-twitter.sh \
  output/new-workout_twitter.mp4 \
  workflows/new-workout.yaml
```

### Find Your Videos

```bash
open VideoAutomation/output/
```

## Complete Guide

For full automation setup, posting schedules, and content strategy, see:
**[AUTOMATION_GUIDE.md](./AUTOMATION_GUIDE.md)**

## Troubleshooting

### App won't launch?

Run the test script to diagnose:
```bash
./VideoAutomation/scripts/test-launch.sh
```

Common issues:
- Simulator not booted: The script will boot it automatically
- App not built: The script will build it if needed
- Timing issues: Try running the test-launch.sh script first

### Dependencies missing?

```bash
# Check if tools are installed
which ffmpeg yq

# Install if missing
brew install ffmpeg yq screenframer
```

## Creating New Workflows

1. Create a new YAML file in `workflows/`:

```yaml
name: "My Demo"
description: "Description of what this demo shows"

simulator:
  device: "iPhone 17 Pro"
  appearance: "dark"  # or "light"

recording:
  duration: 15  # seconds (fallback if XCUITest fails)

output:
  filename: "my-demo"
  twitter_optimized: true
  include_device_frame: true
  background_color: "#f5f5f5"
```

2. Add a test method in `TheLoggerUITests/DemoScenarios.swift`:

```swift
func testMyDemoDemo() {
    // Your UI test code here
    // Use accessibility identifiers to interact with UI
}
```

3. Record it:
```bash
./VideoAutomation/record-demo my-demo
```

## Accessibility Identifiers

These are set up for XCUITest automation:

| UI Element | Identifier |
|-----------|------------|
| Start Workout button | `startWorkoutButton` |
| Add Exercise button | `addExerciseButton` |
| End Workout button | `endWorkoutButton` |
| Exercise search field | `exerciseSearchField` |
| Exercise result cells | `exerciseResult_<name>` |
| Add Set button | `addSetButton` |
| Reps input | `repsInput` |
| Weight input | `weightInput` |
| Save Set button | `saveSetButton` |

## Output Specifications

Videos are optimized for Twitter/X:

- **Format**: MP4 (H.264)
- **Resolution**: 720x1280 (9:16 portrait)
- **Background**: Light neutral (#f5f5f5)
- **Device frame**: iPhone 17 Pro (if screenframer installed)
- **Max size**: Well under 512MB limit
- **Duration**: Configurable (default 15-20s)

## Advanced Usage

### Manual recording (without XCUITest)

Edit your workflow YAML to remove the test dependency:

```yaml
recording:
  duration: 30  # Will just record for 30 seconds
```

### Custom background color

```yaml
output:
  background_color: "#1a1a1a"  # Dark background
```

### Without device frame

```yaml
output:
  include_device_frame: false
```

### Different simulator

```yaml
simulator:
  device: "iPhone 17"  # or any available simulator
  appearance: "light"
```

List available simulators:
```bash
xcrun simctl list devices available | grep iPhone
```

## File Structure

```
VideoAutomation/
├── README.md                    # This file
├── record-demo                  # Entry point script
├── scripts/
│   ├── record-video.sh         # Main orchestration
│   └── test-launch.sh          # Debug helper
├── workflows/
│   └── new-workout.yaml        # Demo definitions
├── assets/                     # Optional assets
└── output/                     # Generated videos
```

## How It Works

1. **Boot Simulator**: Starts the iOS Simulator
2. **Install App**: Builds (if needed) and installs TheLogger.app
3. **Start Recording**: Uses `simctl recordVideo`
4. **Run XCUITest**: Executes the demo scenario
5. **Stop Recording**: Saves raw video
6. **Apply Frame**: Adds device bezel (if screenframer available)
7. **Optimize**: Converts to Twitter-ready format with ffmpeg

## Tips

- Keep demos under 30 seconds for Twitter
- Use dark appearance for better contrast
- Test your XCUITest scenarios in Xcode first
- Check the output video before posting

## Support

If you encounter issues:
1. Run `./VideoAutomation/scripts/test-launch.sh` to diagnose
2. Check that the app builds and runs in Xcode
3. Verify all dependencies are installed: `which ffmpeg yq`
4. Check Console.app for simulator errors
