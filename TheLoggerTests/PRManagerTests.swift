//
//  PRManagerTests.swift
//  TheLoggerTests
//
//  Unit tests for Personal Record detection, 1RM calculation,
//  and all PR manager business logic.
//

import XCTest
import SwiftData
@testable import TheLogger

@MainActor
final class PRManagerTests: XCTestCase {

    var modelContext: ModelContext!
    var modelContainer: ModelContainer!

    override func setUp() async throws {
        let schema = Schema([
            Workout.self,
            Exercise.self,
            WorkoutSet.self,
            ExerciseMemory.self,
            PersonalRecord.self
        ])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        modelContainer = try ModelContainer(for: schema, configurations: [configuration])
        modelContext = ModelContext(modelContainer)
    }

    override func tearDown() {
        modelContext = nil
        modelContainer = nil
    }

    // MARK: - 1RM Calculation (Epley Formula)

    func test1RM_epleyFormula_225x10() {
        // 225 × (1 + 10/30) = 225 × 1.333 = 300
        let pr = PersonalRecord(exerciseName: "Bench Press", weight: 225, reps: 10, workoutId: UUID())
        XCTAssertEqual(pr.estimated1RM, 300.0, accuracy: 1.0)
    }

    func test1RM_epleyFormula_300x5() {
        // 300 × (1 + 5/30) = 300 × 1.167 = 350
        let pr = PersonalRecord(exerciseName: "Squat", weight: 300, reps: 5, workoutId: UUID())
        XCTAssertEqual(pr.estimated1RM, 350.0, accuracy: 1.0)
    }

    func test1RM_highReps_135x15() {
        // 135 × (1 + 15/30) = 135 × 1.5 = 202.5
        let pr = PersonalRecord(exerciseName: "Leg Press", weight: 135, reps: 15, workoutId: UUID())
        XCTAssertEqual(pr.estimated1RM, 202.5, accuracy: 1.0)
    }

    func test1RM_singleRep_equalsWeight() {
        // 225 × (1 + 1/30) = 225 × 1.033 = ~232.5
        let pr = PersonalRecord(exerciseName: "Deadlift", weight: 225, reps: 1, workoutId: UUID())
        XCTAssertEqual(pr.estimated1RM, 232.5, accuracy: 1.0)
    }

    func test1RM_bodyweightExercise_returnsZero() {
        // weight == 0 means bodyweight; formula guard prevents division issues
        let pr = PersonalRecord(exerciseName: "Pull-ups", weight: 0, reps: 15, workoutId: UUID())
        XCTAssertEqual(pr.estimated1RM, 0.0)
    }

    func test1RM_zeroReps_returnsZero() {
        let pr = PersonalRecord(exerciseName: "Bench Press", weight: 225, reps: 0, workoutId: UUID())
        XCTAssertEqual(pr.estimated1RM, 0.0)
    }

    // MARK: - PersonalRecord Model Properties

    func testPRIsBodyweight_trueWhenWeightIsZero() {
        let pr = PersonalRecord(exerciseName: "Pull-ups", weight: 0, reps: 12, workoutId: UUID())
        XCTAssertTrue(pr.isBodyweight)
    }

    func testPRIsBodyweight_falseWhenWeightIsNonZero() {
        let pr = PersonalRecord(exerciseName: "Bench Press", weight: 135, reps: 10, workoutId: UUID())
        XCTAssertFalse(pr.isBodyweight)
    }

    func testPRScore_bodyweight_usesRawReps() {
        let pr = PersonalRecord(exerciseName: "Pull-ups", weight: 0, reps: 15, workoutId: UUID())
        XCTAssertEqual(pr.prScore, 15.0) // Raw reps for bodyweight
    }

    func testPRScore_weighted_uses1RM() {
        // 225 × (1 + 10/30) = 300
        let pr = PersonalRecord(exerciseName: "Bench Press", weight: 225, reps: 10, workoutId: UUID())
        XCTAssertEqual(pr.prScore, 300.0, accuracy: 1.0)
    }

