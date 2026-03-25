//
//  ProgressComparisonTests.swift
//  TheLoggerTests
//
//  Unit tests for ExerciseProgressCalculator — the logic that compares
//  a current exercise against the most recent previous workout.
//

import XCTest
@testable import TheLogger

final class ProgressComparisonTests: XCTestCase {

    // MARK: - First Time

    func testCompare_noCompletedWorkouts_returnsFirstTime() {
        let current = makeExercise(name: "Bench Press", sets: [(10, 135)])
        let workout = makeCompletedWorkout(name: "Current", exercise: current)

        let result = ExerciseProgressCalculator.compare(
            exercise: current,
            currentWorkoutId: workout.id,
            completedWorkouts: [workout]
        )

        if case .firstTime = result {
            // Pass
        } else {
            XCTFail("Expected .firstTime, got \(result)")
        }
    }

    func testCompare_exerciseNotInPreviousWorkout_returnsFirstTime() {
        let current = makeExercise(name: "Deadlift", sets: [(5, 315)])
        let currentWorkout = makeCompletedWorkout(name: "Current", exercise: current)

        // Previous workout has different exercise
        let previousExercise = makeExercise(name: "Squat", sets: [(5, 225)])
        let previousWorkout = makeCompletedWorkout(name: "Previous", exercise: previousExercise)
        previousWorkout.date = Date().addingTimeInterval(-7 * 86400)

        let result = ExerciseProgressCalculator.compare(
            exercise: current,
            currentWorkoutId: currentWorkout.id,
            completedWorkouts: [currentWorkout, previousWorkout]
        )

        if case .firstTime = result {
            // Pass
        } else {
            XCTFail("Expected .firstTime when exercise not in previous workout")
        }
    }

    func testCompare_previousWorkoutHasNoCompletedSets_returnsFirstTime() {
        let current = makeExercise(name: "Bench Press", sets: [(8, 185)])
        let currentWorkout = makeCompletedWorkout(name: "Current", exercise: current)

        // Previous workout has bench press but with 0 reps (incomplete sets)
        let prevExercise = makeExercise(name: "Bench Press", sets: [(0, 135)])
        let previousWorkout = makeCompletedWorkout(name: "Previous", exercise: prevExercise)
        previousWorkout.date = Date().addingTimeInterval(-7 * 86400)

        let result = ExerciseProgressCalculator.compare(
            exercise: current,
            currentWorkoutId: currentWorkout.id,
            completedWorkouts: [currentWorkout, previousWorkout]
        )

        if case .firstTime = result {
            // Pass
        } else {
            XCTFail("Expected .firstTime when previous sets have 0 reps")
        }
    }

    func testCompare_noCompletedSetsInCurrentExercise_returnsFirstTime() {
        let current = makeExercise(name: "Bench Press", sets: [(0, 135)]) // 0 reps
        let currentWorkout = makeCompletedWorkout(name: "Current", exercise: current)

        let prevExercise = makeExercise(name: "Bench Press", sets: [(8, 185)])
        let previousWorkout = makeCompletedWorkout(name: "Previous", exercise: prevExercise)
        previousWorkout.date = Date().addingTimeInterval(-7 * 86400)

        let result = ExerciseProgressCalculator.compare(
            exercise: current,
            currentWorkoutId: currentWorkout.id,
            completedWorkouts: [currentWorkout, previousWorkout]
        )

        if case .firstTime = result {
            // Pass
        } else {
            XCTFail("Expected .firstTime when current exercise has no completed sets")
        }
    }

    // MARK: - Matched

    func testCompare_sameWeightAndReps_returnsMatched() {
        let current = makeExercise(name: "Bench Press", sets: [(8, 185)])
        let currentWorkout = makeCompletedWorkout(name: "Current", exercise: current)

        let prev = makeExercise(name: "Bench Press", sets: [(8, 185)])
        let prevWorkout = makeCompletedWorkout(name: "Previous", exercise: prev)
        prevWorkout.date = Date().addingTimeInterval(-7 * 86400)

        let result = ExerciseProgressCalculator.compare(
            exercise: current,
            currentWorkoutId: currentWorkout.id,
            completedWorkouts: [currentWorkout, prevWorkout]
        )

        if case .matched = result {
            // Pass
        } else {
            XCTFail("Expected .matched, got \(result)")
        }
    }

    // MARK: - Improved

