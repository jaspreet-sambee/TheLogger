# Workflow Recording Fix - Complete Summary

## Issues Fixed

### Issue 1: Static Frame (7 seconds)
**Problem**: Video was only 7 seconds of static content
**Cause**: Wrong Xcode scheme used (`TheLoggerUITests` instead of `TheLogger`)
**Fix**: Changed scheme in `record-video.sh` line 218

### Issue 2: No Workflow Execution
**Problem**: Video showed main screen with no interactions
**Cause**: Test used `--demo-mode` flag but app only recognized `--uitesting`
**Fix**: Changed DemoScenarios.swift to use `--uitesting` flag

### Issue 3: App Installation Failure
**Problem**: Script found incomplete app in Index.noindex directory
**Cause**: `find` command found Index.noindex build before correct build
**Fix**: Added `-not -path "*/Index.noindex/*"` to exclude Index.noindex

## Files Modified

### 1. VideoAutomation/scripts/record-video.sh

**Line 134** - Exclude Index.noindex from app search:
```bash
# Before:
APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData -name "TheLogger.app" -path "*/Debug-iphonesimulator/*" -type d 2>/dev/null | head -1)

# After:
APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData -name "TheLogger.app" -path "*/Debug-iphonesimulator/*" -not -path "*/Index.noindex/*" -type d 2>/dev/null | head -1)
```

**Line 218** - Use correct scheme:
```bash
# Before:
xcodebuild test \
    -project TheLogger.xcodeproj \
    -scheme TheLoggerUITests \    # WRONG - not a valid test scheme
    -destination "platform=iOS Simulator,id=$SIMULATOR_UDID" \
    -only-testing:"TheLoggerUITests/DemoScenarios/$TEST_METHOD" \
    2>&1

# After:
xcodebuild test \
    -project TheLogger.xcodeproj \
    -scheme TheLogger \              # CORRECT - main app scheme
    -destination "platform=iOS Simulator,id=$SIMULATOR_UDID" \
    -only-testing:"TheLoggerUITests/DemoScenarios/$TEST_METHOD" \
    2>&1
```

### 2. TheLoggerUITests/DemoScenarios.swift

**Line 23** - Use correct launch argument:
```swift
// Before:
app.launchArguments = ["--demo-mode"]  // Not recognized by app

// After:
app.launchArguments = ["--uitesting"]  // Skips onboarding
```

**Line 27** - Increased wait time:
```swift
// Before:
sleep(1)

// After:
sleep(2)  // Give app more time to settle
```

## What Each Fix Does

### Fix 1: Correct Scheme
- **TheLogger** scheme includes UI tests as a target
- **TheLoggerUITests** is a target name, not a runnable scheme
- Using wrong scheme caused immediate test failure
- Test would exit after ~7 seconds instead of running full workflow

### Fix 2: Correct Launch Argument
- `--uitesting` is checked in TheLoggerApp.swift init() method
- Sets `hasCompletedOnboarding = true` to skip onboarding
- Without this, app shows onboarding screens instead of main UI
- Test can't find elements because they're on wrong screen

### Fix 3: Avoid Index.noindex
- Index.noindex is Xcode's indexing cache directory
- Contains incomplete builds without proper Info.plist
- Installing from there causes "Missing bundle ID" error
- Must use Build/Products/Debug-iphonesimulator instead

## Testing the Fix

```bash
cd VideoAutomation
./scripts/record-video.sh workflows/new-workout.yaml
```

**Expected results**:
- ✅ Test runs for ~35-40 seconds
- ✅ Video is ~18-20 seconds
- ✅ Video shows:
  1. Home screen with "Start Workout" button
  2. Tapping "Start Workout"
  3. Adding an exercise (Bench Press)
  4. Logging a set (135 lbs x 10 reps)
  5. Completed set visible in list

**Before fixes**:
- ❌ Test failed after 7 seconds
- ❌ Video was 7 seconds of static home screen
- ❌ No interactions visible

## Verifying All Demos Work

Test all 9 demo workflows:

```bash
cd VideoAutomation
./scripts/batch-record.sh all
```

Each video should show actual UI interactions:
1. **new-workout** - Start workout, add exercise, log set
2. **add-exercise** - Add multiple exercises
3. **complete-workout** - Full workout with summary
4. **template-workflow** - Create and use template
5. **quicklog-strip** - Rapid set logging
6. **pr-celebration** - PR animation
7. **live-activity** - Lock screen widget
8. **progress-chart** - Progress visualization
9. **rest-timer** - Rest timer functionality

## Common Issues

### "Missing bundle ID" error
**Cause**: Script found app in Index.noindex
**Solution**: Run `rm -rf ~/Library/Developer/Xcode/DerivedData/*/Index.noindex/Build/Products/*/TheLogger.app`

### Video shows onboarding
**Cause**: Wrong launch argument
**Solution**: Ensure DemoScenarios uses `--uitesting` not `--demo-mode`

### Test exits early (< 30 seconds)
**Cause**: Wrong scheme or test not found
**Solution**: Use `-scheme TheLogger` and verify test method name matches

### Elements not found
**Cause**: Accessibility identifiers missing or wrong
**Solution**: Verify elements have correct accessibility IDs in app code

## Accessibility Identifiers Used

The tests rely on these identifiers being set in the app:
- `startWorkoutButton` - Start Workout button
- `addExerciseButton` - Add Exercise button
- `exerciseSearchField` - Exercise search text field
- `exerciseResult_<name>` - Exercise result cells
- `addSetButton` - Add Set button
- `weightInput` - Weight text field
- `repsInput` - Reps text field
- `saveSetButton` - Save Set button

If any are missing, update the app code to add them.

## App Launch Arguments

TheLoggerApp.swift recognizes these launch arguments:

### `--uitesting`
- Skips onboarding by setting `hasCompletedOnboarding = true`
- Used for all UI tests and demo videos
- Checked in `init()` method

### Future Arguments
If you need more test modes, add them in TheLoggerApp.swift:
```swift
init() {
    #if DEBUG
    if CommandLine.arguments.contains("--uitesting") {
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
    }
    if CommandLine.arguments.contains("--demo-data") {
        // Add sample workouts for demo
    }
    #endif
}
```

## Troubleshooting Commands

```bash
# Check which app will be found
find ~/Library/Developer/Xcode/DerivedData -name "TheLogger.app" -path "*/Debug-iphonesimulator/*" -not -path "*/Index.noindex/*"

# Verify bundle ID in found app
plutil -p <APP_PATH>/Info.plist | grep CFBundleIdentifier

# Test video manually
cd VideoAutomation
./scripts/record-video.sh workflows/new-workout.yaml

# Run test without recording
xcodebuild test -project TheLogger.xcodeproj -scheme TheLogger \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:TheLoggerUITests/DemoScenarios/testNewWorkoutDemo
```

## Success Criteria

✅ All 3 issues resolved:
1. Video duration matches test duration (~18s)
2. Video shows actual UI interactions
3. No installation errors

✅ Video quality:
- Clear UI interactions visible
- Smooth transitions between screens
- All taps and typing captured
- Device frame applied (if enabled)
- Twitter-optimized format (720x1280, H.264)
