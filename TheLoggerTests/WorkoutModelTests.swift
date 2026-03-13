//
//  WorkoutModelTests.swift
//  TheLoggerTests
//
//  Unit tests for Workout, Exercise, and WorkoutSet models.
//  Each test follows Arrange → Act → Assert.
//

import XCTest
import SwiftData
@testable import TheLogger

@MainActor
final class WorkoutModelTests: XCTestCase {

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

    // MARK: - Workout Creation

    func testWorkoutCreation_setsNameAndDefaults() {
        let workout = Workout(name: "Push Day", date: Date(), isTemplate: false)

        XCTAssertEqual(workout.name, "Push Day")
        XCTAssertFalse(workout.isTemplate)
        XCTAssertFalse(workout.isActive)
        XCTAssertFalse(workout.isCompleted)
        XCTAssertNil(workout.startTime)
        XCTAssertNil(workout.endTime)
        XCTAssertEqual(workout.exerciseCount, 0)
        XCTAssertEqual(workout.totalSets, 0)
    }

    func testWorkoutCreation_templateFlag() {
        let template = Workout(name: "My Template", date: Date(), isTemplate: true)

        XCTAssertTrue(template.isTemplate)
        XCTAssertFalse(template.isActive)
        XCTAssertFalse(template.isCompleted)
    }

    // MARK: - Default Name Generation

    func testDefaultName_morningHour_returnsMorningWorkout() {
        var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        components.hour = 7
        let morningDate = Calendar.current.date(from: components)!

        let workout = Workout(name: "", date: morningDate, isTemplate: false)

        XCTAssertEqual(workout.name, "Morning Workout")
    }

    func testDefaultName_afternoonHour_returnsAfternoonWorkout() {
        var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        components.hour = 14
        let date = Calendar.current.date(from: components)!

        let workout = Workout(name: "", date: date, isTemplate: false)

        XCTAssertEqual(workout.name, "Afternoon Workout")
    }

    func testDefaultName_eveningHour_returnsEveningWorkout() {
        var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        components.hour = 19
        let date = Calendar.current.date(from: components)!

        let workout = Workout(name: "", date: date, isTemplate: false)

        XCTAssertEqual(workout.name, "Evening Workout")
    }

    func testDefaultName_nightHour_returnsNightWorkout() {
        var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        components.hour = 2
        let date = Calendar.current.date(from: components)!

        let workout = Workout(name: "", date: date, isTemplate: false)

        XCTAssertEqual(workout.name, "Night Workout")
    }

    func testDefaultName_withExercises_usesFirstExerciseName() {
        let exercise = Exercise(name: "Bench Press", order: 0)
        let workout = Workout(name: "", date: Date(), exercises: [exercise], isTemplate: false)

        XCTAssertEqual(workout.name, "Bench Press Workout")
    }

    // MARK: - Workout State Transitions

    func testIsActive_requiresStartTimeAndNoEndTime() {
        let workout = Workout(name: "Test", date: Date(), isTemplate: false)

        XCTAssertFalse(workout.isActive)

        workout.startTime = Date()
        XCTAssertTrue(workout.isActive)

        workout.endTime = Date()
        XCTAssertFalse(workout.isActive)
    }

    func testIsCompleted_requiresEndTime() {
        let workout = Workout(name: "Test", date: Date(), isTemplate: false)

        XCTAssertFalse(workout.isCompleted)

        workout.startTime = Date()
        XCTAssertFalse(workout.isCompleted)

        workout.endTime = Date()
        XCTAssertTrue(workout.isCompleted)
    }

    // MARK: - Exercise Management

    func testAddExercise_incrementsOrderAutomatically() {
        let workout = Workout(name: "Test", date: Date(), isTemplate: false)

        workout.addExercise(name: "Bench Press")
        workout.addExercise(name: "Squat")
        workout.addExercise(name: "Deadlift")

        let ordered = workout.exercisesByOrder
        XCTAssertEqual(ordered.count, 3)
        XCTAssertEqual(ordered[0].name, "Bench Press")
        XCTAssertEqual(ordered[0].order, 0)
        XCTAssertEqual(ordered[1].name, "Squat")
        XCTAssertEqual(ordered[1].order, 1)
        XCTAssertEqual(ordered[2].name, "Deadlift")
        XCTAssertEqual(ordered[2].order, 2)
    }

    func testRemoveExercise_removesById() {
        let workout = Workout(name: "Test", date: Date(), isTemplate: false)
        let ex1 = Exercise(name: "Bench Press", order: 0)
        let ex2 = Exercise(name: "Squat", order: 1)
        workout.exercises = [ex1, ex2]

        workout.removeExercise(id: ex1.id)

        XCTAssertEqual(workout.exerciseCount, 1)
        XCTAssertEqual(workout.exercises?.first?.name, "Squat")
    }