    func testCompare_higherWeight_returnsImproved() {
        let current = makeExercise(name: "Squat", sets: [(5, 245)]) // +10 lbs
        let currentWorkout = makeCompletedWorkout(name: "Current", exercise: current)

        let prev = makeExercise(name: "Squat", sets: [(5, 235)])
        let prevWorkout = makeCompletedWorkout(name: "Previous", exercise: prev)
        prevWorkout.date = Date().addingTimeInterval(-7 * 86400)

        let result = ExerciseProgressCalculator.compare(
            exercise: current,
            currentWorkoutId: currentWorkout.id,
            completedWorkouts: [currentWorkout, prevWorkout]
        )

        if case .improved(let dw, _) = result {
            XCTAssertEqual(dw ?? 0.0, 10.0, accuracy: 0.01)
        } else {
            XCTFail("Expected .improved, got \(result)")
        }
    }

    func testCompare_higherReps_sameWeight_returnsImproved() {
        let current = makeExercise(name: "Bench Press", sets: [(10, 185)]) // +2 reps
        let currentWorkout = makeCompletedWorkout(name: "Current", exercise: current)

        let prev = makeExercise(name: "Bench Press", sets: [(8, 185)])
        let prevWorkout = makeCompletedWorkout(name: "Previous", exercise: prev)
        prevWorkout.date = Date().addingTimeInterval(-7 * 86400)

        let result = ExerciseProgressCalculator.compare(
            exercise: current,
            currentWorkoutId: currentWorkout.id,
            completedWorkouts: [currentWorkout, prevWorkout]
        )

        if case .improved(_, let dr) = result {
            XCTAssertEqual(dr, 2)
        } else {
            XCTFail("Expected .improved with reps delta, got \(result)")
        }
    }

    func testCompare_higherScore_evenWithLowerWeight_returnsImproved() {
        // More reps at slightly lower weight can still be improved overall
        // 12 × 180 = 2160 vs 8 × 185 = 1480
        let current = makeExercise(name: "Bench Press", sets: [(12, 180)])
        let currentWorkout = makeCompletedWorkout(name: "Current", exercise: current)

        let prev = makeExercise(name: "Bench Press", sets: [(8, 185)])
        let prevWorkout = makeCompletedWorkout(name: "Previous", exercise: prev)
        prevWorkout.date = Date().addingTimeInterval(-7 * 86400)

        let result = ExerciseProgressCalculator.compare(
            exercise: current,
            currentWorkoutId: currentWorkout.id,
            completedWorkouts: [currentWorkout, prevWorkout]
        )

        if case .improved = result {
            // Pass
        } else {
            XCTFail("Expected .improved when score is higher, got \(result)")
        }
    }

    func testImproved_isPositive_returnsTrue() {
        let comparison = ExerciseProgressComparison.improved(deltaWeight: 10, deltaReps: nil)
        XCTAssertTrue(comparison.isPositive)
    }

    // MARK: - Regressed

    func testCompare_lowerScore_returnsRegressed() {
        let current = makeExercise(name: "Deadlift", sets: [(3, 315)]) // Score: 945
        let currentWorkout = makeCompletedWorkout(name: "Current", exercise: current)

        let prev = makeExercise(name: "Deadlift", sets: [(5, 315)]) // Score: 1575
        let prevWorkout = makeCompletedWorkout(name: "Previous", exercise: prev)
        prevWorkout.date = Date().addingTimeInterval(-7 * 86400)

        let result = ExerciseProgressCalculator.compare(
            exercise: current,
            currentWorkoutId: currentWorkout.id,
            completedWorkouts: [currentWorkout, prevWorkout]
        )

        if case .regressed = result {
            // Pass
        } else {
            XCTFail("Expected .regressed, got \(result)")
        }
    }

    func testRegressed_isPositive_returnsFalse() {
        let comparison = ExerciseProgressComparison.regressed
        XCTAssertFalse(comparison.isPositive)
    }

    // MARK: - Template Exclusion

    func testCompare_templateWorkout_excluded() {
        let current = makeExercise(name: "Bench Press", sets: [(8, 185)])
        let currentWorkout = makeCompletedWorkout(name: "Current", exercise: current)

        let templateExercise = makeExercise(name: "Bench Press", sets: [(5, 225)])
        let template = Workout(name: "My Template", date: Date().addingTimeInterval(-86400), isTemplate: true)
        template.exercises = [templateExercise]
        template.startTime = Date()
        template.endTime = Date()

        let result = ExerciseProgressCalculator.compare(
            exercise: current,
            currentWorkoutId: currentWorkout.id,
            completedWorkouts: [currentWorkout, template]
        )

        if case .firstTime = result {
            // Pass — template should be excluded from comparison
        } else {
            XCTFail("Template workouts should not be used for comparison, got \(result)")
        }
    }

