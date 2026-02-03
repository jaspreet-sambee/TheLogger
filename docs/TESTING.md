# TheLogger Manual Testing Checklist

Use this checklist to verify app functionality after making changes.

## Quick Smoke Test

Run these checks for any change:

- [ ] App launches without crash
- [ ] Can navigate to all main screens
- [ ] No console errors or warnings

## Core Workflows

### 1. Workout Creation

**Start from home screen:**
- [ ] Tap "Start Workout" → shows workout selector (if templates exist) or creates blank workout
- [ ] Can start new blank workout
- [ ] Can start workout from template
- [ ] Workout shows "Active" badge
- [ ] Timer shows elapsed time
- [ ] Can edit workout name by tapping pencil icon

### 2. Adding Exercises

**From active workout:**
- [ ] Tap "Add Exercise" → shows exercise search
- [ ] Can search for exercise by name
- [ ] Search results show from built-in library
- [ ] Can select exercise from search results
- [ ] Exercise appears in workout (most recent at top)
- [ ] Quick Add buttons show recent exercises (empty state)

### 3. Logging Sets

**From exercise card/detail:**
- [ ] Can tap exercise to open edit view
- [ ] Can add set with reps and weight
- [ ] Weight +/- buttons adjust value
- [ ] Reps +/- buttons adjust value
- [ ] Can mark set as warmup (toggle)
- [ ] "Log Set" button saves the set
- [ ] Set appears in exercise's set list
- [ ] Set shows correct reps × weight format

### 4. Rest Timer

**After logging a set:**
- [ ] Rest timer option appears (if not auto-start)
- [ ] Can tap to start rest timer
- [ ] Timer counts down correctly
- [ ] Progress bar/ring updates
- [ ] +30s button adds time
- [ ] Skip button dismisses timer
- [ ] Haptic feedback on completion
- [ ] Timer auto-dismisses after completion

**Settings interaction:**
- [ ] Default rest time from settings applies
- [ ] Auto-start setting works when enabled
- [ ] Compound exercises use longer rest (120s)

### 5. Personal Records

**PR detection:**
- [ ] Log a working set with weight and reps
- [ ] If new PR: celebration animation shows
- [ ] Confetti or visual feedback appears
- [ ] PR is saved (check on next session)

**PR comparison:**
- [ ] Exercise shows "First time" for new exercises
- [ ] Shows comparison to previous session

### 6. Ending Workout

**From workout detail:**
- [ ] Tap "End Workout" → confirmation appears
- [ ] "Cancel" returns to workout
- [ ] "End" ends the workout
- [ ] "Save as Template & End" creates template and ends
- [ ] After ending: workout summary shows

**Workout summary:**
- [ ] Duration shows correctly
- [ ] Total exercises count correct
- [ ] Total sets count correct
- [ ] Total volume calculated
- [ ] PRs achieved list (if any)

### 7. Templates

**Creating templates:**
- [ ] From workout list: tap "New Template"
- [ ] Can add exercises to template
- [ ] Template saves correctly
- [ ] Template appears in templates section
- [ ] Can save completed workout as template

**Using templates:**
- [ ] Tap template → shows template detail
- [ ] Can start workout from template
- [ ] New workout has all template exercises
- [ ] Exercises have no sets (fresh start)

**Editing templates:**
- [ ] Can edit template name
- [ ] Can add/remove exercises
- [ ] Can delete template (swipe to delete)

### 8. Workout History

**Viewing history:**
- [ ] Tap "Workout History" → shows history view
- [ ] Workouts grouped by date
- [ ] Most recent first
- [ ] Shows workout name, exercise count, duration
- [ ] Can tap to view completed workout detail

**Deleting history:**
- [ ] Can swipe to delete workout
- [ ] Confirmation appears
- [ ] Workout removed from history

### 9. Settings

**Units:**
- [ ] Open Settings → Units section
- [ ] Can switch between Imperial/Metric
- [ ] Weight display updates throughout app
- [ ] Existing data displays correctly in new unit

**Rest Timer:**
- [ ] Can adjust default rest duration (30-300s)
- [ ] Can toggle auto-start rest timer
- [ ] Changes apply to new workouts

**Profile:**
- [ ] Can edit name
- [ ] Name shows in greeting on home screen

**About:**
- [ ] Version number displays
- [ ] Build number displays
- [ ] Privacy policy link works

### 10. Data Export

**From home screen:**
- [ ] Tap "Export Workout Data"
- [ ] Share sheet appears
- [ ] Can save/share CSV file
- [ ] CSV contains workout data

## Edge Cases

### Empty States
- [ ] No templates: shows empty state message
- [ ] No history: shows empty state message
- [ ] No exercises in workout: shows "Add first exercise" prompt

### Data Integrity
- [ ] Close app during workout → workout still active on relaunch
- [ ] Background app during rest timer → timer continues correctly
- [ ] Unit switch → all historical data displays correctly

### Input Validation
- [ ] Weight cannot be negative
- [ ] Reps cannot be negative or zero
- [ ] Empty exercise name handled gracefully

## Device Testing

### Simulator Testing
- [ ] iPhone 15 (standard size)
- [ ] iPhone 15 Pro Max (large size)
- [ ] iPhone SE (small size)

### Real Device (if available)
- [ ] Haptic feedback works
- [ ] Background timer works
- [ ] Performance acceptable

## Accessibility

- [ ] VoiceOver can navigate main screens
- [ ] Dynamic Type sizes don't break layout
- [ ] Sufficient color contrast

## Performance

- [ ] App launches in < 2 seconds
- [ ] Scrolling is smooth (60 fps)
- [ ] No memory warnings in console

---

## Test Results Template

```
Date: _______________
Tester: _____________
Build: ______________
Device: _____________

[ ] All smoke tests pass
[ ] All core workflows pass
[ ] Edge cases verified

Notes:
_____________________
_____________________
```
