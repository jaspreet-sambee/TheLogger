# TheLogger: Path to Launch

## App Identity

**TheLogger is the first workout app that watches you lift.**

It's a full workout logger with an integrated camera system that counts your reps using on-device pose estimation. No other app bridges these two worlds — workout loggers (Strong, Hevy, FitBod) are all manual entry, and camera rep counters (MyRepsCount, Agit, IETORE) are standalone tools with no logging integration.

**One-liner:** "Point your phone at yourself and it counts your reps."

---

## Competitive Landscape

| Category | Players | Camera? | Logger? |
|----------|---------|---------|---------|
| Workout loggers | Strong, Hevy, FitBod, JEFIT | No | Yes |
| Camera rep counters | MyRepsCount, AI Rep Counter, Agit | Yes | No |
| **TheLogger** | **Us** | **Yes** | **Yes** |

### Key Findings
- No major fitness app offers camera-based rep counting
- No camera rep counter app has a full workout logger
- Motra (Apple Watch, 470+ exercises via accelerometer) is an indirect competitor — no visual feedback, requires watch
- Camera rep counter apps are niche with minimal traction (most <15 exercises, few ratings)

### Competitor Pricing (2026)
| App | Model | Price |
|-----|-------|-------|
| Hevy | Freemium | Free / $49.99/yr |
| Strong | Freemium | Free / $29.99/yr |
| Fitbod | Freemium | Free trial / $79.99/yr |
| WHOOP | Hardware + subscription | $239 device + $30/mo |
| GymBook | One-time | $5.99 |

### Our Advantage
- First-of-category: polished logger + camera rep counting
- 100% on-device processing (Vision framework) — real privacy story
- Visual skeleton overlay = trust + shareable content
- No subscription in a market drowning in subscriptions

### Risks to Mitigate
- Gym practicality (propping phone) — camera is optional, logger works without it
- Accuracy with barbell/plates (occlusion) — focus on clearly visible exercises first
- Privacy perception — lead with "100% on-device, zero data leaves your phone"

---

## Current Status (as of March 2026)

### What's Done ✅
- **20 camera exercises** — all implemented (Push/Pull/Legs)
- **Camera UX** — calibration overlay, confidence indicator (Good/Fair/Poor), skeleton toggle, permission handling, "too flat" warning, exercise picker for unsupported exercises
- **Full logger** — workout flow, templates, PRs with Epley 1RM, rest timer, live activity, onboarding, history, charts
- **Landing page** — built, deployed to `thelogger.app` with custom domain ✅
- **Unit tests** — 288 tests passing across 10 test files
- **PR logic audited** — discard bug fixed, double recalculate removed, Epley formula (no rep cap)
- **Supersets** — full create/break/add/remove support
- **Live Activity** — lock screen countdown during rest timer
- **Progress charts** — exercise 1RM and volume over time
- **PR Timeline** — filterable by muscle group
- **Streak + weekly goal** — gamification layer
- **iCloud backup** — CloudKit enabled

### What's NOT Done ❌

#### Code Fixes (new findings from audit)
- [x] ~~**Rename SDL-Tutorial bundle identifiers**~~ — decided to keep; not visible to users, would disrupt TestFlight testers
- [x] **Fix privacy policy** — added iCloud/CloudKit disclosure, added Camera section, fixed "entirely offline" claim
- [x] **Fix hardcoded "lbs" in camera view** — unit label, initial weight display, and storage conversion all fixed
- [x] **Wrap print() in #if DEBUG** — added global `debugLog()` in Components.swift, replaced 102 print() calls across 13 files
- [x] **Fix fatalError → user alert** — replaced with `.alert` bound to `containerCreationFailed` flag; app stays alive
- [x] **Delete dead CalibrationManager.swift** — confirmed unused, deleted
- [x] **Fix PR logic inconsistency** — PRManager now uses `countsForPR` instead of `.working`; regression tests added
- [x] **Fix duplicate stat cards** — `currentPR` now shows best in last 90 days ("Last 90 Days" card); `allTimeBest` unchanged
- [x] **Fix AnimatedFlame timer leak** — timer stored in `@State`, invalidated in `.onDisappear`
- [x] **Fix force unwraps** — `sorted.first!` / `sorted.last!` replaced with `guard let` in `averageGain`

