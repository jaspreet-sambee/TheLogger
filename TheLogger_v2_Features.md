# TheLogger V2 — Feature Ideas

## Core Thesis
The camera is the moat. V2 doubles down on what only a camera-based app can do — turning the phone into a **passive AI coach**, not just a rep counter.

---

## Tier 1: Camera Intelligence (The Differentiators)

### 1. Tempo Tracking & Prescription
- **What:** Surface rep tempo as "1.2s down · 0.3s pause · 0.8s up" per set
- **Prescription mode:** User sets target tempo (e.g., 3-1-2 for hypertrophy), gets real-time audio beeps when too fast/slow
- **Data:** Already have phase detection (goingDown/holdingDown/goingUp) + rep duration in RepCounter
- **Effort:** 1-2 days
- **Why unique:** Requires real-time movement phase detection. Text loggers can't do this.

### 2. Range of Motion (ROM) Tracking
- **What:** Store min/max joint angle per rep. Show "ROM consistency" — e.g., "Squat depth was 95° on rep 1 but only 78° on rep 8"
- **Display:** Chart in exercise detail showing ROM per rep across sets
- **Data:** Already compute `currentAngle` per frame — just need to persist min/max per rep
- **Effort:** 1 day to store, 1 day for UI
- **Why unique:** Physiotherapists charge for this. Requires joint angle data from pose detection.

### 3. Form Drift Detection (Cross-Set Comparison)
- **What:** Compare joint angles across sets within a workout. "Your elbow flare increased 15° from set 1 to set 4 — fatigue is affecting form"
- **Display:** Subtle warning after a set, or a form consistency score
- **Data:** Store average angle stats per set, compare across the workout
- **Effort:** 2 days
- **Why unique:** Only possible with per-rep skeletal data. No text logger has this.

### 4. Voice Coaching
- **What:** `AVSpeechSynthesizer` calls out rep counts and cues during a set. "5... 6... slow down... 7... 8, nice!"
- **Modes:** Counting only, counting + tempo cues, counting + encouragement
- **Integration:** Trigger on `repCount` change and `feedback` state changes
- **Effort:** 1 day
- **Why unique:** Combined with the camera, the app becomes a real-time coach. Works with AirPods.

### 5. Movement Symmetry Analysis
- **What:** Compare left vs right joint angles during bilateral exercises. "Right shoulder drops 12° more than left during OHP"
- **Display:** Symmetry score per set, flag imbalances above threshold
- **Data:** Vision provides bilateral joint positions — compare angles on each side
- **Effort:** 2-3 days
- **Why unique:** Requires skeletal tracking of both sides simultaneously.

### 6. Auto-Detect Exercise Type
- **What:** Use pose angles during first 2 reps to classify the exercise instead of manual selection
- **Approach:** Simple decision tree on joint angles (arm above head = OHP, hip hinge = deadlift, etc.)
- **Fallback:** If uncertain, show top 2-3 guesses for user to confirm
- **Data:** Already have ExerciseType enum with angle patterns defined
- **Effort:** 3-4 days
- **Why unique:** Makes the camera feel intelligent. "It just knows what I'm doing."

### 7. Auto-Detect Rest (Phone-Down Detection)
- **What:** Use accelerometer to detect when phone is placed down (set complete → auto-start rest). Detect when user returns to position (auto-show "Ready?")
- **Approach:** `CMMotionManager` — detect orientation change to flat + stillness
- **Effort:** 2 days
- **Why unique:** Removes manual interaction. The workout runs itself.

### 8. Rep Quality Score
- **What:** Grade each set A/B/C/D based on ROM consistency, tempo consistency, and rejection rate
- **Formula:** A = consistent ROM + steady tempo + 0 rejections. D = degrading ROM + erratic tempo + multiple rejections
- **Display:** Badge on the set row: "8 reps · A" vs "8 reps · C"
- **Data:** All data already computed in RepCounter — just need a scoring function
- **Effort:** 1 day
- **Why unique:** Transforms "rep counting" into "rep quality assessment."

---

## Tier 2: Content & Shareability

### 9. Workout Highlight Video
- **What:** Auto-record 3-5 second clips of each set with skeleton overlay, stitch into a 15-30s highlight reel with stats
- **Approach:** `AVAssetWriter` to save camera buffer during sets, `AVMutableComposition` to stitch + overlay
- **Effort:** 3-4 days
- **Why unique:** Skeleton overlay makes videos visually distinctive. "BeReal for gym bros."

