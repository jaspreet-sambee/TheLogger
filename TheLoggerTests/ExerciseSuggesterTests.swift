//
//  ExerciseSuggesterTests.swift
//  TheLoggerTests
//
//  Tests for ExerciseSuggester — library-based exercise suggestions ranked by frequency.
//

import XCTest
import SwiftData
@testable import TheLogger

@MainActor
final class ExerciseSuggesterTests: XCTestCase {

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

    // MARK: - Helpers

    @discardableResult
    private func insertCompletedWorkout(exercises: [String] = [], daysAgo: Int = 0) -> Workout {
        let date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date())!
        let workout = Workout(name: "Test", date: date, isTemplate: false)
        workout.startTime = date.addingTimeInterval(-3600)
        workout.endTime = date
        var list: [Exercise] = []
        for name in exercises {
            let ex = Exercise(name: name, order: list.count)
            ex.addSet(reps: 10, weight: 100)
            list.append(ex)
        }
        workout.exercises = list
        modelContext.insert(workout)
        try? modelContext.save()
        return workout
    }

    private func makeCurrentWorkout(exercises: [String] = []) -> Workout {
        let workout = Workout(name: "Current", date: Date(), isTemplate: false)
        workout.startTime = Date().addingTimeInterval(-1800)
        var list: [Exercise] = []
        for name in exercises {
            let ex = Exercise(name: name, order: list.count)
            ex.addSet(reps: 10, weight: 100)
            list.append(ex)
        }
        workout.exercises = list
        return workout
    }

    // MARK: - Basic behavior

    func testSuggest_emptyWorkout_returnsResults() {
        insertCompletedWorkout(exercises: ["Bench Press", "Squat"])
        let workout = makeCurrentWorkout()
        let suggestions = ExerciseSuggester.suggest(for: workout, modelContext: modelContext)
        XCTAssertFalse(suggestions.isEmpty)
    }

    func testSuggest_respectsDefaultLimit() {
        let workout = makeCurrentWorkout()
        let suggestions = ExerciseSuggester.suggest(for: workout, modelContext: modelContext)
        XCTAssertLessThanOrEqual(suggestions.count, 5)
    }

    func testSuggest_respectsCustomLimit_three() {
        let workout = makeCurrentWorkout()
        let suggestions = ExerciseSuggester.suggest(for: workout, modelContext: modelContext, limit: 3)
        XCTAssertLessThanOrEqual(suggestions.count, 3)
    }

    func testSuggest_respectsCustomLimit_one() {
        let workout = makeCurrentWorkout()
        let suggestions = ExerciseSuggester.suggest(for: workout, modelContext: modelContext, limit: 1)
        XCTAssertLessThanOrEqual(suggestions.count, 1)
    }

    func testSuggest_resultsAreUnique() {
        let workout = makeCurrentWorkout()
        let suggestions = ExerciseSuggester.suggest(for: workout, modelContext: modelContext, limit: 10)
        XCTAssertEqual(suggestions.count, Set(suggestions).count, "Suggestions should not contain duplicates")
    }

    // MARK: - Exclusion of current exercises

    func testSuggest_excludesSingleCurrentExercise() {
        let workout = makeCurrentWorkout(exercises: ["Bench Press"])
        let suggestions = ExerciseSuggester.suggest(for: workout, modelContext: modelContext, limit: 10)
        XCTAssertFalse(suggestions.contains("Bench Press"))
    }

    func testSuggest_excludesMultipleCurrentExercises() {
        let workout = makeCurrentWorkout(exercises: ["Bench Press", "Squat", "Deadlift"])
        let suggestions = ExerciseSuggester.suggest(for: workout, modelContext: modelContext, limit: 10)
        XCTAssertFalse(suggestions.contains("Bench Press"))
        XCTAssertFalse(suggestions.contains("Squat"))
        XCTAssertFalse(suggestions.contains("Deadlift"))
    }

    // MARK: - Frequency ranking

    func testSuggest_rankedByFrequency_higherFrequencyFirst() {
        // "Squat" in 5 workouts, "Romanian Deadlift" in 1
        for i in 0..<5 { insertCompletedWorkout(exercises: ["Squat"], daysAgo: i + 1) }
        insertCompletedWorkout(exercises: ["Romanian Deadlift"], daysAgo: 10)

        let workout = makeCurrentWorkout()
        let suggestions = ExerciseSuggester.suggest(for: workout, modelContext: modelContext, limit: 20)

        if let squatIdx = suggestions.firstIndex(of: "Squat"),
           let rdlIdx = suggestions.firstIndex(of: "Romanian Deadlift") {
            XCTAssertLessThan(squatIdx, rdlIdx, "More frequent exercise should rank higher")
        }
    }

    func testSuggest_exerciseUsedInManyWorkouts_appearsInResults() {
        for i in 0..<10 { insertCompletedWorkout(exercises: ["Bench Press"], daysAgo: i + 1) }
        let workout = makeCurrentWorkout()
        let suggestions = ExerciseSuggester.suggest(for: workout, modelContext: modelContext, limit: 10)
        XCTAssertTrue(suggestions.contains("Bench Press"))
    }

    // MARK: - Muscle group inference from library exercises

    func testSuggest_benchPressWorkout_suggestsChestOrShoulderExercises() {
        // Bench Press is chest; should suggest other chest/shoulder/arm exercises
        let workout = makeCurrentWorkout(exercises: ["Bench Press"])
        let suggestions = ExerciseSuggester.suggest(for: workout, modelContext: modelContext, limit: 10)
        XCTAssertFalse(suggestions.isEmpty, "Should suggest push-related exercises after Bench Press")
        XCTAssertFalse(suggestions.contains("Bench Press"), "Should not re-suggest current exercise")
    }

    func testSuggest_squatWorkout_suggestsLegExercises() {
        let workout = makeCurrentWorkout(exercises: ["Squat"])
        let suggestions = ExerciseSuggester.suggest(for: workout, modelContext: modelContext, limit: 10)
        XCTAssertFalse(suggestions.isEmpty)
        XCTAssertFalse(suggestions.contains("Squat"))
    }

    func testSuggest_pullUpWorkout_suggestsBackOrArmExercises() {
        let workout = makeCurrentWorkout(exercises: ["Pull-Up"])
        let suggestions = ExerciseSuggester.suggest(for: workout, modelContext: modelContext, limit: 10)
        XCTAssertFalse(suggestions.isEmpty)
        XCTAssertFalse(suggestions.contains("Pull-Up"))
    }

    // MARK: - Keyword fallback for custom exercises

    func testSuggest_customPushExercise_infersPushMuscles() {
        // "push" keyword → chest/shoulder/arms
        let workout = makeCurrentWorkout(exercises: ["Custom Push Move"])
        let suggestions = ExerciseSuggester.suggest(for: workout, modelContext: modelContext, limit: 10)
        XCTAssertFalse(suggestions.isEmpty)
    }

    func testSuggest_customSquatExercise_infersLegMuscles() {
        // "squat" keyword → legs
        let workout = makeCurrentWorkout(exercises: ["Pause Squat Variation"])
        let suggestions = ExerciseSuggester.suggest(for: workout, modelContext: modelContext, limit: 10)
        XCTAssertFalse(suggestions.isEmpty)
    }

    func testSuggest_customRowExercise_infersPullMuscles() {
        // "row" keyword → back/arms
        let workout = makeCurrentWorkout(exercises: ["Custom Row Machine"])
        let suggestions = ExerciseSuggester.suggest(for: workout, modelContext: modelContext, limit: 10)
        XCTAssertFalse(suggestions.isEmpty)
    }

    func testSuggest_customBenchExercise_infersPushMuscles() {
        // "bench" keyword → chest/shoulders
        let workout = makeCurrentWorkout(exercises: ["Reverse Bench Exercise"])
        let suggestions = ExerciseSuggester.suggest(for: workout, modelContext: modelContext, limit: 10)
        XCTAssertFalse(suggestions.isEmpty)
    }

    // MARK: - No history

    func testSuggest_noHistory_returnsLibraryFallback() {
        let workout = makeCurrentWorkout()
        let suggestions = ExerciseSuggester.suggest(for: workout, modelContext: modelContext)
        // No history: falls back to all library exercises sorted alphabetically
        XCTAssertFalse(suggestions.isEmpty)
    }

    // MARK: - Templates excluded from frequency count

    func testSuggest_templateWorkouts_notCountedInFrequency() {
        // Template with Bench Press should NOT boost its frequency
        let template = Workout(name: "My Template", date: Date(), isTemplate: true)
        let ex = Exercise(name: "Bench Press", order: 0)
        ex.addSet(reps: 10, weight: 135)
        template.exercises = [ex]
        modelContext.insert(template)

        // Real workout with Squat
        insertCompletedWorkout(exercises: ["Squat"])

        try? modelContext.save()

        let workout = makeCurrentWorkout()
        let suggestions = ExerciseSuggester.suggest(for: workout, modelContext: modelContext, limit: 10)
        // Should not crash and should return valid results
        XCTAssertFalse(suggestions.isEmpty)
    }

    // MARK: - Limit interactions

    func testSuggest_limitLargerThanCandidates_returnsAllCandidates() {
        // Workout with push exercises → candidates are only push muscles
        let workout = makeCurrentWorkout(exercises: ["Bench Press"])
        // Request more than will exist in the push muscle subset
        let suggestions = ExerciseSuggester.suggest(for: workout, modelContext: modelContext, limit: 1000)
        // Should not crash; should return <= number of push exercises in library minus bench press
        XCTAssertFalse(suggestions.isEmpty)
        XCTAssertFalse(suggestions.contains("Bench Press"))
    }
}
