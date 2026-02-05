# Claude Code Rules for TheLogger

## Project Context

TheLogger is an iOS workout tracking app that emphasizes speed, simplicity, and privacy.

- **Platform**: iOS 17+
- **Framework**: SwiftUI with SwiftData for persistence
- **Dependencies**: None (Apple frameworks only)
- **Architecture**: Modified MVVM with @Observable pattern

## Tech Stack

| Technology | Purpose |
|------------|---------|
| SwiftUI | UI framework |
| SwiftData | Local persistence (replaces Core Data) |
| @Observable | State management (iOS 17+) |
| Charts | Workout statistics visualization |

## Code Style

### Swift Patterns
- Use Swift 5.9+ features
- Prefer `@Observable` over `ObservableObject`
- Use `@Bindable` for SwiftData model binding in views
- Use `guard let` / `if let` instead of force unwraps (`!`)
- Follow Apple Human Interface Guidelines for UI

### Naming Conventions
- Views end with `View` (e.g., `WorkoutDetailView`)
- Models are plain names (e.g., `Workout`, `Exercise`)
- Managers/Helpers end with `Manager` or descriptive suffix

## File Scope Rules

### Models (`TheLogger/`)
| File | Responsibility |
|------|----------------|
| `Workout.swift` | Core Workout model, UnitFormatter, ExerciseLibrary, RestTimerManager, PR logic |
| `Exercise.swift` | Exercise model with sets relationship |
| `WorkoutSet.swift` | Individual set model with SetType enum |

### Views (`TheLogger/`)
| File | Responsibility |
|------|----------------|
| `WorkoutDetailView.swift` | Main active workout screen with exercise list, add/end buttons |
| `WorkoutListView.swift` | Home screen, template list, workout history, navigation |
| `ExerciseViews.swift` | ExerciseRowView, ExerciseCard, ExerciseEditView |
| `ExerciseSearchView.swift` | Exercise search/selection with library and history |
| `TemplateEditView.swift` | Template creation and editing |
| `SetViews.swift` | InlineSetRowView, InlineAddSetView, AddSetView, EditSetView, SelectAllTextField |
| `TimerViews.swift` | RestTimerView, PRCelebrationView, ConfettiView |
| `SummaryViews.swift` | WorkoutEndSummaryView, ExerciseProgressView |
| `SettingsView.swift` | User preferences (units, rest timer, profile) |
| `OnboardingView.swift` | 3-screen onboarding flow |
| `PrivacyPolicyView.swift` | Privacy policy display |
| `ContentView.swift` | AddWorkoutView (legacy) |

### Components (`TheLogger/`)
| File | Responsibility |
|------|----------------|
| `Components.swift` | CardStyle modifier, AppFont typography |
| `Animations.swift` | RingFillProgress, LiquidWaveTimer, HapticSteppers, StaggeredAppear |

### App Entry (`TheLogger/`)
| File | Responsibility |
|------|----------------|
| `TheLoggerApp.swift` | App entry point, SwiftData container setup |
| `SchemaMigrations.swift` | VersionedSchema, SchemaMigrationPlan - required for schema changes |

## Data Model

```
Workout (1) ──── (*) Exercise (1) ──── (*) WorkoutSet
    │                   │                     │
    ├─ id: UUID         ├─ id: UUID           ├─ id: UUID
    ├─ name: String     ├─ name: String       ├─ reps: Int
    ├─ date: Date       └─ sets: [WorkoutSet] ├─ weight: Double
    ├─ startTime: Date?                       ├─ setType: String
    ├─ endTime: Date?                         └─ sortOrder: Int
    ├─ isTemplate: Bool
    └─ exercises: [Exercise]
```

**Supporting Models:**
- `ExerciseMemory` - Remembers last used reps/weight per exercise
- `PersonalRecord` - Tracks PRs with estimated 1RM calculation

## Known Issues to Avoid

### Critical
1. **Never use force unwraps (`!`)** - Always use `guard let` or `if let`
2. **Array deletion order** - When deleting multiple items, sort indices in descending order
3. **TextField + Button race conditions** - Dismiss keyboard before button action or use flags

### Example: Safe Array Deletion
```swift
// WRONG - can crash with index out of bounds
for index in indexSet {
    array.remove(at: index)
}

// CORRECT - sort descending first
for index in indexSet.sorted(by: >) {
    array.remove(at: index)
}
```

### Example: TextField Race Condition
```swift
// If user taps button while editing TextField, the TextField's
// onCommit might fire after the button action starts.
// Solution: dismiss keyboard first
UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
```

## Common Patterns

### Card Background Style
```swift
// Use the cardStyle modifier from Components.swift
.cardStyle(borderColor: .blue)

// Or with custom parameters
.cardStyle(borderColor: .green, fillOpacity: 0.6, cornerRadius: 12)
```

