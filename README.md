# TheLogger

A minimalist iOS workout tracking app built with SwiftUI and SwiftData. Designed for speed in the gym with a focus on privacy - all data stays on your device.

## Features

- **Quick Workout Logging** - Add exercises and log sets with minimal taps
- **Rest Timer** - Automatic rest timer with haptic feedback when complete
- **Personal Records** - Automatic PR detection with celebration animations
- **Templates** - Save workouts as templates for quick repeat sessions
- **Progress Tracking** - Compare current workout to previous sessions
- **Exercise Memory** - Remembers your last weight/reps for each exercise
- **Unit Switching** - Toggle between lbs and kg anytime
- **Export** - Export your workout history to CSV
- **100% Offline** - No accounts, no cloud, no tracking

## Tech Stack

| Technology | Version | Purpose |
|------------|---------|---------|
| SwiftUI | iOS 17+ | UI framework |
| SwiftData | iOS 17+ | Local persistence |
| Swift | 5.9+ | Language |
| Charts | iOS 16+ | Statistics visualization |

**No external dependencies** - built entirely with Apple frameworks.

## Requirements

- iOS 17.0+
- Xcode 15.0+

## Getting Started

### Clone and Build

```bash
git clone <repository-url>
cd TheLogger
open TheLogger.xcodeproj
```

### Run in Simulator

1. Open `TheLogger.xcodeproj` in Xcode
2. Select an iOS 17+ simulator (iPhone 15 recommended)
3. Press `Cmd + R` to build and run

### Build from Command Line

```bash
xcodebuild -project TheLogger.xcodeproj \
  -scheme TheLogger \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  build
```

## Project Structure

```
TheLogger/
├── TheLoggerApp.swift       # App entry point, SwiftData setup
├── Models/
│   ├── Workout.swift        # Workout model + helpers
│   ├── Exercise.swift       # Exercise model
│   └── WorkoutSet.swift     # Set model
├── Views/
│   ├── ContentView.swift    # Workout detail + editing views
│   ├── WorkoutListView.swift # Home screen
│   ├── SettingsView.swift   # Settings
│   ├── OnboardingView.swift # Onboarding
│   └── PrivacyPolicyView.swift
├── Components/
│   ├── Components.swift     # Reusable UI components
│   └── Animations.swift     # Custom animations
└── docs/
    ├── ARCHITECTURE.md      # Technical architecture
    ├── TESTING.md           # Test checklist
    └── KNOWN_BUGS.md        # Bug tracking
```

## Architecture

The app uses a modified MVVM pattern with SwiftData:

- **Models**: SwiftData `@Model` classes for persistence
- **Views**: SwiftUI views with `@Query` for data fetching
- **State**: `@Observable` classes for shared state (RestTimerManager)

See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for detailed diagrams.

## Data Model

```
Workout ────┬──── Exercise ────┬──── WorkoutSet
            │                  │
            │                  ├── reps: Int
            ├── name           ├── weight: Double
            ├── date           └── setType (warmup/working)
            ├── startTime
            ├── endTime
            └── isTemplate
```

**Additional Models:**
- `ExerciseMemory` - Stores last used values per exercise
- `PersonalRecord` - Tracks PRs with estimated 1RM

## Key Features

### Rest Timer
The `RestTimerManager` singleton handles rest periods:
- Auto-starts after logging a set (optional)
- Continues in background
- Haptic feedback on completion
- Adjustable duration per exercise type

### Personal Records
PRs are detected using the Brzycki formula for estimated 1RM:
```
1RM = weight × (36 / (37 - reps))
```

### Unit Conversion
All weights stored internally in lbs. `UnitFormatter` handles display conversion:
```swift
UnitFormatter.convertToDisplay(weightInLbs)  // → display unit
UnitFormatter.convertToStorage(displayWeight) // → lbs for storage
```

## Development

### AI Rules Files

The project includes rules for AI assistants:
- `CLAUDE.md` - Rules for Claude Code
- `.cursorrules` - Rules for Cursor

### Testing

See [docs/TESTING.md](docs/TESTING.md) for the manual testing checklist.

### Known Issues

See [docs/KNOWN_BUGS.md](docs/KNOWN_BUGS.md) for tracked bugs and their status.

## Contributing

1. Read `CLAUDE.md` for coding guidelines
2. Follow existing patterns in the codebase
3. Test all core workflows before submitting changes
4. Keep changes focused and minimal

## Privacy

TheLogger is designed with privacy as a core principle:
- **No accounts** - No sign-up required
- **No cloud** - All data stored locally on device
- **No tracking** - No analytics or telemetry
- **Export anytime** - Your data in CSV format

## License

[Add license information]

---

Built with SwiftUI and SwiftData for iOS 17+
