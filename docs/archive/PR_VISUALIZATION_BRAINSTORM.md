# PR Visualization & Progress Tracking - UX Brainstorm

**Date:** 2026-02-05
**Goal:** Make users answer "Am I getting stronger?" with data visualization
**Current State:** PRs detected but only shown once at workout end summary, then lost forever

---

## 🎯 Core User Questions We Need to Answer

1. **"Am I getting stronger?"** → Show PR progression over time
2. **"What are my current PRs?"** → List all current bests
3. **"When did I last PR?"** → Date/recency info
4. **"How close am I to a PR right now?"** → During-workout awareness
5. **"Which exercises am I improving at?"** → Comparative view
6. **"Where am I plateauing?"** → Stagnation detection

---

## 📊 Current PR Data Available

### PersonalRecord Model (Current Best Only)
```swift
- exerciseName: String (normalized)
- weight: Double (lbs)
- reps: Int
- date: Date (when achieved)
- workoutId: UUID (links to workout)
- estimated1RM: Double (calculated)
```

**Limitation:** Only stores CURRENT best per exercise (overwrites on new PR)

### Historical Data (Workout Archive)
```swift
Workout
  - date: Date
  - exercises: [Exercise]
    - name: String
    - sets: [WorkoutSet]
      - weight: Double
      - reps: Int
      - setType: SetType (.working, .warmup, etc.)
```

**Opportunity:** Can reconstruct PR history by querying all workouts!

---

## 🎨 UX Design Options - Phase A: PR Timeline

### Option 1A: "Feed" Style (Chronological)
**Layout:** Scrollable timeline, newest first
**Visual:** Card per PR achievement with date badge

```
┌─────────────────────────────────────┐
│ 🏆 New PR - Feb 5, 2026            │
│                                     │
│ Bench Press                         │
│ 225 lbs × 5 reps                    │
│ Est. 1RM: 253 lbs                   │
│                                     │
│ Previous: 215 lbs × 5 (Jan 29)     │
│ Progress: +10 lbs 📈                │
└─────────────────────────────────────┘

┌─────────────────────────────────────┐
│ 🏆 New PR - Feb 3, 2026            │
│                                     │
│ Squat                               │
│ 315 lbs × 3 reps                    │
│ Est. 1RM: 335 lbs                   │
│                                     │
│ Previous: 305 lbs × 3 (Jan 15)     │
│ Progress: +10 lbs 📈                │
└─────────────────────────────────────┘
```

**Pros:**
- Chronological story of progress
- Easy to see recent momentum
- Celebrates every achievement
- Natural scroll pattern (familiar from social)

**Cons:**
- Hard to compare exercises side-by-side
- Can't see "which exercise needs work"
- Scrolling required to find specific exercise

---

### Option 1B: "Leaderboard" Style (Grouped by Exercise)
**Layout:** List of exercises, sorted by recency or 1RM
**Visual:** Exercise card with current PR + date

```
┌─────────────────────────────────────┐
│ FILTER: All Exercises ▼  SORT: Recent ▼│
└─────────────────────────────────────┘

┌─────────────────────────────────────┐
│ Bench Press                    →    │
│ 225 lbs × 5 reps                    │
│ Est. 1RM: 253 lbs                   │
│ Feb 5, 2026 (2 days ago)            │
└─────────────────────────────────────┘

┌─────────────────────────────────────┐
│ Squat                          →    │
│ 315 lbs × 3 reps                    │
│ Est. 1RM: 335 lbs                   │
│ Feb 3, 2026 (4 days ago)            │
└─────────────────────────────────────┘

┌─────────────────────────────────────┐
│ Deadlift                       →    │
│ 405 lbs × 1 rep                     │
│ Est. 1RM: 405 lbs                   │
│ Jan 20, 2026 (18 days ago) 🕐       │
└─────────────────────────────────────┘
```

**Pros:**
- Easy to scan all current bests
- Quick comparison across exercises
- Can sort by: recency, weight, 1RM, muscle group
- Filter by muscle group (push/pull/legs)

**Cons:**
- Doesn't show progression over time (need tap to drill)
- Less celebratory feeling
- Doesn't highlight momentum