    func testGetExercise_returnsCorrectExercise() {
        let workout = Workout(name: "Test", date: Date(), isTemplate: false)
        let ex = Exercise(name: "Deadlift", order: 0)
        workout.exercises = [ex]

        let found = workout.getExercise(id: ex.id)
        XCTAssertNotNil(found)
        XCTAssertEqual(found?.name, "Deadlift")

        let notFound = workout.getExercise(id: UUID())
        XCTAssertNil(notFound)
    }

    func testExerciseOrdering_sortsCorrectlyRegardlessOfInsertionOrder() {
        let workout = Workout(name: "Test", date: Date(), isTemplate: false)
        let e1 = Exercise(name: "Bench Press", order: 0)
        let e2 = Exercise(name: "Rows", order: 1)
        let e3 = Exercise(name: "Curls", order: 2)
        workout.exercises = [e3, e1, e2] // Inserted out of order

        let ordered = workout.exercisesByOrder
        XCTAssertEqual(ordered[0].name, "Bench Press")
        XCTAssertEqual(ordered[1].name, "Rows")
        XCTAssertEqual(ordered[2].name, "Curls")
    }

    func testExerciseCount_reflectsCurrentExercises() {
        let workout = Workout(name: "Test", date: Date(), isTemplate: false)
        XCTAssertEqual(workout.exerciseCount, 0)

        workout.addExercise(name: "Bench Press")
        XCTAssertEqual(workout.exerciseCount, 1)

        workout.addExercise(name: "Squat")
        XCTAssertEqual(workout.exerciseCount, 2)
    }

    // MARK: - Workout Type Detection / Smart Naming

    /// updateNameFromExercises() uses first exercise name when it has a non-empty name.
    /// It only calls detectWorkoutType() when the first exercise has an empty name.
    func testUpdateNameFromExercises_singleExerciseWithName_usesExerciseName() {
        let workout = Workout(name: "Test", date: Date(), isTemplate: false)
        workout.name = "" // Force empty so the update triggers
        workout.exercises = [Exercise(name: "Bench Press", order: 0)]

        workout.updateNameFromExercises()

        XCTAssertEqual(workout.name, "Bench Press Workout")
    }

    func testUpdateNameFromExercises_namedWorkout_doesNotOverride() {
        // A user-named workout should not be overridden
        let workout = Workout(name: "My Custom Name", date: Date(), isTemplate: false)
        workout.addExercise(name: "Squat")

        workout.updateNameFromExercises()

        XCTAssertEqual(workout.name, "My Custom Name",
                       "User-set name should not be overridden by auto-naming")
    }

    func testUpdateNameFromExercises_multipleExercises_detectsPushDay() {
        let workout = Workout(name: "Test", date: Date(), isTemplate: false)
        workout.name = "" // Trigger update
        workout.exercises = [
            Exercise(name: "Bench Press", order: 0),
            Exercise(name: "Overhead Press", order: 1),
            Exercise(name: "Tricep Pushdown", order: 2)
        ]
        workout.updateNameFromExercises()
        XCTAssertEqual(workout.name, "Push Day")
    }

    func testUpdateNameFromExercises_multipleExercises_detectsPullDay() {
        let workout = Workout(name: "Test", date: Date(), isTemplate: false)
        workout.name = ""
        workout.exercises = [
            Exercise(name: "Deadlift", order: 0),
            Exercise(name: "Pull-Up", order: 1),
            Exercise(name: "Barbell Row", order: 2)
        ]
        workout.updateNameFromExercises()
        XCTAssertEqual(workout.name, "Pull Day")
    }

    func testUpdateNameFromExercises_multipleExercises_detectsLegDay() {
        let workout = Workout(name: "Test", date: Date(), isTemplate: false)
        workout.name = ""
        workout.exercises = [
            Exercise(name: "Squat", order: 0),
            Exercise(name: "Leg Press", order: 1),
            Exercise(name: "Lunge", order: 2)
        ]
        workout.updateNameFromExercises()
        XCTAssertEqual(workout.name, "Leg Day")
    }

    func testUpdateNameFromExercises_mixedPushPull_detectsUpperBody() {
        let workout = Workout(name: "Test", date: Date(), isTemplate: false)
        workout.name = ""
        workout.exercises = [
            Exercise(name: "Bench Press", order: 0),
            Exercise(name: "Barbell Row", order: 1)
        ]
        workout.updateNameFromExercises()
        XCTAssertEqual(workout.name, "Upper Body")
    }

    // MARK: - Set Management