    func testPRDisplayString_bodyweight() {
        let pr = PersonalRecord(exerciseName: "Pull-ups", weight: 0, reps: 12, workoutId: UUID())
        XCTAssertEqual(pr.displayString, "BW × 12")
    }

    func testPRDisplayString_weighted() {
        UserDefaults.standard.set("Imperial", forKey: "unitSystem")
        let pr = PersonalRecord(exerciseName: "Bench Press", weight: 225, reps: 5, workoutId: UUID())
        XCTAssertTrue(pr.displayString.contains("225"))
        XCTAssertTrue(pr.displayString.contains("5"))
    }

    func testPRNameNormalization_lowercasesTrimmed() {
        let pr = PersonalRecord(exerciseName: "  Bench Press  ", weight: 225, reps: 5, workoutId: UUID())
        XCTAssertEqual(pr.exerciseName, "bench press")
    }

    // MARK: - First Time PR (Baseline)

    func testFirstSet_savedAsPRBaseline() {
        let workout = Workout(name: "Test", date: Date(), isTemplate: false)
        modelContext.insert(workout)

        let isNewPR = PersonalRecordManager.checkAndSavePR(
            exerciseName: "Bench Press",
            weight: 225,
            reps: 5,
            workoutId: workout.id,
            modelContext: modelContext
        )

        // First set: saved silently, no celebration
        XCTAssertFalse(isNewPR, "First set should NOT trigger celebration")
        let pr = PersonalRecordManager.getPR(for: "Bench Press", modelContext: modelContext)
        XCTAssertNotNil(pr, "First set should be saved as baseline")
        XCTAssertEqual(pr?.weight, 225)
        XCTAssertEqual(pr?.reps, 5)
    }

    func testFirstSet_bodyweightExercise_savedAsPR() {
        let workout = Workout(name: "Test", date: Date(), isTemplate: false)
        modelContext.insert(workout)

        _ = PersonalRecordManager.checkAndSavePR(
            exerciseName: "Pull-ups",
            weight: 0,
            reps: 15,
            workoutId: workout.id,
            modelContext: modelContext
        )

        let pr = PersonalRecordManager.getPR(for: "Pull-ups", modelContext: modelContext)
        XCTAssertNotNil(pr)
        XCTAssertTrue(pr?.isBodyweight ?? false)
        XCTAssertEqual(pr?.reps, 15)
    }

    // MARK: - PR Detection: Higher Weight

    func testHigherWeight_sameReps_isCrossWorkoutPR() {
        let workout1 = Workout(name: "W1", date: Date(), isTemplate: false)
        modelContext.insert(workout1)
        _ = PersonalRecordManager.checkAndSavePR(
            exerciseName: "Squat", weight: 315, reps: 5, workoutId: workout1.id, modelContext: modelContext)

        let workout2 = Workout(name: "W2", date: Date(), isTemplate: false)
        modelContext.insert(workout2)
        let isNewPR = PersonalRecordManager.checkAndSavePR(
            exerciseName: "Squat", weight: 335, reps: 5, workoutId: workout2.id, modelContext: modelContext)

        XCTAssertTrue(isNewPR, "Higher weight in new workout should trigger celebration")
        let pr = PersonalRecordManager.getPR(for: "Squat", modelContext: modelContext)
        XCTAssertEqual(pr?.weight, 335)
    }

    func testLowerWeight_sameReps_isNotPR() {
        let workout1 = Workout(name: "W1", date: Date(), isTemplate: false)
        modelContext.insert(workout1)
        _ = PersonalRecordManager.checkAndSavePR(
            exerciseName: "Deadlift", weight: 405, reps: 5, workoutId: workout1.id, modelContext: modelContext)

        let workout2 = Workout(name: "W2", date: Date(), isTemplate: false)
        modelContext.insert(workout2)
        let isNewPR = PersonalRecordManager.checkAndSavePR(
            exerciseName: "Deadlift", weight: 385, reps: 5, workoutId: workout2.id, modelContext: modelContext)

        XCTAssertFalse(isNewPR, "Lower weight should not be a PR")
        let pr = PersonalRecordManager.getPR(for: "Deadlift", modelContext: modelContext)
        XCTAssertEqual(pr?.weight, 405, "PR should remain unchanged")
    }