### Haptic Feedback
```swift
// Light tap feedback
UIImpactFeedbackGenerator(style: .light).impactOccurred()

// Success notification
UINotificationFeedbackGenerator().notificationOccurred(.success)
```

### SwiftData Queries
```swift
// Basic query with sort
@Query(sort: \Workout.date, order: .reverse) private var workouts: [Workout]

// Filtered query
@Query(filter: #Predicate<Workout> { $0.isTemplate == true }) private var templates: [Workout]
```

### Model Binding in Views
```swift
struct ExerciseEditView: View {
    @Bindable var exercise: Exercise  // Use @Bindable for SwiftData models

    var body: some View {
        TextField("Name", text: $exercise.name)
    }
}
```

### Staggered Animations
```swift
// From existing codebase pattern
.staggeredAppear(index: index, maxStagger: 5)
```

## Testing Checklist

After making changes, verify:

1. **Build** - `xcodebuild -scheme TheLogger -destination 'platform=iOS Simulator,name=iPhone 15'`
2. **Core Flow**:
   - [ ] Create workout → add exercise → add sets → end workout
   - [ ] Rest timer starts and completes
   - [ ] PR celebration shows for new records
   - [ ] Templates save and load correctly
3. **Settings**:
   - [ ] Unit switching works (lbs ↔ kg)
   - [ ] Rest duration changes apply

## Build Commands

```bash
# Build for simulator
xcodebuild -project TheLogger.xcodeproj -scheme TheLogger -destination 'platform=iOS Simulator,name=iPhone 15' build

# Run tests (when added)
xcodebuild test -project TheLogger.xcodeproj -scheme TheLogger -destination 'platform=iOS Simulator,name=iPhone 15'
```

## Important Files for Context

When working on features, these files typically need to be read:
- Exercise features → `ExerciseViews.swift`, `ExerciseSearchView.swift`, `Workout.swift` (ExerciseLibrary)
- Set input/editing → `SetViews.swift`
- Workout flow → `WorkoutDetailView.swift`, `WorkoutListView.swift`
- Timer/PR features → `TimerViews.swift`, `Workout.swift` (RestTimerManager)
- Summary/Progress → `SummaryViews.swift`
- Templates → `TemplateEditView.swift`
- UI changes → `Components.swift`, `Animations.swift`
- Navigation → `WorkoutListView.swift`, `TheLoggerApp.swift`
- Settings → `SettingsView.swift`, `Workout.swift` (UnitFormatter)

## SwiftData Schema Migration & Data Preservation

**CRITICAL: User data must never be deleted by the app.**

### Migration Infrastructure
- **File**: `SchemaMigrations.swift`
- **Components**: `TheLoggerSchemaV1` (VersionedSchema), `TheLoggerMigrationPlan` (SchemaMigrationPlan)
- TheLoggerApp creates ModelContainer with `migrationPlan: TheLoggerMigrationPlan.self`

### Rules
1. **Never delete the store** - On ModelContainer failure, move store files to `default.store.recovery.<timestamp>/` instead of deleting. Preserve data for potential recovery.
2. **Keep CloudKit enabled** - `cloudKitDatabase: .automatic` provides iCloud backup. When a fresh store is created after failure, CloudKit can restore data.
3. **All schema changes go through VersionedSchema** - Add new schema versions in SchemaMigrations.swift; add MigrationStage for custom migrations; append to `stages` array.
4. **Lightweight migrations** - Adding optional properties may work automatically. Changing types or removing properties requires `MigrationStage.custom(fromVersion:toVersion:willMigrate:didMigrate:)`.

### Adding a New Schema Version (Future)
1. Create `TheLoggerSchemaV2` enum conforming to VersionedSchema with `versionIdentifier = Schema.Version(2, 0, 0)`
2. Add `migrateV1toV2 = MigrationStage.lightweight(fromVersion:toVersion:)` or `.custom(...)` for complex changes
3. Append to `TheLoggerMigrationPlan.schemas` and `stages`

### Failure Flow (TheLoggerApp)
1. ModelContainer creation fails → Move store to recovery dir (never delete)
2. Create fresh ModelContainer → CloudKit sync may restore data
3. Last resort: in-memory storage

## What Not To Do

- Don't add external dependencies without explicit approval
- Don't modify the SwiftData schema without adding to SchemaMigrations.swift and migration plan
- Don't delete SwiftData store files - move to recovery directory instead
- Don't disable CloudKit without explicit approval
- Don't use `@StateObject` - use `@State` with `@Observable` instead
- Don't add features beyond what was requested
- Don't create new documentation files unless explicitly asked