    func testAddSet_setsInitialSortOrder() {
        let exercise = Exercise(name: "Bench Press", order: 0)
        exercise.addSet(reps: 10, weight: 135)

        XCTAssertEqual(exercise.sets?.count, 1)
        XCTAssertEqual(exercise.setsByOrder.first?.sortOrder, 0)
        XCTAssertEqual(exercise.setsByOrder.first?.reps, 10)
        XCTAssertEqual(exercise.setsByOrder.first?.weight, 135)
    }

    func testAddMultipleSets_sortOrderIncrements() {
        let exercise = Exercise(name: "Squat", order: 0)
        exercise.addSet(reps: 10, weight: 135)
        exercise.addSet(reps: 8, weight: 155)
        exercise.addSet(reps: 6, weight: 175)

        let sets = exercise.setsByOrder
        XCTAssertEqual(sets.count, 3)
        XCTAssertEqual(sets[0].sortOrder, 0)
        XCTAssertEqual(sets[1].sortOrder, 1)
        XCTAssertEqual(sets[2].sortOrder, 2)
    }

    func testRemoveSet_removesById() {
        let exercise = Exercise(name: "Deadlift", order: 0)
        exercise.addSet(reps: 5, weight: 315)
        exercise.addSet(reps: 5, weight: 315)
        let targetId = exercise.setsByOrder.first!.id

        exercise.removeSet(id: targetId)

        XCTAssertEqual(exercise.sets?.count, 1)
        XCTAssertFalse(exercise.sets?.contains { $0.id == targetId } ?? true)
    }

    func testTotalSets_sumsAcrossAllExercises() {
        let workout = Workout(name: "Test", date: Date(), isTemplate: false)
        let e1 = Exercise(name: "Bench Press", order: 0)
        e1.addSet(reps: 10, weight: 135)
        e1.addSet(reps: 8, weight: 155)

        let e2 = Exercise(name: "Squat", order: 1)
        e2.addSet(reps: 5, weight: 225)

        workout.exercises = [e1, e2]

        XCTAssertEqual(workout.totalSets, 3)
    }

    // MARK: - Exercise Computed Properties

    func testTotalReps_sumsAllSetReps() {
        let exercise = Exercise(name: "Curl", order: 0)
        exercise.addSet(reps: 12, weight: 30)
        exercise.addSet(reps: 10, weight: 35)
        exercise.addSet(reps: 8, weight: 40)

        XCTAssertEqual(exercise.totalReps, 30)
    }

    func testHasTimeBasedSets_returnsTrueIfAnySetHasDuration() {
        let exercise = Exercise(name: "Plank", order: 0)
        exercise.addSet(reps: 0, weight: 0, durationSeconds: 60)

        XCTAssertTrue(exercise.hasTimeBasedSets)
    }

    func testHasTimeBasedSets_returnsFalseForRepBasedExercise() {
        let exercise = Exercise(name: "Bench Press", order: 0)
        exercise.addSet(reps: 10, weight: 135)

        XCTAssertFalse(exercise.hasTimeBasedSets)
    }

    func testTotalDurationSeconds_sumsAllTimeBasedSets() {
        let exercise = Exercise(name: "Plank", order: 0)
        exercise.addSet(reps: 0, weight: 0, durationSeconds: 60)
        exercise.addSet(reps: 0, weight: 0, durationSeconds: 45)

        XCTAssertEqual(exercise.totalDurationSeconds, 105)
    }

    // MARK: - WorkoutSet Properties

    func testSetType_defaultIsWorking() {
        let set = WorkoutSet(reps: 10, weight: 135)

        XCTAssertEqual(set.type, .working)
        XCTAssertFalse(set.isWarmup)
    }

    func testSetType_warmupFlagReflected() {
        let set = WorkoutSet(reps: 10, weight: 95, setType: .warmup)

        XCTAssertTrue(set.isWarmup)
        XCTAssertEqual(set.type, .warmup)
    }

    func testSetType_isTimeBased_withDuration() {
        let set = WorkoutSet(reps: 0, weight: 0, durationSeconds: 60)

        XCTAssertTrue(set.isTimeBased)
    }

    func testSetType_isNotTimeBased_withoutDuration() {
        let set = WorkoutSet(reps: 10, weight: 135)

        XCTAssertFalse(set.isTimeBased)
    }

    func testSetType_countsForPR() {
        XCTAssertFalse(SetType.warmup.countsForPR)
        XCTAssertTrue(SetType.working.countsForPR)
        XCTAssertTrue(SetType.dropSet.countsForPR)
        XCTAssertTrue(SetType.failure.countsForPR)
        XCTAssertTrue(SetType.pause.countsForPR)
    }