    // MARK: - PR Detection: Higher Reps

    func testHigherReps_sameWeight_isCrossWorkoutPR() {
        let workout1 = Workout(name: "W1", date: Date(), isTemplate: false)
        modelContext.insert(workout1)
        _ = PersonalRecordManager.checkAndSavePR(
            exerciseName: "Bench Press", weight: 185, reps: 5, workoutId: workout1.id, modelContext: modelContext)

        let workout2 = Workout(name: "W2", date: Date(), isTemplate: false)
        modelContext.insert(workout2)
        // More reps at same weight → higher 1RM → PR
        let isNewPR = PersonalRecordManager.checkAndSavePR(
            exerciseName: "Bench Press", weight: 185, reps: 8, workoutId: workout2.id, modelContext: modelContext)

        XCTAssertTrue(isNewPR, "Higher reps at same weight should be a PR")
    }

    func testBodyweightHigherReps_isCrossWorkoutPR() {
        let workout1 = Workout(name: "W1", date: Date(), isTemplate: false)
        modelContext.insert(workout1)
        _ = PersonalRecordManager.checkAndSavePR(
            exerciseName: "Pull-ups", weight: 0, reps: 10, workoutId: workout1.id, modelContext: modelContext)

        let workout2 = Workout(name: "W2", date: Date(), isTemplate: false)
        modelContext.insert(workout2)
        let isNewPR = PersonalRecordManager.checkAndSavePR(
            exerciseName: "Pull-ups", weight: 0, reps: 15, workoutId: workout2.id, modelContext: modelContext)

        XCTAssertTrue(isNewPR, "More bodyweight reps in new workout should be PR")
    }

    // MARK: - Same Workout PR (Silent)

    func testSameWorkoutImprovement_savedSilently() {
        let workout = Workout(name: "Test", date: Date(), isTemplate: false)
        modelContext.insert(workout)

        // Set 1: baseline
        _ = PersonalRecordManager.checkAndSavePR(
            exerciseName: "OHP", weight: 135, reps: 5, workoutId: workout.id, modelContext: modelContext)

        // Set 2: better set in same workout — saved but no celebration
        let isNewPR = PersonalRecordManager.checkAndSavePR(
            exerciseName: "OHP", weight: 145, reps: 5, workoutId: workout.id, modelContext: modelContext)

        XCTAssertFalse(isNewPR, "Same-workout improvement should be silent (no celebration)")
        let pr = PersonalRecordManager.getPR(for: "OHP", modelContext: modelContext)
        XCTAssertEqual(pr?.weight, 145, "PR should still be updated to the new best")
    }

    // MARK: - Set Type Filtering

    func testWarmupSet_notSavedAsPR() {
        let workout = Workout(name: "Test", date: Date(), isTemplate: false)
        modelContext.insert(workout)

        let isNewPR = PersonalRecordManager.checkAndSavePR(
            exerciseName: "Bench Press",
            weight: 225,
            reps: 10,
            workoutId: workout.id,
            modelContext: modelContext,
            setType: .warmup
        )

        XCTAssertFalse(isNewPR, "Warmup set should never be a PR")
        let pr = PersonalRecordManager.getPR(for: "Bench Press", modelContext: modelContext)
        XCTAssertNil(pr, "No PR should be saved for warmup sets")
    }

    func testDropSet_countsForPR() {
        let workout1 = Workout(name: "W1", date: Date(), isTemplate: false)
        modelContext.insert(workout1)
        _ = PersonalRecordManager.checkAndSavePR(
            exerciseName: "Curl", weight: 40, reps: 10, workoutId: workout1.id, modelContext: modelContext, setType: .working)

        let workout2 = Workout(name: "W2", date: Date(), isTemplate: false)
        modelContext.insert(workout2)
        let isNewPR = PersonalRecordManager.checkAndSavePR(
            exerciseName: "Curl", weight: 50, reps: 10, workoutId: workout2.id, modelContext: modelContext, setType: .dropSet)

        XCTAssertTrue(isNewPR, "Drop set should count for PRs (countsForPR = true)")
    }

