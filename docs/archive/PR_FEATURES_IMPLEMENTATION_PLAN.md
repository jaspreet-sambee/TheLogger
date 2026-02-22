# PR Timeline & Exercise Charts - Implementation Plan

**Date:** 2026-02-05
**Goal:** Design the UX and technical approach for PR visualization features
**Effort:** PR Timeline (6 hours) + Exercise Charts (12 hours) = 18 hours total

---

## 🎯 Core User Stories

### Story 1: Browse All PRs
> "As a lifter, I want to see all my PRs in one place so I can feel proud of my progress and know what exercises I'm improving at."

### Story 2: See Exercise Progression
> "As a lifter following a program, I want to see if my squat is going up over time so I know if my training is working."

### Story 3: Quick PR Check During Workout
> "As I'm about to squat, I want to quickly see my current PR so I know what weight to aim for."

---

## 📊 PART 1: PR Timeline View (6 hours)

### Option A: Home Screen Widget + Full View

#### **Navigation Pattern**
```
[Home Screen]
┌─────────────────────────────────┐
│ Active Workout: Push Day        │
│ ...                             │
└─────────────────────────────────┘

┌─────────────────────────────────┐
│ 🏆 Recent PRs            [All →]│
│                                 │
│ • Bench Press - 225×5 (2d ago) │
│ • Squat - 315×3 (4d ago)       │
│ • Deadlift - 405×1 (1w ago)    │
└─────────────────────────────────┘
```

**Tap "[All →]" → Opens full PR Timeline view**

#### **Full PR Timeline Design**

```
┌─────────────────────────────────┐
│ ← Personal Records              │
└─────────────────────────────────┘

┌─────────────────────────────────┐
│ FILTER: All ▼  SORT: Recent ▼  │
└─────────────────────────────────┘

┌─────────────────────────────────┐
│ 🏆 Bench Press             →    │
│ 225 lbs × 5 reps                │
│ Est. 1RM: 253 lbs               │
│ Feb 5, 2026 (2 days ago)        │
└─────────────────────────────────┘

┌─────────────────────────────────┐
│ 🏆 Squat                   →    │
│ 315 lbs × 3 reps                │
│ Est. 1RM: 335 lbs               │
│ Feb 3, 2026 (4 days ago)        │
└─────────────────────────────────┘

┌─────────────────────────────────┐
│ 🏆 Deadlift                →    │
│ 405 lbs × 1 rep                 │
│ Est. 1RM: 405 lbs               │
│ Jan 20, 2026 (18 days ago) ⚠️  │
└─────────────────────────────────┘
```

**Features:**
- Trophy icon + exercise name
- Current PR weight × reps
- Estimated 1RM
- Date achieved + relative time ("2 days ago")
- Warning icon if >14 days (stagnation indicator)
- Tap card → Navigate to Exercise Detail with chart

**Filter Options:**
- All Exercises
- Push (Chest, Shoulders, Triceps)
- Pull (Back, Biceps)
- Legs (Quads, Hamstrings, Calves)
- Core

**Sort Options:**
- Most Recent (default)
- Oldest
- Highest 1RM
- Lowest 1RM
- A-Z
- Z-A

---

### Option B: Sheet Modal from Toolbar

#### **Navigation Pattern**
```
[Home Screen]
Top toolbar has "PR" button (trophy icon)
Tap → Sheet slides up from bottom
```

**Pros:**
- Doesn't take permanent screen space
- Quick access from anywhere
- Feels like a "peek" at progress

**Cons:**
- Less discoverable (hidden in toolbar)
- Can't stay open while browsing

---

### **Recommendation: Option A (Widget + Full View)**

**Why:**
1. **Discovery:** Widget on home makes feature obvious
2. **Motivation:** See recent PRs every time you open app
3. **Progressive disclosure:** Widget shows 3 recent, full view shows all
4. **Navigation:** Natural tap → drill down pattern

---

## 🔍 **Technical Approach for PR Timeline**

### **Data Source Decision**

Currently, `PersonalRecord` model stores ONLY the current best per exercise:
```swift
@Model
final class PersonalRecord {
    var exerciseName: String
    var weight: Double
    var reps: Int
    var date: Date       // When current PR was achieved
    var workoutId: UUID
}
```

**When a new PR is set → OVERWRITES the old one (line 1016-1019 in Workout.swift)**

### **Option 1: Use Existing PersonalRecord Model (Simple)**

