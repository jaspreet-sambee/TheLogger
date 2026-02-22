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
- "Teach Mode" (user-defined exercise tracking) exists in zero consumer apps
- Motra (Apple Watch, 470+ exercises via accelerometer) is an indirect competitor but different approach — no visual feedback, requires watch
- Camera rep counter apps are niche with minimal traction (most <15 exercises, few ratings)

### Our Advantage
- First-of-category: polished logger + camera rep counting
- Teach Mode (v1.1) is genuinely novel and defensible
- 100% on-device processing (Vision framework) — real privacy story
- Visual skeleton overlay = trust + shareable content

### Risks to Mitigate
- Gym practicality (propping phone) — camera is optional, logger works without it
- Accuracy with barbell/plates (occlusion) — focus on clearly visible exercises
- Privacy perception — lead with "100% on-device, zero data leaves your phone"

---

## Release Plan

### v1.0 — "It Counts For You" (Target: 3 weeks)

#### Camera Expansion: 5 → 15 exercises

**Currently supported (5):**
| Exercise | Joint Tracked | Status |
|----------|---------------|--------|
| Squat | Hip→Knee→Ankle | Done |
| Push-up | Shoulder→Elbow→Wrist | Done |
| Bicep Curl | Shoulder→Elbow→Wrist | Done |
| Shoulder Press | Shoulder→Elbow→Wrist | Done |
| Lunge | Hip→Knee→Ankle | Done |

**To add (10):**
| Exercise | Joint Tracked | Difficulty |
|----------|---------------|------------|
| Tricep Extension | Shoulder→Elbow→Wrist | Trivial (curl variant) |
| Lateral Raise | Hip→Shoulder→Wrist | Medium (new joint combo) |
| Leg Extension | Hip→Knee→Ankle | Trivial (squat joints) |
| Leg Curl | Hip→Knee→Ankle | Trivial (inverted) |
| Romanian Deadlift | Shoulder→Hip→Knee | Medium (new joint combo) |
| Bent Over Row | Shoulder→Elbow→Wrist | Easy (curl-like) |
| Calf Raise | Knee→Ankle→Toe | Medium (foot joint) |
| Pull-up | Shoulder→Elbow→Wrist | Medium (tricky angle) |
| Chest Fly | Shoulder→Elbow→Wrist | Easy (wide angle) |
| Tricep Dip | Shoulder→Elbow→Wrist | Easy (press variant) |

#### Camera UX Polish
- [ ] Calibration prompt: "Stand where the camera can see your full body"
- [ ] Tracking confidence indicator (green/yellow/red border or icon)
- [ ] Skeleton overlay toggle (some users find it distracting)
- [ ] "Exercise not supported yet" state with Teach Mode tease
- [ ] Camera permission denial handling (graceful fallback with instructions)
- [ ] Brief loading/initializing state before detection starts

#### Core App (already done, verify)
- [x] Workout creation → exercise logging → set tracking → end summary
- [x] Templates (create, edit, start from)
- [x] PR detection with celebration + confetti
- [x] PR Timeline on home screen
- [x] Exercise progress charts
- [x] Settings (units, rest timer, goals, profile)
- [x] Onboarding (3-screen flow)
- [x] Live Activity (display during workout)
- [x] Privacy policy
- [x] SwiftData with CloudKit + migration strategy
- [x] Haptics throughout

#### Bug Fixes Before Launch
- [x] PR Home Widget not updating after new PRs (fixed: cache invalidation + notification)

#### App Store Submission Prep
- [ ] App Store screenshots (5-7, camera-first)
  - Screenshot 1: Camera counting squats with skeleton overlay
  - Screenshot 2: Rep count ticking up mid-set
  - Screenshot 3: Set automatically logged in workout view
  - Screenshot 4: PR celebration with confetti
  - Screenshot 5: Workout summary with stats
  - Screenshot 6: Template list / home screen
  - Screenshot 7: Settings / onboarding
- [ ] App Store preview video (15s): camera counting → set logged → next exercise
- [ ] App Store description
- [ ] App Store keywords
- [ ] App Store category: Health & Fitness
- [ ] App title: "TheLogger: AI Workout Tracker"
- [ ] App subtitle: "Camera counts your reps"
- [ ] Support URL
- [ ] External privacy policy URL
- [ ] Verify app icon (1024x1024 for App Store)
- [ ] Run full test suite, all passing
- [ ] Real device QA (camera, workout flow, PR detection)
- [ ] Test on at least 2 iPhone models

#### App Store Description (Draft)

**Short description:**
TheLogger watches you work out. Point your phone camera at yourself and it counts your reps automatically using on-device AI. No cloud, no account, no typing between sets. Just lift.

**Full description:**

TheLogger is the workout tracker that actually tracks your workout. Using your phone's camera and on-device pose estimation, it counts your reps in real-time — no tapping, no typing, no fumbling between sets.

