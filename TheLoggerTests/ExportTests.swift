//
//  ExportTests.swift
//  TheLoggerTests
//
//  Unit tests for WorkoutDataExporter: CSV generation, filtering,
//  unit conversion, and special character handling.
//

import XCTest
@testable import TheLogger

final class ExportTests: XCTestCase {

    override func setUp() {
        UserDefaults.standard.set("Imperial", forKey: "unitSystem")
    }

    override func tearDown() {
        UserDefaults.standard.set("Imperial", forKey: "unitSystem")
    }

    // MARK: - CSV Header

    func testCSVHeader_imperial_containsLbsColumn() {
        let csv = WorkoutDataExporter.generateCSV(from: [])
        XCTAssertTrue(csv.hasPrefix("Workout Date,Workout Name,Exercise,Set Number,Reps,Weight (lbs)"))
    }

    func testCSVHeader_metric_containsKgColumn() {
        UserDefaults.standard.set("Metric", forKey: "unitSystem")
        let csv = WorkoutDataExporter.generateCSV(from: [])
        XCTAssertTrue(csv.contains("Weight (kg)"))
    }

    // MARK: - Workout Filtering

    func testCSVExport_excludesTemplates() {
        let template = makeCompletedWorkout(name: "My Template", exerciseName: "Squat", isTemplate: true)
        let csv = WorkoutDataExporter.generateCSV(from: [template])
        XCTAssertFalse(csv.contains("My Template"), "Templates should not appear in CSV export")
    }

    func testCSVExport_excludesActiveWorkouts_noEndTime() {
        let active = Workout(name: "Active Workout", date: Date(), isTemplate: false)
        active.startTime = Date()
        // No endTime = still active
        let exercise = Exercise(name: "Bench Press", order: 0)
        exercise.addSet(reps: 10, weight: 135)
        active.exercises = [exercise]

        let csv = WorkoutDataExporter.generateCSV(from: [active])
        XCTAssertFalse(csv.contains("Active Workout"), "Active (incomplete) workouts should not export")
    }

    func testCSVExport_includesCompletedWorkouts() {
        let workout = makeCompletedWorkout(name: "Push Day", exerciseName: "Bench Press")
        let csv = WorkoutDataExporter.generateCSV(from: [workout])
        XCTAssertTrue(csv.contains("Push Day"))
        XCTAssertTrue(csv.contains("Bench Press"))
    }

    // MARK: - CSV Content

    func testCSVExport_setNumberStartsAtOne() {
        let workout = makeCompletedWorkout(name: "Test", exerciseName: "Squat", setCount: 3)
        let csv = WorkoutDataExporter.generateCSV(from: [workout])

        let lines = csv.components(separatedBy: "\n").filter { $0.contains("Squat") }
        XCTAssertEqual(lines.count, 3)
        XCTAssertTrue(lines[0].contains(",1,"), "First set should be set #1")
        XCTAssertTrue(lines[1].contains(",2,"), "Second set should be set #2")
        XCTAssertTrue(lines[2].contains(",3,"), "Third set should be set #3")
    }

    func testCSVExport_weightConvertedToDisplayUnit_metric() {
        UserDefaults.standard.set("Metric", forKey: "unitSystem")
        // 100 lbs stored, exported as kg
        let workout = makeCompletedWorkout(name: "Test", exerciseName: "Bench Press", weight: 100)
        let csv = WorkoutDataExporter.generateCSV(from: [workout])

        // 100 lbs ≈ 45.36 kg
        XCTAssertTrue(csv.contains("45.") || csv.contains("45,"), "Should export in kg when metric")
        XCTAssertFalse(csv.contains(",100.0,"), "Should not export raw lbs in metric mode")
    }

    func testCSVExport_multipleExercisesAllIncluded() {
        let workout = Workout(name: "Full Body", date: Date(), isTemplate: false)
        workout.startTime = Date()
        workout.endTime = Date().addingTimeInterval(3600)

        let e1 = Exercise(name: "Squat", order: 0)
        e1.addSet(reps: 5, weight: 225)
        let e2 = Exercise(name: "Bench Press", order: 1)
        e2.addSet(reps: 8, weight: 185)
        let e3 = Exercise(name: "Deadlift", order: 2)
        e3.addSet(reps: 3, weight: 315)
        workout.exercises = [e1, e2, e3]

        let csv = WorkoutDataExporter.generateCSV(from: [workout])
        XCTAssertTrue(csv.contains("Squat"))
        XCTAssertTrue(csv.contains("Bench Press"))
        XCTAssertTrue(csv.contains("Deadlift"))
    }

    func testCSVExport_sortedByDateMostRecentFirst() {
        let older = makeCompletedWorkout(name: "Older Workout", exerciseName: "Squat")
        older.date = Date().addingTimeInterval(-7 * 86400) // 7 days ago

        let newer = makeCompletedWorkout(name: "Newer Workout", exerciseName: "Bench Press")
        newer.date = Date()

        let csv = WorkoutDataExporter.generateCSV(from: [older, newer])
        let newerIdx = csv.range(of: "Newer Workout")?.lowerBound
        let olderIdx = csv.range(of: "Older Workout")?.lowerBound

        if let n = newerIdx, let o = olderIdx {
            XCTAssertLessThan(n, o, "More recent workouts should appear first in CSV")
        }
    }

