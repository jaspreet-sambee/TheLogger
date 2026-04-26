# V2 Build Plan — Final Features

## Selected Features
1. **Tempo Tracking** (#1) — Per-rep tempo from camera
2. **Daily Challenges** (#16) — Gym-day challenges
3. **Rest Day Challenges** (#25) — Non-gym-day engagement
4. **Smart Notifications** (#30) — Contextual push notifications
5. **Progressive Overload Advisor** (#39) — "What to do next" suggestions
6. **Camera Auto-Rest** (#7 enhanced) — After logging a set via camera, auto-start rest timer, then auto-return to counting. The phone is never touched during an exercise.

## The Camera Flow Vision

The complete hands-free exercise flow:
```
User props phone → taps Start → camera opens
  ↓
Camera detects pose → arms → counts reps (with tempo display)
  ↓
Set complete → user taps "Log Set" (or future: auto-detect rack)
  ↓
Set logged → REST TIMER AUTO-STARTS in camera view (gold countdown ring)
  ↓
Timer counts down → user rests
  ↓
Timer ends → camera auto-re-arms → "Set 2 — Go!"
  ↓
Counts next set... repeat until done
  ↓
User taps Close → back to exercise edit view with all sets logged
```

**Key insight:** The rest timer currently only works in ExerciseEditView. For the camera flow, the rest timer needs to work INSIDE CameraRepCounterView — overlaid on the camera feed, same gold ring design, then transition back to counting mode.

---

## Phase A: Tempo Tracking (1.5 days)

### A1. RepMetrics Data Collection
**File:** `CameraRepCounter/RepCounter.swift`
- Add `struct RepMetrics`: downDuration, holdDuration, upDuration, totalDuration, minAngle, maxAngle, rom, avgConfidence
- Add `var completedRepMetrics: [RepMetrics] = []` published array
- In `completeRep()` (line ~466): compute phase durations from timestamps, create RepMetrics, append to array
- Track phase transition timestamps: `downStartTime`, `holdStartTime`, `upStartTime` (some already exist as `phaseStartTime`)

### A2. WorkoutSet Model Extension
**File:** `Models/WorkoutSet.swift`
- Add `var tempoDown: Double?` — average eccentric duration (seconds)
- Add `var tempoHold: Double?` — average pause duration
- Add `var tempoUp: Double?` — average concentric duration
- All optional → lightweight migration, no schema bump

### A3. Camera UI — Tempo Display
**File:** `CameraRepCounter/CameraRepCounterView.swift`
- In bottom panel, add a tempo display row showing last rep's tempo: "↓ 1.2s · ↓↓ 0.3s · ↑ 0.8s"
- Color code: green if consistent with previous reps, yellow if deviating >30%
- On set log, compute averages and save to WorkoutSet

### A4. Set Row — Tempo Badge
**File:** `Features/Sets/InlineSetRowView.swift`
- In display mode (performanceLabel), optionally show tempo if available: "135 × 10 · 2-1-1"
- Small, subtle — don't clutter the row

---

## Phase B: Camera Auto-Rest (2 days)

### B1. Rest Timer Inside Camera View
**File:** `CameraRepCounter/CameraRepCounterView.swift`
- After `logCurrentSet()`, instead of just resetting the rep counter:
  1. Show a rest timer overlay on the camera feed (gold ring, same design as ExerciseEditView's RestTimerView)
  2. Camera preview continues running (user can see themselves resting)
  3. Countdown: use `RestTimerManager.shared` or a local timer
  4. Duration: read from user's rest timer setting or exercise-specific preference
- Bottom panel during rest: countdown + "+30s" + "Skip" buttons (replace the log/reset buttons)

### B2. Auto-Re-Arm After Rest
- When rest timer completes:
  1. Reset rep counter (`repCounter.reset()`)
  2. Update set number display ("Set 3 — Go!")
  3. Camera automatically starts watching for the next set
  4. Brief "Ready!" feedback pill
- The user never leaves the camera view between sets

### B3. Camera State Machine Enhancement
- Current states: counting / complete / paused
- New states: `resting` (between sets)
- The bottom panel switches between:
  - **Counting mode:** sensitivity picker + weight/rep controls + log/reset buttons
  - **Resting mode:** countdown ring + extend/skip buttons + set history

### B4. Integration with RestTimerManager
- Use `RestTimerManager.shared.offerRest(for:duration:autoStart:)` — already handles the timer logic
- Listen to `restTimer.isComplete` to know when to re-arm
- Respect user's `autoStartRestTimer` preference

---

## Phase C: Daily Challenges + Rest Day Challenges (4 days)

### C1. Challenge Model
**New file:** `Models/DailyChallenge.swift`
```swift
struct DailyChallenge: Codable {
    let id: String           // "2026-04-01-volume-5000"
    let date: Date
    let type: ChallengeType
    let target: Int          // target value
    let description: String  // "Lift 5,000 lbs today"
    var progress: Int = 0
    var isCompleted: Bool = false
}

enum ChallengeType: String, Codable {
    // Gym-day challenges
    case volumeTarget     // "Lift X lbs"
    case setCount         // "Complete X sets"
    case prAttempt        // "Try to beat your X PR"
    case variety          // "Train a muscle you haven't hit in 7 days"

    // Rest-day challenges
    case bodyweight       // "Do 50 pushups"
    case mobility         // "Stretch for 5 minutes"
    case quiz             // "Answer 3 exercise questions"
}
```

### C2. Challenge Generator
**New file:** `Services/ChallengeGenerator.swift`
- On app launch, check if today's challenge exists in UserDefaults
- If not, generate based on:
  - Is this a rest day (no workout started today)?
  - User's average volume/sets (scale challenge to their level)
  - Which muscle groups are neglected
  - Whether they're close to any PRs
- Store as JSON in UserDefaults with date key

### C3. Rest Day Challenge UI
**New file:** `Features/Challenges/RestDayChallengeView.swift`
- Bodyweight challenge: simple rep counter (manual +/- buttons, no camera needed)
- Mobility challenge: countdown timer ("Hold stretch for 60s")
- Quiz challenge: 3 multiple-choice questions about exercise form/muscles
- Completion → keeps streak alive, awards XP

### C4. Home Screen Integration
**File:** `Features/Workout/WorkoutListView.swift`
- Show challenge banner card at top of Home screen
- "Today's Challenge: Lift 5,000 lbs" with progress bar
- Or on rest days: "Rest Day Challenge: 50 Pushups" with completion button

### C5. Streak Integration
**File:** `Services/GamificationEngine.swift`
- Modify streak calculation: a day counts if user completed a workout OR a rest day challenge
- Add `restDayChallengesCompleted: [Date]` tracking

---

## Phase D: Smart Notifications (2 days)

### D1. Notification Setup
**File:** `App/TheLoggerApp.swift`
- Request `UNUserNotificationCenter` authorization on first launch
- Register notification categories

### D2. Notification Scheduler
**New file:** `Services/NotificationScheduler.swift`
- Runs on app background / close
- Schedules contextual notifications based on:

| Trigger | Message | Timing |
|---------|---------|--------|
| Streak at risk | "12-day streak. Don't break it 🔥" | Evening if no workout today |
| PR proximity | "Your bench was 5 lbs from a PR. One more session!" | Morning after relevant workout |
| Muscle neglect | "You haven't trained legs in 12 days" | Morning, once per neglected group |
| Daily challenge | "Today's challenge: 50 pushups. 2 min to keep your streak!" | Afternoon on rest days |
| Weekly recap | "This week: 4 workouts, 12.4k lbs, 2 PRs! 🏆" | Sunday evening |
| Comeback | "Haven't seen you in 5 days. Quick bodyweight session?" | After 5+ day gap |

### D3. Settings
**File:** `Features/Settings/SettingsView.swift`
- Notification time preference (morning/evening)
- Toggle categories on/off
- Master notification toggle

---

## Phase E: Progressive Overload Advisor (2 days)

### E1. Overload Advisor Service
**New file:** `Services/OverloadAdvisor.swift`
- Query last 3-4 sessions for a given exercise from SwiftData
- Apply rules:

| Rule | Condition | Suggestion |
|------|-----------|------------|
| Weight increase | Hit target reps (e.g., 3×8) for 2+ consecutive sessions | "Increase to X+5 lbs" |
| Rep increase | Hit target reps but weight is stuck | "Try for 1 more rep at X lbs" |
| Volume plateau | Total volume flat for 2+ weeks | "Add a drop set or extra set" |
| Tempo degradation | Average tempo speeding up session over session (needs Phase A) | "Slow down — focus on 2-1-2 tempo" |
| Deload signal | Volume spike + form degradation signals | "Consider a deload week" |

### E2. Suggestion Display
**File:** `Features/Exercise/ExerciseEditView.swift`
- Show as a subtle card between the note section and the SETS section
- "💡 You hit 8 reps at 185 two sessions in a row. Try 190 today."
- Dismissable — user can swipe away
- Only shows when there's a meaningful suggestion

### E3. Data Requirements
- Needs: last 3+ sessions of the same exercise (query from completed workouts)
- Enhanced with: tempo data from Phase A (tempo trend)
- Uses: `ExerciseMemory` for quick lookup, `PersonalRecord` for PR context

---

## Total Effort

| Phase | Feature | Days |
|-------|---------|------|
| A | Tempo tracking | 1.5 |
| B | Camera auto-rest | 2 |
| C | Daily + rest day challenges | 4 |
| D | Smart notifications | 2 |
| E | Progressive overload advisor | 2 |
| **Total** | | **~11.5 days** |

## Build Order

1. **Phase A** first — Tempo data is the foundation. Other features get better with it.
2. **Phase B** next — Camera auto-rest completes the "hands-free" story.
3. **Phase C** — Challenges create the daily habit loop.
4. **Phase D** — Notifications bring users back.
5. **Phase E** — Advisor ties it all together with smart coaching.

## New Files Summary

| File | Purpose |
|------|---------|
| `Models/DailyChallenge.swift` | Challenge data model |
| `Services/ChallengeGenerator.swift` | Daily/rest-day challenge generation |
| `Services/NotificationScheduler.swift` | Smart push notifications |
| `Services/OverloadAdvisor.swift` | Progressive overload suggestions |
| `Features/Challenges/RestDayChallengeView.swift` | Rest day challenge UI |

## Modified Files Summary

| File | What Changes |
|------|-------------|
| `CameraRepCounter/RepCounter.swift` | RepMetrics struct, phase timing, data collection |
| `CameraRepCounter/CameraRepCounterView.swift` | Tempo display, rest timer overlay, auto-re-arm |
| `Models/WorkoutSet.swift` | Optional tempo properties (lightweight migration) |
| `Features/Sets/InlineSetRowView.swift` | Tempo badge in display mode |
| `Features/Workout/WorkoutListView.swift` | Challenge banner on Home screen |
| `Features/Exercise/ExerciseEditView.swift` | Overload advisor card |
| `Services/GamificationEngine.swift` | Streak counts rest day challenges |
| `Features/Settings/SettingsView.swift` | Notification settings |
| `App/TheLoggerApp.swift` | Notification permission request |

---

## Data & Compatibility Impact Assessment

### Will this break existing data? NO.

**WorkoutSet model changes (Phase A):**
- Adding `tempoDown: Double?`, `tempoHold: Double?`, `tempoUp: Double?` — all **optional**
- SwiftData handles optional property additions as **lightweight migrations** automatically
- Existing WorkoutSet records get `nil` for these fields — no data loss
- No schema version bump needed (optional additions don't require `VersionedSchema`)
- Existing sets display exactly as before (tempo badge only shows when data is non-nil)

**No model changes for other phases:**
- Phase B (Camera auto-rest): purely UI changes in CameraRepCounterView + RestTimerManager usage
- Phase C (Challenges): stored in UserDefaults (JSON), not SwiftData. No model migration.
- Phase D (Notifications): UNUserNotificationCenter — system API, no model changes
- Phase E (Overload advisor): read-only queries on existing data. No writes to new fields.

### Will this break existing features? NO.

| Concern | Assessment |
|---------|------------|
| **Existing workout logging** | Untouched. Tempo is only recorded from camera sets. Manual sets get nil tempo. |
| **PR detection** | Untouched. Uses weight + reps, doesn't read tempo fields. |
| **Rest timer** | Phase B adds a new usage context (inside camera) but doesn't change the existing ExerciseEditView rest timer flow. |
| **Templates** | Untouched. Templates don't have tempo data — they still work as before. |
| **Export/Import** | JSON export/import will need `tempoDown`/`tempoHold`/`tempoUp` added to DTOs (additive, backward compatible). Old exports import fine (missing fields → nil). |
| **Widget / Live Activity** | Untouched. Widget reads exercise name + set count, doesn't touch tempo. |
| **Streak calculation** | Phase C modifies this — rest day challenges will count toward streaks. This is additive (more ways to keep a streak, not fewer). Existing gym-day streaks still count. |
| **Achievement system** | Phase C may add new achievements for challenges. Existing achievements untouched. |
| **Tests** | All 444+ existing tests should pass. New features need new tests. |

### Migration Path
1. **Before building:** Run `./run-tests.sh` — confirm 0 failures baseline
2. **After Phase A:** Run tests — WorkoutSet changes are lightweight, no test should break
3. **After each phase:** Run tests — each phase is additive, not destructive
4. **CloudKit sync:** Optional tempo fields sync automatically (CloudKit handles optional additions). Devices running older versions simply ignore the new fields.

### Rollback Safety
Every change is additive. If any phase needs to be reverted:
- Phase A: Remove tempo properties from WorkoutSet → SwiftData ignores missing optional fields on next migration
- Phase B: Revert CameraRepCounterView changes → rest timer goes back to ExerciseEditView-only
- Phase C: Remove UserDefaults challenge data → app works as before
- Phase D: Remove notification scheduling → no more push notifications
- Phase E: Remove advisor card from ExerciseEditView → no suggestions shown