CAMERA REP COUNTING
- Point your phone at yourself during any supported exercise
- Real-time skeleton overlay shows what the app sees
- Reps counted automatically as you move
- 15 exercises supported including squats, bench press, curls, and more
- 100% on-device — your camera feed never leaves your phone

FULL WORKOUT LOGGER
- Log sets with weight, reps, and set type (working, warmup, drop, AMRAP)
- Create and reuse workout templates
- Auto-fill from your exercise history
- Per-exercise rest timer with customizable duration
- Superset support

PERSONAL RECORDS
- Automatic PR detection with estimated 1RM calculation
- Confetti celebration when you hit a new record
- PR Timeline showing your recent achievements
- Exercise progress charts over time

PRIVACY FIRST
- All data stays on your device
- iCloud backup via CloudKit (your iCloud, not ours)
- No account required
- No tracking, no ads, no third-party services
- Camera processing is 100% on-device using Apple's Vision framework

---

### v1.1 — "Teach It Anything" (4-6 weeks post-launch)

The differentiator update. The feature nobody else has.

#### Teach Mode
- User opens camera, selects "Teach New Exercise"
- App shows detected skeleton with labeled joints
- User taps 3 joints to define the angle to track
- App prompts: "Show me the TOP position" → captures angle
- App prompts: "Show me the BOTTOM position" → captures angle
- Exercise is now camera-trackable forever

#### Storage: CustomExerciseProfile (SwiftData)
- exerciseName (linked to Exercise)
- joint1, joint2 (vertex), joint3
- upAngle, downAngle
- isInverted (auto-detected from angle ordering)
- dateCreated

#### Smart Exercise Detection
- Auto-identify exercise from movement pattern (3-5 second observation)
- "Looks like you're doing Bicep Curls — is that right?"

#### Marketing Moment
- This is the post/video that goes viral
- "Your app doesn't know Bulgarian Split Squats. Mine does, because I taught it."

---

### v1.2 — "It Knows Your Form" (post user feedback)

Build based on what users actually request. Candidates:

#### Rep Tempo Tracking
- Live tempo display: "2s down / 1s pause / 1.5s up"
- Target tempo setting for training protocols
- Audio/haptic cue if going too fast or slow
- Post-set tempo chart

#### Range of Motion Tracker
- Track min/max angles per set over time
- "Your squat depth improved 12 degrees this month"
- Alert if ROM decreasing (fatigue/injury indicator)

---

### v2.0 — Long-Term Vision

#### Form Score
- Per-rep quality rating based on depth, symmetry, consistency
- Average form score per set
- "Form PRs" alongside weight PRs

#### Ghost Reps
- Ghost overlay of previous set's angle curve
- Race your past self
- Visual indicator: "You're 0.5s ahead of last time"

#### Set Replay
- Save skeleton animation of final rep (tiny data, no video)
- Replay in set details
- Share clips with skeleton overlay

#### Apple Watch Companion
- Rep counting from wrist (accelerometer-based)
- Complement camera when phone isn't propped up

---

## Marketing Strategy

### Positioning
- **Not** "another workout logger"
- **Is** "the first workout app that watches you lift"
- Privacy is a supporting pillar, not the lead

### Content Calendar

| # | Post | Content | When |
|---|------|---------|------|
| 1 | Teaser | "Building a workout app that uses your camera to count reps" + demo video | Pre-launch |
| 2 | Launch | "It works for 15 exercises. Here's the full list" + App Store link | Launch day |
| 3 | Dev Story | "The hardest part was bicep curls — angle detection is inverted" + technical deep dive | Week 1 |
| 4 | Social Proof | User reactions / first reviews | Week 2-3 |
| 5 | Teach Mode | "You can now TEACH it any exercise" + Teach Mode demo | v1.1 launch |
| 6 | Tempo | "It tracks your rep tempo now. Turns out I cheat my last 3 reps." | v1.2 launch |

### The Hero Shot (always)
Phone propped at gym → camera sees user → skeleton overlay → rep count ticking up → set logged automatically.

---

## Implementation Priority (v1.0)

### Week 1: Camera Expansion
1. Add 10 new exercises to ExerciseType.swift with thresholds
2. Test each exercise on real device
3. Update exercise name matching for auto-detection
4. Fix any accuracy issues with new joint combinations

### Week 2: Camera UX Polish + Bug Fixes
1. Calibration prompt
2. Confidence indicator
3. Skeleton toggle
4. Unsupported exercise state
5. Camera permission handling
6. Run full test suite, fix failures
7. Real device QA

### Week 3: App Store Prep + Submit
1. Screenshots (camera-first)
2. Preview video
3. Description, keywords, metadata
4. Support URL, privacy policy URL
5. Final QA on 2+ devices
6. Submit to App Review

---

## Success Metrics (Post-Launch)

### Week 1-2
- App Store approval
- First 10 organic downloads
- No crash reports
- Camera feature actually used (can track via analytics later)

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