    // MARK: - CSV Special Characters

    func testCSVEscaping_commaInWorkoutName_quoteWrapped() {
        let workout = makeCompletedWorkout(name: "Push, Pull, Legs", exerciseName: "Squat")
        let csv = WorkoutDataExporter.generateCSV(from: [workout])
        XCTAssertTrue(csv.contains("\"Push, Pull, Legs\""), "Commas in name should be CSV-escaped with quotes")
    }

    func testCSVEscaping_quoteInName_doubleQuoted() {
        let workout = makeCompletedWorkout(name: "John's Workout", exerciseName: "Bench Press")
        // The apostrophe is fine, but a literal quote would need escaping
        let workout2 = makeCompletedWorkout(name: "The \"Big\" Workout", exerciseName: "Deadlift")
        let csv = WorkoutDataExporter.generateCSV(from: [workout, workout2])
        // Should not crash and should contain the exercise
        XCTAssertTrue(csv.contains("Deadlift"))
    }

    func testCSVEscaping_plainName_notQuoteWrapped() {
        let workout = makeCompletedWorkout(name: "Push Day", exerciseName: "Bench Press")
        let csv = WorkoutDataExporter.generateCSV(from: [workout])
        XCTAssertFalse(csv.contains("\"Push Day\""), "Simple names should not be quote-wrapped")
    }

    // MARK: - ExportStats

    func testExportStats_totalCounts() {
        let workout1 = makeCompletedWorkout(name: "W1", exerciseName: "Squat", setCount: 3)
        let workout2 = makeCompletedWorkout(name: "W2", exerciseName: "Bench Press", setCount: 2)

        let stats = WorkoutDataExporter.generateStats(from: [workout1, workout2])
        XCTAssertEqual(stats.totalWorkouts, 2)
        XCTAssertEqual(stats.totalExercises, 2)
        XCTAssertEqual(stats.totalSets, 5)
    }

    func testExportStats_excludesTemplates() {
        let template = makeCompletedWorkout(name: "Template", exerciseName: "Squat", isTemplate: true)
        let real = makeCompletedWorkout(name: "Real Workout", exerciseName: "Deadlift")

        let stats = WorkoutDataExporter.generateStats(from: [template, real])
        XCTAssertEqual(stats.totalWorkouts, 1, "Templates should not count in stats")
    }

    func testExportStats_emptyList_allCountsZero() {
        let stats = WorkoutDataExporter.generateStats(from: [])
        XCTAssertEqual(stats.totalWorkouts, 0)
        XCTAssertEqual(stats.totalExercises, 0)
        XCTAssertEqual(stats.totalSets, 0)
        XCTAssertNil(stats.firstWorkoutDate)
        XCTAssertNil(stats.lastWorkoutDate)
    }

    func testExportStats_dateRange_singleWorkout() {
        let workout = makeCompletedWorkout(name: "Only Workout", exerciseName: "Squat")
        workout.date = Date()

        let stats = WorkoutDataExporter.generateStats(from: [workout])
        XCTAssertNotNil(stats.firstWorkoutDate)
        XCTAssertNotNil(stats.lastWorkoutDate)
    }

    func testExportStats_dateRangeString_singleDay_oneDate() {
        let workout = makeCompletedWorkout(name: "W", exerciseName: "S")
        workout.date = Date()

        let stats = WorkoutDataExporter.generateStats(from: [workout])
        // When first == last date, should return a single date (no range separator)
        XCTAssertFalse(stats.dateRangeString.contains("–"), "Single day should not show a range separator")
    }

    func testExportStats_dateRangeString_multipleDays_showsRange() {
        let w1 = makeCompletedWorkout(name: "W1", exerciseName: "S")
        w1.date = Date().addingTimeInterval(-30 * 86400) // 30 days ago

        let w2 = makeCompletedWorkout(name: "W2", exerciseName: "S")
        w2.date = Date()

        let stats = WorkoutDataExporter.generateStats(from: [w1, w2])
        XCTAssertTrue(stats.dateRangeString.contains("–"), "Multi-day range should show separator")
    }

    func testExportStats_noWorkoutsDateRange_returnsNoWorkoutsYet() {
        let stats = WorkoutDataExporter.generateStats(from: [])
        XCTAssertEqual(stats.dateRangeString, "No workouts yet")
    }

    // MARK: - Helpers

    private func makeCompletedWorkout(
        name: String,
        exerciseName: String,
        setCount: Int = 1,
        weight: Double = 135,
        reps: Int = 10,
        isTemplate: Bool = false
    ) -> Workout {
        let workout = Workout(name: name, date: Date(), isTemplate: isTemplate)
        workout.startTime = Date()
        workout.endTime = Date().addingTimeInterval(3600)

        let exercise = Exercise(name: exerciseName, order: 0)
        for _ in 0..<setCount {
            exercise.addSet(reps: reps, weight: weight)
        }
        workout.exercises = [exercise]
        return workout
    }
}
