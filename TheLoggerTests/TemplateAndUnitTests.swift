//
//  TemplateAndUnitTests.swift
//  TheLoggerTests
//
//  Tests for:
//  - Template creation, querying, and workout-from-template logic
//  - Unit system switching (lbs ↔ kg) and its effect on display, storage, and CSV
//

import XCTest
import SwiftData
@testable import TheLogger

@MainActor
final class TemplateTests: XCTestCase {

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

    // MARK: - Template Creation

    func testTemplate_isTemplate_flagIsTrue() {
        let template = Workout(name: "Push Day Template", date: Date(), isTemplate: true)
        XCTAssertTrue(template.isTemplate)
        XCTAssertFalse(template.isActive)
        XCTAssertFalse(template.isCompleted)
    }

    func testTemplate_neverHasStartOrEndTime() {
        let template = Workout(name: "My Template", date: Date(), isTemplate: true)
        XCTAssertNil(template.startTime)
        XCTAssertNil(template.endTime)
    }

    func testTemplate_canHaveExercises() {
        let template = Workout(name: "Push Day", date: Date(), isTemplate: true)
        template.addExercise(name: "Bench Press")
        template.addExercise(name: "Overhead Press")
        template.addExercise(name: "Tricep Dips")

        XCTAssertEqual(template.exerciseCount, 3)
    }

    func testTemplate_exerciseOrderPreserved() {
        let template = Workout(name: "Pull Day", date: Date(), isTemplate: true)
        template.addExercise(name: "Deadlift")
        template.addExercise(name: "Pull-Up")
        template.addExercise(name: "Barbell Row")

        let ordered = template.exercisesByOrder
        XCTAssertEqual(ordered[0].name, "Deadlift")
        XCTAssertEqual(ordered[1].name, "Pull-Up")
        XCTAssertEqual(ordered[2].name, "Barbell Row")
    }

    func testTemplate_storedInDatabase_fetchableByFlag() {
        let template = Workout(name: "Leg Day", date: Date(), isTemplate: true)
        template.addExercise(name: "Squat")
        modelContext.insert(template)

        let nonTemplate = Workout(name: "Monday Workout", date: Date(), isTemplate: false)
        modelContext.insert(nonTemplate)
        try? modelContext.save()

        let descriptor = FetchDescriptor<Workout>(
            predicate: #Predicate<Workout> { $0.isTemplate == true }
        )
        let templates = (try? modelContext.fetch(descriptor)) ?? []
        XCTAssertEqual(templates.count, 1)
        XCTAssertEqual(templates.first?.name, "Leg Day")
    }

    func testTemplate_notReturnedInHistoryQuery() {
        let template = Workout(name: "My Template", date: Date(), isTemplate: true)
        modelContext.insert(template)

        let history = Workout(name: "Real Workout", date: Date(), isTemplate: false)
        history.startTime = Date()
        history.endTime = Date()
        modelContext.insert(history)
        try? modelContext.save()

        let descriptor = FetchDescriptor<Workout>(
            predicate: #Predicate<Workout> { $0.isTemplate == false }
        )
        let workouts = (try? modelContext.fetch(descriptor)) ?? []
        XCTAssertEqual(workouts.count, 1)
        XCTAssertFalse(workouts.contains { $0.isTemplate }, "Templates must not appear in workout history")
    }

    // MARK: - Workout From Template

    func testWorkoutFromTemplate_copiesExerciseNames() {
        let template = Workout(name: "Push Day", date: Date(), isTemplate: true)
        template.addExercise(name: "Bench Press")
        template.addExercise(name: "Overhead Press")
        template.addExercise(name: "Tricep Pushdown")

        // Simulate creating workout from template (copy exercise names)
        let newWorkout = Workout(name: "Push Day", date: Date(), isTemplate: false)
        for exercise in template.exercisesByOrder {
            newWorkout.addExercise(name: exercise.name)
        }

        XCTAssertEqual(newWorkout.exerciseCount, 3)
        XCTAssertEqual(newWorkout.exercisesByOrder[0].name, "Bench Press")
        XCTAssertEqual(newWorkout.exercisesByOrder[1].name, "Overhead Press")
        XCTAssertEqual(newWorkout.exercisesByOrder[2].name, "Tricep Pushdown")
    }

