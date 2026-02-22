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

## Testing Requirements

**🚨 CRITICAL: All code changes MUST include corresponding test updates.**

### Quick Reference

| Change Type | Test File | What to Test |
|------------|-----------|--------------|
| Model properties/methods | `WorkoutModelTests.swift` | Properties, computed values, relationships |
| PR detection/1RM calc | `PRManagerTests.swift` | Calculations, edge cases, PR logic |
| Unit formatting/library | `UtilityTests.swift` | Conversions, search, formatting |
| UI/User flows | `WorkflowTests.swift` | Button taps, navigation, complete flows |
| New feature | New test file/method | Happy path, edge cases, errors |
| Bug fix | Regression test | Test that would have caught the bug |

### When to Update Tests

#### 1. Model Changes (Workout.swift, Exercise.swift, WorkoutSet.swift)
- **Add/Update**: Unit tests in `TheLoggerTests/WorkoutModelTests.swift`
- **Test**: Model properties, computed properties, initialization, relationships
- **Example**: If you add a new property to Workout, add a test verifying it's set correctly

#### 2. Business Logic Changes (PersonalRecordManager, UnitFormatter, ExerciseLibrary)
- **Add/Update**: Unit tests in `TheLoggerTests/PRManagerTests.swift` or `TheLoggerTests/UtilityTests.swift`
- **Test**: Calculations, conversions, PR detection, search functionality
- **Example**: If you modify 1RM calculation, update `testEstimated1RMCalculation()`

#### 3. UI Changes (Any View file)
- **Add/Update**: UI tests in `TheLoggerUITests/WorkflowTests.swift`
- **Test**: User interactions, button taps, navigation flows
- **Example**: If you add a new button, add a test that taps it and verifies the result
- **Add**: Accessibility identifiers for new interactive elements:
  ```swift
  Button("Save") { ... }
      .accessibilityIdentifier("saveButton")
  ```

#### 4. New Features
- **Add**: New test file or test method covering the feature
- **Test**: Happy path, edge cases, error conditions
- **Example**: New superset feature → add `testSupersetWorkflow()` in WorkflowTests

#### 5. Bug Fixes
- **Add**: Test that reproduces the bug (should fail before fix, pass after)
- **Prevents**: Regression - ensures bug doesn't come back
- **Example**: PR detection bug → add test showing correct behavior

### Test Structure

```
TheLoggerTests/           # Unit tests (fast, isolated)
├── WorkoutModelTests.swift      # Workout, Exercise, WorkoutSet models
├── PRManagerTests.swift         # PR detection and 1RM calculations
├── UtilityTests.swift          # UnitFormatter, ExerciseLibrary, helpers
└── TheLoggerTests.swift        # General tests

TheLoggerUITests/         # UI tests (comprehensive, real flows)
├── WorkflowTests.swift         # Complete user workflows
└── DemoScenarios.swift         # Marketing demo scenarios
```

### Test Writing Guidelines

#### Unit Tests (TheLoggerTests)
```swift
@MainActor
final class YourFeatureTests: XCTestCase {
    var modelContext: ModelContext!
    var modelContainer: ModelContainer!

    override func setUp() async throws {
        // Create in-memory container for isolation
        let schema = Schema([Workout.self, Exercise.self, WorkoutSet.self])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        modelContainer = try ModelContainer(for: schema, configurations: [configuration])
        modelContext = ModelContext(modelContainer)
    }

    func testYourFeature() {
        // Arrange - set up test data
        let workout = Workout(name: "Test", date: Date(), isTemplate: false)
        modelContext.insert(workout)

        // Act - perform action
        workout.startTime = Date()

        // Assert - verify result
        XCTAssertTrue(workout.isActive)
    }
}
```

#### UI Tests (TheLoggerUITests)
```swift
final class YourFeatureUITests: XCTestCase {
    let app = XCUIApplication()

    override func setUp() {
        app.launchArguments = ["--uitesting"]
        app.launch()
    }

    func testYourFeature() {
        // Find element by accessibility identifier
        let button = app.buttons["yourButtonIdentifier"]
        XCTAssertTrue(button.waitForExistence(timeout: 3))

        // Check if hittable before tapping
        if button.isHittable {
            button.tap()
        }

        // Verify result
        XCTAssertTrue(app.staticTexts["expectedText"].exists)
    }
}
```

### Common Test Patterns