### 10. Enhanced Story Cards
- **What:** Auto-generate Instagram Story-sized card after every workout. Show: exercises, PRs, streak, form snapshot, rep quality grades
- **Current:** `WorkoutCardRenderer` exists with basic cards
- **Enhancement:** Add form snapshot photo, quality grades, tempo data
- **Effort:** 1-2 days (building on existing renderer)

### 11. Weekly Recap Video
- **What:** Stitch the week's form snapshots into a 5-second slideshow with stats overlay
- **Approach:** `AVFoundation` with image-to-video pipeline
- **Effort:** 2 days

---

## Tier 3: Smart Logging (Speed)

### 12. Predictive Sets
- **What:** Pre-fill QuickLogStrip based on last 3 sessions + progression pattern. "Last time: 4×8 at 185. You've been adding 5lbs/week. Suggested: 190 lbs"
- **Data:** `ExerciseMemory` + simple linear regression on last 3-4 weights
- **Effort:** 1-2 days

### 13. Auto-Suggest Next Exercise
- **What:** After logging all sets, suggest the next exercise based on template or historical patterns
- **Effort:** 1 day

### 14. Superset Quick-Switch
- **What:** After logging set on exercise A, auto-navigate to exercise B with swipe
- **Data:** Superset model already exists
- **Effort:** 1 day

---

## Tier 4: Gamification & Retention

### 15. Level System (XP)
- **What:** Every set = XP. PRs = bonus. Streaks = multiplier. Level up → confetti + unlock
- **Unlocks:** Themes, icons, card styles at specific levels
- **Effort:** 2 days

### 16. Daily Challenges
- **What:** Auto-generated daily goals from user history. "Lift 5,000 lbs today" / "PR on any exercise"
- **Effort:** 2 days

### 17. App Themes (Unlockable)
- **What:** 6-8 color themes unlocked via achievements/levels
- **Effort:** 1 day

### 18. Alternate App Icons
- **What:** 4-5 icon variants, selectable in Settings
- **Effort:** 0.5 day

---

## Tier 5: Social & Community

### 19. Buddy Leaderboards (CloudKit)
- **What:** Share code with friend, see each other's weekly volume/streak
- **Approach:** CloudKit public database, no backend
- **Effort:** 2-3 days

### 20. Anonymous Percentile
- **What:** "You lifted more than 73% of TheLogger users this week"
- **Approach:** Aggregate anonymous stats via CloudKit
- **Effort:** 1 day

### 21. iMessage Challenges
- **What:** "Challenge a Friend" sends workout summary via iMessage, friend opens app to compare
- **Effort:** 1-2 days

---

## Tier 6: Platform Integration

### 22. Apple Watch Companion
- **What:** Show current exercise, set count, rest timer on wrist. Log sets from watch.
- **Effort:** 4-5 days (new target, WatchConnectivity)

### 23. HealthKit Sync
- **What:** Write workout volume, duration, calories to HealthKit Activity rings
- **Effort:** 1 day

### 24. Live Activity Enhancement
- **What:** Already have basic Live Activity. Add set-by-set progress, timer countdown, PR alerts to Dynamic Island
- **Effort:** 1-2 days

---

## The V2 Vision: "Hands-Free AI Gym Coach"

The endgame for the camera features is the **zero-touch workout:**

1. User props phone up, taps "Start"
2. Camera auto-detects the exercise
3. Counts reps, tracks tempo and ROM
4. Gives real-time voice feedback on form
5. Auto-logs the set when user racks the weight
6. Auto-starts rest timer when phone goes flat
7. Detects return, shows "Set 2 — ready?"
8. After workout, auto-generates highlight video with form grades

No tapping, no typing, no scrolling. Just lift. **That's the product no text-logger can ever build.**

---

## Tier 7: Duolingo-Style Retention Mechanics

### 25. Rest Day Challenges
- **What:** Daily micro-tasks that don't require a gym visit — "Do 50 pushups," "Log your bodyweight," "Stretch for 5 min," or even exercise knowledge quizzes
- **Why:** Changes TheLogger from "gym-day app" to "every-day app." Most gym apps have zero engagement on rest days.
- **Streak integration:** Completing a rest day challenge keeps the streak alive
- **Effort:** 2-3 days
- **Impact:** ⭐⭐⭐⭐⭐ (biggest retention lever)

### 26. Volume Leagues (Anonymous Ranked)
- **What:** Weekly anonymous leaderboard. Bronze → Silver → Gold → Diamond. Top 10 promote, bottom 10 demote.
- **Approach:** CloudKit public DB, anonymous user IDs, weekly volume aggregation
- **Why:** The #1 Duolingo retention mechanic. Fear of demotion > desire to promote.
- **Rewards:** League promotion unlocks themes, badges, card styles
- **Effort:** 3-4 days