    func testWorkoutFromTemplate_isNotATemplate() {
        let template = Workout(name: "My Template", date: Date(), isTemplate: true)
        let newWorkout = Workout(name: template.name, date: Date(), isTemplate: false)

        XCTAssertFalse(newWorkout.isTemplate)
        XCTAssertFalse(newWorkout.isCompleted)
    }

    func testWorkoutFromTemplate_doesNotShareExerciseInstances() {
        // Exercises should be new instances, not references to template exercises
        let template = Workout(name: "Template", date: Date(), isTemplate: true)
        template.addExercise(name: "Bench Press")

        let newWorkout = Workout(name: "Workout", date: Date(), isTemplate: false)
        newWorkout.addExercise(name: "Bench Press")

        // Different exercise IDs
        XCTAssertNotEqual(
            template.exercisesByOrder.first?.id,
            newWorkout.exercisesByOrder.first?.id,
            "Template and workout should have independent exercise instances"
        )
    }

    // MARK: - Template Summary

    func testTemplate_summary_returnsCorrectExerciseCount() {
        let template = Workout(name: "Upper Body", date: Date(), isTemplate: true)
        template.addExercise(name: "Bench Press")
        template.addExercise(name: "Rows")

        let summary = WorkoutSummary(workout: template)
        XCTAssertEqual(summary.totalExercises, 2)
    }

    func testTemplate_csvExport_excluded() {
        let template = Workout(name: "My Template", date: Date(), isTemplate: true)
        template.startTime = Date()
        template.endTime = Date() // Even if it has times (edge case)
        let exercise = Exercise(name: "Squat", order: 0)
        exercise.addSet(reps: 5, weight: 225)
        template.exercises = [exercise]

        let csv = WorkoutDataExporter.generateCSV(from: [template])
        XCTAssertFalse(csv.contains("My Template"), "Templates should never appear in CSV export")
    }

    // MARK: - Template Editing

    func testTemplate_addRemoveExercise() {
        let template = Workout(name: "My Template", date: Date(), isTemplate: true)
        template.addExercise(name: "Bench Press")
        template.addExercise(name: "Squat")
        XCTAssertEqual(template.exerciseCount, 2)

        let squat = template.exercisesByOrder.last!
        template.removeExercise(id: squat.id)
        XCTAssertEqual(template.exerciseCount, 1)
        XCTAssertEqual(template.exercisesByOrder.first?.name, "Bench Press")
    }
}

// MARK: - Unit System Switching Tests

final class UnitSwitchingTests: XCTestCase {

    override func setUp() {
        UserDefaults.standard.set("Imperial", forKey: "unitSystem")
    }

    override func tearDown() {
        UserDefaults.standard.set("Imperial", forKey: "unitSystem")
    }

    // MARK: - Storage Always in Lbs

    func testWeightStorage_alwaysInLbs_notAffectedByDisplayUnit() {
        // Storage is always in lbs regardless of display unit
        let set = WorkoutSet(reps: 10, weight: 100.0) // 100 lbs stored
        XCTAssertEqual(set.weight, 100.0, "Weight stored in lbs regardless of unit system")

        // Switch to metric — stored value doesn't change
        UserDefaults.standard.set("Metric", forKey: "unitSystem")
        XCTAssertEqual(set.weight, 100.0, "Stored value must never change when unit system changes")
    }

    // MARK: - Display Conversion

    func testDisplay_imperial_noConversion() {
        UserDefaults.standard.set("Imperial", forKey: "unitSystem")
        let displayed = UnitFormatter.convertToDisplay(225.0)
        XCTAssertEqual(displayed, 225.0, "In imperial, display == storage")
    }

    func testDisplay_metric_convertsToKg() {
        UserDefaults.standard.set("Metric", forKey: "unitSystem")
        let displayed = UnitFormatter.convertToDisplay(100.0)
        XCTAssertEqual(displayed, 45.3592, accuracy: 0.01, "100 lbs should display as ~45.36 kg")
    }