    func testFailureSet_countsForPR() {
        let workout1 = Workout(name: "W1", date: Date(), isTemplate: false)
        modelContext.insert(workout1)
        _ = PersonalRecordManager.checkAndSavePR(
            exerciseName: "Squat", weight: 225, reps: 5, workoutId: workout1.id, modelContext: modelContext)

        let workout2 = Workout(name: "W2", date: Date(), isTemplate: false)
        modelContext.insert(workout2)
        let isNewPR = PersonalRecordManager.checkAndSavePR(
            exerciseName: "Squat", weight: 245, reps: 5, workoutId: workout2.id, modelContext: modelContext, setType: .failure)

        XCTAssertTrue(isNewPR, "Failure set should count for PRs (countsForPR = true)")
    }

    func testRestPauseSet_countsForPR() {
        let workout1 = Workout(name: "W1", date: Date(), isTemplate: false)
        modelContext.insert(workout1)
        _ = PersonalRecordManager.checkAndSavePR(
            exerciseName: "Bench Press", weight: 185, reps: 5, workoutId: workout1.id, modelContext: modelContext)

        let workout2 = Workout(name: "W2", date: Date(), isTemplate: false)
        modelContext.insert(workout2)
        let isNewPR = PersonalRecordManager.checkAndSavePR(
            exerciseName: "Bench Press", weight: 200, reps: 5, workoutId: workout2.id, modelContext: modelContext, setType: .pause)

        XCTAssertTrue(isNewPR, "Rest-pause set should count for PRs (countsForPR = true)")
    }

    func testWarmup_doesNotCountForPR_evenWithHigherWeight() {
        let workout1 = Workout(name: "W1", date: Date(), isTemplate: false)
        modelContext.insert(workout1)
        _ = PersonalRecordManager.checkAndSavePR(
            exerciseName: "Deadlift", weight: 315, reps: 5, workoutId: workout1.id, modelContext: modelContext)

        let workout2 = Workout(name: "W2", date: Date(), isTemplate: false)
        modelContext.insert(workout2)
        let isNewPR = PersonalRecordManager.checkAndSavePR(
            exerciseName: "Deadlift", weight: 999, reps: 20, workoutId: workout2.id, modelContext: modelContext, setType: .warmup)

        XCTAssertFalse(isNewPR, "Warmup sets must never count for PRs, regardless of weight")
        let pr = PersonalRecordManager.getPR(for: "Deadlift", modelContext: modelContext)
        XCTAssertEqual(pr?.weight, 315, "PR should be unchanged after a warmup set")
    }

    func testZeroReps_notSavedAsPR() {
        let workout = Workout(name: "Test", date: Date(), isTemplate: false)
        modelContext.insert(workout)

        let isNewPR = PersonalRecordManager.checkAndSavePR(
            exerciseName: "Bench Press",
            weight: 225,
            reps: 0,       // Invalid
            workoutId: workout.id,
            modelContext: modelContext
        )

        XCTAssertFalse(isNewPR)
        let pr = PersonalRecordManager.getPR(for: "Bench Press", modelContext: modelContext)
        XCTAssertNil(pr, "Zero reps should not create a PR record")
    }

    // MARK: - PR Name Normalization

    func testPRLookup_caseInsensitive() {
        let workout = Workout(name: "Test", date: Date(), isTemplate: false)
        modelContext.insert(workout)

        _ = PersonalRecordManager.checkAndSavePR(
            exerciseName: "BENCH PRESS", weight: 225, reps: 5, workoutId: workout.id, modelContext: modelContext)

        let pr = PersonalRecordManager.getPR(for: "bench press", modelContext: modelContext)
        XCTAssertNotNil(pr, "PR lookup should be case-insensitive")
    }

    func testPRLookup_trailingWhitespaceTrimmed() {
        let workout = Workout(name: "Test", date: Date(), isTemplate: false)
        modelContext.insert(workout)

        _ = PersonalRecordManager.checkAndSavePR(
            exerciseName: "  Squat  ", weight: 315, reps: 5, workoutId: workout.id, modelContext: modelContext)

        let pr = PersonalRecordManager.getPR(for: "Squat", modelContext: modelContext)
        XCTAssertNotNil(pr, "PR lookup should be whitespace-insensitive")
    }

