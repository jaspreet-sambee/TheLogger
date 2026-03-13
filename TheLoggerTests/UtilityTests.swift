//
//  UtilityTests.swift
//  TheLoggerTests
//
//  Unit tests for UnitFormatter, ExerciseLibrary, ExerciseMemory,
//  WorkoutSummary, and data export utilities.
//

import XCTest
@testable import TheLogger

final class UtilityTests: XCTestCase {

    override func setUp() {
        // Ensure clean state for unit system
        UserDefaults.standard.set("Imperial", forKey: "unitSystem")
    }

    override func tearDown() {
        UserDefaults.standard.set("Imperial", forKey: "unitSystem")
    }

    // MARK: - UnitFormatter: Weight Formatting (Imperial)

    func testFormatWeight_imperial_includesLbsUnit() {
        UserDefaults.standard.set("Imperial", forKey: "unitSystem")
        let formatted = UnitFormatter.formatWeight(225.0, showUnit: true)
        XCTAssertTrue(formatted.contains("225"))
        XCTAssertTrue(formatted.contains("lbs"))
    }

    func testFormatWeight_imperial_oneDecimalPlace() {
        UserDefaults.standard.set("Imperial", forKey: "unitSystem")
        let formatted = UnitFormatter.formatWeight(135.0, showUnit: false)
        XCTAssertEqual(formatted, "135.0")
    }

    func testFormatWeightCompact_imperial_noDecimal() {
        UserDefaults.standard.set("Imperial", forKey: "unitSystem")
        let formatted = UnitFormatter.formatWeightCompact(225.0, showUnit: false)
        XCTAssertEqual(formatted, "225")
    }

    func testFormatWeightCompact_imperial_withUnit() {
        UserDefaults.standard.set("Imperial", forKey: "unitSystem")
        let formatted = UnitFormatter.formatWeightCompact(225.0, showUnit: true)
        XCTAssertTrue(formatted.contains("225"))
        XCTAssertTrue(formatted.contains("lbs"))
    }

    // MARK: - UnitFormatter: Weight Formatting (Metric)

    func testFormatWeight_metric_includesKgUnit() {
        UserDefaults.standard.set("Metric", forKey: "unitSystem")
        let formatted = UnitFormatter.formatWeight(225.0, showUnit: true)
        // 225 lbs ≈ 102.1 kg
        XCTAssertTrue(formatted.contains("102") || formatted.contains("103"))
        XCTAssertTrue(formatted.contains("kg"))
    }

    func testFormatWeightCompact_metric_noDecimalRounded() {
        UserDefaults.standard.set("Metric", forKey: "unitSystem")
        let formatted = UnitFormatter.formatWeightCompact(220.0, showUnit: false)
        // 220 lbs = 99.79 kg → rounds to "100"
        XCTAssertTrue(formatted.contains("99") || formatted.contains("100"))
    }

    // MARK: - UnitFormatter: Conversion

    func testConvertToDisplay_imperial_unchanged() {
        UserDefaults.standard.set("Imperial", forKey: "unitSystem")
        XCTAssertEqual(UnitFormatter.convertToDisplay(225.0), 225.0)
    }

    func testConvertToDisplay_metric_convertsToKg() {
        UserDefaults.standard.set("Metric", forKey: "unitSystem")
        let kg = UnitFormatter.convertToDisplay(225.0)
        XCTAssertEqual(kg, 102.1, accuracy: 0.5) // 225 × 0.453592 ≈ 102.1
    }

    func testConvertToStorage_imperial_unchanged() {
        UserDefaults.standard.set("Imperial", forKey: "unitSystem")
        XCTAssertEqual(UnitFormatter.convertToStorage(225.0), 225.0)
    }

    func testConvertToStorage_metric_convertsToLbs() {
        UserDefaults.standard.set("Metric", forKey: "unitSystem")
        let lbs = UnitFormatter.convertToStorage(100.0)
        // 100 kg / 0.453592 ≈ 220.5 lbs
        XCTAssertEqual(lbs, 220.5, accuracy: 1.0)
    }

    func testConvertRoundTrip_displayThenStorageEqualsOriginal() {
        UserDefaults.standard.set("Metric", forKey: "unitSystem")
        let original = 315.0 // lbs
        let inKg = UnitFormatter.convertToDisplay(original)
        let backToLbs = UnitFormatter.convertToStorage(inKg)
        XCTAssertEqual(backToLbs, original, accuracy: 0.01)
    }

    // MARK: - UnitFormatter: Edge Cases

