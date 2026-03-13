//
//  SupersetTests.swift
//  TheLoggerTests
//
//  Unit tests for superset management: creating, breaking,
//  and modifying supersets within a workout.
//

import XCTest
import SwiftData
@testable import TheLogger

@MainActor
final class SupersetTests: XCTestCase {

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

    // MARK: - Create Superset

    func testCreateSuperset_twoExercises_assignsSameGroupId() {
        let workout = makeWorkoutWithExercises(["Bench Press", "Dumbbell Fly"])
        let exercises = workout.exercisesByOrder
        let ids = exercises.map(\.id)

        workout.createSuperset(from: ids)

        let groupIds = exercises.compactMap(\.supersetGroupId)
        XCTAssertEqual(Set(groupIds).count, 1, "Both exercises should share one superset group ID")
    }

    func testCreateSuperset_assignsOrderWithinGroup() {
        let workout = makeWorkoutWithExercises(["Pull-Up", "Face Pull"])
        let exercises = workout.exercisesByOrder
        let ids = exercises.map(\.id)

        workout.createSuperset(from: ids)

        let ordered = exercises.sorted { $0.supersetOrder < $1.supersetOrder }
        XCTAssertEqual(ordered[0].name, "Pull-Up")
        XCTAssertEqual(ordered[0].supersetOrder, 0)
        XCTAssertEqual(ordered[1].name, "Face Pull")
        XCTAssertEqual(ordered[1].supersetOrder, 1)
    }

    func testCreateSuperset_threeExercises_triSet() {
        let workout = makeWorkoutWithExercises(["Squat", "Leg Press", "Leg Extension"])
        let ids = workout.exercisesByOrder.map(\.id)

        workout.createSuperset(from: ids)

        let groupIds = workout.exercisesByOrder.compactMap(\.supersetGroupId)
        XCTAssertEqual(Set(groupIds).count, 1, "Tri-set: all three should share one group")
    }

    func testCreateSuperset_oneExercise_doesNothing() {
        let workout = makeWorkoutWithExercises(["Bench Press"])
        let ids = workout.exercisesByOrder.map(\.id)

        workout.createSuperset(from: ids) // Requires >= 2

        XCTAssertNil(workout.exercisesByOrder.first?.supersetGroupId, "Single exercise cannot form superset")
    }

    func testCreateSuperset_emptyArray_doesNothing() {
        let workout = makeWorkoutWithExercises(["Bench Press", "Squat"])
        workout.createSuperset(from: [])

        XCTAssertNil(workout.exercisesByOrder.first?.supersetGroupId)
    }

    // MARK: - isInSuperset

    func testIsInSuperset_trueAfterSupersetCreated() {
        let workout = makeWorkoutWithExercises(["Bench Press", "Dips"])
        let ids = workout.exercisesByOrder.map(\.id)
        workout.createSuperset(from: ids)

        XCTAssertTrue(workout.exercisesByOrder[0].isInSuperset)
        XCTAssertTrue(workout.exercisesByOrder[1].isInSuperset)
    }

    func testIsInSuperset_falseForStandaloneExercise() {
        let workout = makeWorkoutWithExercises(["Squat"])
        XCTAssertFalse(workout.exercisesByOrder[0].isInSuperset)
    }

    // MARK: - Break Superset

    func testBreakSuperset_makesAllExercisesStandalone() {
        let workout = makeWorkoutWithExercises(["Bench Press", "Dumbbell Fly"])
        let ids = workout.exercisesByOrder.map(\.id)
        workout.createSuperset(from: ids)

        let groupId = workout.exercisesByOrder[0].supersetGroupId!
        workout.breakSuperset(groupId: groupId)

        for exercise in workout.exercisesByOrder {
            XCTAssertNil(exercise.supersetGroupId, "\(exercise.name) should have no group after break")
            XCTAssertEqual(exercise.supersetOrder, 0)
        }
    }

