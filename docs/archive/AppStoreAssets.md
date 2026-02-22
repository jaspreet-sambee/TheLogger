# TheLogger App Store Assets Guide

## App Icon Requirements

### Technical Specs
- **Size**: 1024 x 1024 pixels (single source file)
- **Format**: PNG with no transparency
- **Color Space**: sRGB or Display P3
- **Corners**: Will be automatically rounded by iOS

### Design Recommendations
For a fitness/workout app called "TheLogger":

1. **Simple, Bold Design**
   - Avoid complex details (gets lost at small sizes)
   - Use 1-2 colors max for recognition
   
2. **Suggested Concepts**
   - Stylized dumbbell or barbell
   - Abstract weight plate
   - "L" lettermark (for Logger)
   - Chart/progress arrow (upward trend)

3. **Color Suggestions**
   - Primary: Deep blue (#0066CC) - matches app accent
   - Background: Dark gray/black - matches app theme
   - Accent: Yellow/gold (for PR celebration tie-in)

### Files to Replace
- `TheLogger/Assets.xcassets/AppIcon.appiconset/AppIcon.png`

---

## App Store Screenshots

### Required Sizes

| Device | Size (Portrait) | Mandatory |
|--------|-----------------|-----------|
| iPhone 6.7" | 1290 x 2796 | Yes |
| iPhone 6.5" | 1284 x 2778 | Yes |
| iPhone 5.5" | 1242 x 2208 | Yes (if supporting < iPhone X) |

### Recommended Screenshots (5-8 total)

1. **Main Screen** - Welcome with stats, active workout
2. **Exercise Logging** - Inline set editing in action
3. **Progress Chart** - Exercise progress view
4. **Personal Records** - PR celebration moment
5. **Templates** - Workout selector screen
6. **Rest Timer** - Timer in use
7. **Settings** - Units toggle, preferences
8. **Privacy** - Privacy-first messaging

### Screenshot Tips
- Use iPhone 15 Pro Max simulator for 6.7"
- Show real-looking data (not empty states)
- Highlight key features in captions
- Keep consistent style across all screenshots

---

## App Store Listing

### App Name
**TheLogger - Workout Tracker**

### Subtitle (30 chars max)
**Fast, Private Strength Log**

### Keywords (100 chars max)
`gym,workout,fitness,weightlifting,strength,training,exercise,log,tracker,barbell,gains,PR`

### Description
```
TheLogger is the fastest way to log your workouts. No frills, no distractions—just you and your lifts.

KEY FEATURES:

• Lightning Fast Logging
  - Inline set editing—no extra screens
  - One-tap "Repeat Set" for quick entries
  - Smart rest timer that stays out of your way

• Track Your Progress
  - Automatic personal record detection
  - Per-exercise progress charts
  - Workout history and stats

• Privacy First
  - All data stays on your device
  - No accounts, no cloud, no tracking
  - Export anytime as CSV

• Built for Lifters
  - 68+ common exercises
  - Custom exercise support
  - Workout templates
  - Metric and Imperial units

TheLogger respects your time and your privacy. Start logging, see progress, own your data.
```

### Category
Health & Fitness

### Age Rating
4+

### Privacy URL
(You need to host this - can use GitHub Pages, Notion, or your own site)

---

## App Review Checklist

- [ ] App icon displays correctly on all devices
- [ ] Screenshots match actual app UI
- [ ] Privacy policy URL is accessible
- [ ] No placeholder content in screenshots
- [ ] All features work offline
- [ ] VoiceOver accessibility tested
- [ ] Works on iPhone SE (smallest screen)
- [ ] Works on iPad (if supported)