**Implementation:**
```swift
// Query all PersonalRecord entries (one per exercise)
let descriptor = FetchDescriptor<PersonalRecord>(
    sortBy: [SortDescriptor(\.date, order: .reverse)]
)
let prs = try? modelContext.fetch(descriptor)
```

**What we get:**
- Current PR per exercise
- Date achieved
- Weight, reps, 1RM

**What we DON'T get:**
- Historical PR progression
- How much improvement from last PR
- PR timeline over time

**Pros:**
- Fast query (just fetch PersonalRecord)
- No data model changes needed
- 1-2 hours to implement

**Cons:**
- No historical data ("When did I first hit 225?" - can't answer)
- Can't show progression charts yet
- Limited storytelling

---

### **Option 2: Query Workout History (Complex but Rich)**

**Implementation:**
```swift
func getPRTimeline() -> [PREntry] {
    // 1. Fetch all completed workouts
    let workouts = try? modelContext.fetch(FetchDescriptor<Workout>(
        predicate: #Predicate { !$0.isTemplate && $0.endTime != nil },
        sortBy: [SortDescriptor(\.date, order: .reverse)]
    ))

    // 2. For each exercise, find all working sets across all workouts
    var exerciseHistory: [String: [(date: Date, weight: Double, reps: Int, workoutId: UUID)]] = [:]

    for workout in workouts {
        for exercise in workout.exercises ?? [] {
            let normalizedName = exercise.name.lowercased().trimmingCharacters(in: .whitespaces)

            for set in exercise.sets ?? [] where set.type == "Working" {
                if exerciseHistory[normalizedName] == nil {
                    exerciseHistory[normalizedName] = []
                }
                exerciseHistory[normalizedName]?.append((
                    date: workout.date,
                    weight: set.weight,
                    reps: set.reps,
                    workoutId: workout.id
                ))
            }
        }
    }

    // 3. For each exercise, find current best (by 1RM)
    var prEntries: [PREntry] = []

    for (exerciseName, sets) in exerciseHistory {
        // Calculate 1RM for each set
        let setsWithRM = sets.map { set in
            let rm = calculateEstimated1RM(weight: set.weight, reps: set.reps)
            return (set: set, rm: rm)
        }

        // Find max 1RM
        if let best = setsWithRM.max(by: { $0.rm < $1.rm }) {
            prEntries.append(PREntry(
                exerciseName: exerciseName,
                weight: best.set.weight,
                reps: best.set.reps,
                date: best.set.date,
                workoutId: best.set.workoutId,
                estimated1RM: best.rm,
                allHistory: setsWithRM  // For charting later
            ))
        }
    }

    return prEntries.sorted { $0.date > $1.date }
}
```

**What we get:**
- Current PR per exercise (same as Option 1)
- PLUS: Full history of all sets for each exercise
- Can calculate progression ("First hit 225 on Dec 1, hit 250 on Feb 5")
- Can show "PR journey" (all PRs over time)

**Pros:**
- Rich data for storytelling
- Enables historical charts
- No data model changes
- Always accurate (source of truth = workouts)

**Cons:**
- Slower query (O(workouts × exercises × sets))
- Need to cache results (don't recompute every render)
- More complex code (~100-150 lines)

---

### **Option 3: Hybrid (Best of Both)**

**Implementation:**
```swift
// For PR Timeline list: Use PersonalRecord (fast)
let prs = try? modelContext.fetch(FetchDescriptor<PersonalRecord>(...))

// For Exercise Detail charts: Query workout history on-demand (slow but accurate)
func getExerciseHistory(name: String) -> [HistoryPoint] {
    // Query workouts for this exercise only (filtered, faster)
}
```

**Pros:**
- Fast list view (Option 1)
- Rich detail view (Option 2)
- Progressive complexity (simple → detailed)

**Cons:**
- Two code paths to maintain
- Inconsistency if PersonalRecord gets out of sync with workouts

---

### **Recommendation: Option 2 (Query Workout History)**

**Why:**
1. **Accuracy:** Always correct (workouts are source of truth)
2. **Richness:** Enables future features (progression charts, PR streaks)
3. **Simplicity:** One code path, no sync issues
4. **Performance:** Cache results, invalidate on new workout
5. **Timeline:** 18 hours includes both list + charts, so complexity is acceptable

**Caching Strategy:**
```swift
class PRManager {
    private var cachedPRs: [PREntry] = []
    private var lastCacheDate: Date = .distantPast

    func getPRs(modelContext: ModelContext, forceRefresh: Bool = false) -> [PREntry] {
        // If cache is fresh (<5 min old), return cached
        if !forceRefresh && Date().timeIntervalSince(lastCacheDate) < 300 {
            return cachedPRs
        }

        // Otherwise, recompute
        cachedPRs = computePRsFromWorkouts(modelContext)
        lastCacheDate = Date()
        return cachedPRs
    }
}
```

---

## 📈 PART 2: Exercise Progress Charts (12 hours)

### **User Flow**

```
PR Timeline → Tap "Bench Press" → Exercise Detail View
```

### **Exercise Detail View Layout**

```
┌─────────────────────────────────┐
│ ← Bench Press                   │
└─────────────────────────────────┘

┌─────────────────────────────────┐
│ CURRENT PR                      │
│ 225 lbs × 5 reps                │
│ Est. 1RM: 253 lbs               │
│ Achieved: Feb 5, 2026           │
└─────────────────────────────────┘

┌─────────────────────────────────┐
│ Estimated 1RM Over Time         │
│                                 │
│ 260│                       •    │
│ 240│                  •         │
│ 220│             •              │
│ 200│        •                   │
│ 180│   •                        │
│    └───────────────────────────│
│     Dec  Jan  Feb  Mar  Apr    │
│                                 │
│ [3 Months] [6 Months] [1 Year] │
└─────────────────────────────────┘

┌───────────────┬─────────────────┐
│ Total PRs     │ Avg Gain        │
│ 12            │ +8.5 lbs        │
└───────────────┴─────────────────┘

┌───────────────┬─────────────────┐
│ Best This Mo  │ Last PR         │
│ 225 lbs       │ 2 days ago      │
└───────────────┴─────────────────┘

┌─────────────────────────────────┐
│ ALL PR HISTORY                  │
│                                 │
│ Feb 5  · 225 lbs × 5 reps      │
│ Jan 29 · 215 lbs × 5 reps      │
│ Jan 15 · 205 lbs × 6 reps      │
│ Dec 28 · 195 lbs × 5 reps      │
│ [Show All 12 PRs]              │
└─────────────────────────────────┘
```

---

### **Chart Design Options**

#### **Option A: Estimated 1RM Line Chart (Recommended)**

**X-axis:** Date
**Y-axis:** Estimated 1RM (lbs/kg)
**Data Points:** Best 1RM per workout where exercise was performed

```swift
struct ChartDataPoint {
    let date: Date
    let estimated1RM: Double
    let weight: Double  // For tooltip
    let reps: Int       // For tooltip
    let workoutId: UUID // For linking
}
```

**Why 1RM instead of raw weight?**
- Normalizes different rep ranges (225×5 vs 215×6 - which is stronger?)
- Shows true strength progression
- Industry standard metric

**Calculation:**
```swift
// Brzycki formula (already in codebase)
func calculateEstimated1RM(weight: Double, reps: Int) -> Double {
    guard reps > 0 && reps <= 10 else { return weight }
    return weight * (36.0 / (37.0 - Double(reps)))
}
```

**Chart Library:** Use SwiftUI Charts (already imported in codebase)

**Implementation:**
```swift
import Charts

struct ExerciseProgressChart: View {
    let dataPoints: [ChartDataPoint]
    @State private var selectedPoint: ChartDataPoint?

    var body: some View {
        Chart(dataPoints) { point in
            LineMark(
                x: .value("Date", point.date),
                y: .value("1RM", point.estimated1RM)
            )
            .foregroundStyle(.blue)
            .lineStyle(StrokeStyle(lineWidth: 2))

            PointMark(
                x: .value("Date", point.date),
                y: .value("1RM", point.estimated1RM)
            )
            .foregroundStyle(.blue)
            .symbolSize(60)
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .month)) { _ in
                AxisGridLine()
                AxisValueLabel(format: .dateTime.month(.abbreviated))
            }
        }
        .chartYAxis {
            AxisMarks { value in
                AxisGridLine()
                AxisValueLabel {
                    if let rm = value.as(Double.self) {
                        Text("\(Int(rm))")
                    }
                }
            }
        }
        .chartOverlay { proxy in
            GeometryReader { geometry in
                Rectangle()
                    .fill(.clear)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                // Show tooltip on tap/drag
                                let location = value.location
                                if let date: Date = proxy.value(atX: location.x) {
                                    selectedPoint = dataPoints.min(by: {
                                        abs($0.date.timeIntervalSince(date)) <
                                        abs($1.date.timeIntervalSince(date))
                                    })
                                }
                            }
                            .onEnded { _ in
                                selectedPoint = nil
                            }
                    )
            }
        }
        .frame(height: 220)

        // Tooltip
        if let point = selectedPoint {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(Int(point.estimated1RM)) lbs 1RM")
                    .font(.headline)
                Text("\(Int(point.weight)) × \(point.reps)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(point.date, style: .date)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(8)
            .background(RoundedRectangle(cornerRadius: 8).fill(.thinMaterial))
        }
    }
}
```

---

#### **Option B: Max Weight Line Chart (Simpler)**

**X-axis:** Date
**Y-axis:** Max weight lifted
**Data Points:** Heaviest set per workout

**Pros:**
- Easier to understand (just weight, not calculated)
- Simpler for users who don't know 1RM

**Cons:**
- Doesn't account for reps (225×5 vs 235×3 - chart shows 235 as better, but is it?)
- Less accurate for strength progression

**Recommendation:** Use Option A (1RM) with explanation tooltip

---

#### **Option C: Scatter Plot (Weight vs Reps)**

**X-axis:** Reps
**Y-axis:** Weight
**Color:** Date (gradient from old to recent)

```
Weight
│
250 │  • (recent, blue)
225 │      •  •
200 │   •  •  ○ (old, gray)
175 │ •  ○
    └──────────────────→
      1   3   5   7   9  Reps
```

**Pros:**
- Shows full strength curve (1RM vs high-rep)
- Reveals rep range preferences

**Cons:**
- More complex to read
- Overwhelming for casual users
- Doesn't show progression over time clearly

**Recommendation:** Save for "advanced analytics" later

---

### **Time Range Selector**

```
[3 Months ●] [6 Months ○] [1 Year ○] [All Time ○]
```

**Implementation:**
```swift
enum TimeRange: String, CaseIterable {
    case threeMonths = "3 Months"
    case sixMonths = "6 Months"
    case oneYear = "1 Year"
    case allTime = "All Time"

    var startDate: Date? {
        let calendar = Calendar.current
        let now = Date()
        switch self {
        case .threeMonths: return calendar.date(byAdding: .month, value: -3, to: now)
        case .sixMonths: return calendar.date(byAdding: .month, value: -6, to: now)
        case .oneYear: return calendar.date(byAdding: .year, value: -1, to: now)
        case .allTime: return nil  // No filter
        }
    }
}

@State private var selectedRange: TimeRange = .sixMonths

var filteredDataPoints: [ChartDataPoint] {
    guard let startDate = selectedRange.startDate else {
        return dataPoints  // All time
    }
    return dataPoints.filter { $0.date >= startDate }
}
```

---

### **Stats Cards**

#### **Card 1: Current PR**
```
┌─────────────────────────────────┐
│ CURRENT PR                      │
│ 225 lbs × 5 reps                │
│ Est. 1RM: 253 lbs               │
│ Achieved: Feb 5, 2026           │
└─────────────────────────────────┘
```

#### **Card 2: Progress Metrics**
```
┌───────────────┬─────────────────┐
│ Total PRs     │ Avg Gain/PR     │
│ 12            │ +8.5 lbs        │
└───────────────┴─────────────────┘
```

**Calculation:**
```swift
let totalPRs = prHistory.count
let gains = prHistory.sorted { $0.date < $1.date }
    .adjacentPairs()
    .map { $1.estimated1RM - $0.estimated1RM }
let avgGain = gains.reduce(0, +) / Double(gains.count)
```

#### **Card 3: Recency Metrics**
```
┌───────────────┬─────────────────┐
│ Last PR       │ Best This Month │
│ 2 days ago    │ 225 lbs         │
└───────────────┴─────────────────┘
```

---

### **PR History List**

```
┌─────────────────────────────────┐
│ ALL PR HISTORY                  │
│                                 │
│ Feb 5, 2026  · 225 lbs × 5 reps │
│ Jan 29, 2026 · 215 lbs × 5 reps │
│ Jan 15, 2026 · 205 lbs × 6 reps │
│ Dec 28, 2025 · 195 lbs × 5 reps │
│ Dec 1, 2025  · 185 lbs × 5 reps │
│                                 │
│ [Show All 12 PRs]              │
└─────────────────────────────────┘
```

**Tap a PR → Navigate to workout detail where it was achieved**

---

## 🗂️ **File Structure**

### **New Files to Create**

```
TheLogger/
├── PRViews.swift (NEW)
│   ├── PRTimelineView
│   ├── PRCardView
│   ├── PRHomeWidgetView
│   └── ExerciseDetailView
│
├── Charts/ (NEW folder)
│   ├── ExerciseProgressChart.swift
│   ├── ChartDataPoint.swift
│   └── TimeRangeSelector.swift
│
├── Managers/ (NEW folder)
│   └── PRManager.swift
│       ├── getPRTimeline()
│       ├── getExerciseHistory()
│       ├── caching logic
```

### **Modified Files**

```
WorkoutListView.swift
├── Add PRHomeWidgetView to home screen
└── Navigation to PRTimelineView

Workout.swift
└── Keep existing PersonalRecord + PersonalRecordManager
    (still used for PR detection during workout)
```

---

## 🔄 **Data Flow**

### **Phase 1: App Launch**
```
1. WorkoutListView appears
2. PRHomeWidgetView queries PRManager.getPRs() → shows last 3 PRs
3. Data cached in PRManager
```

### **Phase 2: User Taps "View All"**
```
1. Navigate to PRTimelineView
2. Use cached PRs from PRManager (instant display)
3. Allow filters/sorts (re-filter cached data, no new query)
```

### **Phase 3: User Taps Exercise Card**
```
1. Navigate to ExerciseDetailView(exerciseName: "Bench Press")
2. Query PRManager.getExerciseHistory("Bench Press")
   - Filters workouts to only this exercise
   - Returns all sets with dates
3. Generate ChartDataPoints (calculate 1RM for each)
4. Display chart + stats + history list
```

### **Phase 4: User Logs New Workout**
```
1. Workout ends
2. PersonalRecordManager.checkAndSavePR() updates PersonalRecord
3. PRManager.invalidateCache() called
4. Next time PRHomeWidgetView appears → recompute from workouts
```

---

## ⏱️ **Time Breakdown**

### **PR Timeline View (6 hours)**

| Task | Time | Details |
|------|------|---------|
| PRManager data queries | 2 hours | Query workouts, compute PRs, caching |
| PRTimelineView UI | 1.5 hours | List view, cards, filters, sorts |
| PRHomeWidgetView | 1 hour | Widget on home screen |
| Navigation wiring | 0.5 hours | Link home → timeline, timeline → detail |
| Testing | 1 hour | Test with 50+ workouts, verify filters |

### **Exercise Progress Charts (12 hours)**

| Task | Time | Details |
|------|------|---------|
| Chart data preparation | 2 hours | ChartDataPoint model, 1RM calculations |
| ExerciseProgressChart | 3 hours | SwiftUI Charts implementation, tooltip |
| Stats cards | 2 hours | Current PR, metrics, recency |
| PR history list | 1 hour | List view, tap to workout |
| Time range selector | 1 hour | Filter logic, UI |
| ExerciseDetailView layout | 2 hours | Compose chart + stats + history |
| Testing & polish | 1 hour | Test with various exercises, edge cases |

**Total: 18 hours**

---

## 🎨 **Visual Design Decisions**

### **Colors**

- **PR Cards:** Blue border (`.blue.opacity(0.25)`)
- **Trophy Icon:** Gold/Yellow (`.yellow`)
- **Chart Line:** Blue gradient (`.blue`)
- **Chart Points:** Blue filled circles
- **Warning (stagnation):** Orange (`.orange`)
- **Background:** Black with opacity (`.black.opacity(0.6)`) - consistent with app

### **Typography**

- **Exercise Name:** `.headline` semibold
- **Weight × Reps:** `.title3` bold
- **1RM:** `.subheadline` medium
- **Date:** `.caption` regular, `.secondary` color
- **Stats labels:** `.caption` uppercase

### **Spacing**

- **Card padding:** 16pt
- **Card spacing:** 12pt
- **Section spacing:** 24pt
- **Corner radius:** 12pt (standard in app)

---

## 🚨 **Edge Cases to Handle**

### **Case 1: No PRs Yet (New User)**
```
┌─────────────────────────────────┐
│ 🏆 No PRs Yet                   │
│                                 │
│ Complete your first workout     │
│ to start tracking PRs!          │
│                                 │
│ [Start Workout]                │
└─────────────────────────────────┘
```

### **Case 2: Exercise with Only 1 Workout**
- Chart shows single point (no line)
- Stats show "1 PR"
- Avg gain: "N/A" (need 2+ PRs)

### **Case 3: Exercise Not Logged in Selected Time Range**
```
┌─────────────────────────────────┐
│ No data in last 3 months        │
│                                 │
│ Last logged: Dec 15, 2025       │
│ [View All Time]                │
└─────────────────────────────────┘
```

### **Case 4: Multiple PRs Same Day (Rare)**
- Show best set from that day
- Tooltip: "Best of 2 sets on this day"

### **Case 5: User Changes Unit System**
- Charts auto-update (use `UnitFormatter.convertToDisplay()`)
- Y-axis label updates (lbs → kg)

---

## 🎯 **Success Criteria**

### **Functional:**
- ✅ User can see all current PRs in one list
- ✅ User can filter by muscle group
- ✅ User can sort by recency/weight/name
- ✅ User can tap exercise → see progression chart
- ✅ Chart shows 1RM over time
- ✅ User can change time range (3mo/6mo/1yr/all)
- ✅ User can tap PR in history → jump to workout

### **Performance:**
- ✅ PR Timeline loads in <1 second (cached)
- ✅ Exercise Detail loads in <2 seconds (query + compute)
- ✅ Chart renders smoothly (no jank)
- ✅ Works with 100+ workouts without slowdown

### **UX:**
- ✅ PR widget on home motivates users
- ✅ Chart is easy to understand (tooltip helps)
- ✅ Navigation is intuitive (tap → drill down)
- ✅ Edge cases handled gracefully

---

## 🤔 **Open Questions for Discussion**

### **Question 1: Home Widget Position?**
**Option A:** Between active workout and weekly stats (current plan)
**Option B:** Above active workout (more prominent)
**Option C:** In separate "Progress" tab

**Your preference?**

---

### **Question 2: Filter Chips - Always Visible or Hidden?**
**Option A:** Always show filter chips at top (takes space)
**Option B:** Hidden in menu, tap "Filter" button
**Option C:** Swipeable horizontal scroll (compact)

**Your preference?**

---

### **Question 3: Chart Tooltip Style?**
**Option A:** Floating box above point (as shown in mockups)
**Option B:** Bottom sheet slides up
**Option C:** Inline below chart

**Your preference?**

---

### **Question 4: PR History - Show All or Paginate?**
**Option A:** Show first 5, tap "Show All 12" to expand
**Option B:** Always show all PRs (could be 50+ for veteran users)
**Option C:** Show first 10, infinite scroll

**Your preference?**

---

### **Question 5: Stats Cards - Which Metrics Matter Most?**

**Current selection:**
- Total PRs
- Avg gain per PR
- Last PR date
- Best this month

**Alternative metrics:**
- Longest plateau (days since last PR)
- PR frequency (avg days between PRs)
- Best rep range (5 reps vs 10 reps)
- Volume progression (not just max weight)

**Your preference? Any other metrics you want?**

---

## 🚀 **Implementation Order**

### **Phase 1: Data Layer (4 hours)**
1. Create `PRManager.swift` (2 hours)
   - `getPRTimeline()` query workouts → compute PRs
   - Caching logic
   - `getExerciseHistory()` for charts

2. Create `ChartDataPoint.swift` (1 hour)
   - Data models for charts
   - 1RM calculation helpers

3. Test queries with mock data (1 hour)
   - Verify performance with 100 workouts
   - Edge cases (no PRs, single workout, etc.)

---

### **Phase 2: PR Timeline View (4 hours)**
1. Create `PRTimelineView.swift` (2 hours)
   - List view with cards
   - Filter/sort UI
   - Navigation to detail

2. Create `PRHomeWidgetView.swift` (1 hour)
   - Widget on home screen
   - Show last 3 PRs
   - "View All" button

3. Wire navigation (0.5 hours)
   - Home → Timeline
   - Timeline → Detail

4. Test & polish (0.5 hours)

---

### **Phase 3: Exercise Charts (10 hours)**
1. Create `ExerciseProgressChart.swift` (4 hours)
   - SwiftUI Charts implementation
   - Time range filtering
   - Tooltip interactions

2. Create `ExerciseDetailView.swift` (3 hours)
   - Layout: chart + stats + history
   - Stats cards
   - PR history list

3. Create `TimeRangeSelector.swift` (1 hour)
   - Segmented control
   - Filter logic

4. Navigation from timeline (0.5 hours)

5. Test & polish (1.5 hours)
   - Test with various exercises
   - Verify calculations
   - Edge cases

---

## 📝 **Next Steps**

1. **Answer open questions** above (filter placement, tooltip style, etc.)
2. **Approve implementation plan** (or suggest changes)
3. **Start Phase 1** (PRManager data layer)
4. **Build iteratively** (test each phase before moving to next)

---

**Does this implementation plan look good? Any changes or preferences on the open questions?**