#### Test Model Lifecycle
```swift
func testWorkoutCreation() {
    let workout = Workout(name: "Push Day", date: Date(), isTemplate: false)

    XCTAssertEqual(workout.name, "Push Day")
    XCTAssertFalse(workout.isTemplate)
    XCTAssertNil(workout.startTime) // Not active until started
}
```

#### Test Computed Properties
```swift
func testWorkoutIsActive() {
    let workout = Workout(name: "Test", date: Date(), isTemplate: false)

    XCTAssertFalse(workout.isActive) // No startTime

    workout.startTime = Date()
    XCTAssertTrue(workout.isActive) // Has startTime, no endTime

    workout.endTime = Date()
    XCTAssertFalse(workout.isActive) // Completed
}
```

#### Test UI Interactions
```swift
func testAddExerciseFlow() {
    // Start workout
    app.buttons["startWorkoutButton"].tap()
    sleep(1)

    // Add exercise
    app.buttons["addExerciseButton"].tap()
    sleep(1)

    // Search
    let searchField = app.textFields["exerciseSearchField"]
    searchField.tap()
    searchField.typeText("Bench Press")
    sleep(1)

    // Select result (check hittability)
    let result = app.cells.firstMatch
    if result.waitForExistence(timeout: 3) && result.isHittable {
        result.tap()
    }

    // Verify exercise added
    XCTAssertTrue(app.staticTexts["Bench Press"].exists)
}
```

### Running Tests

```bash
# Run all tests
./run-tests.sh

# Run only unit tests (fast - 2 seconds)
xcodebuild test -project TheLogger.xcodeproj -scheme TheLogger \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:TheLoggerTests

# Run only UI tests (slower - 4-5 minutes)
xcodebuild test -project TheLogger.xcodeproj -scheme TheLogger \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:TheLoggerUITests

# Run specific test
xcodebuild test -only-testing:TheLoggerTests/PRManagerTests/testFirstSetIsPR
```

### Test Checklist Before Committing

Before committing code changes, verify:

1. **All Tests Pass** ✅
   ```bash
   ./run-tests.sh
   ```

2. **New Tests Added** ✅
   - [ ] Unit tests for model/logic changes
   - [ ] UI tests for view/interaction changes
   - [ ] Accessibility identifiers added for new UI elements

3. **Edge Cases Covered** ✅
   - [ ] Nil/empty values
   - [ ] Zero/negative numbers
   - [ ] Boundary conditions
   - [ ] Error states

4. **No Regressions** ✅
   - [ ] Existing tests still pass
   - [ ] No tests commented out or skipped
   - [ ] No flaky tests (intermittent failures)

5. **Manual Verification** ✅
   - [ ] Core Flow: Create workout → add exercise → add sets → end workout
   - [ ] Rest timer starts and completes
   - [ ] PR celebration shows for new records
   - [ ] Templates save and load correctly
   - [ ] Settings: Unit switching works (lbs ↔ kg)
   - [ ] Settings: Rest duration changes apply

### Test Coverage Goals

Aim for:
- **Models**: 100% coverage of public APIs
- **Business Logic**: 100% coverage of calculations and transformations
- **Views**: Core user flows covered by UI tests
- **Edge Cases**: All error conditions and boundary cases tested

### When Tests Fail

1. **Read the error message** - XCTest provides detailed failure information
2. **Check the line number** - Failure location is shown in test output
3. **Verify accessibility identifiers** - Ensure UI elements have correct IDs
4. **Check hittability** - UI elements must be `.isHittable` before tapping
5. **Add waits** - Use `waitForExistence(timeout:)` for async operations
6. **Run in isolation** - Single failing test is easier to debug than full suite

### Documentation

See `TEST_FIXES_SUMMARY.md` for detailed examples of test fixes and patterns.

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

- **Don't make code changes without updating tests** - All code changes MUST have corresponding test updates
- Don't add external dependencies without explicit approval
- Don't modify the SwiftData schema without adding to SchemaMigrations.swift and migration plan
- Don't delete SwiftData store files - move to recovery directory instead
- Don't disable CloudKit without explicit approval
- Don't use `@StateObject` - use `@State` with `@Observable` instead
- Don't add features beyond what was requested
- Don't create new documentation files unless explicitly asked
- Don't skip accessibility identifiers for new interactive UI elements
- Don't commit code with failing tests or commented-out tests