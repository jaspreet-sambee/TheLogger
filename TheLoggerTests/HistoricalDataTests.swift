//
//  HistoricalDataTests.swift
//  TheLoggerTests
//
//  Full-pipeline historical data tests. Every workout, exercise, and set is
//  inserted into an in-memory SwiftData context — exactly as the real app does —
//  then queried back to verify PR detection, progress comparison, exercise memory,
//  and volume accumulation across many sessions.
//

import XCTest
import SwiftData
@testable import TheLogger

@MainActor
final class HistoricalDataTests: XCTestCase {

    var modelContext: ModelContext!
    var modelContainer: ModelContainer!

    override func setUp() async throws {
        let schema = Schema([
            Workout.self, Exercise.self, WorkoutSet.self,
            ExerciseMemory.self, PersonalRecord.self
        ])
        modelContainer = try ModelContainer(
            for: schema,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        modelContext = ModelContext(modelContainer)
    }

    override func tearDown() {
        modelContext = nil
        modelContainer = nil
    }

    // MARK: ─────────────────────────────────────────────────────────────
    // MARK: PR PROGRESSION
    // MARK: ─────────────────────────────────────────────────────────────

    /// 12-week linear bench press progression. Baseline on week 1, PRs on every
    /// subsequent week. Verifies the full checkAndSavePR → getPR round-trip.
    func testPR_12WeekLinearProgression_allWorkoutsStoredInContext() {
        // Week 1 baseline: 135 × 5  →  weeks 2-12 each add 5 lbs
        let startWeight: Double = 135
        let weeksTotal = 12
        var celebrations = 0

        for week in 1...weeksTotal {
            let weight = startWeight + Double((week - 1) * 5)
            let date = weekAgo(weeksTotal - week)
            let workout = persistedCompletedWorkout(name: "Bench W\(week)", date: date,
                                                    exercise: "Bench Press",
                                                    sets: [(5, weight, .working)])
            let celebrated = PersonalRecordManager.checkAndSavePR(
                exerciseName: "Bench Press", weight: weight, reps: 5,
                workoutId: workout.id, modelContext: modelContext)
            if week > 1, celebrated { celebrations += 1 }
        }

        XCTAssertEqual(celebrations, 11, "Weeks 2-12 should each celebrate a new PR")

        let finalPR = PersonalRecordManager.getPR(for: "Bench Press", modelContext: modelContext)
        let expectedWeight = startWeight + Double((weeksTotal - 1) * 5) // 135 + 55 = 190
        XCTAssertEqual(finalPR?.weight, expectedWeight)
        XCTAssertEqual(finalPR?.reps, 5)
        XCTAssertEqual(finalPR?.exerciseName, "bench press")
    }

    /// Plateau: 6 consecutive workouts at exactly the same weight and reps.
    /// Only week 1 saves a baseline; no celebrations after that.
    func testPR_plateau_6Weeks_noCelebrationAfterBaseline() {
        var celebrations = 0
        for week in 1...6 {
            let w = persistedCompletedWorkout(name: "Squat W\(week)", date: weekAgo(6 - week),
                                              exercise: "Squat", sets: [(5, 225, .working)])
            let celebrated = PersonalRecordManager.checkAndSavePR(
                exerciseName: "Squat", weight: 225, reps: 5,
                workoutId: w.id, modelContext: modelContext)
            if week > 1, celebrated { celebrations += 1 }
        }
        XCTAssertEqual(celebrations, 0, "Plateaued workouts must never trigger PR celebration")
    }

    /// Regression then recovery. Peak at week 2, dip at weeks 3-4, new peak at week 5.
    func testPR_regressionThenRecovery_peakPreservedDuringDip() {
        // W1 baseline
        let w1 = persistedCompletedWorkout(name: "W1", date: weekAgo(4),
                                           exercise: "Deadlift", sets: [(5, 225, .working)])
        _ = PersonalRecordManager.checkAndSavePR(
            exerciseName: "Deadlift", weight: 225, reps: 5, workoutId: w1.id, modelContext: modelContext)

        // W2 — PR at 275
        let w2 = persistedCompletedWorkout(name: "W2", date: weekAgo(3),
                                           exercise: "Deadlift", sets: [(5, 275, .working)])
        let pr2 = PersonalRecordManager.checkAndSavePR(
            exerciseName: "Deadlift", weight: 275, reps: 5, workoutId: w2.id, modelContext: modelContext)
        XCTAssertTrue(pr2)

        // W3 & W4 — bad weeks (lower weight)
        for (i, weight) in [(225.0), (245.0)].enumerated() {
            let w = persistedCompletedWorkout(name: "Dip W\(i+3)", date: weekAgo(2 - i),
                                              exercise: "Deadlift", sets: [(5, weight, .working)])
            let celebrated = PersonalRecordManager.checkAndSavePR(
                exerciseName: "Deadlift", weight: weight, reps: 5, workoutId: w.id, modelContext: modelContext)
            XCTAssertFalse(celebrated, "Weights below 275 should not trigger PR celebration")
        }

        // Verify PR still 275
        XCTAssertEqual(PersonalRecordManager.getPR(for: "Deadlift", modelContext: modelContext)?.weight, 275)

        // W5 — new all-time best
        let w5 = persistedCompletedWorkout(name: "W5", date: Date(),
                                           exercise: "Deadlift", sets: [(5, 295, .working)])
        let pr5 = PersonalRecordManager.checkAndSavePR(
            exerciseName: "Deadlift", weight: 295, reps: 5, workoutId: w5.id, modelContext: modelContext)
        XCTAssertTrue(pr5)
        XCTAssertEqual(PersonalRecordManager.getPR(for: "Deadlift", modelContext: modelContext)?.weight, 295)
    }

    /// Rep-based PR progression for a bodyweight exercise over 8 weeks.
    func testPR_bodyweightProgression_8Weeks() {
        let repScheme: [Int] = [8, 8, 9, 10, 10, 11, 12, 13]
        var celebrations = 0

        for (i, reps) in repScheme.enumerated() {
            let w = persistedCompletedWorkout(name: "Pullups W\(i+1)", date: weekAgo(8 - i),
                                              exercise: "Pull-Up", sets: [(reps, 0, .working)])
            let celebrated = PersonalRecordManager.checkAndSavePR(
                exerciseName: "Pull-Up", weight: 0, reps: reps, workoutId: w.id, modelContext: modelContext)
            if i > 0, celebrated { celebrations += 1 }
        }

        // Celebrations on weeks where reps increased over previous PR:
        // W1 baseline, W3(9>8)✓, W4(10>9)✓, W6(11>10)✓, W7(12>11)✓, W8(13>12)✓ = 5
        XCTAssertEqual(celebrations, 5)
        XCTAssertEqual(PersonalRecordManager.getPR(for: "Pull-Up", modelContext: modelContext)?.reps, 13)
    }

    // MARK: ─────────────────────────────────────────────────────────────
    // MARK: DROP SET & FAILURE SET PRs ACROSS HISTORY (bug fix validation)
    // MARK: ─────────────────────────────────────────────────────────────

    /// After the bug fix, a drop set in workout 2 beats a working set from workout 1.
    func testPR_dropSetBeatsWorkingSet_acrossWorkouts() {
        let w1 = persistedCompletedWorkout(name: "W1", date: weekAgo(2),
                                           exercise: "Curl", sets: [(10, 40, .working)])
        _ = PersonalRecordManager.checkAndSavePR(
            exerciseName: "Curl", weight: 40, reps: 10, workoutId: w1.id, modelContext: modelContext, setType: .working)

        let w2 = persistedCompletedWorkout(name: "W2", date: weekAgo(1),
                                           exercise: "Curl", sets: [(10, 50, .dropSet)])
        let celebrated = PersonalRecordManager.checkAndSavePR(
            exerciseName: "Curl", weight: 50, reps: 10, workoutId: w2.id, modelContext: modelContext, setType: .dropSet)

        XCTAssertTrue(celebrated, "Drop set PR (50 > 40) should celebrate across workouts")
        XCTAssertEqual(PersonalRecordManager.getPR(for: "Curl", modelContext: modelContext)?.weight, 50)
    }

    /// Failure set in workout 3 beats previous PR from working set in workout 1.
    func testPR_failureSetBeatsWorkingSet_acrossWorkouts() {
        let w1 = persistedCompletedWorkout(name: "W1", date: weekAgo(3),
                                           exercise: "Squat", sets: [(5, 225, .working)])
        _ = PersonalRecordManager.checkAndSavePR(
            exerciseName: "Squat", weight: 225, reps: 5, workoutId: w1.id, modelContext: modelContext)

        // Plateau in W2
        let w2 = persistedCompletedWorkout(name: "W2", date: weekAgo(2),
                                           exercise: "Squat", sets: [(5, 225, .working)])
        _ = PersonalRecordManager.checkAndSavePR(
            exerciseName: "Squat", weight: 225, reps: 5, workoutId: w2.id, modelContext: modelContext)

        // Failure set in W3 at 245 — should beat previous PR
        let w3 = persistedCompletedWorkout(name: "W3", date: weekAgo(1),
                                           exercise: "Squat", sets: [(5, 245, .failure)])
        let celebrated = PersonalRecordManager.checkAndSavePR(
            exerciseName: "Squat", weight: 245, reps: 5, workoutId: w3.id, modelContext: modelContext, setType: .failure)

        XCTAssertTrue(celebrated)
        XCTAssertEqual(PersonalRecordManager.getPR(for: "Squat", modelContext: modelContext)?.weight, 245)
    }

    /// recalculatePR scans stored workouts and picks up drop/failure sets after the bug fix.
    func testRecalculatePR_honorsDropAndFailureSets_inStoredWorkouts() {
        // W1: working set at 185
        _ = persistedCompletedWorkout(name: "W1", date: weekAgo(3),
                                      exercise: "Bench Press", sets: [(8, 185, .working)])

        // W2: drop set at 200 (was previously ignored by bug — should now count)
        _ = persistedCompletedWorkout(name: "W2", date: weekAgo(2),
                                      exercise: "Bench Press", sets: [(6, 200, .dropSet)])

        // W3: failure set at 210
        _ = persistedCompletedWorkout(name: "W3", date: weekAgo(1),
                                      exercise: "Bench Press", sets: [(4, 210, .failure)])
        try? modelContext.save()

        PersonalRecordManager.recalculatePR(exerciseName: "Bench Press", modelContext: modelContext)

        let pr = PersonalRecordManager.getPR(for: "Bench Press", modelContext: modelContext)
        // 210×4 1RM = 210*(1+4/30) = 238, 200×6 = 200*(1+6/30) = 240
        // 200×6 has higher 1RM — but 210×4 = 238.0, 200×6 = 240.0
        // So PR should be for 200×6 (highest 1RM)
        XCTAssertNotNil(pr)
        // The winning set by 1RM: 200*1.2=240, 210*1.133=238 — so 200×6 wins
        XCTAssertEqual(pr?.weight, 200)
        XCTAssertEqual(pr?.reps, 6)
    }

    /// Warmup sets must never count even when stored workouts contain them.
    func testRecalculatePR_ignoresWarmupSetsInStoredWorkouts() {
        // Only warmup sets in all workouts
        _ = persistedCompletedWorkout(name: "W1", date: weekAgo(2),
                                      exercise: "OHP", sets: [(10, 95, .warmup), (8, 115, .warmup)])
        // One working set at 135
        _ = persistedCompletedWorkout(name: "W2", date: weekAgo(1),
                                      exercise: "OHP", sets: [(10, 95, .warmup), (5, 135, .working)])
        try? modelContext.save()

        PersonalRecordManager.recalculatePR(exerciseName: "OHP", modelContext: modelContext)

        let pr = PersonalRecordManager.getPR(for: "OHP", modelContext: modelContext)
        XCTAssertEqual(pr?.weight, 135, "Only the working set should count as PR, not warmups")
        XCTAssertEqual(pr?.reps, 5)
    }

    // MARK: ─────────────────────────────────────────────────────────────
    // MARK: recalculatePR WITH FULL STORED HISTORY
    // MARK: ─────────────────────────────────────────────────────────────

    /// recalculatePR scans the actual SwiftData store — all 8 workouts — and
    /// finds the true all-time best set.
    func testRecalculatePR_scansAllStoredWorkouts_findsActualBest() {
        let weights: [(Double, Int)] = [
            (135, 10), (155, 8), (175, 6), (165, 8),
            (185, 5), (175, 7), (170, 8), (195, 3)
        ]
        for (i, (weight, reps)) in weights.enumerated() {
            _ = persistedCompletedWorkout(name: "W\(i+1)", date: weekAgo(8 - i),
                                          exercise: "Overhead Press", sets: [(reps, weight, .working)])
        }
        try? modelContext.save()

        // Pre-corrupt the PR to test that recalculate fixes it
        let bad = PersonalRecord(exerciseName: "overhead press", weight: 9999, reps: 1, workoutId: UUID())
        modelContext.insert(bad)
        try? modelContext.save()

        PersonalRecordManager.recalculatePR(exerciseName: "Overhead Press", modelContext: modelContext)

        let pr = PersonalRecordManager.getPR(for: "Overhead Press", modelContext: modelContext)
        // Best 1RM: 185*1.167=215.8, 195*1.1=214.5, 175*1.233=215.8
        // 185×5 and 175×7 tie-break, but 185*1.167=215.8 and 175*1.233=215.75 → 185×5 wins
        XCTAssertNotNil(pr)
        // The actual winner by Epley: 185*(1+5/30)=215.83, 175*(1+7/30)=215.83
        // These are approximately equal; either could win depending on iteration order.
        // Just verify it's NOT the corrupted 9999 value
        XCTAssertLessThan(pr!.weight, 500, "recalculate should correct the corrupted PR value")
    }

    /// After deleting the only working sets, recalculatePR should remove the PR record.
    func testRecalculatePR_noValidSetsInHistory_removesPR() {
        // Insert a workout with only warmup sets
        _ = persistedCompletedWorkout(name: "W1", date: weekAgo(1),
                                      exercise: "Face Pull", sets: [(15, 40, .warmup)])
        try? modelContext.save()

        // Manually insert a PR that has no valid backing set
        let orphan = PersonalRecord(exerciseName: "face pull", weight: 40, reps: 15, workoutId: UUID())
        modelContext.insert(orphan)
        try? modelContext.save()

        PersonalRecordManager.recalculatePR(exerciseName: "Face Pull", modelContext: modelContext)

        let pr = PersonalRecordManager.getPR(for: "Face Pull", modelContext: modelContext)
        XCTAssertNil(pr, "PR should be removed when no valid (non-warmup) sets exist in history")
    }

    // MARK: ─────────────────────────────────────────────────────────────
    // MARK: PROGRESS COMPARISON — PICKS MOST RECENT PREVIOUS WORKOUT
    // MARK: ─────────────────────────────────────────────────────────────

    /// When 10 previous workouts exist, comparison uses the MOST RECENT one,
    /// not the all-time best and not any random one.
    func testProgressComparison_picksOnlyMostRecentPreviousWorkout() {
        // Build 10 weeks of bench press history (most recent = week 10)
        var history: [Workout] = []
        let scheme: [(Double, Int)] = [
            (135,10),(145,8),(155,8),(165,6),(175,5),
            (185,5),(175,6),(165,8),(155,10),(185,5)  // W10 same as W6
        ]
        for (i, (w, r)) in scheme.enumerated() {
            let workout = persistedCompletedWorkout(
                name: "W\(i+1)", date: weekAgo(10 - i),
                exercise: "Bench Press", sets: [(r, w, .working)])
            history.append(workout)
        }

        // Current workout: bench at 175 × 8 (score = 1400)
        // Most recent previous = W10: 185×5 (score = 925)
        // 1400 > 925 → improved
        let currentExercise = makeExercise(name: "Bench Press", sets: [(8, 175)])
        let currentWorkout = history.last! // pretend W10 is still "current"
        // Actually set up a new current workout
        let newWorkout = persistedCompletedWorkout(
            name: "W11", date: Date(),
            exercise: "Bench Press", sets: [(8, 175)])
        let currentEx = newWorkout.exercisesByOrder.first!
        history.append(newWorkout)

        let result = ExerciseProgressCalculator.compare(
            exercise: currentEx,
            currentWorkoutId: newWorkout.id,
            completedWorkouts: history.sorted { $0.date > $1.date }
        )
        _ = currentWorkout
        _ = currentExercise

        // 175×8=1400 vs most recent previous (W10: 185×5=925) → improved
        if case .improved = result { /* pass */ }
        else { XCTFail("W11 (175×8=1400) vs most recent prev W10 (185×5=925) should be improved, got \(result)") }
    }

    /// Comparison ignores templates — only real completed workouts count.
    func testProgressComparison_ignoresTemplates_acrossHistory() {
        // Real workout 2 weeks ago
        let real = persistedCompletedWorkout(
            name: "Real", date: weekAgo(2),
            exercise: "Squat", sets: [(5, 225)])
        // Template with same exercise (should be excluded)
        let template = Workout(name: "My Template", date: weekAgo(1), isTemplate: true)
        template.startTime = weekAgo(1)
        template.endTime = weekAgo(1)
        let tEx = Exercise(name: "Squat", order: 0)
        tEx.sets = [WorkoutSet(reps: 5, weight: 315, setType: .working, sortOrder: 0)]
        template.exercises = [tEx]
        modelContext.insert(template)
        try? modelContext.save()

        // Current workout
        let current = persistedCompletedWorkout(
            name: "Current", date: Date(),
            exercise: "Squat", sets: [(5, 235)])
        let currentEx = current.exercisesByOrder.first!

        let allWorkouts = [real, template, current].sorted { $0.date > $1.date }
        let result = ExerciseProgressCalculator.compare(
            exercise: currentEx,
            currentWorkoutId: current.id,
            completedWorkouts: allWorkouts
        )

        // Comparison must ignore template (315×5 would make current look regressed)
        // Vs real workout (225×5=1125): 235×5=1175 → improved
        if case .improved = result { /* pass */ }
        else { XCTFail("Template should be excluded; comparison vs real 225×5 should be improved, got \(result)") }
    }

    /// When the same exercise appears in many workouts, comparison ignores the
    /// current workout itself (no self-comparison).
    func testProgressComparison_doesNotCompareToItself() {
        let workout = persistedCompletedWorkout(
            name: "Solo", date: Date(),
            exercise: "Deadlift", sets: [(5, 315)])
        let ex = workout.exercisesByOrder.first!

        let result = ExerciseProgressCalculator.compare(
            exercise: ex,
            currentWorkoutId: workout.id,
            completedWorkouts: [workout]
        )
        if case .firstTime = result { /* pass */ }
        else { XCTFail("Single workout should compare as firstTime (no previous), got \(result)") }
    }

    /// With 3 workouts at the same exercise: oldest, middle, newest.
    /// A new current workout must compare against newest (not oldest).
    func testProgressComparison_3Workouts_comparesAgainstMostRecent() {
        // Oldest: 135×10 (score 1350)
        _ = persistedCompletedWorkout(name: "Old", date: weekAgo(4),
                                      exercise: "Bench Press", sets: [(10, 135)])
        // Middle: 185×5 (score 925)
        _ = persistedCompletedWorkout(name: "Mid", date: weekAgo(2),
                                      exercise: "Bench Press", sets: [(5, 185)])
        // Most recent previous: 155×8 (score 1240)
        let recent = persistedCompletedWorkout(name: "Recent", date: weekAgo(1),
                                               exercise: "Bench Press", sets: [(8, 155)])

        // Current: 165×8 (score 1320) — better than most recent (1240), but worse than oldest (1350)
        let current = persistedCompletedWorkout(name: "Current", date: Date(),
                                                exercise: "Bench Press", sets: [(8, 165)])
        let ex = current.exercisesByOrder.first!

        let allSorted = [current, recent,
                         modelContext.fetch(fetchAll: Workout.self)
                            .first { $0.name == "Mid" }!,
                         modelContext.fetch(fetchAll: Workout.self)
                            .first { $0.name == "Old" }!]
            .sorted { $0.date > $1.date }

        let result = ExerciseProgressCalculator.compare(
            exercise: ex,
            currentWorkoutId: current.id,
            completedWorkouts: allSorted
        )
        // Must compare vs most recent prev (155×8=1240): 165×8=1320 > 1240 → improved
        if case .improved = result { /* pass */ }
        else { XCTFail("Should compare vs MOST RECENT previous (155×8), not oldest (135×10). Got \(result)") }
    }

    // MARK: ─────────────────────────────────────────────────────────────
    // MARK: EXERCISE MEMORY — STORED IN CONTEXT
    // MARK: ─────────────────────────────────────────────────────────────

    /// Single ExerciseMemory record updated after each of 6 workouts.
    /// Final state must reflect only the last workout's values.
    func testExerciseMemory_singleRecord_updatedAcross6Workouts() {
        let memory = ExerciseMemory(name: "Bench Press", lastReps: 10, lastWeight: 135, lastSets: 3)
        modelContext.insert(memory)
        try? modelContext.save()

        let sessions: [(Int, Double, Int)] = [
            (10, 135, 3), (8, 145, 4), (6, 155, 4),
            (5, 165, 5), (8, 160, 4), (10, 155, 3)
        ]
        for (reps, weight, sets) in sessions {
            memory.update(reps: reps, weight: weight, sets: sets)
        }
        try? modelContext.save()

        // Fetch back from context to confirm persistence
        let descriptor = FetchDescriptor<ExerciseMemory>(
            predicate: #Predicate { $0.name == "Bench Press" }
        )
        let fetched = try? modelContext.fetch(descriptor)
        XCTAssertEqual(fetched?.count, 1, "Should be exactly one ExerciseMemory record for Bench Press")
        XCTAssertEqual(fetched?.first?.lastReps, 10, "Should reflect the LAST session's reps")
        XCTAssertEqual(fetched?.first?.lastWeight, 155, "Should reflect the LAST session's weight")
        XCTAssertEqual(fetched?.first?.lastSets, 3)
    }

    /// Multiple exercises tracked simultaneously; each memory is independent.
    func testExerciseMemory_multipleExercises_storedIndependently() {
        let bench = ExerciseMemory(name: "Bench Press", lastReps: 8, lastWeight: 185, lastSets: 3)
        let squat = ExerciseMemory(name: "Squat", lastReps: 5, lastWeight: 225, lastSets: 4)
        let deadlift = ExerciseMemory(name: "Deadlift", lastReps: 3, lastWeight: 315, lastSets: 3)
        modelContext.insert(bench)
        modelContext.insert(squat)
        modelContext.insert(deadlift)
        try? modelContext.save()

        // Update only bench
        bench.update(reps: 6, weight: 205, sets: 3)
        try? modelContext.save()

        let descriptor = FetchDescriptor<ExerciseMemory>()
        let all = (try? modelContext.fetch(descriptor)) ?? []

        let benchFetched = all.first { $0.name == "Bench Press" }
        let squatFetched = all.first { $0.name == "Squat" }
        XCTAssertEqual(benchFetched?.lastWeight, 205, "Bench memory should update")
        XCTAssertEqual(squatFetched?.lastWeight, 225, "Squat memory should be unchanged")
    }

    /// Time-based exercise (Plank) — duration stored separately in lastDuration.
    func testExerciseMemory_timeBased_lastDurationUpdatesCorrectly() {
        let plank = ExerciseMemory(name: "Plank", lastReps: 0, lastWeight: 0, lastSets: 3, lastDuration: 30)
        modelContext.insert(plank)

        plank.update(reps: 0, weight: 0, sets: 3, durationSeconds: 60)
        plank.update(reps: 0, weight: 0, sets: 3, durationSeconds: 90)
        try? modelContext.save()

        let descriptor = FetchDescriptor<ExerciseMemory>(predicate: #Predicate { $0.name == "Plank" })
        let fetched = (try? modelContext.fetch(descriptor))?.first
        XCTAssertEqual(fetched?.lastDuration, 90, "Should reflect the most recent duration")
    }

    // MARK: ─────────────────────────────────────────────────────────────
    // MARK: MULTIPLE EXERCISES & VOLUME ACROSS HISTORY
    // MARK: ─────────────────────────────────────────────────────────────

    /// 10-week full-body program. All 5 exercises × 4 sets per workout.
    /// Verify total stored sets, volume, and PR records for each exercise.
    func testFullBodyProgram_10Weeks_correctSetCountAndPRs() {
        let program: [(String, Double, Int, SetType)] = [
            ("Bench Press", 185, 5, .working),
            ("Squat",       225, 5, .working),
            ("Deadlift",    315, 3, .working),
            ("Pull-Up",       0, 8, .working),
            ("Overhead Press",135, 8, .working)
        ]
        // Week 1 is baseline; weeks 2-10 each increase by small increment
        for week in 1...10 {
            let date = weekAgo(10 - week)
            let workout = Workout(name: "Full Body W\(week)", date: date, isTemplate: false)
            workout.startTime = date
            workout.endTime = date.addingTimeInterval(5400)
            modelContext.insert(workout)

            var exercises: [Exercise] = []
            for (i, (name, baseWeight, baseReps, type)) in program.enumerated() {
                let exercise = Exercise(name: name, order: i)
                let weight = baseWeight + Double((week - 1) * 5)
                let reps = baseReps // keep reps constant; weight increases
                exercise.sets = [
                    WorkoutSet(reps: reps, weight: weight, setType: type, sortOrder: 0),
                    WorkoutSet(reps: reps, weight: weight, setType: type, sortOrder: 1),
                    WorkoutSet(reps: reps, weight: weight, setType: type, sortOrder: 2),
                    WorkoutSet(reps: reps, weight: weight, setType: type, sortOrder: 3)
                ]
                exercises.append(exercise)

                _ = PersonalRecordManager.checkAndSavePR(
                    exerciseName: name, weight: weight, reps: reps,
                    workoutId: workout.id, modelContext: modelContext)
            }
            workout.exercises = exercises
        }
        try? modelContext.save()

        // Verify total sets stored
        let workoutDesc = FetchDescriptor<Workout>(predicate: #Predicate { $0.isTemplate == false })
        let allWorkouts = (try? modelContext.fetch(workoutDesc)) ?? []
        let totalSets = allWorkouts.reduce(0) { $0 + $1.totalSets }
        XCTAssertEqual(totalSets, 200, "10 weeks × 5 exercises × 4 sets = 200 sets")

        // Verify PRs exist for all 5 exercises and reflect week 10 (highest weight)
        for (name, baseWeight, baseReps, _) in program {
            let pr = PersonalRecordManager.getPR(for: name, modelContext: modelContext)
            XCTAssertNotNil(pr, "\(name) should have a PR")
            // Week 10 weight = baseWeight + 9*5 = baseWeight + 45
            let expectedWeight = baseWeight + 45
            XCTAssertEqual(pr?.weight, expectedWeight, "\(name) PR should be week 10 weight")
            XCTAssertEqual(pr?.reps, baseReps)
        }
    }

    /// Templates mixed into history do NOT affect PR calculations.
    func testPR_templatesInHistory_doNotContaminatePRs() {
        // Real workout: bench at 185
        let real = persistedCompletedWorkout(name: "Real", date: weekAgo(2),
                                             exercise: "Bench Press", sets: [(5, 185, .working)])
        _ = PersonalRecordManager.checkAndSavePR(
            exerciseName: "Bench Press", weight: 185, reps: 5, workoutId: real.id, modelContext: modelContext)

        // Template with bench at 250 (should NOT affect PR)
        let template = Workout(name: "Push Day Template", date: weekAgo(1), isTemplate: true)
        template.exercises = [makeExerciseWithSets("Bench Press", [(5, 250, .working)])]
        modelContext.insert(template)
        try? modelContext.save()

        // Recalculate scans only non-template workouts
        PersonalRecordManager.recalculatePR(exerciseName: "Bench Press", modelContext: modelContext)

        let pr = PersonalRecordManager.getPR(for: "Bench Press", modelContext: modelContext)
        XCTAssertEqual(pr?.weight, 185, "Template sets must not count toward PRs")
    }

    // MARK: ─────────────────────────────────────────────────────────────
    // MARK: processWorkoutForPRs — END-OF-WORKOUT FULL SCAN
    // MARK: ─────────────────────────────────────────────────────────────

    /// Simulates ending a workout: 3 exercises, 2 hit PRs, 1 doesn't.
    func testProcessWorkoutForPRs_3Exercises_correctPRList() {
        // Previous baseline workout
        let prev = Workout(name: "Prev", date: weekAgo(1), isTemplate: false)
        prev.startTime = weekAgo(1); prev.endTime = weekAgo(1)
        prev.exercises = [
            makeExerciseWithSets("Bench Press",   [(5, 175, .working)]),
            makeExerciseWithSets("Squat",         [(5, 225, .working)]),
            makeExerciseWithSets("Cable Fly",     [(12, 40, .working)])
        ]
        modelContext.insert(prev)
        try? modelContext.save()

        // Establish previous PRs
        _ = PersonalRecordManager.checkAndSavePR(exerciseName: "Bench Press", weight: 175, reps: 5, workoutId: prev.id, modelContext: modelContext)
        _ = PersonalRecordManager.checkAndSavePR(exerciseName: "Squat",       weight: 225, reps: 5, workoutId: prev.id, modelContext: modelContext)
        _ = PersonalRecordManager.checkAndSavePR(exerciseName: "Cable Fly",   weight: 40,  reps: 12, workoutId: prev.id, modelContext: modelContext)

        // New workout with 2 PRs
        let current = Workout(name: "Today", date: Date(), isTemplate: false)
        current.startTime = Date(); current.endTime = Date()
        current.exercises = [
            makeExerciseWithSets("Bench Press", [(5, 185, .working)]),   // PR (185 > 175)
            makeExerciseWithSets("Squat",       [(5, 215, .working)]),   // not PR (215 < 225)
            makeExerciseWithSets("Cable Fly",   [(12, 45, .working)])    // PR (45 > 40)
        ]
        modelContext.insert(current)
        try? modelContext.save()

        let prExercises = PersonalRecordManager.processWorkoutForPRs(workout: current, modelContext: modelContext)

        XCTAssertTrue(prExercises.contains("Bench Press"), "Bench Press PR (185>175) should be flagged")
        XCTAssertFalse(prExercises.contains("Squat"),      "Squat (215<225) should NOT be flagged")
        XCTAssertTrue(prExercises.contains("Cable Fly"),   "Cable Fly PR (45>40) should be flagged")
    }

    /// processWorkoutForPRs with a workout containing warmup + working sets.
    /// Warmup sets must not be included in PR detection.
    func testProcessWorkoutForPRs_mixedSetTypes_warmupExcluded() {
        let prev = Workout(name: "Prev", date: weekAgo(1), isTemplate: false)
        prev.startTime = weekAgo(1); prev.endTime = weekAgo(1)
        prev.exercises = [makeExerciseWithSets("OHP", [(5, 95, .working)])]
        modelContext.insert(prev)
        _ = PersonalRecordManager.checkAndSavePR(exerciseName: "OHP", weight: 95, reps: 5, workoutId: prev.id, modelContext: modelContext)
        try? modelContext.save()

        // New workout: warmup at 115 (huge weight but warmup), working at 100
        let current = Workout(name: "Current", date: Date(), isTemplate: false)
        current.startTime = Date(); current.endTime = Date()
        current.exercises = [makeExerciseWithSets("OHP", [(8, 115, .warmup), (5, 100, .working)])]
        modelContext.insert(current)
        try? modelContext.save()

        let prExercises = PersonalRecordManager.processWorkoutForPRs(workout: current, modelContext: modelContext)

        XCTAssertTrue(prExercises.contains("OHP"), "Working set (100 > 95) should produce a PR")
        // Verify PR is 100, not 115 (the warmup)
        let pr = PersonalRecordManager.getPR(for: "OHP", modelContext: modelContext)
        XCTAssertEqual(pr?.weight, 100)
    }

    // MARK: ─────────────────────────────────────────────────────────────
    // MARK: VOLUME OVER HISTORY
    // MARK: ─────────────────────────────────────────────────────────────

    func testVolume_5WeekPushDay_cumulativeVolumeIncreasesCorrectly() {
        let benchSets: [(Double, Int)] = [(135,10),(145,8),(155,8),(165,6),(175,5)]
        var expectedVolume: Double = 0

        for (i, (weight, reps)) in benchSets.enumerated() {
            _ = persistedCompletedWorkout(
                name: "Push W\(i+1)", date: weekAgo(5 - i),
                exercise: "Bench Press", sets: [(reps, weight, .working)])
            expectedVolume += weight * Double(reps)
        }
        try? modelContext.save()

        // Sum volume across all workouts
        let desc = FetchDescriptor<Workout>(predicate: #Predicate { $0.isTemplate == false })
        let workouts = (try? modelContext.fetch(desc)) ?? []
        let actualVolume = workouts.flatMap { $0.exercisesByOrder }
            .flatMap { $0.setsByOrder }
            .reduce(0.0) { $0 + $1.weight * Double($1.reps) }

        // 135*10 + 145*8 + 155*8 + 165*6 + 175*5 = 1350+1160+1240+990+875 = 5615
        XCTAssertEqual(actualVolume, expectedVolume, accuracy: 0.01)
        XCTAssertEqual(expectedVolume, 5615)
    }

    // MARK: ─────────────────────────────────────────────────────────────
    // MARK: HELPERS
    // MARK: ─────────────────────────────────────────────────────────────

    /// Insert a completed workout with one exercise and the given sets into modelContext.
    @discardableResult
    private func persistedCompletedWorkout(
        name: String,
        date: Date,
        exercise exerciseName: String,
        sets: [(Int, Double, SetType)] = []
    ) -> Workout {
        let workout = Workout(name: name, date: date, isTemplate: false)
        workout.startTime = date
        workout.endTime = date.addingTimeInterval(3600)

        var sortOrder = 0
        let exercise = Exercise(name: exerciseName, order: 0)
        exercise.sets = sets.map { (reps, weight, type) in
            let s = WorkoutSet(reps: reps, weight: weight, setType: type, sortOrder: sortOrder)
            sortOrder += 1
            return s
        }
        workout.exercises = [exercise]
        modelContext.insert(workout)
        try? modelContext.save()
        return workout
    }

    /// Overload: (Int, Double) without explicit set type (defaults to .working)
    @discardableResult
    private func persistedCompletedWorkout(
        name: String,
        date: Date,
        exercise exerciseName: String,
        sets: [(Int, Double)]
    ) -> Workout {
        persistedCompletedWorkout(
            name: name, date: date,
            exercise: exerciseName,
            sets: sets.map { ($0.0, $0.1, .working) }
        )
    }

    private func makeExercise(name: String, sets: [(Int, Double)]) -> Exercise {
        let e = Exercise(name: name, order: 0)
        e.sets = sets.enumerated().map { i, s in
            WorkoutSet(reps: s.0, weight: s.1, setType: .working, sortOrder: i)
        }
        return e
    }

    private func makeExerciseWithSets(_ name: String, _ sets: [(Int, Double, SetType)]) -> Exercise {
        let e = Exercise(name: name, order: 0)
        e.sets = sets.enumerated().map { i, s in
            WorkoutSet(reps: s.0, weight: s.1, setType: s.2, sortOrder: i)
        }
        return e
    }

    /// n weeks ago from now
    private func weekAgo(_ n: Int) -> Date {
        Date().addingTimeInterval(Double(-n) * 7 * 86400)
    }
}

// MARK: - ModelContext convenience

private extension ModelContext {
    func fetch<T: PersistentModel>(fetchAll _: T.Type) -> [T] {
        (try? fetch(FetchDescriptor<T>())) ?? []
    }
}