    // MARK: - RecalculatePR

    func testRecalculatePR_findsActualBestSetAfterEdit() {
        let workout = Workout(name: "Test", date: Date(), isTemplate: false)
        modelContext.insert(workout)

        let exercise = Exercise(name: "Bench Press", order: 0)
        exercise.addSet(reps: 5, weight: 225)
        exercise.addSet(reps: 5, weight: 205) // Lower set
        workout.exercises = [exercise]
        workout.startTime = Date()
        workout.endTime = Date()

        // Set PR to wrong value initially
        let badPR = PersonalRecord(exerciseName: "bench press", weight: 300, reps: 5, workoutId: workout.id)
        modelContext.insert(badPR)
        try? modelContext.save()

        PersonalRecordManager.recalculatePR(exerciseName: "Bench Press", modelContext: modelContext)

        let corrected = PersonalRecordManager.getPR(for: "Bench Press", modelContext: modelContext)
        XCTAssertEqual(corrected?.weight, 225, "Recalculate should find true best set")
        XCTAssertEqual(corrected?.reps, 5)
    }

    func testRecalculatePR_removesPRWhenNoValidSetsExist() {
        let workout = Workout(name: "Test", date: Date(), isTemplate: false)
        modelContext.insert(workout)

        // Insert a PR with no valid backing sets in database
        let orphanPR = PersonalRecord(exerciseName: "overhead press", weight: 135, reps: 8, workoutId: workout.id)
        modelContext.insert(orphanPR)
        try? modelContext.save()

        // Recalculate with no workouts containing this exercise
        PersonalRecordManager.recalculatePR(exerciseName: "Overhead Press", modelContext: modelContext)

        let pr = PersonalRecordManager.getPR(for: "Overhead Press", modelContext: modelContext)
        XCTAssertNil(pr, "PR should be removed when no valid sets exist")
    }

    func testRecalculatePR_ignoresWarmupSets() {
        let workout = Workout(name: "Test", date: Date(), isTemplate: false)
        modelContext.insert(workout)

        let exercise = Exercise(name: "Deadlift", order: 0)
        // Only warmup sets — should not count
        let warmupSet = WorkoutSet(reps: 5, weight: 135, setType: .warmup, sortOrder: 0)
        exercise.sets = [warmupSet]
        workout.exercises = [exercise]
        workout.startTime = Date()
        workout.endTime = Date()

        // Pre-insert a PR
        let pr = PersonalRecord(exerciseName: "deadlift", weight: 315, reps: 5, workoutId: workout.id)
        modelContext.insert(pr)
        try? modelContext.save()

        PersonalRecordManager.recalculatePR(exerciseName: "Deadlift", modelContext: modelContext)

        // Warmup sets don't count, PR should be removed
        let afterPR = PersonalRecordManager.getPR(for: "Deadlift", modelContext: modelContext)
        XCTAssertNil(afterPR, "Warmup-only exercise should have no PR after recalculation")
    }

    // MARK: - exercisesWithPRsInWorkout

    func testExercisesWithPRsInWorkout_returnsExercisesMatchingWorkoutId() {
        let workout = Workout(name: "Test", date: Date(), isTemplate: false)
        modelContext.insert(workout)

        let exercise = Exercise(name: "Bench Press", order: 0)
        exercise.addSet(reps: 10, weight: 225)
        workout.exercises = [exercise]

        let pr = PersonalRecord(exerciseName: "bench press", weight: 225, reps: 10, workoutId: workout.id)
        modelContext.insert(pr)
        try? modelContext.save()

        let prExercises = PersonalRecordManager.exercisesWithPRsInWorkout(workout, modelContext: modelContext)
        XCTAssertTrue(prExercises.contains("Bench Press"), "Should return exercises whose PR was set in this workout")
    }