---

### Option 1C: "Stats Dashboard" (Visual Summary)
**Layout:** Cards with key metrics + mini charts
**Visual:** High-density info display

```
┌───────────────┬───────────────────┐
│ Total PRs     │ This Month        │
│ 47            │ 3 🔥              │
└───────────────┴───────────────────┘

┌─────────────────────────────────────┐
│ Recent PRs (Last 30 Days)           │
│                                     │
│ ▁▂▃▄▅▆▇█ (Activity sparkline)      │
│                                     │
│ • Bench Press - 225×5 (Feb 5)      │
│ • Squat - 315×3 (Feb 3)            │
│ • OHP - 135×5 (Jan 28)             │
└─────────────────────────────────────┘

┌─────────────────────────────────────┐
│ Longest Streak Without PR: 18 days │
│ Deadlift (Last PR: Jan 20)         │
│ 🎯 Time to push harder?            │
└─────────────────────────────────────┘

┌─────────────────────────────────────┐
│ Fastest Improving                   │
│ 1. OHP (+20% last 3 months)        │
│ 2. Bench (+15% last 3 months)      │
│ 3. Squat (+10% last 3 months)      │
└─────────────────────────────────────┘
```

**Pros:**
- Gamified metrics create engagement
- Shows patterns at a glance
- Motivational ("streak without PR" nudges action)
- Insights without drilling down

**Cons:**
- Information overload for casual users
- Requires more complex calculations
- Less detail per exercise

---

### Option 1D: "Hybrid" (Feed + Filter)
**Layout:** Feed with grouping option
**Visual:** Chronological with muscle group badges

```
┌─────────────────────────────────────┐
│ VIEW: Timeline ●  By Exercise ○    │
│ FILTER: 🔵 Push  🔴 Pull  🟢 Legs  │
└─────────────────────────────────────┘

🔵 PUSH
┌─────────────────────────────────────┐
│ 🏆 Feb 5 · Bench Press         →   │
│ 225 lbs × 5 reps (+10 lbs)          │
└─────────────────────────────────────┘

┌─────────────────────────────────────┐
│ 🏆 Jan 28 · Overhead Press     →   │
│ 135 lbs × 5 reps (+5 lbs)           │
└─────────────────────────────────────┘

🔴 PULL
┌─────────────────────────────────────┐
│ 🏆 Feb 3 · Bent Row            →   │
│ 185 lbs × 8 reps (+10 lbs)          │
└─────────────────────────────────────┘
```

**Pros:**
- Best of both worlds (feed + grouping)
- Filter by muscle group reveals patterns
- Toggle view based on user intent
- Clean progressive disclosure

**Cons:**
- More UI complexity
- Need to maintain two view modes
- Filter state management

---

## 🎨 UX Design Options - Phase B: Exercise Detail

When user taps a PR exercise → drill into progression view

### Option 2A: "Chart First" (Visual Priority)
**Layout:** Large chart, stats below
**Visual:** Line chart dominates screen

```
┌─────────────────────────────────────┐
│ ← Bench Press                       │
└─────────────────────────────────────┘

┌─────────────────────────────────────┐
│     Max Weight Over Time            │
│                                     │
│ 250│                           •    │
│ 225│                      •         │
│ 200│                 •              │
│ 175│            •                   │
│ 150│       •                        │
│ 125│  •                             │
│    └────────────────────────────────│
│     Dec   Jan   Feb   Mar   Apr    │
│                                     │
│ Showing: Last 6 Months ▼            │
└─────────────────────────────────────┘

┌─────────────────────────────────────┐
│ Current PR                          │
│ 225 lbs × 5 reps                    │
│ Est. 1RM: 253 lbs                   │
│ Achieved: Feb 5, 2026               │
└─────────────────────────────────────┘

┌─────────────────────────────────────┐
│ PR History                          │
│ • 225×5 (Feb 5) - Current           │
│ • 215×5 (Jan 29) - Previous         │
│ • 205×6 (Jan 15)                    │
│ • 195×5 (Dec 28)                    │
│ [View All 12 PRs]                   │
└─────────────────────────────────────┘
```