    func testFormatWeight_zero_returnsZero() {
        UserDefaults.standard.set("Imperial", forKey: "unitSystem")
        let formatted = UnitFormatter.formatWeight(0, showUnit: true)
        XCTAssertTrue(formatted.contains("0"))
    }

    func testFormatWeight_veryLargeValue_displaysCorrectly() {
        UserDefaults.standard.set("Imperial", forKey: "unitSystem")
        let formatted = UnitFormatter.formatWeight(9999, showUnit: true)
        XCTAssertTrue(formatted.contains("9999") || formatted.contains("9,999"))
    }

    func testFormatWeight_fractional_roundsAppropriately() {
        UserDefaults.standard.set("Imperial", forKey: "unitSystem")
        let formatted = UnitFormatter.formatWeight(135.55, showUnit: false)
        XCTAssertTrue(formatted.contains("135.5") || formatted.contains("135.6"))
    }

    // MARK: - UnitFormatter: Duration

    func testFormatDuration_seconds_formatsAsMinutesColonSeconds() {
        let formatted = UnitFormatter.formatDuration(45)
        XCTAssertEqual(formatted, "0:45")
    }

    func testFormatDuration_minutesAndSeconds() {
        let formatted = UnitFormatter.formatDuration(90)
        XCTAssertEqual(formatted, "1:30")
    }

    func testFormatDuration_exactMinutes_zerosSeconds() {
        let formatted = UnitFormatter.formatDuration(120)
        XCTAssertEqual(formatted, "2:00")
    }

    func testFormatDuration_tenMinutes() {
        let formatted = UnitFormatter.formatDuration(600)
        XCTAssertEqual(formatted, "10:00")
    }

    func testFormatDuration_zero() {
        let formatted = UnitFormatter.formatDuration(0)
        XCTAssertEqual(formatted, "0:00")
    }

    func testFormatDuration_oneSecond() {
        let formatted = UnitFormatter.formatDuration(1)
        XCTAssertEqual(formatted, "0:01")
    }

    // MARK: - UnitFormatter: Weight Unit String

    func testWeightUnit_imperial_isLbs() {
        UserDefaults.standard.set("Imperial", forKey: "unitSystem")
        XCTAssertEqual(UnitFormatter.weightUnit, "lbs")
    }

    func testWeightUnit_metric_isKg() {
        UserDefaults.standard.set("Metric", forKey: "unitSystem")
        XCTAssertEqual(UnitFormatter.weightUnit, "kg")
    }

    // MARK: - ExerciseLibrary: Search

    func testExerciseLibrarySearch_byPartialName_returnsMatches() {
        let results = ExerciseLibrary.shared.search("bench")
        XCTAssertGreaterThan(results.count, 0)
        XCTAssertTrue(results.allSatisfy { $0.name.lowercased().contains("bench") })
    }

    func testExerciseLibrarySearch_emptyQuery_returnsAllExercises() {
        let results = ExerciseLibrary.shared.search("")
        XCTAssertGreaterThan(results.count, 50, "Library should contain 50+ exercises")
    }

    func testExerciseLibrarySearch_caseInsensitive() {
        let lower = ExerciseLibrary.shared.search("BENCH")
        let upper = ExerciseLibrary.shared.search("bench")
        XCTAssertEqual(lower.count, upper.count)
    }

    func testExerciseLibrarySearch_noMatch_returnsEmpty() {
        let results = ExerciseLibrary.shared.search("xyznonexistentexercise")
        XCTAssertEqual(results.count, 0)
    }

    // MARK: - ExerciseLibrary: Find

    func testExerciseLibraryFind_exactMatch_returnsExercise() {
        let exercise = ExerciseLibrary.shared.find(name: "Bench Press")
        XCTAssertNotNil(exercise)
        XCTAssertEqual(exercise?.name, "Bench Press")
    }

    func testExerciseLibraryFind_nonExistent_returnsNil() {
        let exercise = ExerciseLibrary.shared.find(name: "Nonexistent Exercise XYZ123")
        XCTAssertNil(exercise)
    }

    func testExerciseLibraryFind_caseInsensitive() {
        let exercise = ExerciseLibrary.shared.find(name: "bench press")
        XCTAssertNotNil(exercise, "Find should be case-insensitive")
    }

    // MARK: - ExerciseLibrary: Time-Based Exercises

    func testExerciseLibrary_plank_isTimeBased() {
        let plank = ExerciseLibrary.shared.find(name: "Plank")
        XCTAssertNotNil(plank)
        XCTAssertTrue(plank?.isTimeBased ?? false)
    }