#### App Store Assets
- [ ] App Store screenshots (7 needed, camera-first) at 1320×2868px
- [ ] App Store preview video (15s trimmed from demo recording)
- [ ] App Store Connect listing filled in (metadata below)
- [ ] App Privacy labels filled in (App Store Connect)
- [ ] `/privacy` page live at `https://thelogger.app/privacy`

#### Final QA
- [x] **Add review request prompt** — triggers at 3rd, 10th, 25th completed workout via `SKStoreReviewController`
- [ ] Real device QA at a real gym (camera with actual weights, different lighting)
- [ ] Test fresh install (simulates reviewer's experience — no existing data)
- [ ] `./run-tests.sh` — all passing before submission

---

## Release Plan

### v1.0 — "It Counts For You"

#### Camera Implementation Status

| Exercise | Joint Tracked | Status |
|----------|---------------|--------|
| Squat | Hip→Knee→Ankle | ✅ Done |
| Push-up | Shoulder→Elbow→Wrist | ✅ Done |
| Bicep Curl | Shoulder→Elbow→Wrist | ✅ Done |
| Shoulder Press | Shoulder→Elbow→Wrist | ✅ Done |
| Lunge | Hip→Knee→Ankle | ✅ Done |
| Tricep Extension | Shoulder→Elbow→Wrist | ✅ Done |
| Lateral Raise | Hip→Shoulder→Wrist | ✅ Done |
| Bent Over Row | Shoulder→Elbow→Wrist | ✅ Done |
| Chest Fly | Hip→Shoulder→Wrist | ✅ Done |
| Tricep Dip | Shoulder→Elbow→Wrist | ✅ Done |
| Leg Extension | Hip→Knee→Ankle | ✅ Done |
| Leg Curl | Hip→Knee→Ankle | ✅ Done |
| Romanian Deadlift | Shoulder→Hip→Knee | ✅ Done |
| Calf Raise | Hip→Knee→Ankle | ✅ Done |
| Pull-up | Shoulder→Elbow→Wrist | ✅ Done |
| Overhead Press | Shoulder→Elbow→Wrist | ✅ Done |
| Deadlift | Shoulder→Hip→Knee | ✅ Done |
| Hip Thrust | Shoulder→Hip→Knee | ✅ Done |
| Face Pull | Shoulder→Elbow→Wrist | ✅ Done |
| Plank | (duration-based) | ✅ Done |

#### Camera UX Polish Status
- [x] Calibration prompt: "Stand where the camera can see your full body"
- [x] Tracking confidence indicator (Good / Fair / Poor dot)
- [x] Skeleton overlay toggle
- [x] "Exercise not supported yet" state with picker fallback
- [x] Camera permission denial handling (graceful fallback with instructions)
- [x] "Too flat" phone orientation warning
- [x] Low visibility auto-pause + recovery
- [x] Rep rejection feedback ("Go deeper", "Too fast")

#### Core App
- [x] Workout creation → exercise logging → set tracking → end summary
- [x] Templates (create, edit, start from, duplicate name warning)
- [x] PR detection (Epley formula, all rep ranges, discard bug fixed)
- [x] PR Timeline on home screen
- [x] Exercise progress charts
- [x] Settings (units, rest timer, goals, profile, PR formula info)
- [x] Onboarding (3-screen flow)
- [x] Live Activity (display during workout)
- [x] Privacy policy (in-app)
- [x] SwiftData with CloudKit + migration strategy
- [x] Haptics throughout
- [x] Workout end-summary dark theme (matches app)
- [x] Supersets
- [x] Streak tracking + weekly goal
- [x] Smart exercise suggestions

---

## Code Fixes — Prioritized

Work through these in order before submission. Each is self-contained.

### 🔴 Must Fix (potential rejection or permanent damage)

#### Fix 1: Rename SDL-Tutorial bundle identifiers
**Why:** Identifiers become permanent on first App Store submission. "SDL-Tutorial" looks like scaffolding.
**Files:**
- `TheLogger/TheLogger.entitlements`
- `TheLoggerWidget/TheLoggerWidget.entitlements` (if exists)
- `TheLogger/WidgetShared.swift` — `appGroupIdentifier` constant
- Xcode target settings → Bundle Identifier for app + widget extension

**Change to:**
- App Bundle ID: `com.thelogger.app`
- iCloud container: `iCloud.com.thelogger.app`
- App Group: `group.com.thelogger.app`

**Test:** Build + run; widget still shows data; CloudKit still syncs.

---

#### Fix 2: Update privacy policy (CloudKit contradiction)
**Why:** Privacy policy says "No accounts, no cloud, no tracking." CloudKit IS enabled. Apple checks this.
**File:** `TheLogger/PrivacyPolicyView.swift`
**Change:** Update data storage section:
> All workout data is stored locally on your device. You can optionally back it up via your personal iCloud account — this uses Apple's iCloud infrastructure, not our servers. We don't have servers.

Also update "Last updated" date.

---

#### Fix 3: Fix hardcoded "lbs" in camera view
**File:** `TheLogger/CameraRepCounter/CameraRepCounterView.swift`, line ~689
**Change:** `Text("lbs")` → `Text(UnitFormatter.weightUnit)`
**Also verify:** The weight value passed through `onLogSet` goes through `UnitFormatter.convertToStorage()` before being saved to `WorkoutSet.weight`.

---

### 🟡 Important (quality + correctness)

#### Fix 4: Wrap print() in #if DEBUG
**Files:** `TheLogger/Workout.swift` (~20 prints in RestTimerManager), `TheLogger/LiveActivityManager.swift` (~16 prints)
**Approach:** Add a helper at the top of each file:
```swift
#if DEBUG
private func debugLog(_ msg: String) { print(msg) }
#else
private func debugLog(_ msg: String) {}
#endif
```
Replace all `print(...)` calls with `debugLog(...)` in those two files. Also wrap/remove prints in `WorkoutListView.swift`, `WorkoutDetailView.swift`, `ExerciseViews.swift`, `CameraRepCounterView.swift`.

---

#### Fix 5: Fix fatalError → user-facing alert
**File:** `TheLogger/TheLoggerApp.swift`, line ~135
**Change:** Replace `fatalError("Could not create ModelContainer: \(error)")` with an `@State var criticalError: Error?` that triggers an `.alert` in the root view.

---

#### Fix 6: Delete dead CalibrationManager.swift
**File:** `TheLogger/CameraRepCounter/CalibrationManager.swift`
**Verify first:** `grep -r "CalibrationManager" TheLogger/` — should return no results.
**Then:** Delete file + remove from Xcode project.

---

#### Fix 7: Fix PR logic inconsistency
**File:** `TheLogger/PRManager.swift`, line ~247
**Current:** `guard set.type == .working && set.reps > 0`
**Change:** `guard set.setType.countsForPR && set.reps > 0`
**Test:** Add test in `TheLoggerTests/PRManagerTests.swift` verifying drop set PRs appear in the timeline.

---

#### Fix 8: Fix duplicate stat cards in ExerciseDetailView
**File:** `TheLogger/ExerciseDetailView.swift`, lines ~25-31
`allTimeBest` and `currentPR` compute identical values. Change `currentPR` to return the best in the last 90 days (filter `chartData` by date) so the two cards show different, meaningful values.

---

#### Fix 9: Fix AnimatedFlame timer leak
**File:** `TheLogger/Animations.swift`, lines ~666-669
Store the `Timer` in `@State`, invalidate in `.onDisappear`. See code pattern in Fix section.

---

#### Fix 10: Fix force unwraps
**File:** `TheLogger/ExerciseDetailView.swift`, lines ~40-41
Replace `sorted.first!` and `sorted.last!` with `guard let first = sorted.first, let last = sorted.last else { return nil }`.

---

#### Fix 11: Add review request prompt
**Where:** After a workout is saved as completed in `WorkoutListView.swift` or wherever `endTime` is set.
**Trigger:** After the 3rd, 10th, and 25th completed workout.
```swift
import StoreKit
let completedCount = workouts.filter { !$0.isTemplate && $0.endTime != nil }.count
if [3, 10, 25].contains(completedCount) {
    if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
        SKStoreReviewController.requestReview(in: scene)
    }
}
```

---

## App Store Submission Checklist

### Metadata (fill in App Store Connect)

**App Name (30 chars):** `TheLogger - Workout Tracker`
**Subtitle (30 chars):** `Camera Rep Counter & Gym Log`
**Promotional Text (170 chars):**
`Count reps with your camera. No wearable needed. Log workouts, track PRs, and see your progress — all on your device, no account required.`

**Keywords (100 chars, no spaces after commas):**
`weightlifting,exercise,fitness,strength,training,sets,personal,record,PR,bodybuilding,lifting`

**Support URL:** `https://thelogger.app`
**Privacy Policy URL:** `https://thelogger.app/privacy`
**Marketing URL:** `https://thelogger.app`
**Primary Category:** Health & Fitness
**Secondary Category:** Sports
**Price:** Free
**Age Rating:** 4+ (answer "None" to all questionnaire items)

**Full Description:**
```
Track your workouts faster than ever — and count reps with just your camera.

TheLogger uses on-device pose detection to count your reps in real time. No wearable needed. No account needed. No data leaves your phone.

CAMERA REP COUNTER
Point your iPhone at yourself while lifting. TheLogger detects your movement and counts every rep automatically. Works for squats, curls, push-ups, rows, and more.

FAST WORKOUT LOGGING
• Log sets in seconds with weight pre-filled from your last session
• Rest timer starts automatically after every set
• Personal Record detection with estimated 1RM tracking
• 139-exercise library with search

PROGRESS TRACKING
• PR timeline shows your strength gains over time
• Exercise progress charts
• Full workout history
• CSV export — your data, always accessible

TEMPLATES & ROUTINES
• Save your program once, start it in one tap
• All exercises and weights pre-loaded

BUILT FOR PRIVACY
• No account required — ever
• All data on your device
• Optional iCloud backup (your iCloud, not ours)
• No ads, no tracking, no subscription

Built by a lifter, for lifters.
```

### Screenshots (7 total, 1320×2868px)

| # | Screen to capture | Overlay text |
|---|------------------|-------------|
| 1 | Camera rep counter — skeleton overlay on squat | "Count Reps With Your Camera" |
| 2 | Active workout — exercise row with weight/reps | "Log Sets in Seconds" |
| 3 | PR celebration with confetti | "Celebrate Every PR" |
| 4 | Rest timer (liquid wave animation) | "Auto Rest Timer" |
| 5 | Exercise progress chart | "Track Your Progress" |
| 6 | Workout list / home screen | "Your Full Gym History" |
| 7 | Template list | "Save Your Routines" |

**How:** Run in Simulator (iPhone 16 Pro Max) → navigate to screen → Cmd+S → add text overlays in Figma/Keynote.

### App Preview Video (15s)
```
0:00–0:03  Skeleton appears on squat
0:03–0:08  Rep counter ticking: 1, 2, 3, 4, 5
0:08–0:12  "Log Set" tapped → set logged in workout view
0:12–0:15  App icon / name card
```
Source: trim from `/Users/jaspreet/Downloads/ScreenRecording_02-24-2026 18-51-48_1.mov`
Must be 1320×2868px — may need to re-record in Simulator at that resolution.

### Privacy Page
Add `Landing/privacy.html` with the full privacy policy text (same content as `PrivacyPolicyView.swift`).
Must be live at `https://thelogger.app/privacy` before submission.

### App Privacy Labels (in App Store Connect)
- Select "Data Not Collected" for all categories
- Camera: used on-device only, no video stored or collected

### Final Checks
- [ ] All code fixes above completed
- [ ] `./run-tests.sh` — 0 failures
- [ ] Tested on real physical device
- [ ] Camera tested in real gym lighting conditions
- [ ] Fresh install tested (delete app, reinstall, go through onboarding)
- [ ] All screenshots uploaded at correct resolution
- [ ] All metadata filled in App Store Connect

---

## Monetization Plan (Week 4-6 Post-Launch)

### Strategy: Freemium + One-Time Purchase

Launch 100% free to build reviews and validate the camera feature. At week 4-6, introduce **TheLogger Pro at $9.99 one-time** (not a subscription — this is the differentiator).

### Free Forever
- Unlimited workout logging
- Camera rep counting (5-6 most common exercises: squats, curls, push-ups, shoulder press, rows)
- Rest timer
- Exercise library
- Up to 3 templates
- Basic workout history

### TheLogger Pro — $9.99 one-time
- Camera rep counting (all 20 exercises)
- Progress charts & analytics
- Full PR timeline
- CSV export
- Unlimited templates
- Workout comparison

### Implementation (when ready)
- Add `.storekit` configuration file for local testing
- Implement `StoreKitManager` using StoreKit 2 (`Product.products(for:)`)
- Add `ProGateView` — shown when user taps a Pro feature
- Gate features with `isPro` check
- Add "Restore Purchases" in Settings
- Update App Store metadata to mention Pro

### Pricing rationale
- $9.99 one-time vs Hevy $49/yr or Strong $30/yr — looks like a steal
- "Pay once, own forever" is a genuine differentiator in 2026
- Subscription contradicts the privacy-first, no-account brand

---

## Marketing Strategy

### Positioning
- **Not** "another workout logger"
- **Is** "the first workout app that watches you lift"
- Privacy is a supporting pillar, not the lead
- Avoid "AI" in casual copy — say "your camera counts your reps" (concrete > buzzword)

### Content Calendar

| # | Post | Content | When |
|---|------|---------|------|
| 1 | Teaser | Camera rep counting demo + skeleton clip | Pre-launch (now) |
| 2 | Launch | "Available on the App Store" + App Store link | Launch day |
| 3 | Dev Story | Technical deep dive on pose detection | Week 1 |
| 4 | Social Proof | First reviews / user reactions | Week 2-3 |
| 5 | v1.1 | "Teach Mode" — teach it any exercise | v1.1 launch |

---

## Demo Video Guide

### No-Face Approach (Recommended)
You don't need to show your face. Crop at chin or show body from shoulders down.
The "phone-screen only" cut (just skeleton overlay + counter) is the most shareable on social.

### What to Record (One 60-90s master take)
```
Segment 1: Setup (5s)      — phone propped, skeleton overlay appears
Segment 2: Squat set (15s) — 5-6 reps, counter ticking up
Segment 3: Log the set (8s) — "Log Set" tapped, set appears in workout view
Segment 4: Bicep curl (12s) — shows it's not just squats
Segment 5: PR moment (8s)  — confetti fires
Segment 6: App overview (10s) — scroll through workout, charts, history
Segment 7: End card (5s)   — App icon + "Available on the App Store"
```

### Best exercises to feature
1. **Squat** — full body, dramatic skeleton, striking visual
2. **Bicep Curl** — relatable, clear tracking
3. **Push-up** — no equipment, easy to film

---

## v1.1 — "Teach It Anything" (4-6 weeks post-launch)

### Teach Mode
User opens camera → "Teach New Exercise" → taps 3 joints to define the angle → shows TOP position → shows BOTTOM position → exercise is now camera-trackable forever.

#### Storage: CustomExerciseProfile (SwiftData)
- `exerciseName` (linked to Exercise)
- `joint1`, `joint2` (vertex), `joint3`
- `upAngle`, `downAngle`
- `isInverted` (auto-detected)
- `dateCreated`

**Marketing:** "Your app doesn't know Bulgarian Split Squats. Mine does, because I taught it."

---

## v1.2 — "It Knows Your Form" (post user feedback)

Candidates based on user requests:
- **Rep Tempo Tracking** — live tempo display, target tempo setting, audio/haptic feedback
- **Range of Motion Tracker** — min/max angles per set over time, depth improvement tracking

---

## v2.0 — Long-Term Vision

- **Form Score** — per-rep quality rating (depth, symmetry, consistency)
- **Ghost Reps** — ghost overlay of previous set's angle curve, race your past self
- **Set Replay** — save skeleton animation of final rep, share clips
- **Apple Watch Companion** — rep counting from wrist to complement camera

---

## Success Metrics (Post-Launch)

### Week 1-2
- App Store approval
- First 10 organic downloads
- No crash reports
- Camera feature used at least once per session on average

### Month 1
- 100+ downloads
- 4.0+ star rating
- User feedback on camera accuracy
- Identify top 3 feature requests

### Month 2-3
- Ship v1.1 (Teach Mode)
- Second marketing push
- Target: 500+ downloads
- First press/blog coverage