**Pros:**
- Visual progression immediately clear
- Satisfying to see upward trajectory
- Chart is high-impact, motivating
- Can toggle time ranges (3mo/6mo/1yr/all)

**Cons:**
- Chart requires space (less on small screens)
- Doesn't show reps (only max weight)
- Need to scroll for detailed stats

---

### Option 2B: "Stats First" (Data Priority)
**Layout:** Stats cards, chart optional below
**Visual:** Dense data, chart supplementary

```
┌─────────────────────────────────────┐
│ ← Bench Press                       │
└─────────────────────────────────────┘

┌─────────────────────────────────────┐
│ CURRENT PR                          │
│ 225 lbs × 5 reps                    │
│ Est. 1RM: 253 lbs                   │
│ Feb 5, 2026 (2 days ago)            │
└─────────────────────────────────────┘

┌───────────────┬───────────────────┐
│ All-Time Best │ Best This Month   │
│ 225 lbs       │ 225 lbs           │
└───────────────┴───────────────────┘

┌───────────────┬───────────────────┐
│ Total PRs     │ Avg Gain/PR       │
│ 12            │ +8.5 lbs          │
└───────────────┴───────────────────┘

┌─────────────────────────────────────┐
│ PROGRESSION                         │
│ [Mini line chart - sparkline]       │
│ +30 lbs in 4 months 📈              │
└─────────────────────────────────────┘

┌─────────────────────────────────────┐
│ PR HISTORY                          │
│ Feb 5  · 225×5 (Current)            │
│ Jan 29 · 215×5                      │
│ Jan 15 · 205×6                      │
│ Dec 28 · 195×5                      │
│ Dec 1  · 185×5                      │
│ [Show All 12]                       │
└─────────────────────────────────────┘
```

**Pros:**
- Numbers-focused users get immediate info
- No scrolling for key stats
- Compact summary metrics
- PR history readily accessible

**Cons:**
- Less visual impact
- Chart relegated to secondary position
- Can feel dense/overwhelming

---

### Option 2C: "Hybrid Scroll" (Progressive Detail)
**Layout:** Chart hero → stats → history
**Visual:** Natural scroll reveals depth

```
[Above fold - hero section]
┌─────────────────────────────────────┐
│ ← Bench Press                       │
│                                     │
│ 225 lbs × 5 reps                    │
│ Est. 1RM: 253 lbs                   │
│ Feb 5, 2026                         │
│                                     │
│     Max Weight Over Time            │
│ 250│                           •    │
│ 225│                      •         │
│ 200│                 •              │
│ 175│            •                   │
│    └────────────────────────────────│
│     Dec   Jan   Feb   Mar   Apr    │
│                                     │
│ [6 Months ▼]                        │
└─────────────────────────────────────┘

[Scroll down - stats section]
┌─────────────────────────────────────┐
│ STATS                               │
│                                     │
│ Total PRs: 12                       │
│ Avg Gain: +8.5 lbs per PR           │
│ Time Since Last: 2 days             │
│ Longest Gap: 34 days (Dec-Jan)     │
└─────────────────────────────────────┘

[Scroll more - history section]
┌─────────────────────────────────────┐
│ ALL PR HISTORY                      │
│                                     │
│ Feb 5, 2026  · 225 lbs × 5 reps    │
│ Jan 29, 2026 · 215 lbs × 5 reps    │
│ Jan 15, 2026 · 205 lbs × 6 reps    │
│ ...                                 │
└─────────────────────────────────────┘
```

**Pros:**
- Best of both (chart hero + data depth)
- Natural mobile pattern (scroll to learn more)
- Hero chart creates immediate impact
- Stats available without overwhelming

**Cons:**
- Requires scrolling for details
- Hero chart takes vertical space

---

## 🎯 During-Workout PR Awareness

### Option 3A: "Near-PR Badge" (Inline Warning)
**When:** User is logging a set that's within 5% of PR
**Where:** Inline in set input view