    func testExercisesWithPRsInWorkout_excludesOtherWorkouts() {
        let workout1 = Workout(name: "W1", date: Date(), isTemplate: false)
        let workout2 = Workout(name: "W2", date: Date(), isTemplate: false)
        modelContext.insert(workout1)
        modelContext.insert(workout2)

        let exercise = Exercise(name: "Squat", order: 0)
        workout1.exercises = [exercise]

        // PR belongs to workout1
        let pr = PersonalRecord(exerciseName: "squat", weight: 315, reps: 5, workoutId: workout1.id)
        modelContext.insert(pr)
        try? modelContext.save()

        // workout2 has different exercise
        let exercise2 = Exercise(name: "Deadlift", order: 0)
        workout2.exercises = [exercise2]

        let prExercises = PersonalRecordManager.exercisesWithPRsInWorkout(workout2, modelContext: modelContext)
        XCTAssertFalse(prExercises.contains("Squat"), "PR from another workout should not appear")
    }

    // MARK: - PRManager Timeline (regression: drop sets must appear in timeline)

    func testPRTimeline_dropSet_appearsInTimeline() {
        // Regression test: PRManager previously used set.type == .working,
        // excluding drop sets. It should use countsForPR instead.
        let workout = Workout(name: "Test", date: Date(), isTemplate: false)
        workout.endTime = Date()
        modelContext.insert(workout)

        let exercise = Exercise(name: "Curl", order: 0)
        workout.exercises = [exercise]

        // Add a drop set (not a working set)
        let dropSet = WorkoutSet(reps: 10, weight: 50, sortOrder: 0)
        dropSet.setType = SetType.dropSet.rawValue
        exercise.sets = [dropSet]

        try? modelContext.save()

        let manager = PRManager.shared
        let timeline = manager.getPRTimeline(modelContext: modelContext, forceRefresh: true)

        XCTAssertFalse(timeline.isEmpty, "Drop set should appear in PR timeline")
        XCTAssertEqual(timeline.first?.exerciseName, "curl")
        XCTAssertEqual(timeline.first?.weight, 50)
    }

    func testPRTimeline_warmupSet_doesNotAppearInTimeline() {
        let workout = Workout(name: "Test", date: Date(), isTemplate: false)
        workout.endTime = Date()
        modelContext.insert(workout)

        let exercise = Exercise(name: "Squat", order: 0)
        workout.exercises = [exercise]

        // Add only a warmup set
        let warmupSet = WorkoutSet(reps: 10, weight: 135, sortOrder: 0)
        warmupSet.setType = SetType.warmup.rawValue
        exercise.sets = [warmupSet]

        try? modelContext.save()

        let manager = PRManager.shared
        let timeline = manager.getPRTimeline(modelContext: modelContext, forceRefresh: true)

        XCTAssertTrue(timeline.isEmpty, "Warmup set must not appear in PR timeline")
    }

    // MARK: - PR Celebration Direction Tests

    func testPRCelebration_doesNotFireOnWeightReduction() {
        // Set up initial PR at 225×5
        let workout = Workout(name: "Test", date: Date(), isTemplate: false)
        workout.endTime = Date()
        modelContext.insert(workout)

        let exercise = Exercise(name: "Bench Press", order: 0)
        workout.exercises = [exercise]

        let set1 = WorkoutSet(reps: 5, weight: 225, sortOrder: 0)
        exercise.sets = [set1]
        try? modelContext.save()

        _ = PersonalRecordManager.recalculatePR(exerciseName: "Bench Press", modelContext: modelContext)
        let oldPR = PersonalRecordManager.getPR(for: "Bench Press", modelContext: modelContext)
        let oldScore = oldPR.map { PersonalRecordManager.prScore(weight: $0.weight, reps: $0.reps) } ?? 0

        // Reduce weight to 200×5 (simulating user edit)
        set1.weight = 200
        try? modelContext.save()

        _ = PersonalRecordManager.recalculatePR(exerciseName: "Bench Press", modelContext: modelContext)
        let newPR = PersonalRecordManager.getPR(for: "Bench Press", modelContext: modelContext)
        let newScore = newPR.map { PersonalRecordManager.prScore(weight: $0.weight, reps: $0.reps) } ?? 0

        XCTAssertTrue(newScore < oldScore, "Reduced weight should yield lower PR score — celebration should NOT fire")
    }