    func testBreakSuperset_wrongGroupId_noEffect() {
        let workout = makeWorkoutWithExercises(["Bench Press", "Dumbbell Fly"])
        let ids = workout.exercisesByOrder.map(\.id)
        workout.createSuperset(from: ids)

        let fakeGroupId = UUID()
        workout.breakSuperset(groupId: fakeGroupId)

        for exercise in workout.exercisesByOrder {
            XCTAssertNotNil(exercise.supersetGroupId, "Group should be untouched with wrong groupId")
        }
    }

    // MARK: - Add To Superset

    func testAddToSuperset_addsThirdExercise() {
        let workout = makeWorkoutWithExercises(["Bench Press", "Dumbbell Fly", "Cable Fly"])
        let exercises = workout.exercisesByOrder
        // Create initial superset with first two
        workout.createSuperset(from: [exercises[0].id, exercises[1].id])
        let groupId = exercises[0].supersetGroupId!

        workout.addToSuperset(exerciseId: exercises[2].id, groupId: groupId)

        XCTAssertEqual(exercises[2].supersetGroupId, groupId)
        XCTAssertEqual(exercises[2].supersetOrder, 2, "Third exercise should have order 2")
    }

    func testAddToSuperset_invalidExerciseId_doesNothing() {
        let workout = makeWorkoutWithExercises(["Bench Press", "Squat"])
        let ids = workout.exercisesByOrder.map(\.id)
        workout.createSuperset(from: ids)
        let groupId = workout.exercisesByOrder[0].supersetGroupId!

        workout.addToSuperset(exerciseId: UUID(), groupId: groupId) // Invalid ID

        // No crash, no change
        XCTAssertEqual(workout.exercisesInSuperset(groupId: groupId).count, 2)
    }

    // MARK: - Remove From Superset

    func testRemoveFromSuperset_oneExercise_becomesStandalone() {
        let workout = makeWorkoutWithExercises(["Bench Press", "Dumbbell Fly", "Cable Fly"])
        let exercises = workout.exercisesByOrder
        workout.createSuperset(from: exercises.map(\.id))
        let groupId = exercises[0].supersetGroupId!

        workout.removeFromSuperset(exerciseId: exercises[2].id)

        XCTAssertNil(exercises[2].supersetGroupId, "Removed exercise should be standalone")
        XCTAssertEqual(exercises[2].supersetOrder, 0)
        // Remaining two still in group
        XCTAssertEqual(workout.exercisesInSuperset(groupId: groupId).count, 2)
    }

    func testRemoveFromSuperset_lastTwoExercises_bothBecomesStandalone() {
        let workout = makeWorkoutWithExercises(["Bench Press", "Dumbbell Fly"])
        let exercises = workout.exercisesByOrder
        workout.createSuperset(from: exercises.map(\.id))

        // Remove one — only 1 remains, it should also become standalone
        workout.removeFromSuperset(exerciseId: exercises[0].id)

        XCTAssertNil(exercises[0].supersetGroupId, "Removed exercise standalone")
        XCTAssertNil(exercises[1].supersetGroupId, "Last remaining exercise also becomes standalone")
    }

    func testRemoveFromSuperset_nonSupersetExercise_doesNothing() {
        let workout = makeWorkoutWithExercises(["Bench Press"])
        workout.removeFromSuperset(exerciseId: workout.exercisesByOrder[0].id)
        XCTAssertNil(workout.exercisesByOrder[0].supersetGroupId)
    }

    // MARK: - exercisesInSuperset

    func testExercisesInSuperset_returnsCorrectExercisesInOrder() {
        let workout = makeWorkoutWithExercises(["A", "B", "C"])
        let exercises = workout.exercisesByOrder
        workout.createSuperset(from: exercises.map(\.id))
        let groupId = exercises[0].supersetGroupId!

        let inGroup = workout.exercisesInSuperset(groupId: groupId)
        XCTAssertEqual(inGroup.count, 3)
        XCTAssertEqual(inGroup[0].name, "A")
        XCTAssertEqual(inGroup[1].name, "B")
        XCTAssertEqual(inGroup[2].name, "C")
    }

    func testExercisesInSuperset_unknownGroupId_returnsEmpty() {
        let workout = makeWorkoutWithExercises(["Bench Press"])
        let result = workout.exercisesInSuperset(groupId: UUID())
        XCTAssertTrue(result.isEmpty)
    }