    func testCompare_currentWorkoutExcludedFromComparison() {
        let exercise = makeExercise(name: "Bench Press", sets: [(8, 185)])
        let workout = makeCompletedWorkout(name: "Only Workout", exercise: exercise)

        // If only completed workout is the current one, no previous exists
        let result = ExerciseProgressCalculator.compare(
            exercise: exercise,
            currentWorkoutId: workout.id,
            completedWorkouts: [workout]
        )

        if case .firstTime = result {
            // Pass
        } else {
            XCTFail("Current workout should not compare against itself")
        }
    }

    // MARK: - Exercise Name Normalization

    func testCompare_differentCasing_stillMatches() {
        let current = makeExercise(name: "bench press", sets: [(8, 185)])
        let currentWorkout = makeCompletedWorkout(name: "Current", exercise: current)

        let prev = makeExercise(name: "BENCH PRESS", sets: [(8, 185)])
        let prevWorkout = makeCompletedWorkout(name: "Previous", exercise: prev)
        prevWorkout.date = Date().addingTimeInterval(-86400)

        let result = ExerciseProgressCalculator.compare(
            exercise: current,
            currentWorkoutId: currentWorkout.id,
            completedWorkouts: [currentWorkout, prevWorkout]
        )

        if case .matched = result {
            // Pass
        } else {
            XCTFail("Should match case-insensitively, got \(result)")
        }
    }

    // MARK: - Display Text

    func testComparisonDisplayText_firstTime() {
        XCTAssertEqual(ExerciseProgressComparison.firstTime.displayText, "First time")
    }

    func testComparisonDisplayText_matched() {
        XCTAssertEqual(ExerciseProgressComparison.matched.displayText, "Matched last time")
    }

    func testComparisonDisplayText_regressed() {
        XCTAssertEqual(ExerciseProgressComparison.regressed.displayText, "Below previous")
    }

    func testComparisonDisplayText_improved_withWeightAndReps() {
        UserDefaults.standard.set("Imperial", forKey: "unitSystem")
        let result = ExerciseProgressComparison.improved(deltaWeight: 10, deltaReps: 2)
        XCTAssertTrue(result.displayText.contains("+"))
    }

    func testComparisonDisplayText_improved_nilDeltas_returnsImproved() {
        let result = ExerciseProgressComparison.improved(deltaWeight: nil, deltaReps: nil)
        XCTAssertEqual(result.displayText, "Improved")
    }

    // MARK: - Multi-set comparison

    func testCompare_previousHasMultipleSets_usesHighestScoreSet() {
        // Previous: 3 sets — best is (10, 135) score=1350
        let prev = Exercise(name: "Bench Press", order: 0)
        prev.addSet(reps: 8, weight: 100)   // score 800
        prev.addSet(reps: 10, weight: 135)  // score 1350 ← best
        prev.addSet(reps: 6, weight: 155)   // score 930
        let prevWorkout = makeCompletedWorkout(name: "Previous", exercise: prev)
        prevWorkout.date = Date().addingTimeInterval(-86400)

        // Current: 1 set with score 1080 (worse than previous best 1350)
        let current = makeExercise(name: "Bench Press", sets: [(8, 135)])
        let currentWorkout = makeCompletedWorkout(name: "Current", exercise: current)

        let result = ExerciseProgressCalculator.compare(
            exercise: current,
            currentWorkoutId: currentWorkout.id,
            completedWorkouts: [currentWorkout, prevWorkout]
        )

        if case .regressed = result {
            // Pass — current best (1080) < previous best (1350)
        } else {
            XCTFail("Expected .regressed when current best set is lower than previous best set, got \(result)")
        }
    }

    func testCompare_currentHasMultipleSets_usesHighestScoreSet() {
        // Previous: 1 set (8, 135) score=1080
        let prev = makeExercise(name: "Bench Press", sets: [(8, 135)])
        let prevWorkout = makeCompletedWorkout(name: "Previous", exercise: prev)
        prevWorkout.date = Date().addingTimeInterval(-86400)

        // Current: 3 sets — best is (10, 135) score=1350
        let current = Exercise(name: "Bench Press", order: 0)
        current.addSet(reps: 6, weight: 100)   // score 600
        current.addSet(reps: 10, weight: 135)  // score 1350 ← best
        current.addSet(reps: 8, weight: 110)   // score 880
        let currentWorkout = makeCompletedWorkout(name: "Current", exercise: current)

        let result = ExerciseProgressCalculator.compare(
            exercise: current,
            currentWorkoutId: currentWorkout.id,
            completedWorkouts: [currentWorkout, prevWorkout]
        )

        if case .improved = result {
            // Pass — current best (1350) > previous best (1080)
        } else {
            XCTFail("Expected .improved when current has a better set, got \(result)")
        }
    }

