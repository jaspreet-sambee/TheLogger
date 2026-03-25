//
//  AnalyticsTests.swift
//  TheLoggerTests
//
//  Tests for Analytics signal name constants and send function.
//

import XCTest
@testable import TheLogger

final class AnalyticsTests: XCTestCase {

    // MARK: - Signal Name Constants

    func testWorkoutSignalNames() {
        XCTAssertEqual(Analytics.Signal.workoutStarted, "Workout.Started")
        XCTAssertEqual(Analytics.Signal.workoutCompleted, "Workout.Completed")
        XCTAssertEqual(Analytics.Signal.workoutDiscarded, "Workout.Discarded")
    }

    func testExerciseSignalNames() {
        XCTAssertEqual(Analytics.Signal.exerciseAdded, "Exercise.Added")
        XCTAssertEqual(Analytics.Signal.supersetCreated, "Superset.Created")
    }

    func testTemplateSignalNames() {
        XCTAssertEqual(Analytics.Signal.templateCreated, "Template.Created")
    }

    func testPRSignalNames() {
        XCTAssertEqual(Analytics.Signal.prAchieved, "PR.Achieved")
    }

    func testBackupSignalNames() {
        XCTAssertEqual(Analytics.Signal.backupExportedJSON, "Backup.Exported.JSON")
        XCTAssertEqual(Analytics.Signal.backupImported, "Backup.Imported")
    }

    func testSettingsSignalNames() {
        XCTAssertEqual(Analytics.Signal.settingsUnitChanged, "Settings.UnitChanged")
        XCTAssertEqual(Analytics.Signal.settingsRestTimerToggled, "Settings.RestTimer.Toggled")
    }

    func testRestTimerSignalNames() {
        XCTAssertEqual(Analytics.Signal.restTimerCompleted, "RestTimer.Completed")
    }

    func testCameraSignalNames() {
        XCTAssertEqual(Analytics.Signal.cameraOpened, "Camera.Opened")
        XCTAssertEqual(Analytics.Signal.cameraSetLogged, "Camera.SetLogged")
        XCTAssertEqual(Analytics.Signal.cameraRepRejected, "Camera.RepRejected")
        XCTAssertEqual(Analytics.Signal.cameraClosed, "Camera.Closed")
    }

    // MARK: - Send Function

    func testSendDoesNotCrashWithoutInitialization() {
        // TelemetryDeck is not initialized in test environment.
        // Calling send should be a no-op and not crash.
        Analytics.send("Test.Signal")
        Analytics.send("Test.Signal", parameters: ["key": "value"])
    }

    // MARK: - Signal Name Uniqueness

    func testAllSignalNamesAreUnique() {
        let allSignals = [
            Analytics.Signal.workoutStarted,
            Analytics.Signal.workoutCompleted,
            Analytics.Signal.workoutDiscarded,
            Analytics.Signal.exerciseAdded,
            Analytics.Signal.templateCreated,
            Analytics.Signal.supersetCreated,
            Analytics.Signal.prAchieved,
            Analytics.Signal.backupExportedJSON,
            Analytics.Signal.backupImported,
            Analytics.Signal.settingsUnitChanged,
            Analytics.Signal.settingsRestTimerToggled,
            Analytics.Signal.restTimerCompleted,
            Analytics.Signal.cameraOpened,
            Analytics.Signal.cameraSetLogged,
            Analytics.Signal.cameraRepRejected,
            Analytics.Signal.cameraClosed,
        ]
        let uniqueSignals = Set(allSignals)
        XCTAssertEqual(allSignals.count, uniqueSignals.count, "Duplicate signal names found")
    }
}
