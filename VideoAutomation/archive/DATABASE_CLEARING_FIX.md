# Database Clearing Fix for UI Tests

## Problem
After fixing the test method name generation, tests were executing but not showing full workflow interactions. The test would tap "Start Workout" and then get stuck because a template selector sheet appeared instead of going directly to the workout screen.

## Root Cause
When you tap "Start Workout":
- If `templates.isEmpty` → starts workout immediately ✅
- If templates exist → shows `WorkoutSelectorView` sheet ❌

The `--uitesting` launch argument only skipped onboarding but didn't clear the database. If templates existed from previous test runs or normal app usage, the test couldn't proceed because it didn't handle the selector sheet.

## Solution
Clear all database data when `--uitesting` flag is detected.

### Implementation

**File**: `TheLogger/WorkoutListView.swift` (lines 661-693)

Added data clearing logic in the `.task` modifier:

```swift
.task {
    #if DEBUG
    // Clear all data for UI testing mode (clean state for each test)
    if CommandLine.arguments.contains("--uitesting") && !hasCheckedActiveWorkout {
        do {
            // Delete all workouts (including templates)
            let workoutDescriptor = FetchDescriptor<Workout>()
            let allWorkouts = try modelContext.fetch(workoutDescriptor)
            for workout in allWorkouts {
                modelContext.delete(workout)
            }

            // Delete all exercise memories
            let memoryDescriptor = FetchDescriptor<ExerciseMemory>()
            let memories = try modelContext.fetch(memoryDescriptor)
            for memory in memories {
                modelContext.delete(memory)
            }

            // Delete all personal records
            let prDescriptor = FetchDescriptor<PersonalRecord>()
            let prs = try modelContext.fetch(prDescriptor)
            for pr in prs {
                modelContext.delete(pr)
            }

            try modelContext.save()
            print("[TheLogger] UI Testing: Cleared all data for clean test state")
        } catch {
            print("[TheLogger] UI Testing: Failed to clear data - \(error)")
        }
    }
    #endif

    // Auto-navigate to active workout on app launch (only once)
    if !hasCheckedActiveWorkout {
        hasCheckedActiveWorkout = true
        if let activeWorkout = activeWorkout {
            navigationPath.append(activeWorkout.id.uuidString)
        }
    }
}
```

## Results

### Before Fix
```
t = 6.07s  Tap "startWorkoutButton"
t = 7.95s  Waiting for "addExerciseButton" (times out - selector sheet showing)
t = 11.15s Waiting for "exerciseSearchField" (times out)
...all subsequent elements time out
```

**Video**: One screen transition (home → workout screen never happens), rest is static

### After Fix
```
t = 6.10s  Tap "startWorkoutButton" ✅
t = 9.58s  Tap "addExerciseButton" ✅
t = 12.61s Tap "exerciseSearchField" ✅
t = 13.04s Type 'Bench Press' ✅
...test continues with actual interactions
```

**Video**: 50 seconds, 856KB, full workflow captured

## Why This Location?

The `.task` modifier runs when the view appears, which is:
1. **After** the ModelContainer is initialized
2. **Before** the user sees any UI elements
3. **Only once** per app launch (controlled by `hasCheckedActiveWorkout` flag)

This ensures:
- Data is cleared before any queries run
- Tests always start with a clean slate
- No race conditions with container initialization

## Alternative Approaches Considered

### 1. Clear in TheLoggerApp.init() ❌
**Problem**: Can't access `sharedModelContainer.mainContext` in init() due to escaping closure capture of mutating `self`

### 2. Use in-memory ModelContainer for tests ❌
**Problem**: Would require separate container configuration, complicates setup, doesn't test real data persistence

### 3. Handle WorkoutSelectorView in tests ❌
**Problem**: Adds complexity to every test, templates might be desirable for some demos (template-workflow)

## Impact on Different Workflows

Most workflows benefit from clean state:
- ✅ **new-workout**: No templates → direct workout start
- ✅ **add-exercise**: Clean exercise list
- ✅ **complete-workout**: No previous workout history
- ✅ **quicklog-strip**: No exercise memories to interfere
- ✅ **pr-celebration**: No existing PRs, first set triggers celebration
- ✅ **rest-timer**: Clean timer state
- ✅ **progress-chart**: Can seed specific data in test setup
- ✅ **live-activity**: Clean live activity state

For workflows that need templates:
- **template-workflow**: Test can create templates in setup before interaction

## Verification

```bash
cd /Users/jaspreet/Documents/MyApps/TheLogger

# Run test with --uitesting flag
xcodebuild test \
  -project TheLogger.xcodeproj \
  -scheme TheLogger \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:TheLoggerUITests/DemoScenarios/testNewWorkoutDemo

# Check for data clearing in logs
# Should see: "[TheLogger] UI Testing: Cleared all data for clean test state"
```

## Files Modified

1. **TheLogger/WorkoutListView.swift** (lines 661-693)
   - Added database clearing logic in `.task` modifier
   - Only runs in DEBUG mode with `--uitesting` flag
   - Deletes all Workouts, ExerciseMemories, and PersonalRecords

## Summary

The key insight was that `--uitesting` needed to do more than just skip onboarding - it needed to ensure a completely clean database state. By clearing all data in `WorkoutListView.task`, we guarantee:

1. No template selector appears (templates are deleted)
2. No exercise memories interfere with searches
3. No PR history affects test expectations
4. Each test run starts identically

This allows tests to reliably capture full UI workflows for demo videos.