```
┌─────────────────────────────────────┐
│ Bench Press - Set 3                 │
│                                     │
│ ⚡ 5 lbs away from PR! (Current: 225)│
│                                     │
│ Reps: [10]                          │
│ Weight: [220] lbs                   │
│                                     │
│ [Log Set]                           │
└─────────────────────────────────────┘
```

**Pros:**
- Timely—user can push harder NOW
- Non-intrusive inline placement
- Motivational nudge at perfect moment

**Cons:**
- Could distract from focus
- Might create pressure/anxiety

---

### Option 3B: "PR Attempt Mode" (Explicit Flag)
**When:** User taps "PR Attempt" button before set
**Where:** Set input view with special mode

```
┌─────────────────────────────────────┐
│ Bench Press - Set 3                 │
│                                     │
│ 🔥 PR ATTEMPT MODE                  │
│ Current PR: 225 lbs × 5 reps        │
│ Beat it by logging 230+ lbs         │
│                                     │
│ Reps: [5]                           │
│ Weight: [   ] lbs                   │
│                                     │
│ [Cancel]  [LOG PR ATTEMPT]          │
└─────────────────────────────────────┘
```

**Pros:**
- User opts-in (no surprise pressure)
- Clear target to beat
- Celebratory when achieved
- Can track "attempts" separately

**Cons:**
- Extra tap to enable
- Might be ignored/forgotten
- Adds UI complexity

---

### Option 3C: "Exercise Header Badge" (Persistent Display)
**When:** Always shown if user has PR for this exercise
**Where:** Exercise header in workout detail

```
┌─────────────────────────────────────┐
│ Bench Press                    🏆   │
│ PR: 225×5 (Feb 5) • 1RM: 253 lbs   │
│ ────────────────────────────────────│
│ Set 1: 185 × 10 (warmup)            │
│ Set 2: 205 × 8                      │
│ Set 3: 225 × 5                      │
│                                     │
│ [Add Set]                           │
└─────────────────────────────────────┘
```

**Pros:**
- Always visible, no surprise
- Subtle reference (not pushy)
- Shows target without pressure
- Helps remember what weight to aim for

**Cons:**
- Takes header space
- Might clutter on small screens
- Less exciting than inline nudge

---

## 🏗️ Information Architecture Options

### Option IA-1: New Top-Level Tab
**Navigation:** Home | Workouts | **Progress** | Settings

**Pros:**
- Dedicated space for all progress features
- Clear feature discoverability
- Can house PR timeline, charts, analytics

**Cons:**
- Adds navigation complexity
- Requires 4-tab bar (more crowded on small screens)
- Splits user attention

---

### Option IA-2: Home Screen Widget
**Navigation:** Add "PRs" card to home screen below active workout

```
[Home Screen]

┌─────────────────────────────────────┐
│ Active Workout: Push Day            │
│ ...                                 │
└─────────────────────────────────────┘

┌─────────────────────────────────────┐
│ 🏆 Recent PRs                  [All]│
│                                     │
│ • Bench Press - 225×5 (2 days ago) │
│ • Squat - 315×3 (4 days ago)       │
│ • OHP - 135×5 (10 days ago)        │
└─────────────────────────────────────┘

┌─────────────────────────────────────┐
│ This Week                           │
│ 3 workouts • Goal: 4                │
└─────────────────────────────────────┘
```

**Pros:**
- No navigation change needed
- PRs visible without tapping
- Reinforces progress on every app open
- Can tap card → full PR timeline

**Cons:**
- Home screen getting crowded
- Limited space for detailed view
- Competes for attention with workout CTA

---

### Option IA-3: Workout History Tab (Add Section)
**Navigation:** History tab → Add "PRs" section at top

```
[Workout History]

┌─────────────────────────────────────┐
│ 🏆 Personal Records           [All] │
│ Last 7 Days: 2 PRs                  │
│ • Bench Press - 225×5               │
│ • Squat - 315×3                     │
└─────────────────────────────────────┘

────────────────────────────────────────

February 2026
┌─────────────────────────────────────┐
│ Feb 5 · Push Day                    │
│ 6 exercises • 18 sets • 47 min      │
└─────────────────────────────────────┘
```