### 27. Streak Shields
- **What:** Earn 1 shield per perfect week. Use to protect streak on a rest day without completing a challenge.
- **Creates scarcity** — users hoard shields and fear using them
- **Effort:** 1 day

### 28. XP + Coins Economy
- **What:** Every set = 10 XP. PR = 50 XP. Camera set = 25 XP. Quality A grade = 15 bonus XP. Streak day = 20 XP.
- **Coins:** Earned from league promotions + weekly challenges. Spend on streak shields, themes, card styles, app icons.
- **All client-side.** No real money. Just a tangible progression economy.
- **Effort:** 2 days

### 29. Exercise Mastery Tree
- **What:** Each exercise has levels: Beginner (3 sessions) → Intermediate (10 sessions + consistent form) → Advanced (25 sessions + PRs) → Master (50+ sessions)
- **Visual:** Skill tree UI showing exercise progression paths
- **Unlock mechanic:** "Unlock" advanced exercises by mastering basics (not actually locked — just a visualization)
- **Effort:** 2-3 days

### 30. Smart Notifications
- **What:** Data-driven, personal push notifications:
  - "Your bench was 5 lbs from a PR last week. One more session could be the one 🔥"
  - "12-day streak. Don't break it now."
  - "You haven't trained legs in 12 days."
  - "Your buddy outlifted you by 2,000 lbs this week 😤"
- **Why:** Contextual, not spammy. Camera data makes them uniquely insightful.
- **Effort:** 2 days

### 31. Buddy Challenges
- **What:** "Both log 4 workouts this week" or "Combined volume: 50,000 lbs" — both must complete for reward
- **Sent via iMessage share link.** No accounts needed.
- **Effort:** 2-3 days

---

## Tier 8: Truly Novel / Unique Features

### 32. Coach Mode (Train Your Friend)
- **What:** Flip to rear camera. Your friend works out, YOUR phone counts their reps and tracks their form. You're the coach.
- **Both sets logged** — yours and theirs (shared via link)
- **Why unique:** No app treats the phone as a coaching tool for someone else.
- **Effort:** 2 days (just switch camera + add a "coaching" session mode)

### 33. Ghost Mode (Race Your Past Self)
- **What:** During a set, show a faint overlay of your previous session's rep timing on the rep ring. If you're ahead of your ghost, ring is green. Behind = red.
- **Creates subtle competition against yourself** using real-time camera timing data.
- **Effort:** 2 days

### 34. Workout DNA / Training Fingerprint
- **What:** Generate a unique abstract visual pattern from your training data — muscle group balance, rep ranges, tempo patterns, consistency. Like a fingerprint that changes as you evolve.
- **Shareable vanity feature.** Users post their DNA on socials.
- **Effort:** 2-3 days (generative art from data)

### 35. Body Map Heatmap
- **What:** Visual body silhouette that lights up by muscle group. Red = trained today, orange = this week, gray = neglected.
- **Tap a muscle** → see exercises + last trained date
- **Why unique:** Visual and intuitive. Most apps show muscle groups as text lists.
- **Effort:** 2 days

### 36. PR Playlist (Apple Music Integration)
- **What:** Track which songs were playing during PRs and A-grade sets via MusicKit. Auto-build a "PR Playlist."
- "You PR'd Bench during 'Lose Yourself' 3 times"
- **Effort:** 2 days

### 37. Time Under Tension Leaderboard
- **What:** Compete on total TUT (seconds muscles were loaded) instead of volume. Only measurable with camera tracking.
- **Rewards quality over ego lifting.** Slow controlled reps > fast bouncy reps.
- **Effort:** 1 day (data already exists in rep duration tracking)

### 38. Injury Prevention Score
- **What:** Traffic light score (Green/Yellow/Red) combining: asymmetry trend, ROM degradation, volume spikes, form drift within session.
- **Proactive health feature.** Warns BEFORE injury, not after.
- **Effort:** 2 days

### 39. Progressive Overload Advisor
- **What:** Rules-based advice: "You've hit 8 reps at 185 for 3 sessions → move to 190" or "Volume plateaued 2 weeks → add a drop set" or "ROM decreasing → deload week."
- **Not AI — just heuristics** on progression patterns. Camera data (ROM, tempo, quality) makes advice richer.
- **Effort:** 2-3 days

