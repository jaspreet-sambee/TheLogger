//
//  UtilityTests.swift
//  TheLoggerTests
//
//  Unit tests for utility classes and formatters
//

import XCTest
@testable import TheLogger

final class UtilityTests: XCTestCase {

    // MARK: - UnitFormatter Tests

    func testWeightFormattingLBS() {
        UserDefaults.standard.set("Imperial", forKey: "unitSystem")

        let formatted = UnitFormatter.formatWeight(225.0, showUnit: true)
        XCTAssertTrue(formatted.contains("225"))
        XCTAssertTrue(formatted.contains("lbs"))
    }

    func testWeightFormattingKG() {
        UserDefaults.standard.set("Metric", forKey: "unitSystem")

        // 225 lbs = ~102 kg
        let formatted = UnitFormatter.formatWeight(225.0, showUnit: true)
        XCTAssertTrue(formatted.contains("102") || formatted.contains("103"))
        XCTAssertTrue(formatted.contains("kg"))

        // Reset to Imperial
        UserDefaults.standard.set("Imperial", forKey: "unitSystem")
    }

    func testWeightFormattingCompact() {
        UserDefaults.standard.set("Imperial", forKey: "unitSystem")

        let formatted = UnitFormatter.formatWeightCompact(225.0, showUnit: false)
        XCTAssertEqual(formatted, "225")
    }

    func testConvertToDisplay() {
        UserDefaults.standard.set("Imperial", forKey: "unitSystem")
        let lbs = UnitFormatter.convertToDisplay(225.0)
        XCTAssertEqual(lbs, 225.0)

        UserDefaults.standard.set("Metric", forKey: "unitSystem")
        let kg = UnitFormatter.convertToDisplay(225.0)
        XCTAssertEqual(kg, 102.1, accuracy: 0.5) // 225 lbs ≈ 102 kg

        // Reset
        UserDefaults.standard.set("Imperial", forKey: "unitSystem")
    }

    // MARK: - ExerciseMemory Tests

    func testExerciseMemoryNormalization() {
        let memory = ExerciseMemory(
            name: "  Bench Press  ",
            lastReps: 10,
            lastWeight: 185,
            lastSets: 3
        )

        XCTAssertEqual(memory.normalizedName, "bench press")
    }

    func testExerciseMemoryCreation() {
        let memory = ExerciseMemory(
            name: "Squat",
            lastReps: 5,
            lastWeight: 225,
            lastSets: 3
        )

        XCTAssertEqual(memory.name, "Squat")
        XCTAssertEqual(memory.lastReps, 5)
        XCTAssertEqual(memory.lastWeight, 225)
        XCTAssertEqual(memory.lastSets, 3)
    }

    // MARK: - ExerciseLibrary Tests

    func testExerciseLibrarySearch() {
        let library = ExerciseLibrary.shared

        let results = library.search("bench")
        XCTAssertGreaterThan(results.count, 0)
        XCTAssertTrue(results.contains { $0.name.lowercased().contains("bench") })
    }

    func testExerciseLibraryFind() {
        let library = ExerciseLibrary.shared

        let benchPress = library.find(name: "Bench Press")
        XCTAssertNotNil(benchPress)
        XCTAssertEqual(benchPress?.name, "Bench Press")

        let nonExistent = library.find(name: "Nonexistent Exercise 12345")
        XCTAssertNil(nonExistent)
    }

    func testTimeBasedExercises() {
        let library = ExerciseLibrary.shared

        let plank = library.find(name: "Plank")
        XCTAssertNotNil(plank)
        XCTAssertTrue(plank?.isTimeBased ?? false)

        let benchPress = library.find(name: "Bench Press")
        XCTAssertNotNil(benchPress)
        XCTAssertFalse(benchPress?.isTimeBased ?? true)
    }

    // MARK: - WorkoutSummary Tests

    func testWorkoutSummaryCalculations() {
        let workout = Workout(name: "Test", date: Date(), isTemplate: false)
        let exercise1 = Exercise(name: "Bench Press", order: 0)
        exercise1.addSet(reps: 10, weight: 135)
        exercise1.addSet(reps: 8, weight: 155)

        workout.exercises = [exercise1]
        workout.startTime = Date()
        workout.endTime = Date().addingTimeInterval(1800)

        let summary = WorkoutSummary(workout: workout)

        XCTAssertEqual(summary.totalExercises, 1)
        XCTAssertEqual(summary.totalSets, 2)
        XCTAssertNotNil(summary.duration)
    }

    // MARK: - Edge Cases

    func testZeroWeightFormatting() {
        let formatted = UnitFormatter.formatWeight(0, showUnit: true)
        XCTAssertTrue(formatted.contains("0"))
    }

    func testVeryLargeWeightFormatting() {
        let formatted = UnitFormatter.formatWeight(9999, showUnit: true)
        XCTAssertTrue(formatted.contains("9999") || formatted.contains("9,999"))
    }
}