**Pros:**
- Logical grouping (history + PRs)
- No new navigation needed
- PRs are workout outcomes, makes sense together

**Cons:**
- Might feel buried
- History list could overshadow PRs
- Users looking for "progress" might not check history

---

### Option IA-4: Exercise Search/Library Integration
**Navigation:** Add exercise → Search → Each exercise shows PR

```
[Exercise Search]

Search: [bench]

┌─────────────────────────────────────┐
│ Bench Press                         │
│ Chest, Triceps, Shoulders           │
│ 🏆 PR: 225×5 (Feb 5) • 1RM: 253    │
│ [+ Add to Workout]   [View Stats →]│
└─────────────────────────────────────┘
```

**Pros:**
- Contextual (see PR when choosing exercise)
- Helps decide "should I do this today?"
- Tapping "View Stats" → Exercise detail with chart

**Cons:**
- Doesn't solve "browse all PRs" use case
- Requires searching for specific exercise
- PR info secondary to search

---

## 📊 Chart Design Options

### Chart Type 1: Line Chart (Max Weight Over Time)
**X-axis:** Date
**Y-axis:** Weight (lbs/kg)
**Data Points:** Each PR achievement

```
Weight (lbs)
│
250 │                                  •
    │                             •
225 │                        •
    │                   •
200 │              •
    │         •
175 │    •
    │•
    └──────────────────────────────────→
      Dec  Jan  Feb  Mar  Apr  May  Jun
```

**Pros:**
- Shows trend clearly (up/flat/down)
- Familiar chart type
- Easy to see momentum
- Can project future trend line

**Cons:**
- Doesn't show reps (only weight)
- Sparse if user doesn't PR often
- Empty periods look discouraging

---

### Chart Type 2: Scatter Plot (Weight vs Reps)
**X-axis:** Reps
**Y-axis:** Weight
**Data Points:** All working sets (color = date)

```
Weight (lbs)
│
250 │  •
    │
225 │      •  • ← Recent (blue)
    │         •
200 │   •  •  ○ ← Older (gray)
    │      ○
175 │ •  ○
    │
    └──────────────────────────────────→
      1   3   5   7   9  11  13  15 Reps
```

**Pros:**
- Shows full picture (all sets, not just PRs)
- Reveals strength curve (1RM vs high-rep)
- Color gradient shows recency
- Useful for analyzing rep ranges

**Cons:**
- More complex to understand
- Can be cluttered with many data points
- Casual users might not care about rep ranges

---

### Chart Type 3: Bar Chart (Volume Per Workout)
**X-axis:** Workout date
**Y-axis:** Total volume (weight × reps)
**Bars:** Per workout

```
Volume (lbs)
│
10k │     █
    │     █
 8k │     █   █
    │ █   █   █
 6k │ █   █   █   █
    │ █   █   █   █
 4k │ █   █   █   █
    │ █   █   █   █
    └──────────────────────────────────→
      Jan 8  15  22  29  Feb 5  12  19
```

**Pros:**
- Shows total work done per session
- Good for tracking volume progression
- Easy to spot deload weeks
- Motivational (bigger bars = more work)

**Cons:**
- Volume ≠ strength (high reps inflate volume)
- Doesn't show max weight PRs directly
- Less relevant for low-rep strength work

---

### Chart Type 4: Estimated 1RM Line Chart
**X-axis:** Date
**Y-axis:** Estimated 1RM (calculated from weight × reps)
**Data Points:** Best set per workout

```
Est. 1RM (lbs)
│
280 │                                  •
    │                             •
260 │                        •
    │                   •
240 │              •    •
    │         •
220 │    •
    │•
    └──────────────────────────────────→
      Dec  Jan  Feb  Mar  Apr  May  Jun
```

**Pros:**
- Normalizes different rep ranges (5 reps vs 8 reps)
- True strength progression visible
- Smooths out rep variations
- Industry-standard metric

**Cons:**
- Formula less accurate above 10 reps
- Casual users might not understand "1RM"
- Requires explanation/tooltip

---

## 🎨 Visual Design Considerations