    func testExerciseLibrary_benchPress_isNotTimeBased() {
        let bench = ExerciseLibrary.shared.find(name: "Bench Press")
        XCTAssertNotNil(bench)
        XCTAssertFalse(bench?.isTimeBased ?? true)
    }

    // MARK: - ExerciseLibrary: Rest Duration

    func testRestDuration_compoundExercise_returns120Seconds() {
        let duration = ExerciseLibrary.shared.restDuration(for: "Bench Press")
        XCTAssertEqual(duration, 120, "Compound exercises should suggest 120s rest")
    }

    func testRestDuration_isolationExercise_returns60Seconds() {
        let duration = ExerciseLibrary.shared.restDuration(for: "Cable Fly")
        XCTAssertEqual(duration, 60, "Isolation exercises should suggest 60s rest")
    }

    func testRestDuration_unknownExercise_usesKeywordHeuristic() {
        // Contains "squat" keyword → compound → 120s
        let duration = ExerciseLibrary.shared.restDuration(for: "Hack Squat Machine")
        XCTAssertEqual(duration, 120)
    }

    func testRestDuration_unknownExerciseNoKeyword_returns60() {
        let duration = ExerciseLibrary.shared.restDuration(for: "Random Custom Exercise")
        XCTAssertEqual(duration, 60, "Unknown exercises without compound keywords default to 60s")
    }

    // MARK: - ExerciseLibrary: Grouped By Muscle

    func testExerciseLibraryGroupedByMuscle_hasAllMuscleGroups() {
        let grouped = ExerciseLibrary.shared.groupedByMuscle
        XCTAssertTrue(grouped.keys.contains(.chest))
        XCTAssertTrue(grouped.keys.contains(.back))
        XCTAssertTrue(grouped.keys.contains(.shoulders))
        XCTAssertTrue(grouped.keys.contains(.arms))
        XCTAssertTrue(grouped.keys.contains(.legs))
        XCTAssertTrue(grouped.keys.contains(.core))
    }

    func testExerciseLibraryGroupedByMuscle_allExercisesAccountedFor() {
        let grouped = ExerciseLibrary.shared.groupedByMuscle
        let totalInGroups = grouped.values.reduce(0) { $0 + $1.count }
        XCTAssertEqual(totalInGroups, ExerciseLibrary.shared.exercises.count)
    }

    // MARK: - ExerciseMemory

    func testExerciseMemoryCreation_defaultValues() {
        let memory = ExerciseMemory(name: "Squat", lastReps: 5, lastWeight: 225, lastSets: 3)
        XCTAssertEqual(memory.name, "Squat")
        XCTAssertEqual(memory.lastReps, 5)
        XCTAssertEqual(memory.lastWeight, 225)
        XCTAssertEqual(memory.lastSets, 3)
        XCTAssertNil(memory.lastDuration)
        XCTAssertNil(memory.note)
        XCTAssertNil(memory.restTimerEnabled)
    }

    func testExerciseMemoryNormalization_lowercaseAndTrimmed() {
        let memory = ExerciseMemory(name: "  Bench Press  ", lastReps: 10, lastWeight: 185, lastSets: 3)
        XCTAssertEqual(memory.normalizedName, "bench press")
    }

    func testExerciseMemoryUpdate_allFieldsUpdated() {
        let memory = ExerciseMemory(name: "OHP", lastReps: 5, lastWeight: 95, lastSets: 3)
        memory.update(reps: 8, weight: 105, sets: 4, durationSeconds: nil, note: "Felt strong")

        XCTAssertEqual(memory.lastReps, 8)
        XCTAssertEqual(memory.lastWeight, 105)
        XCTAssertEqual(memory.lastSets, 4)
        XCTAssertEqual(memory.note, "Felt strong")
    }

    func testExerciseMemoryUpdateNote_emptyStringBecomesNil() {
        let memory = ExerciseMemory(name: "Curl", lastReps: 10, lastWeight: 35, lastSets: 3, note: "Old note")
        memory.updateNote("")
        XCTAssertNil(memory.note, "Empty note string should be stored as nil")
    }

    func testExerciseMemoryUpdateNote_nonEmptyStringPersists() {
        let memory = ExerciseMemory(name: "Curl", lastReps: 10, lastWeight: 35, lastSets: 3)
        memory.updateNote("Wide grip")
        XCTAssertEqual(memory.note, "Wide grip")
    }

    func testExerciseMemoryUpdateRestTimerEnabled_storesValue() {
        let memory = ExerciseMemory(name: "Bench Press", lastReps: 5, lastWeight: 185, lastSets: 3)
        XCTAssertNil(memory.restTimerEnabled, "Starts as nil (use global default)")

        memory.updateRestTimerEnabled(false)
        XCTAssertEqual(memory.restTimerEnabled, false)

        memory.updateRestTimerEnabled(nil)
        XCTAssertNil(memory.restTimerEnabled)
    }