    func testSetType_typeRoundTripFromString() {
        let set = WorkoutSet(reps: 5, weight: 200, setType: .dropSet)

        XCTAssertEqual(set.type, .dropSet)
        XCTAssertEqual(set.setType, "Drop Set")

        set.type = .failure
        XCTAssertEqual(set.setType, "Failure")
    }

    func testSetType_unknownStringFallsBackToWorking() {
        let set = WorkoutSet(reps: 10, weight: 100)
        set.setType = "UnknownType"

        XCTAssertEqual(set.type, .working)
    }

    // MARK: - Workout Duration

    func testWorkoutDuration_completedWorkout() {
        let start = Date()
        let workout = Workout(name: "Test", date: start, isTemplate: false)
        workout.startTime = start
        workout.endTime = start.addingTimeInterval(3600)

        let summary = WorkoutSummary(workout: workout)
        XCTAssertEqual(summary.duration ?? 0, 3600, accuracy: 1)
    }

    func testWorkoutDuration_activeWorkout_isApproximatelyNow() {
        let start = Date().addingTimeInterval(-1800) // 30 min ago
        let workout = Workout(name: "Test", date: start, isTemplate: false)
        workout.startTime = start

        let summary = WorkoutSummary(workout: workout)
        XCTAssertNotNil(summary.duration)
        XCTAssertGreaterThan(summary.duration ?? 0, 1700)
        XCTAssertLessThan(summary.duration ?? 0, 1900)
    }

    func testWorkoutDuration_noStartTime_returnsNil() {
        let workout = Workout(name: "Test", date: Date(), isTemplate: false)

        let summary = WorkoutSummary(workout: workout)
        XCTAssertNil(summary.duration)
    }

    // MARK: - WorkoutSummary Calculations

    func testWorkoutSummary_countsExercisesAndSets() {
        let workout = Workout(name: "Test", date: Date(), isTemplate: false)
        let e1 = Exercise(name: "Bench Press", order: 0)
        e1.addSet(reps: 10, weight: 135)
        e1.addSet(reps: 8, weight: 155)

        let e2 = Exercise(name: "Squat", order: 1)
        e2.addSet(reps: 5, weight: 225)

        workout.exercises = [e1, e2]
        workout.startTime = Date()
        workout.endTime = Date().addingTimeInterval(1800)

        let summary = WorkoutSummary(workout: workout)
        XCTAssertEqual(summary.totalExercises, 2)
        XCTAssertEqual(summary.totalSets, 3)
        XCTAssertEqual(summary.totalReps, 23) // 10+8+5
    }

    func testWorkoutSummary_totalVolume_isWeightTimesReps() {
        let workout = Workout(name: "Test", date: Date(), isTemplate: false)
        let exercise = Exercise(name: "Bench Press", order: 0)
        // 10 × 135 = 1350
        // 8 × 155 = 1240
        // Total = 2590
        exercise.addSet(reps: 10, weight: 135)
        exercise.addSet(reps: 8, weight: 155)
        workout.exercises = [exercise]

        let summary = WorkoutSummary(workout: workout)
        XCTAssertEqual(summary.totalVolume, 2590, accuracy: 0.01)
    }

    func testWorkoutSummary_formattedDuration_hours() {
        let start = Date()
        let workout = Workout(name: "Test", date: start, isTemplate: false)
        workout.startTime = start
        workout.endTime = start.addingTimeInterval(5400) // 1h 30m

        let summary = WorkoutSummary(workout: workout)
        XCTAssertTrue(summary.formattedDuration.contains("1h"))
    }

    func testWorkoutSummary_formattedDuration_minutesOnly() {
        let start = Date()
        let workout = Workout(name: "Test", date: start, isTemplate: false)
        workout.startTime = start
        workout.endTime = start.addingTimeInterval(1800) // 30m

        let summary = WorkoutSummary(workout: workout)
        XCTAssertTrue(summary.formattedDuration.contains("30m"))
        XCTAssertFalse(summary.formattedDuration.contains("h"))
    }

    func testWorkoutSummary_isEmpty_trueWhenNoExercisesOrSets() {
        let workout = Workout(name: "Test", date: Date(), isTemplate: false)
        let summary = WorkoutSummary(workout: workout)

        XCTAssertTrue(summary.isEmpty)
    }

    func testWorkoutSummary_isEmpty_falseWhenHasSets() {
        let workout = Workout(name: "Test", date: Date(), isTemplate: false)
        let exercise = Exercise(name: "Bench Press", order: 0)
        exercise.addSet(reps: 10, weight: 135)
        workout.exercises = [exercise]

        let summary = WorkoutSummary(workout: workout)
        XCTAssertFalse(summary.isEmpty)
    }
}
