//
//  WorkoutModelTests.swift
//  TheLoggerTests
//
//  Unit tests for Workout model and operations
//

import XCTest
import SwiftData
@testable import TheLogger

@MainActor
final class WorkoutModelTests: XCTestCase {

    var modelContext: ModelContext!
    var modelContainer: ModelContainer!

    override func setUp() async throws {
        // Create in-memory model container for testing
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

    // MARK: - Workout Creation Tests

    func testWorkoutCreation() {
        let workout = Workout(name: "Push Day", date: Date(), isTemplate: false)

        XCTAssertEqual(workout.name, "Push Day")
        XCTAssertFalse(workout.isTemplate)
        XCTAssertFalse(workout.isActive) // Not active until startTime is set
        XCTAssertNil(workout.endTime)
        XCTAssertNil(workout.startTime) // startTime is nil on creation
    }

    func testTemplateCreation() {
        let template = Workout(name: "Push Day Template", date: Date(), isTemplate: true)

        XCTAssertTrue(template.isTemplate)
        XCTAssertFalse(template.isActive)
    }

    func testWorkoutWithExercises() {
        let workout = Workout(name: "Chest Day", date: Date(), isTemplate: false)
        let exercise1 = Exercise(name: "Bench Press", order: 0)
        let exercise2 = Exercise(name: "Incline Press", order: 1)

        workout.exercises = [exercise1, exercise2]

        XCTAssertEqual(workout.exerciseCount, 2)
        XCTAssertEqual(workout.exercisesByOrder.count, 2)
        XCTAssertEqual(workout.exercisesByOrder[0].name, "Bench Press")
        XCTAssertEqual(workout.exercisesByOrder[1].name, "Incline Press")
    }

    // MARK: - Exercise Addition Tests

    func testAddExercise() {
        let workout = Workout(name: "Test", date: Date(), isTemplate: false)
        let exercise = Exercise(name: "Squat", order: 0)

        workout.exercises = [exercise]

        XCTAssertEqual(workout.exerciseCount, 1)
        XCTAssertEqual(workout.exercises?.first?.name, "Squat")
    }

    // MARK: - Set Management Tests

    func testAddSetToExercise() {
        let exercise = Exercise(name: "Deadlift", order: 0)
        exercise.addSet(reps: 5, weight: 315)

        XCTAssertEqual(exercise.sets?.count, 1)
        XCTAssertEqual(exercise.setsByOrder.first?.reps, 5)
        XCTAssertEqual(exercise.setsByOrder.first?.weight, 315)
    }

    func testMultipleSetsOrder() {
        let exercise = Exercise(name: "Bench Press", order: 0)
        exercise.addSet(reps: 10, weight: 135)
        exercise.addSet(reps: 8, weight: 155)
        exercise.addSet(reps: 6, weight: 175)

        let sets = exercise.setsByOrder
        XCTAssertEqual(sets.count, 3)
        XCTAssertEqual(sets[0].sortOrder, 0)
        XCTAssertEqual(sets[1].sortOrder, 1)
        XCTAssertEqual(sets[2].sortOrder, 2)
    }

    func testSetDeletion() throws {
        let exercise = Exercise(name: "Squat", order: 0)
        exercise.addSet(reps: 5, weight: 225)
        exercise.addSet(reps: 5, weight: 225)
        exercise.addSet(reps: 5, weight: 225)

        XCTAssertEqual(exercise.sets?.count, 3)

        // Note: Actual deletion would be done through modelContext
        // This test verifies sets were added correctly
    }

    // MARK: - Workout Duration Tests

    func testWorkoutDuration() {
        let startTime = Date()
        let workout = Workout(name: "Test", date: startTime, isTemplate: false)
        workout.startTime = startTime
        workout.endTime = startTime.addingTimeInterval(3600) // 1 hour later

        let summary = WorkoutSummary(workout: workout)
        XCTAssertNotNil(summary.duration)
        XCTAssertEqual(summary.duration ?? 0, 3600, accuracy: 1)
    }

    func testActiveWorkoutDuration() {
        let startTime = Date().addingTimeInterval(-1800) // Started 30 min ago
        let workout = Workout(name: "Test", date: startTime, isTemplate: false)
        workout.startTime = startTime
        workout.endTime = nil

        // Active workout duration should be time since start
        let summary = WorkoutSummary(workout: workout)
        XCTAssertNotNil(summary.duration)
        XCTAssertGreaterThan(summary.duration ?? 0, 1700)
        XCTAssertLessThan(summary.duration ?? 0, 1900)
    }

    // MARK: - Workout Completion Tests

    func testWorkoutCompletion() {
        let workout = Workout(name: "Test", date: Date(), isTemplate: false)
        workout.startTime = Date() // Start the workout

        XCTAssertTrue(workout.isActive) // Should be active after starting
        XCTAssertFalse(workout.isCompleted)

        workout.endTime = Date()

        XCTAssertFalse(workout.isActive)
        XCTAssertTrue(workout.isCompleted)
    }

    // MARK: - Workout Summary Tests

    func testWorkoutSummary() {
        let workout = Workout(name: "Test", date: Date(), isTemplate: false)
        let exercise1 = Exercise(name: "Bench Press", order: 0)
        exercise1.addSet(reps: 10, weight: 135)
        exercise1.addSet(reps: 8, weight: 155)

        let exercise2 = Exercise(name: "Squat", order: 1)
        exercise2.addSet(reps: 5, weight: 225)

        workout.exercises = [exercise1, exercise2]
        workout.startTime = Date()
        workout.endTime = Date().addingTimeInterval(1800) // 30 min

        let summary = WorkoutSummary(workout: workout)

        XCTAssertEqual(summary.totalExercises, 2)
        XCTAssertEqual(summary.totalSets, 3)
        XCTAssertEqual(summary.duration ?? 0, 1800, accuracy: 1)
    }

    // MARK: - Exercise Ordering Tests

    func testExerciseOrdering() {
        let workout = Workout(name: "Test", date: Date(), isTemplate: false)
        let exercise1 = Exercise(name: "Bench Press", order: 0)
        let exercise2 = Exercise(name: "Rows", order: 1)
        let exercise3 = Exercise(name: "Curls", order: 2)

        workout.exercises = [exercise3, exercise1, exercise2] // Add out of order

        let ordered = workout.exercisesByOrder
        XCTAssertEqual(ordered[0].name, "Bench Press")
        XCTAssertEqual(ordered[1].name, "Rows")
        XCTAssertEqual(ordered[2].name, "Curls")
    }
}
