# TheLogger ProVideos

Professional video production pipeline for TheLogger marketing content.

## Quick Start

```bash
# Produce a single video (record + process)
./scripts/produce.sh workflows/quick-logging.yaml

# Process an existing raw recording
./scripts/produce.sh --process-only workflows/pr-celebration.yaml

# Batch produce all videos
./scripts/produce.sh --batch
```

## Structure

```
ProVideos/
├── scripts/
│   ├── record.sh       # Simulator recording engine
│   ├── process.sh      # Post-processing (zoom, effects, framing)
│   └── produce.sh      # Master orchestrator
├── workflows/          # Video configs (YAML)
│   ├── camera-rep-counter.yaml
│   ├── quick-logging.yaml
│   ├── pr-celebration.yaml
│   └── feature-tour.yaml
├── assets/
│   ├── music/          # Background tracks (add .mp3/.m4a files here)
│   ├── fonts/          # Custom fonts
│   └── overlays/       # Logo overlays, watermarks
├── output/
│   ├── raw/            # Raw simulator recordings
│   ├── processed/      # Intermediate files (auto-cleaned)
│   └── final/          # Production-ready videos
└── templates/          # Reusable workflow templates
```

## Dependencies

```bash
brew install yq ffmpeg
# Xcode + iOS Simulator required for recording
```

## Pipeline

1. **Record** — Boots simulator, builds app, runs XCUITest scenario, captures video
2. **Process** — Applies cinematic effects in sequence:
   - Trim (remove springboard / test teardown)
   - Scale to working resolution
   - Speed ramps (compress navigation, keep features real-time)
   - Cinematic zoom moments (crop + scale with anchor points)
   - Ken Burns (subtle drift zoom for polish)
   - Flash effects (brightness pulse on key interactions)
   - Text overlays (timed captions with shadow)
   - Vignette + color grading (warm/cool/cinematic)
   - Background music mixing (with fade-out)
   - Device framing (premium iPhone bezel + background)
   - Final encode (Twitter CRF 18 + Production CRF 14)

## Output Formats

| Format | Resolution | Quality | Use |
|--------|-----------|---------|-----|
| `_twitter.mp4` | 720x1280 | CRF 18 | Twitter/X posting |
| `_production.mp4` | Native | CRF 14 | Archive / other platforms |

## Adding Music

Drop `.mp3` or `.m4a` files into `assets/music/`. The pipeline auto-detects the first available track unless `music_file` is specified in the workflow.

Recommended: Lo-fi gym beats from Pixabay (CC0 license).

## Creating New Workflows

Copy an existing YAML and customize. Key sections:

```yaml
name: "Video Title"
simulator:
  device: "iPhone 17 Pro"
  appearance: "dark"              # or "light"
recording:
  test_method: "testYourDemoMethod"  # XCUITest method in DemoScenarios.swift
output:
  filename: "your-video"
  background_color: "#0A0D1E"
effects:
  trim_start: 7.0
  zoom_moments:
    - time: 5.0
      scale: 1.2
      duration: 2.0
      anchor: "center"            # center|bottom|top|right|bottom_center
  text_overlays:
    - text: "Your caption here."
      start: 3.0
      end: 7.0
      position: "bottom"          # top|center|bottom
  music: true
  vignette: true
  color_grade: "cinematic"        # none|warm|cool|cinematic
```