### Color Palette for Progress
- **Green (#10B981):** Upward trend, new PR, improvement
- **Orange (#F59E0B):** Plateau, no PR in 2+ weeks
- **Red (#EF4444):** Declining, deload period
- **Blue (#3B82F6):** Current PR, active exercise
- **Gray (#6B7280):** Historical data, older records

### Animation Opportunities
- **Chart reveal:** Line draws from left to right on load
- **PR badge pulse:** Trophy icon bounces when appearing
- **Confetti:** On new PR achievement (already exists)
- **Data point highlight:** Tap point → show weight/reps/date
- **Trend arrow:** Animate upward/downward based on trajectory

### Accessibility
- **VoiceOver:** "Bench Press, current PR 225 pounds for 5 reps, achieved February 5th"
- **Chart descriptions:** "Weight progression from 175 to 225 pounds over 4 months"
- **High contrast mode:** Increase line thickness, use patterns in addition to colors
- **Dynamic type:** Scale text in stat cards

---

## 🚀 Implementation Approach

### Data Source Decision

**Option A: Query Workouts Dynamically**
```swift
// Reconstruct PR history from all workouts
func getPRHistory(exerciseName: String) -> [(date: Date, weight: Double, reps: Int)] {
    // Fetch all workouts
    // Find all sets for this exercise (working sets only)
    // Calculate estimated 1RM for each
    // Sort by 1RM descending
    // Return timeline of bests
}
```

**Pros:**
- No schema changes needed
- Always accurate (source of truth = workouts)
- Works with existing data

**Cons:**
- Slower queries (N workouts × M exercises × P sets)
- Complex filtering logic
- Requires caching for performance

---

**Option B: Store PR History Records**
```swift
// Modify PersonalRecord to append instead of update
@Model
final class PersonalRecordHistory {
    var exerciseName: String
    var weight: Double
    var reps: Int
    var date: Date
    var workoutId: UUID
    var isPRAtTime: Bool  // Was this a PR when logged?
}
```

**Pros:**
- Fast queries (indexed by exercise)
- Simple to display
- Can track "was PR at time" vs "is PR now"

**Cons:**
- Requires data migration
- Duplication (data in workouts AND PR records)
- Need to backfill existing data

---

### Recommended Hybrid Approach
1. **Current PR:** Keep existing `PersonalRecord` (fastest lookup)
2. **PR History:** Query workouts on-demand (accurate)
3. **Caching:** Cache computed PR timeline per exercise (invalidate on new workout)

```swift
class PRProgressManager {
    // Fast: Get current PR
    func getCurrentPR(exercise: String) -> PersonalRecord?

    // Slow but accurate: Reconstruct history
    func getPRHistory(exercise: String) -> [PRDataPoint]

    // Cached: Don't recompute every time
    private var cachedHistory: [String: [PRDataPoint]] = [:]
}
```

---

## 🎯 Recommended UX Flow

### Phase A: PR Timeline (Week 1-2)

**Information Architecture:**
- Add "Progress" home screen widget (Option IA-2)
- Tap widget → Full PR Timeline view

**Timeline View Design:**
- Use **Option 1D: Hybrid Feed** (timeline with muscle group filters)
- Chronological by default, toggle to group by exercise
- Filter chips: All | Push | Pull | Legs | Other

**Exercise Card:**
```
┌─────────────────────────────────────┐
│ 🏆 Feb 5, 2026 · Bench Press   →   │
│ 225 lbs × 5 reps (+10 lbs)          │
│ Est. 1RM: 253 lbs                   │
└─────────────────────────────────────┘
```

**Interactions:**
- Tap card → Navigate to Exercise Detail (Phase B)
- Long press → "View Workout" (jumps to workout where PR was set)

---

### Phase B: Exercise Detail Charts (Week 3-4)

**Layout:**
- Use **Option 2C: Hybrid Scroll** (chart hero → stats → history)

**Chart:**
- **Type:** Estimated 1RM Line Chart (Option 4)
- **Time ranges:** 3 months (default) | 6 months | 1 year | All time
- **Interaction:** Tap data point → Show tooltip with weight/reps/date

**Stats Section:**
```
Total PRs: 12
Avg Gain per PR: +8.5 lbs
Last PR: 2 days ago
Longest Gap: 34 days (Dec-Jan)
```

**History List:**
- All historical PRs in reverse chronological order
- Tap PR → Navigate to workout detail where it was achieved

---

### Phase C: During-Workout Awareness (Week 5)

**Implementation:**
- Use **Option 3C: Exercise Header Badge** (persistent display)
- Shows current PR in exercise header
- Subtle, always visible, not pushy

**When new PR detected:**
- Immediate confetti animation (already exists)
- Update header badge in real-time
- Add to "Recent PRs" home widget

---

## 📏 Success Metrics

### User Engagement
- **PR Timeline View:** % of users who open it per week
- **Exercise Detail Views:** Avg views per user per week
- **Time Spent:** Avg seconds on PR timeline/detail
- **Retention:** Do users return to view PRs repeatedly?

### Behavioral Impact
- **PR Frequency:** Do users achieve PRs more often after seeing charts?
- **Workout Consistency:** Do users log more workouts to see chart update?
- **Exercise Selection:** Do users choose exercises they haven't PR'd recently?

### Feature Adoption
- **Widget Tap Rate:** % of home screen visits that tap PR widget
- **Filter Usage:** % of timeline views that use muscle group filters
- **Chart Interactions:** % of users who change time range or tap data points

---

## 🎨 Visual Mockup Priority

Before coding, should we:
1. **Sketch wireframes** for each view (hand-drawn or Figma)
2. **User test concept** with 2-3 people (show mockups, gather feedback)
3. **Prototype in SwiftUI** with dummy data (no real queries)
4. **Validate design** before implementing full backend

---

## 🤔 Open Questions for Discussion

1. **Should PR timeline show ALL PRs or just top 10-20?**
   - Pro: All = complete history
   - Con: Scrolling hundreds of PRs might feel overwhelming

2. **Should we track "near PRs" (95-99% of best)?**
   - Pro: Encourages "almost there" attempts
   - Con: Might feel like participation trophies

3. **Should charts show projected trend lines?**
   - Pro: Gamification ("if you continue this rate, you'll hit 300 lbs by June")
   - Con: Could be demotivating if projection shows plateau

4. **Should we notify users on PR anniversaries?**
   - "1 year ago today you hit 225 lbs—time to beat it!"
   - Pro: Re-engagement trigger
   - Con: Could feel naggy

5. **Should we allow editing/deleting historical PRs?**
   - User realizes they logged 315 instead of 135 (typo)
   - Current behavior: PR is wrong forever
   - Fix: Allow correction → recalculate timeline

6. **Dark mode for charts?**
   - Current app is dark-first
   - Charts need high contrast lines/points
   - Should we invert chart colors in dark mode?

---

## 🎯 Next Steps

1. **Decide on UX approach** (which options from above?)
2. **Create wireframes** (even rough sketches help)
3. **Validate data queries** (can we reconstruct PR history efficiently?)
4. **Prototype Phase A** (PR timeline view only)
5. **User test** (show to 2-3 people, iterate)
6. **Implement Phase A**
7. **Ship, measure, iterate**
8. **Add Phase B** (exercise detail charts)

---

## My Recommendations (If I Had to Choose Now)

### Phase A: PR Timeline
- **IA:** Home screen widget (Option IA-2) → Tap opens full view
- **Layout:** Hybrid Feed (Option 1D) with filter chips
- **Card Design:** Chronological feed with muscle group badges
- **Why:** Balance of visibility, grouping, and flexibility

### Phase B: Exercise Detail
- **Layout:** Hybrid Scroll (Option 2C) - chart hero, stats, history
- **Chart:** Estimated 1RM line chart (Option 4) with time range picker
- **Stats:** Total PRs, avg gain, last PR date, longest gap
- **Why:** Visual impact + data depth without overwhelming

### During-Workout
- **Awareness:** Exercise Header Badge (Option 3C)
- **Why:** Persistent, subtle, doesn't interrupt flow

---

**Let's discuss which direction resonates most with your vision! 🚀**