### 40. Gym Equipment Scanner
- **What:** Point camera at equipment → auto-select exercise. Or scan weight plates → auto-fill weight. Or QR codes for home gym equipment.
- **Simpler v1:** Just QR codes you print and stick on your equipment.
- **Effort:** 2-4 days depending on approach

### 41. Heart Rate Zone Overlay (Apple Watch)
- **What:** If user has Apple Watch, overlay HR data on camera view during sets. "Rep 6 — 165 BPM — Zone 4." Track recovery speed between sets.
- **Why unique:** Merges pose tracking + heart rate. Two data streams nobody else combines.
- **Effort:** 3-4 days (requires HealthKit real-time HR streaming)

---

## Priority Matrix (All 41 Features)

### 🔴 Must-Have for V2 (Camera Differentiators + Retention)

| # | Feature | Effort | Impact | Unique? |
|---|---------|--------|--------|---------|
| 1 | Tempo tracking | 1-2d | ⭐⭐⭐⭐⭐ | ✅ Camera |
| 2 | ROM tracking | 2d | ⭐⭐⭐⭐⭐ | ✅ Camera |
| 4 | Voice coaching | 1d | ⭐⭐⭐⭐⭐ | ✅ Camera |
| 8 | Rep quality score | 1d | ⭐⭐⭐⭐ | ✅ Camera |
| 25 | Rest day challenges | 2-3d | ⭐⭐⭐⭐⭐ | ✅ Novel |
| 26 | Volume leagues | 3-4d | ⭐⭐⭐⭐⭐ | ✅ Novel |
| 30 | Smart notifications | 2d | ⭐⭐⭐⭐⭐ | ✅ Data-driven |

### 🟡 High-Value, Build Soon

| # | Feature | Effort | Impact | Unique? |
|---|---------|--------|--------|---------|
| 3 | Form drift detection | 2d | ⭐⭐⭐⭐ | ✅ Camera |
| 28 | XP + coins economy | 2d | ⭐⭐⭐⭐ | Duolingo-style |
| 33 | Ghost mode | 2d | ⭐⭐⭐⭐ | ✅ Camera |
| 35 | Body map heatmap | 2d | ⭐⭐⭐⭐ | ✅ Visual |
| 38 | Injury prevention score | 2d | ⭐⭐⭐⭐ | ✅ Camera |
| 39 | Progressive overload advisor | 2-3d | ⭐⭐⭐⭐ | ✅ Data-driven |
| 12 | Predictive sets | 1-2d | ⭐⭐⭐⭐ | ❌ |
| 7 | Auto-detect rest | 2d | ⭐⭐⭐⭐ | Partial |
| 37 | TUT leaderboard | 1d | ⭐⭐⭐ | ✅ Camera |

### 🟢 Nice-to-Have

| # | Feature | Effort | Impact | Unique? |
|---|---------|--------|--------|---------|
| 6 | Auto-detect exercise | 3-4d | ⭐⭐⭐⭐⭐ | ✅ Camera |
| 9 | Highlight video | 3-4d | ⭐⭐⭐⭐ | ✅ Camera |
| 5 | Symmetry analysis | 2-3d | ⭐⭐⭐ | ✅ Camera |
| 15 | Level system (XP) | 2d | ⭐⭐⭐ | ❌ |
| 27 | Streak shields | 1d | ⭐⭐⭐ | Duolingo-style |
| 29 | Exercise mastery tree | 2-3d | ⭐⭐⭐ | ❌ |
| 32 | Coach mode | 2d | ⭐⭐⭐ | ✅ Novel |
| 34 | Workout DNA | 2-3d | ⭐⭐⭐ | ✅ Novel |
| 36 | PR playlist | 2d | ⭐⭐⭐ | ✅ Novel |
| 17 | App themes | 1d | ⭐⭐ | ❌ |
| 18 | Alternate app icons | 0.5d | ⭐⭐ | ❌ |
| 23 | HealthKit sync | 1d | ⭐⭐⭐ | ❌ |

### 🔵 Future / Post-V2

| # | Feature | Effort | Impact | Unique? |
|---|---------|--------|--------|---------|
| 19 | Buddy leaderboards | 2-3d | ⭐⭐⭐ | ❌ |
| 22 | Apple Watch | 4-5d | ⭐⭐⭐ | ❌ |
| 31 | Buddy challenges | 2-3d | ⭐⭐⭐ | ❌ |
| 40 | Gym equipment scanner | 2-4d | ⭐⭐ | Partial |
| 41 | HR zone overlay | 3-4d | ⭐⭐⭐ | ✅ Novel |