    func testPRCelebration_firesOnWeightIncrease() {
        // Set up initial PR at 200×5
        let workout = Workout(name: "Test", date: Date(), isTemplate: false)
        workout.endTime = Date()
        modelContext.insert(workout)

        let exercise = Exercise(name: "Bench Press", order: 0)
        workout.exercises = [exercise]

        let set1 = WorkoutSet(reps: 5, weight: 200, sortOrder: 0)
        exercise.sets = [set1]
        try? modelContext.save()

        _ = PersonalRecordManager.recalculatePR(exerciseName: "Bench Press", modelContext: modelContext)
        let oldPR = PersonalRecordManager.getPR(for: "Bench Press", modelContext: modelContext)
        let oldScore = oldPR.map { PersonalRecordManager.prScore(weight: $0.weight, reps: $0.reps) } ?? 0

        // Increase weight to 225×5
        set1.weight = 225
        try? modelContext.save()

        _ = PersonalRecordManager.recalculatePR(exerciseName: "Bench Press", modelContext: modelContext)
        let newPR = PersonalRecordManager.getPR(for: "Bench Press", modelContext: modelContext)
        let newScore = newPR.map { PersonalRecordManager.prScore(weight: $0.weight, reps: $0.reps) } ?? 0

        XCTAssertTrue(newScore > oldScore, "Increased weight should yield higher PR score — celebration SHOULD fire")
    }

    func testPRScore_isAccessibleAndReturnsExpectedValues() {
        // Bodyweight exercise: score equals reps
        let bwScore = PersonalRecordManager.prScore(weight: 0, reps: 20)
        XCTAssertEqual(bwScore, 20.0, "Bodyweight PR score should equal reps")

        // Weighted exercise: score equals estimated 1RM (Epley)
        let weightedScore = PersonalRecordManager.prScore(weight: 225, reps: 5)
        // Epley: 225 * (1 + 5/30) = 225 * 1.1667 ≈ 262.5
        XCTAssertEqual(weightedScore, 262.5, accuracy: 0.5, "Weighted PR score should match Epley 1RM")
    }

    // MARK: - Camera Share Card isPR Flag

    /// Verifies that a PR-beating set returns true from checkAndSavePR,
    /// which is the value the camera onSetLogged closure captures and passes to ShareCardConfig.isPR.
    func testCameraShareCardIsPRFlag_prBeatingSetReturnsTrue() {
        let workout1 = Workout(name: "Push", date: Date(), isTemplate: false)
        modelContext.insert(workout1)
        // Establish baseline PR
        _ = PersonalRecordManager.checkAndSavePR(
            exerciseName: "Bench Press", weight: 185, reps: 8,
            workoutId: workout1.id, modelContext: modelContext)

        let workout2 = Workout(name: "Push 2", date: Date(), isTemplate: false)
        modelContext.insert(workout2)
        // Log a PR-beating set — the camera closure captures this Bool for ShareCardConfig.isPR
        let wasPR = PersonalRecordManager.checkAndSavePR(
            exerciseName: "Bench Press", weight: 225, reps: 5,
            workoutId: workout2.id, modelContext: modelContext)

        XCTAssertTrue(wasPR, "PR-beating camera set must return true so share card shows the PR badge")
    }

    func testCameraShareCardIsPRFlag_normalSetReturnsFalse() {
        let workout1 = Workout(name: "Push", date: Date(), isTemplate: false)
        modelContext.insert(workout1)
        _ = PersonalRecordManager.checkAndSavePR(
            exerciseName: "Bench Press", weight: 225, reps: 5,
            workoutId: workout1.id, modelContext: modelContext)

        let workout2 = Workout(name: "Push 2", date: Date(), isTemplate: false)
        modelContext.insert(workout2)
        // Same weight/reps — not a new PR
        let wasPR = PersonalRecordManager.checkAndSavePR(
            exerciseName: "Bench Press", weight: 185, reps: 3,
            workoutId: workout2.id, modelContext: modelContext)

        XCTAssertFalse(wasPR, "Non-PR camera set must return false so share card does not show PR badge")
    }
}