    // MARK: - isLastInSuperset

    func testIsLastInSuperset_lastExercise_returnsTrue() {
        let workout = makeWorkoutWithExercises(["A", "B", "C"])
        let exercises = workout.exercisesByOrder
        workout.createSuperset(from: exercises.map(\.id))

        XCTAssertTrue(workout.isLastInSuperset(exercises[2]))
    }

    func testIsLastInSuperset_firstExercise_returnsFalse() {
        let workout = makeWorkoutWithExercises(["A", "B", "C"])
        let exercises = workout.exercisesByOrder
        workout.createSuperset(from: exercises.map(\.id))

        XCTAssertFalse(workout.isLastInSuperset(exercises[0]))
    }

    func testIsLastInSuperset_standaloneExercise_returnsTrue() {
        let workout = makeWorkoutWithExercises(["Bench Press"])
        let exercise = workout.exercisesByOrder[0]
        // Standalone exercise has no superset, guard returns true
        XCTAssertTrue(workout.isLastInSuperset(exercise))
    }

    // MARK: - ExerciseDisplayItem

    func testExercisesGroupedForDisplay_standalone_oneItemPerExercise() {
        let workout = makeWorkoutWithExercises(["Bench Press", "Squat"])

        let items = workout.exercisesGroupedForDisplay
        XCTAssertEqual(items.count, 2)
        XCTAssertFalse(items[0].isSuperset)
        XCTAssertFalse(items[1].isSuperset)
    }

    func testExercisesGroupedForDisplay_superset_appearsAsOneItem() {
        let workout = makeWorkoutWithExercises(["Bench Press", "Dumbbell Fly", "Squat"])
        let exercises = workout.exercisesByOrder
        workout.createSuperset(from: [exercises[0].id, exercises[1].id])

        let items = workout.exercisesGroupedForDisplay
        // Superset (2 exercises) + standalone Squat = 2 display items
        XCTAssertEqual(items.count, 2)
        XCTAssertTrue(items[0].isSuperset)
        XCTAssertFalse(items[1].isSuperset)
    }

    func testExerciseDisplayItemDisplayName_twoExercises_isSuperset() {
        let workout = makeWorkoutWithExercises(["A", "B"])
        let exercises = workout.exercisesByOrder
        workout.createSuperset(from: exercises.map(\.id))

        let item = workout.exercisesGroupedForDisplay[0]
        XCTAssertEqual(item.displayName, "Superset")
    }

    func testExerciseDisplayItemDisplayName_threeExercises_isTriSet() {
        let workout = makeWorkoutWithExercises(["A", "B", "C"])
        let exercises = workout.exercisesByOrder
        workout.createSuperset(from: exercises.map(\.id))

        let item = workout.exercisesGroupedForDisplay[0]
        XCTAssertEqual(item.displayName, "Tri-set")
    }

    func testExerciseDisplayItemDisplayName_fourExercises_isGiantSet() {
        let workout = makeWorkoutWithExercises(["A", "B", "C", "D"])
        let exercises = workout.exercisesByOrder
        workout.createSuperset(from: exercises.map(\.id))

        let item = workout.exercisesGroupedForDisplay[0]
        XCTAssertEqual(item.displayName, "Giant Set")
    }

    func testExerciseDisplayItem_allExercises_correctCount() {
        let workout = makeWorkoutWithExercises(["A", "B", "C"])
        let exercises = workout.exercisesByOrder
        workout.createSuperset(from: exercises.map(\.id))

        let item = workout.exercisesGroupedForDisplay[0]
        XCTAssertEqual(item.allExercises.count, 3)
    }

    // MARK: - Helper

    private func makeWorkoutWithExercises(_ names: [String]) -> Workout {
        let workout = Workout(name: "Test Workout", date: Date(), isTemplate: false)
        for (index, name) in names.enumerated() {
            let exercise = Exercise(name: name, order: index)
            if workout.exercises == nil {
                workout.exercises = [exercise]
            } else {
                workout.exercises?.append(exercise)
            }
        }
        return workout
    }
}
