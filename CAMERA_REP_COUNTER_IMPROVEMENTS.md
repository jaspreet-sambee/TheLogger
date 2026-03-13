# Camera Rep Counter: Smarter Detection & False Positive Fix

## Problem

The camera rep counter counts setup movements (racking/unracking, adjusting position, getting into stance) as reps. Fix must not interrupt workout flow.

---

## Phase 1: Core False Positive Fix

### 1.1 — Four-State State Machine (RepCounter.swift)

Replace 2-state (up/down) with 4-state:

```
idle → armed → down → up → down → up → ... → (auto-disarm) → idle
```

- **`idle`**: Camera on, angles observed, NO reps counted. Waits for stable position near start angle for ~0.7s (20 frames).
- **`armed`**: User in starting position. Ready for first rep.
- **`down`**: Lowering/eccentric phase.
- **`up`**: Rep completion (after validation).

**Stability detection** (idle → armed): Angle within 8° of `upThreshold` AND angular velocity < 1.5°/frame for 20 consecutive frames. No user action needed.

**Auto-disarm**: No rep for 8s AND angle far outside exercise zone → back to `idle`. Prevents counting racking/unracking.

### 1.2 — Rep Quality Validation

Three checks before accepting a rep:

| Check | Threshold | Filters out |
|-------|-----------|-------------|
| Minimum ROM | 40% of expected | Setup adjustments, partial movements |
| Minimum duration | 0.6s per cycle | Jerky non-exercise movements |
| Hysteresis | 8% of expected ROM | Threshold boundary oscillation |

ROM example (squat): expected = 45° (155-110), minimum = 18°.

### 1.3 — Better Smoothing

Replace 5-frame simple average:

1. **Outlier rejection**: Discard single-frame jumps > 40° (Vision glitches)
2. **EMA (α=0.3)**: Exponential moving average — responsive yet smooth
3. **Angular velocity**: From EMA, used for stability detection

### 1.4 — New Feedback States

- `settingUp` → "Setting up..." (idle, no stability)
- `almostReady` → "Hold steady..." (partial stability + progress bar)
- `armed` → "Ready!" (green flash)
- `tooShallow` → "Too shallow" (rep rejected)

### Key Thresholds

| Parameter | Value | Rationale |
|-----------|-------|-----------|
| requiredStabilityFrames | 20 (~0.7s) | Confirms hold, not annoying |
| stabilityAngleTolerance | 8° | Body sway is 3-5° |
| stabilityVelocityThreshold | 1.5°/frame | Breathing ≈ 0.5-1.0 |
| EMA alpha | 0.3 | Responsive yet smooth |
| outlierThreshold | 40° | Single-frame spike = noise |
| minimumROM | 40% of expected | Catches setup, allows partials |
| minimumRepDuration | 0.6s | Fastest real rep ≈ 0.8s |
| hysteresis | 8% of expected ROM | Prevents oscillation |
| autoDisarmTimeout | 8s | Allows rest-pause, catches racking |

### Files to Modify

- `TheLogger/CameraRepCounter/RepCounter.swift` — Full rewrite
- `TheLogger/CameraRepCounter/ExerciseType.swift` — Add `expectedROM`, `minimumROM`, `hysteresis` to JointConfiguration
- `TheLogger/CameraRepCounter/CameraRepCounterView.swift` — Stability progress bar, new feedback, larger undo button
- `TheLoggerTests/RepCounterTests.swift` — New test file

---

## Phase 2: More Exercises & Calibration

### 2.1 — New Hard-Coded Exercises

| Exercise | Joints | Down° | Up° |
|----------|--------|-------|-----|
| Hip Thrust | shoulder→hip→knee | 100 | 160 |
| Front Raise | hip→shoulder→wrist | 25 | 80 |
| Upright Row | hip→shoulder→elbow | 20 | 70 |

Expand name matching for more variants.

### 2.2 — Calibration-Based Custom Mode

For unsupported exercises:

1. User picks "Calibrate for this exercise"
2. "Do 3 slow reps" — system tries all joint triples
3. Picks triple with largest consistent oscillation
4. Sets thresholds with 10% buffer
5. Stores per exercise name in @AppStorage

New file: `CalibrationManager.swift`

---

## Edge Cases to Fix

_Add observations from testing below:_

- [ ] _(testing in progress — add specific false positive scenarios here)_