    func testSwitchToMetric_displayChanges_storageUnchanged() {
        let storedWeightLbs = 225.0

        UserDefaults.standard.set("Imperial", forKey: "unitSystem")
        let displayImperial = UnitFormatter.convertToDisplay(storedWeightLbs)
        XCTAssertEqual(displayImperial, 225.0)

        UserDefaults.standard.set("Metric", forKey: "unitSystem")
        let displayMetric = UnitFormatter.convertToDisplay(storedWeightLbs)
        XCTAssertEqual(displayMetric, 102.1, accuracy: 0.5)

        // Storage value is unchanged
        XCTAssertEqual(storedWeightLbs, 225.0)
    }

    // MARK: - Storage Conversion (User Input → lbs)

    func testConvertToStorage_metric_convertsKgToLbs() {
        UserDefaults.standard.set("Metric", forKey: "unitSystem")
        let stored = UnitFormatter.convertToStorage(100.0) // user enters 100 kg
        XCTAssertEqual(stored, 220.46, accuracy: 0.5, "100 kg should store as ~220.5 lbs")
    }

    func testConvertToStorage_imperial_noConversion() {
        UserDefaults.standard.set("Imperial", forKey: "unitSystem")
        let stored = UnitFormatter.convertToStorage(185.0)
        XCTAssertEqual(stored, 185.0)
    }

    func testConvertRoundTrip_metric_isAccurate() {
        UserDefaults.standard.set("Metric", forKey: "unitSystem")
        let originalLbs = 315.0
        let asKg = UnitFormatter.convertToDisplay(originalLbs)
        let backToLbs = UnitFormatter.convertToStorage(asKg)
        XCTAssertEqual(backToLbs, originalLbs, accuracy: 0.01)
    }

    // MARK: - PR Comparison is Unit-Agnostic

    func testPRComparison_unitAgnostic_alwaysComparesinLbs() {
        // PRs store weight in lbs; the unit system doesn't affect comparison
        let pr1 = PersonalRecord(exerciseName: "Bench Press", weight: 225, reps: 5, workoutId: UUID())
        let pr2 = PersonalRecord(exerciseName: "Bench Press", weight: 245, reps: 5, workoutId: UUID())

        // Switch to metric — PR scores should be identical (lbs storage)
        UserDefaults.standard.set("Metric", forKey: "unitSystem")
        XCTAssertGreaterThan(pr2.prScore, pr1.prScore, "PR comparison works the same in metric")
        UserDefaults.standard.set("Imperial", forKey: "unitSystem")
        XCTAssertGreaterThan(pr2.prScore, pr1.prScore, "PR comparison works the same in imperial")
    }

    // MARK: - Formatted Weight Strings

    func testFormattedWeight_switchMidSession_imperialFormat() {
        UserDefaults.standard.set("Imperial", forKey: "unitSystem")
        let formatted = UnitFormatter.formatWeight(135, showUnit: true)
        XCTAssertTrue(formatted.contains("135.0"))
        XCTAssertTrue(formatted.contains("lbs"))
    }

    func testFormattedWeight_switchMidSession_metricFormat() {
        UserDefaults.standard.set("Metric", forKey: "unitSystem")
        let formatted = UnitFormatter.formatWeight(135, showUnit: true)
        // 135 lbs ≈ 61.2 kg
        XCTAssertTrue(formatted.contains("61"))
        XCTAssertTrue(formatted.contains("kg"))
    }

    func testFormatWeightCompact_metric_roundsToWholeNumber() {
        UserDefaults.standard.set("Metric", forKey: "unitSystem")
        let compact = UnitFormatter.formatWeightCompact(100, showUnit: false)
        // 100 lbs ≈ 45 kg
        XCTAssertTrue(compact == "45" || compact == "45", "Should round to whole kg")
    }

    // MARK: - CSV Export Respects Unit System

