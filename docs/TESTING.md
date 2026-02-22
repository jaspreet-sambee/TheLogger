# TheLogger Testing Guide

This document covers both automated testing and manual testing for TheLogger.

---

## Part 1: Automated Testing

### Test Structure

```
TheLogger/
├── TheLoggerTests/           # Unit tests (models, managers, utilities)
│   ├── WorkoutModelTests.swift
│   ├── PRManagerTests.swift
│   └── UtilityTests.swift
├── TheLoggerUITests/         # UI workflow tests
│   ├── WorkflowTests.swift   # Core app workflows
│   └── DemoScenarios.swift   # Video demo scenarios
└── run-tests.sh              # Test automation script
```

### Running Automated Tests

**Using Xcode:** Press `⌘U` to run all tests.

**Using command line:**
```bash
./run-tests.sh
```

**Run in Xcode:** `⌘U` | **Run specific test:** Click diamond icon next to test method.

### Test Coverage

- **Unit tests:** Workout CRUD, Exercise Management, Set Operations, PR Detection, 1RM, Unit Conversion
- **UI tests:** Complete workout flow, QuickLogStrip, Templates, Multiple exercises, Data persistence

### Full Setup & Reference

See [VideoAutomation/AUTOMATION_GUIDE.md](../VideoAutomation/AUTOMATION_GUIDE.md) for detailed test setup, accessibility identifiers, and troubleshooting.

---

## Part 2: Manual Testing Checklist

Use this checklist to verify app functionality after making changes.

### Quick Smoke Test

Run these checks for any change:

- [ ] App launches without crash
- [ ] Can navigate to all main screens
- [ ] No console errors or warnings

### Core Workflows

#### 1. Workout Creation

- [ ] Tap "Start Workout" → shows workout selector (if templates exist) or creates blank workout
- [ ] Can start new blank workout
- [ ] Can start workout from template
- [ ] Workout shows "Active" badge
- [ ] Timer shows elapsed time

#### 2. Adding Exercises

- [ ] Tap "Add Exercise" → shows exercise search
- [ ] Can search for exercise by name
- [ ] Can select exercise from search results
- [ ] Exercise appears in workout

#### 3. Logging Sets

- [ ] Can tap exercise to open edit view
- [ ] Can add set with reps and weight
- [ ] Weight +/- buttons adjust value
- [ ] "Log Set" button saves the set
- [ ] Set appears in exercise's set list

#### 4. Rest Timer

- [ ] Rest timer option appears after logging set
- [ ] Timer counts down correctly
- [ ] Haptic feedback on completion

#### 5. Personal Records

- [ ] Log a working set → if new PR, celebration animation shows
- [ ] PR is saved for next session

#### 6. Ending Workout

- [ ] Tap "End Workout" → confirmation appears
- [ ] "End" ends the workout
- [ ] Workout summary shows after ending

#### 7. Templates

- [ ] Can create template from "New Template"
- [ ] Can start workout from template
- [ ] Template exercises carry over (no sets)

#### 8. Settings

- [ ] Can switch between Imperial/Metric
- [ ] Weight display updates throughout app

### Pre-Release Checklist

Before each App Store release:

- [ ] Run `./run-tests.sh` - all tests must pass
- [ ] Manual smoke test on device
- [ ] Test with different unit systems
