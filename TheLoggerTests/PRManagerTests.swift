//
//  PRManagerTests.swift
//  TheLoggerTests
//
//  Unit tests for Personal Record detection and management
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

    // MARK: - 1RM Calculation Tests

    func testEstimated1RMCalculation() {
        let workout = Workout(name: "Test", date: Date(), isTemplate: false)
        modelContext.insert(workout)

        // Test 1: 225 lbs x 10 reps
        // Epley: 225 * (1 + 10/30) = 225 * 1.333 = 300.0
        let pr1 = PersonalRecord(exerciseName: "Bench Press", weight: 225, reps: 10, workoutId: workout.id)
        XCTAssertEqual(pr1.estimated1RM, 300.0, accuracy: 1.0)

        // Test 2: 300 lbs x 5 reps
        // Epley: 300 * (1 + 5/30) = 300 * 1.167 = 350.0
        let pr2 = PersonalRecord(exerciseName: "Squat", weight: 300, reps: 5, workoutId: workout.id)
        XCTAssertEqual(pr2.estimated1RM, 350.0, accuracy: 1.0)
    }

    func testEstimated1RMForHighReps() {
        let workout = Workout(name: "Test", date: Date(), isTemplate: false)
        modelContext.insert(workout)

        // Epley works for all rep ranges — high-rep sets get a real 1RM estimate
        // 135 lbs x 15 reps: 135 * (1 + 15/30) = 135 * 1.5 = 202.5
        let pr = PersonalRecord(exerciseName: "Leg Press", weight: 135, reps: 15, workoutId: workout.id)
        XCTAssertEqual(pr.estimated1RM, 202.5, accuracy: 1.0)
    }

    // MARK: - PR Detection Tests

    func testFirstSetSavedAsPR() {
        let workout = Workout(name: "Test", date: Date(), isTemplate: false)
        modelContext.insert(workout)

        _ = PersonalRecordManager.checkAndSavePR(
            exerciseName: "Bench Press",
            weight: 225,
            reps: 5,
            workoutId: workout.id,
            modelContext: modelContext
        )

        // First set is saved as a baseline PR record (no celebration, but record exists)
        let pr = PersonalRecordManager.getPR(for: "Bench Press", modelContext: modelContext)
        XCTAssertNotNil(pr, "First set should be saved as a PR baseline")
        XCTAssertEqual(pr?.weight, 225)
        XCTAssertEqual(pr?.reps, 5)
    }

    func testHigherWeightIsPR() {
        let workout1 = Workout(name: "Test 1", date: Date(), isTemplate: false)
        modelContext.insert(workout1)

        // Save initial PR
        _ = PersonalRecordManager.checkAndSavePR(
            exerciseName: "Squat",
            weight: 315,
            reps: 5,
            workoutId: workout1.id,
            modelContext: modelContext
        )

        let workout2 = Workout(name: "Test 2", date: Date(), isTemplate: false)
        modelContext.insert(workout2)

        // Higher weight with same reps should be PR
        let isNewPR = PersonalRecordManager.checkAndSavePR(
            exerciseName: "Squat",
            weight: 335,
            reps: 5,
            workoutId: workout2.id,
            modelContext: modelContext
        )

        XCTAssertTrue(isNewPR, "Higher weight should be a PR")
    }

    func testLowerWeightIsNotPR() {
        let workout1 = Workout(name: "Test 1", date: Date(), isTemplate: false)
        modelContext.insert(workout1)

        // Save initial PR
        _ = PersonalRecordManager.checkAndSavePR(
            exerciseName: "Deadlift",
            weight: 405,
            reps: 5,
            workoutId: workout1.id,
            modelContext: modelContext
        )

        let workout2 = Workout(name: "Test 2", date: Date(), isTemplate: false)
        modelContext.insert(workout2)

        // Lower weight should not be PR
        let isNewPR = PersonalRecordManager.checkAndSavePR(
            exerciseName: "Deadlift",
            weight: 385,
            reps: 5,
            workoutId: workout2.id,
            modelContext: modelContext
        )

        XCTAssertFalse(isNewPR, "Lower weight should not be a PR")
    }

    // MARK: - Set Type Tests

    func testWarmupSetsNotPR() {
        let workout = Workout(name: "Test", date: Date(), isTemplate: false)
        modelContext.insert(workout)

        // Warmup sets should not count as PRs
        let isNewPR = PersonalRecordManager.checkAndSavePR(
            exerciseName: "Bench Press",
            weight: 135,
            reps: 10,
            workoutId: workout.id,
            modelContext: modelContext,
            setType: .warmup
        )

        XCTAssertFalse(isNewPR, "Warmup sets should not be PRs")
    }

    // MARK: - Edge Cases

    func testBodyweightSetSavedAsPR() {
        let workout = Workout(name: "Test", date: Date(), isTemplate: false)
        modelContext.insert(workout)

        // Bodyweight exercises (weight = 0) are valid and tracked by rep count
        _ = PersonalRecordManager.checkAndSavePR(
            exerciseName: "Pull-ups",
            weight: 0,
            reps: 15,
            workoutId: workout.id,
            modelContext: modelContext
        )

        let pr = PersonalRecordManager.getPR(for: "Pull-ups", modelContext: modelContext)
        XCTAssertNotNil(pr, "Bodyweight set should be saved as a PR")
        XCTAssertEqual(pr?.reps, 15)
        XCTAssertTrue(pr?.isBodyweight ?? false)
    }
}