    func testCompare_bothHaveMultipleSets_comparesHighestScores() {
        // Previous best: (10, 135) = 1350
        let prev = Exercise(name: "Bench Press", order: 0)
        prev.addSet(reps: 8, weight: 100)
        prev.addSet(reps: 10, weight: 135)
        let prevWorkout = makeCompletedWorkout(name: "Previous", exercise: prev)
        prevWorkout.date = Date().addingTimeInterval(-86400)

        // Current best: (10, 135) = 1350 — matched
        let current = Exercise(name: "Bench Press", order: 0)
        current.addSet(reps: 6, weight: 100)
        current.addSet(reps: 10, weight: 135)
        let currentWorkout = makeCompletedWorkout(name: "Current", exercise: current)

        let result = ExerciseProgressCalculator.compare(
            exercise: current,
            currentWorkoutId: currentWorkout.id,
            completedWorkouts: [currentWorkout, prevWorkout]
        )

        if case .matched = result {
            // Pass
        } else {
            XCTFail("Expected .matched when best sets are equal, got \(result)")
        }
    }

    // MARK: - Time-based exercises

    func testCompare_timeBased_plankWithZeroReps_returnsFirstTime() {
        // Time-based exercises store reps=0; the calculator filters reps > 0.
        // Previous Plank: 60s, reps=0 → filtered out → no valid sets → firstTime
        let prev = Exercise(name: "Plank", order: 0)
        prev.addSet(reps: 0, weight: 0, durationSeconds: 60)
        let prevWorkout = makeCompletedWorkout(name: "Previous", exercise: prev)
        prevWorkout.date = Date().addingTimeInterval(-86400)

        let current = Exercise(name: "Plank", order: 0)
        current.addSet(reps: 0, weight: 0, durationSeconds: 90)
        let currentWorkout = makeCompletedWorkout(name: "Current", exercise: current)

        let result = ExerciseProgressCalculator.compare(
            exercise: current,
            currentWorkoutId: currentWorkout.id,
            completedWorkouts: [currentWorkout, prevWorkout]
        )

        // Time-based sets (reps=0) are filtered out, so both workouts appear to have
        // no valid sets, resulting in firstTime for the current set too.
        if case .firstTime = result {
            // Expected — documents current behavior for time-based exercises
        } else {
            XCTFail("Time-based exercises (reps=0) should return .firstTime due to reps filter, got \(result)")
        }
    }

    // MARK: - getPreviousBest

    func testGetPreviousBest_returnsCorrectValues() {
        let prev = makeExercise(name: "Bench Press", sets: [(10, 135), (8, 155), (6, 175)])
        let prevWorkout = makeCompletedWorkout(name: "Previous", exercise: prev)
        prevWorkout.date = Date().addingTimeInterval(-86400)

        let current = makeExercise(name: "Bench Press", sets: [(5, 185)])
        let currentWorkout = makeCompletedWorkout(name: "Current", exercise: current)

        let best = ExerciseProgressCalculator.getPreviousBest(
            exerciseName: "Bench Press",
            currentWorkoutId: currentWorkout.id,
            completedWorkouts: [currentWorkout, prevWorkout]
        )

        XCTAssertNotNil(best)
        // Best set from previous: (10, 135)=1350, (8,155)=1240, (6,175)=1050 → max is (10,135)
        XCTAssertEqual(best?.weight, 135)
        XCTAssertEqual(best?.reps, 10)
        XCTAssertEqual(best?.totalSets, 3)
    }

    func testGetPreviousBest_returnsNilForFirstTime() {
        let current = makeExercise(name: "Deadlift", sets: [(5, 315)])
        let currentWorkout = makeCompletedWorkout(name: "Only", exercise: current)

        let best = ExerciseProgressCalculator.getPreviousBest(
            exerciseName: "Deadlift",
            currentWorkoutId: currentWorkout.id,
            completedWorkouts: [currentWorkout]
        )

        XCTAssertNil(best)
    }

    // MARK: - Helpers

    private func makeExercise(name: String, sets: [(Int, Double)]) -> Exercise {
        let exercise = Exercise(name: name, order: 0)
        for (reps, weight) in sets {
            exercise.addSet(reps: reps, weight: weight)
        }
        return exercise
    }

    private func makeCompletedWorkout(name: String, exercise: Exercise) -> Workout {
        let workout = Workout(name: name, date: Date(), isTemplate: false)
        workout.startTime = Date()
        workout.endTime = Date().addingTimeInterval(3600)
        workout.exercises = [exercise]
        return workout
    }
}