    func testExerciseMemoryTimeBased_storesDuration() {
        let memory = ExerciseMemory(name: "Plank", lastReps: 0, lastWeight: 0, lastSets: 3, lastDuration: 60)
        XCTAssertEqual(memory.lastDuration, 60)
    }

    // MARK: - WorkoutSummary

    func testWorkoutSummary_noStartTime_durationIsNil() {
        let workout = Workout(name: "Test", date: Date(), isTemplate: false)
        let summary = WorkoutSummary(workout: workout)
        XCTAssertNil(summary.duration)
        XCTAssertEqual(summary.formattedDuration, "--")
    }

    func testWorkoutSummary_quickSummary_formatsCorrectly() {
        let workout = Workout(name: "Test", date: Date(), isTemplate: false)
        let exercise = Exercise(name: "Bench Press", order: 0)
        exercise.addSet(reps: 10, weight: 135)
        exercise.addSet(reps: 8, weight: 155)
        workout.exercises = [exercise]
        workout.startTime = Date()
        workout.endTime = Date().addingTimeInterval(1800)

        let summary = WorkoutSummary(workout: workout)
        let quick = summary.quickSummary
        XCTAssertTrue(quick.contains("1 exercises"))
        XCTAssertTrue(quick.contains("2 sets"))
    }

    func testWorkoutSummary_formattedVolume_imperialUnits() {
        UserDefaults.standard.set("Imperial", forKey: "unitSystem")
        let workout = Workout(name: "Test", date: Date(), isTemplate: false)
        let exercise = Exercise(name: "Bench Press", order: 0)
        // 10 × 100 = 1000 lbs total volume
        exercise.addSet(reps: 10, weight: 100)
        workout.exercises = [exercise]

        let summary = WorkoutSummary(workout: workout)
        let volume = summary.formattedVolume
        XCTAssertTrue(volume.contains("1000") || volume.contains("1.0k"), "Volume should reflect 1000 lbs")
        XCTAssertTrue(volume.contains("lbs"))
    }

    func testWorkoutSummary_durationMinutes_calculatesCorrectly() {
        let start = Date()
        let workout = Workout(name: "Test", date: start, isTemplate: false)
        workout.startTime = start
        workout.endTime = start.addingTimeInterval(3000) // 50 minutes

        let summary = WorkoutSummary(workout: workout)
        XCTAssertEqual(summary.durationMinutes, 50)
    }

    // MARK: - Onboarding: Locale-Based Unit Detection

    func testRecommendedUnitSystem_metricLocale_returnsMetric() {
        // Use a known metric locale (Germany)
        let metricLocale = Locale(identifier: "de_DE")
        XCTAssertEqual(recommendedUnitSystem(for: metricLocale), "Metric")
    }

    func testRecommendedUnitSystem_imperialLocale_returnsImperial() {
        // Use a known imperial locale (US)
        let usLocale = Locale(identifier: "en_US")
        XCTAssertEqual(recommendedUnitSystem(for: usLocale), "Imperial")
    }

    func testRecommendedUnitSystem_ukLocale_returnsMetric() {
        // UK uses metric measurement system
        let ukLocale = Locale(identifier: "en_GB")
        XCTAssertEqual(recommendedUnitSystem(for: ukLocale), "Metric")
    }

    func testRecommendedUnitSystem_japanLocale_returnsMetric() {
        let jpLocale = Locale(identifier: "ja_JP")
        XCTAssertEqual(recommendedUnitSystem(for: jpLocale), "Metric")
    }

    // MARK: - Onboarding: startWorkoutOnLaunch Flag

    func testStartWorkoutOnLaunch_defaultsToFalse() {
        // Clean up any existing value
        UserDefaults.standard.removeObject(forKey: "startWorkoutOnLaunch")
        let value = UserDefaults.standard.bool(forKey: "startWorkoutOnLaunch")
        XCTAssertFalse(value, "startWorkoutOnLaunch should default to false")
    }

    func testStartWorkoutOnLaunch_canBeSetAndRead() {
        UserDefaults.standard.set(true, forKey: "startWorkoutOnLaunch")
        XCTAssertTrue(UserDefaults.standard.bool(forKey: "startWorkoutOnLaunch"))

        // Clean up
        UserDefaults.standard.set(false, forKey: "startWorkoutOnLaunch")
    }
}
