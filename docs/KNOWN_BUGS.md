# TheLogger Known Bugs

Track bugs and their status here. Move fixed bugs to the "Fixed" section for reference.

---

## Critical

Issues that cause crashes or data loss.

*No critical bugs currently tracked.*

---

## High Priority

Issues that significantly impact user experience.

### Weight +/- Buttons Race Condition
**Status:** Open
**Location:** `ContentView.swift` - InlineAddSetView / weight stepper views
**Description:** When rapidly tapping +/- buttons while TextField is focused, the value may not update correctly due to a race condition between TextField's onChange and button action.
**Workaround:** Tap outside TextField to dismiss keyboard before using +/- buttons.
**Fix approach:** Dismiss keyboard on button tap before updating value, or use a debounced update mechanism.

---

## Medium Priority

Issues that are annoying but have workarounds.

### Template Duplication on onAppear
**Status:** Investigating
**Location:** `WorkoutListView.swift`
**Description:** In some cases, templates may appear duplicated briefly when the view appears.
**Workaround:** Pull to refresh or navigate away and back.

### Timer addSeconds Calculation
**Status:** Open
**Location:** `Workout.swift` - RestTimerManager
**Description:** When adding time to an active timer, the totalSeconds may not update correctly relative to remainingSeconds, causing progress ring to show incorrect percentage.
**Workaround:** None needed - visual only, timer completes correctly.

---

## Low Priority

Minor issues or cosmetic problems.

### Keyboard Dismiss Animation
**Status:** Open
**Description:** When dismissing keyboard on some screens, the animation may stutter slightly.
**Impact:** Visual only, no functional impact.

---

## Fixed

Reference for previously fixed bugs.

### Force Unwrap Crash in saveExerciseMemory
**Fixed:** 2026-01-xx
**Location:** `ContentView.swift`
**Description:** Force unwrap of optional `modelContext` caused crash when saving exercise memory.
**Fix:** Changed to `guard let` with early return.

### Multi-Delete Array Index Error
**Fixed:** 2026-01-xx
**Location:** Various delete handlers
**Description:** Deleting multiple items from array caused "index out of bounds" crash.
**Fix:** Sort indices in descending order before deletion:
```swift
for index in indexSet.sorted(by: >) {
    array.remove(at: index)
}
```

### Recent Exercises Order Lost
**Fixed:** 2026-01-xx
**Location:** `ContentView.swift` - recentlyUsedExercises
**Description:** Recent exercises weren't sorted by lastUpdated date.
**Fix:** Use `@Query` with sort descriptor instead of manual sorting.

### Rest Timer Resume Not Called on Cancel
**Fixed:** 2026-01-xx
**Location:** `Workout.swift` - RestTimerManager
**Description:** When user cancelled adding a set, the rest timer didn't resume.
**Fix:** Added `resume()` call in sheet dismiss handler.

---

## Reporting New Bugs

When adding a bug, include:

1. **Status:** Open / Investigating / In Progress / Fixed
2. **Location:** File and function/view name
3. **Description:** What happens and when
4. **Workaround:** How users can avoid the issue
5. **Fix approach:** Ideas for how to fix (if known)

### Example Template

```markdown
### Bug Title
**Status:** Open
**Location:** `FileName.swift` - FunctionOrViewName
**Description:** Description of what happens.
**Workaround:** How to avoid the issue.
**Fix approach:** Potential solution.
```

---

## Bug Triage Priority

| Priority | Criteria |
|----------|----------|
| Critical | Crashes, data loss, security issues |
| High | Blocks core functionality, no workaround |
| Medium | Annoying but has workaround |
| Low | Cosmetic, edge cases, minor UX issues |
