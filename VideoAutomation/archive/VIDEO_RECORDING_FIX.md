# Video Recording Fix

## Problem
Video recordings were producing static frames (only 7 seconds instead of full demo duration).

## Root Cause
The `record-video.sh` script was using the wrong Xcode scheme:
- ❌ **Wrong**: `-scheme TheLoggerUITests` (UI test target, not a valid test scheme)
- ✅ **Correct**: `-scheme TheLogger` (main app scheme that includes UI tests)

When the wrong scheme was used, the test failed immediately, causing the recording to capture only the app launch and then stop.

## The Fix

### File: `VideoAutomation/scripts/record-video.sh`

**Line 218 - Changed:**
```bash
# Before (WRONG)
xcodebuild test \
    -project TheLogger.xcodeproj \
    -scheme TheLoggerUITests \
    -destination "platform=iOS Simulator,id=$SIMULATOR_UDID" \
    -only-testing:"TheLoggerUITests/DemoScenarios/$TEST_METHOD" \
    -quiet \
    2>&1 || { ... }

# After (CORRECT)
xcodebuild test \
    -project TheLogger.xcodeproj \
    -scheme TheLogger \
    -destination "platform=iOS Simulator,id=$SIMULATOR_UDID" \
    -only-testing:"TheLoggerUITests/DemoScenarios/$TEST_METHOD" \
    2>&1 || { ... }
```

## Results

### Before Fix
- Video duration: **7 seconds**
- File size: **214 KB**
- Content: Static frame, no interaction
- Test: Failed/exited early due to wrong scheme

### After Fix
- Video duration: **18 seconds** ✅
- File size: **181 KB** (proper size for content)
- Content: Full demo with all interactions ✅
- Test: Passed successfully (41 seconds runtime) ✅

## Testing

To verify the fix works:

```bash
cd VideoAutomation
./scripts/record-video.sh workflows/new-workout.yaml
```

Expected output:
- ✅ Test runs for ~40 seconds
- ✅ Video is 15-20 seconds (matches demo flow)
- ✅ Video shows actual UI interactions, not static frames
- ✅ "TEST SUCCEEDED" message appears

## Available Schemes

For reference, the project has these schemes:
- **TheLogger** ← Use this for running UI tests
- TheLoggerUITests ← This is a target, not a runnable scheme
- TheLoggerWidgetExtension

## Why It Happened

Xcode allows creating separate schemes for test targets, but `TheLoggerUITests` is configured as a UI test target within the main `TheLogger` scheme, not as a standalone test scheme. When trying to run tests with `-scheme TheLoggerUITests`, xcodebuild couldn't find a valid test plan and exited immediately.

## Prevention

When writing automation scripts that run UI tests:
1. ✅ Always use the main app scheme (e.g., `TheLogger`)
2. ✅ Specify the test target in `-only-testing:` parameter
3. ❌ Don't use test target names as scheme names

## Additional Notes

- The script also has a fallback mechanism that uses a timer if the test fails
- The fallback duration is set in the workflow YAML (default: 15-20 seconds)
- However, the fallback won't capture actual UI interactions, just a static screen

## Testing All Workflows

To test all demo videos work correctly:

```bash
cd VideoAutomation
./scripts/batch-record.sh all
```

This will record all 9 demo scenarios:
1. new-workout
2. add-exercise
3. complete-workout
4. template-workflow
5. quicklog-strip
6. pr-celebration
7. live-activity
8. progress-chart
9. rest-timer

Each should produce a video of 15-30 seconds showing actual UI interactions.