    func testCSVExport_imperial_weightsInLbs() {
        UserDefaults.standard.set("Imperial", forKey: "unitSystem")
        let workout = makeCompletedWorkout(weight: 225)
        let csv = WorkoutDataExporter.generateCSV(from: [workout])
        XCTAssertTrue(csv.contains("Weight (lbs)"), "CSV header should say lbs in imperial mode")
        XCTAssertTrue(csv.contains("225.0") || csv.contains("225"), "Weight exported as lbs value")
    }

    func testCSVExport_metric_weightsInKg() {
        UserDefaults.standard.set("Metric", forKey: "unitSystem")
        let workout = makeCompletedWorkout(weight: 100) // 100 lbs stored
        let csv = WorkoutDataExporter.generateCSV(from: [workout])
        XCTAssertTrue(csv.contains("Weight (kg)"), "CSV header should say kg in metric mode")
        // 100 lbs ≈ 45.36 kg — should NOT contain "100.0" as exported weight
        XCTAssertFalse(csv.contains(",100.0,"), "Should not export raw lbs value in metric mode")
    }

    func testCSVExport_unitSwitchMidHistory_respectsCurrentSetting() {
        // Create workout logged in imperial
        let workout = makeCompletedWorkout(weight: 225)

        // Switch to metric before exporting
        UserDefaults.standard.set("Metric", forKey: "unitSystem")
        let csv = WorkoutDataExporter.generateCSV(from: [workout])

        XCTAssertTrue(csv.contains("Weight (kg)"))
        // 225 lbs ≈ 102 kg
        XCTAssertTrue(csv.contains("102.") || csv.contains("102,"))
    }

    // MARK: - Weight Unit String

    func testWeightUnit_imperial() {
        UserDefaults.standard.set("Imperial", forKey: "unitSystem")
        XCTAssertEqual(UnitFormatter.weightUnit, "lbs")
        XCTAssertEqual(UnitSystem.imperial.weightUnit, "lbs")
    }

    func testWeightUnit_metric() {
        UserDefaults.standard.set("Metric", forKey: "unitSystem")
        XCTAssertEqual(UnitFormatter.weightUnit, "kg")
        XCTAssertEqual(UnitSystem.metric.weightUnit, "kg")
    }

    func testUnitSystemRawValues() {
        XCTAssertEqual(UnitSystem.imperial.rawValue, "Imperial")
        XCTAssertEqual(UnitSystem.metric.rawValue, "Metric")
    }

    // MARK: - Edge Cases

    func testZeroWeight_displaysSameInBothSystems() {
        UserDefaults.standard.set("Imperial", forKey: "unitSystem")
        let imperial = UnitFormatter.formatWeightCompact(0, showUnit: false)

        UserDefaults.standard.set("Metric", forKey: "unitSystem")
        let metric = UnitFormatter.formatWeightCompact(0, showUnit: false)

        XCTAssertEqual(imperial, "0")
        XCTAssertEqual(metric, "0", "Zero weight displays as 0 in any unit system")
    }

    func testVerySmallWeight_1lb_displayedCorrectly() {
        UserDefaults.standard.set("Metric", forKey: "unitSystem")
        let formatted = UnitFormatter.formatWeightCompact(1, showUnit: true)
        // 1 lbs = 0.45 kg → rounds to 0 kg
        XCTAssertTrue(formatted.contains("kg"))
    }

    func testUnknownUnitString_fallsBackToImperial() {
        UserDefaults.standard.set("Unknown", forKey: "unitSystem")
        let system = UnitFormatter.currentSystem
        XCTAssertEqual(system, .imperial, "Unknown unit string should fall back to imperial")
    }

    // MARK: - Helper

    private func makeCompletedWorkout(weight: Double) -> Workout {
        let workout = Workout(name: "Test Workout", date: Date(), isTemplate: false)
        workout.startTime = Date()
        workout.endTime = Date().addingTimeInterval(3600)
        let exercise = Exercise(name: "Bench Press", order: 0)
        exercise.addSet(reps: 10, weight: weight)
        workout.exercises = [exercise]
        return workout
    }
}
