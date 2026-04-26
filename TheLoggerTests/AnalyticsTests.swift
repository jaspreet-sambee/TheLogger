//
//  AnalyticsTests.swift
//  TheLoggerTests
//
//  Tests for Analytics signal name constants, send function, and signal uniqueness.
//

import XCTest
@testable import TheLogger

final class AnalyticsTests: XCTestCase {

    // MARK: - Onboarding Signal Names

    func testOnboardingSignalNames() {
        XCTAssertEqual(Analytics.Signal.onboardingStarted, "Onboarding.Started")
        XCTAssertEqual(Analytics.Signal.onboardingStepViewed, "Onboarding.StepViewed")
        XCTAssertEqual(Analytics.Signal.onboardingCompleted, "Onboarding.Completed")
    }

    // MARK: - Navigation Signal Names

    func testNavigationSignalNames() {
        XCTAssertEqual(Analytics.Signal.tabSelected, "Tab.Selected")
    }

    // MARK: - Workout Signal Names

    func testWorkoutSignalNames() {
        XCTAssertEqual(Analytics.Signal.workoutStarted, "Workout.Started")
        XCTAssertEqual(Analytics.Signal.workoutCompleted, "Workout.Completed")
        XCTAssertEqual(Analytics.Signal.workoutDiscarded, "Workout.Discarded")
        XCTAssertEqual(Analytics.Signal.workoutResumed, "Workout.Resumed")
    }

    // MARK: - Exercise Signal Names

    func testExerciseSignalNames() {
        XCTAssertEqual(Analytics.Signal.exerciseAdded, "Exercise.Added")
        XCTAssertEqual(Analytics.Signal.exerciseSearched, "Exercise.Searched")
        XCTAssertEqual(Analytics.Signal.exerciseNoteEdited, "Exercise.NoteEdited")
        XCTAssertEqual(Analytics.Signal.exerciseDetailViewed, "Exercise.DetailViewed")
        XCTAssertEqual(Analytics.Signal.setLogged, "Set.Logged")
        XCTAssertEqual(Analytics.Signal.setDeleted, "Set.Deleted")
    }

    // MARK: - Template Signal Names

    func testTemplateSignalNames() {
        XCTAssertEqual(Analytics.Signal.templateCreated, "Template.Created")
        XCTAssertEqual(Analytics.Signal.templateEdited, "Template.Edited")
        XCTAssertEqual(Analytics.Signal.templateDeleted, "Template.Deleted")
        XCTAssertEqual(Analytics.Signal.templateStarted, "Template.Started")
        XCTAssertEqual(Analytics.Signal.supersetCreated, "Superset.Created")
    }

    // MARK: - PR Signal Names

    func testPRSignalNames() {
        XCTAssertEqual(Analytics.Signal.prAchieved, "PR.Achieved")
        XCTAssertEqual(Analytics.Signal.prTimelineViewed, "PR.TimelineViewed")
        XCTAssertEqual(Analytics.Signal.prFilterChanged, "PR.FilterChanged")
    }

    // MARK: - Rest Timer Signal Names

    func testRestTimerSignalNames() {
        XCTAssertEqual(Analytics.Signal.restTimerCompleted, "RestTimer.Completed")
        XCTAssertEqual(Analytics.Signal.restTimerSkipped, "RestTimer.Skipped")
        XCTAssertEqual(Analytics.Signal.restTimerExtended, "RestTimer.Extended")
    }

    // MARK: - Camera Signal Names

    func testCameraSignalNames() {
        XCTAssertEqual(Analytics.Signal.cameraOpened, "Camera.Opened")
        XCTAssertEqual(Analytics.Signal.cameraSetLogged, "Camera.SetLogged")
        XCTAssertEqual(Analytics.Signal.cameraRepRejected, "Camera.RepRejected")
        XCTAssertEqual(Analytics.Signal.cameraClosed, "Camera.Closed")
        XCTAssertEqual(Analytics.Signal.cameraExerciseChanged, "Camera.ExerciseChanged")
        XCTAssertEqual(Analytics.Signal.cameraSensitivityChanged, "Camera.SensitivityChanged")
        XCTAssertEqual(Analytics.Signal.cameraSkeletonToggled, "Camera.SkeletonToggled")
    }

    // MARK: - Share Card Signal Names

    func testShareCardSignalNames() {
        XCTAssertEqual(Analytics.Signal.shareCardCreated, "ShareCard.Created")
        XCTAssertEqual(Analytics.Signal.shareCardShared, "ShareCard.Shared")
        XCTAssertEqual(Analytics.Signal.shareCardSaved, "ShareCard.Saved")
    }

    // MARK: - Gamification Signal Names

    func testGamificationSignalNames() {
        XCTAssertEqual(Analytics.Signal.achievementUnlocked, "Achievement.Unlocked")
        XCTAssertEqual(Analytics.Signal.achievementsViewed, "Achievements.Viewed")
        XCTAssertEqual(Analytics.Signal.streakMilestone, "Streak.Milestone")
        XCTAssertEqual(Analytics.Signal.weeklyGoalAchieved, "WeeklyGoal.Achieved")
        XCTAssertEqual(Analytics.Signal.restDayChallengeStarted, "RestDayChallenge.Started")
        XCTAssertEqual(Analytics.Signal.restDayChallengeCompleted, "RestDayChallenge.Completed")
        XCTAssertEqual(Analytics.Signal.levelUp, "Level.Up")
    }

    // MARK: - Stats & Dashboard Signal Names

    func testStatsDashboardSignalNames() {
        XCTAssertEqual(Analytics.Signal.statsDashboardViewed, "Stats.DashboardViewed")
        XCTAssertEqual(Analytics.Signal.statsPeriodChanged, "Stats.PeriodChanged")
        XCTAssertEqual(Analytics.Signal.weeklyRecapViewed, "WeeklyRecap.Viewed")
        XCTAssertEqual(Analytics.Signal.muscleBreakdownViewed, "Stats.MuscleBreakdownViewed")
    }

    // MARK: - Backup Signal Names

    func testBackupSignalNames() {
        XCTAssertEqual(Analytics.Signal.backupExportedJSON, "Backup.Exported.JSON")
        XCTAssertEqual(Analytics.Signal.backupExportedCSV, "Backup.Exported.CSV")
        XCTAssertEqual(Analytics.Signal.backupImported, "Backup.Imported")
    }

    // MARK: - Settings Signal Names

    func testSettingsSignalNames() {
        XCTAssertEqual(Analytics.Signal.settingsUnitChanged, "Settings.UnitChanged")
        XCTAssertEqual(Analytics.Signal.settingsRestTimerToggled, "Settings.RestTimer.Toggled")
        XCTAssertEqual(Analytics.Signal.settingsRestDurationChanged, "Settings.RestDuration.Changed")
        XCTAssertEqual(Analytics.Signal.settingsWeeklyGoalChanged, "Settings.WeeklyGoal.Changed")
        XCTAssertEqual(Analytics.Signal.settingsNotificationToggled, "Settings.Notification.Toggled")
        XCTAssertEqual(Analytics.Signal.settingsCameraHandsFreeToggled, "Settings.Camera.HandsFreeToggled")
        XCTAssertEqual(Analytics.Signal.settingsTempoChanged, "Settings.Tempo.Changed")
    }

    // MARK: - Profile Signal Names

    func testProfileSignalNames() {
        XCTAssertEqual(Analytics.Signal.profileViewed, "Profile.Viewed")
        XCTAssertEqual(Analytics.Signal.upgradePromptViewed, "Upgrade.PromptViewed")
        XCTAssertEqual(Analytics.Signal.upgradePromptTapped, "Upgrade.PromptTapped")
    }

    // MARK: - Workout Summary Signal Names

    func testWorkoutSummarySignalNames() {
        XCTAssertEqual(Analytics.Signal.workoutSummaryViewed, "WorkoutSummary.Viewed")
        XCTAssertEqual(Analytics.Signal.workoutSummaryDismissed, "WorkoutSummary.Dismissed")
    }

    // MARK: - Send Function Safety

    func testSendDoesNotCrashWithoutInitialization() {
        // TelemetryDeck is not initialized in test environment.
        // Calling send should be a no-op and not crash.
        Analytics.send("Test.Signal")
        Analytics.send("Test.Signal", parameters: ["key": "value"])
    }

    func testSendWithEmptySignalName() {
        // Should not crash even with an empty signal name
        Analytics.send("")
        Analytics.send("", parameters: [:])
    }

    func testSendWithEmptyParameters() {
        Analytics.send("Test.Signal", parameters: [:])
    }

    func testSendWithManyParameters() {
        Analytics.send("Test.Signal", parameters: [
            "key1": "value1",
            "key2": "value2",
            "key3": "value3",
            "key4": "value4",
            "key5": "value5"
        ])
    }

    func testSendWithSpecialCharactersInParameters() {
        Analytics.send("Test.Signal", parameters: [
            "exerciseName": "Barbell Bench Press (Flat)",
            "weight": "225.5",
            "unicode": "Emoji 💪"
        ])
    }

    func testIsInitialized_defaultsFalseInTests() {
        // In test environment, TelemetryDeck.initialize is not called
        XCTAssertFalse(Analytics.isInitialized)
    }

    // MARK: - Signal Name Format Consistency

    func testAllSignalNames_useDotSeparatedFormat() {
        let allSignals = allSignalNames()
        for signal in allSignals {
            XCTAssertTrue(
                signal.contains("."),
                "Signal '\(signal)' should use dot-separated format (e.g., 'Category.Action')"
            )
        }
    }

    func testAllSignalNames_startWithCapitalLetter() {
        let allSignals = allSignalNames()
        for signal in allSignals {
            let first = signal.first!
            XCTAssertTrue(
                first.isUppercase,
                "Signal '\(signal)' should start with a capital letter"
            )
        }
    }

    func testAllSignalNames_noWhitespace() {
        let allSignals = allSignalNames()
        for signal in allSignals {
            XCTAssertFalse(
                signal.contains(" "),
                "Signal '\(signal)' should not contain whitespace"
            )
        }
    }

    func testAllSignalNames_noTrailingDot() {
        let allSignals = allSignalNames()
        for signal in allSignals {
            XCTAssertFalse(
                signal.hasSuffix("."),
                "Signal '\(signal)' should not end with a dot"
            )
        }
    }

    // MARK: - Signal Name Uniqueness

    func testAllSignalNamesAreUnique() {
        let allSignals = allSignalNames()
        let uniqueSignals = Set(allSignals)
        XCTAssertEqual(allSignals.count, uniqueSignals.count, "Duplicate signal names found")
    }

    func testTotalSignalCount() {
        let allSignals = allSignalNames()
        // 61 signals total — update this if you add more
        XCTAssertEqual(allSignals.count, 61, "Signal count changed — update this test and verify uniqueness")
    }

    // MARK: - Category Coverage

    func testOnboardingCategory_hasThreeSignals() {
        let onboarding = [
            Analytics.Signal.onboardingStarted,
            Analytics.Signal.onboardingStepViewed,
            Analytics.Signal.onboardingCompleted,
        ]
        XCTAssertEqual(onboarding.count, 3)
        XCTAssertTrue(onboarding.allSatisfy { $0.hasPrefix("Onboarding.") })
    }

    func testWorkoutCategory_hasFourSignals() {
        let workout = [
            Analytics.Signal.workoutStarted,
            Analytics.Signal.workoutCompleted,
            Analytics.Signal.workoutDiscarded,
            Analytics.Signal.workoutResumed,
        ]
        XCTAssertEqual(workout.count, 4)
        XCTAssertTrue(workout.allSatisfy { $0.hasPrefix("Workout.") })
    }

    func testCameraCategory_hasSevenSignals() {
        let camera = [
            Analytics.Signal.cameraOpened,
            Analytics.Signal.cameraSetLogged,
            Analytics.Signal.cameraRepRejected,
            Analytics.Signal.cameraClosed,
            Analytics.Signal.cameraExerciseChanged,
            Analytics.Signal.cameraSensitivityChanged,
            Analytics.Signal.cameraSkeletonToggled,
        ]
        XCTAssertEqual(camera.count, 7)
        XCTAssertTrue(camera.allSatisfy { $0.hasPrefix("Camera.") })
    }

    func testSettingsCategory_hasSevenSignals() {
        let settings = [
            Analytics.Signal.settingsUnitChanged,
            Analytics.Signal.settingsRestTimerToggled,
            Analytics.Signal.settingsRestDurationChanged,
            Analytics.Signal.settingsWeeklyGoalChanged,
            Analytics.Signal.settingsNotificationToggled,
            Analytics.Signal.settingsCameraHandsFreeToggled,
            Analytics.Signal.settingsTempoChanged,
        ]
        XCTAssertEqual(settings.count, 7)
        XCTAssertTrue(settings.allSatisfy { $0.hasPrefix("Settings.") })
    }

    // MARK: - Helpers

    private func allSignalNames() -> [String] {
        [
            // Onboarding
            Analytics.Signal.onboardingStarted,
            Analytics.Signal.onboardingStepViewed,
            Analytics.Signal.onboardingCompleted,
            // Navigation
            Analytics.Signal.tabSelected,
            // Workout
            Analytics.Signal.workoutStarted,
            Analytics.Signal.workoutCompleted,
            Analytics.Signal.workoutDiscarded,
            Analytics.Signal.workoutResumed,
            // Exercise
            Analytics.Signal.exerciseAdded,
            Analytics.Signal.exerciseSearched,
            Analytics.Signal.exerciseNoteEdited,
            Analytics.Signal.exerciseDetailViewed,
            Analytics.Signal.setLogged,
            Analytics.Signal.setDeleted,
            // Templates
            Analytics.Signal.templateCreated,
            Analytics.Signal.templateEdited,
            Analytics.Signal.templateDeleted,
            Analytics.Signal.templateStarted,
            Analytics.Signal.supersetCreated,
            // PRs
            Analytics.Signal.prAchieved,
            Analytics.Signal.prTimelineViewed,
            Analytics.Signal.prFilterChanged,
            // Rest timer
            Analytics.Signal.restTimerCompleted,
            Analytics.Signal.restTimerSkipped,
            Analytics.Signal.restTimerExtended,
            // Camera
            Analytics.Signal.cameraOpened,
            Analytics.Signal.cameraSetLogged,
            Analytics.Signal.cameraRepRejected,
            Analytics.Signal.cameraClosed,
            Analytics.Signal.cameraExerciseChanged,
            Analytics.Signal.cameraSensitivityChanged,
            Analytics.Signal.cameraSkeletonToggled,
            // Share cards
            Analytics.Signal.shareCardCreated,
            Analytics.Signal.shareCardShared,
            Analytics.Signal.shareCardSaved,
            // Gamification
            Analytics.Signal.achievementUnlocked,
            Analytics.Signal.achievementsViewed,
            Analytics.Signal.streakMilestone,
            Analytics.Signal.weeklyGoalAchieved,
            Analytics.Signal.restDayChallengeStarted,
            Analytics.Signal.restDayChallengeCompleted,
            Analytics.Signal.levelUp,
            // Stats
            Analytics.Signal.statsDashboardViewed,
            Analytics.Signal.statsPeriodChanged,
            Analytics.Signal.weeklyRecapViewed,
            Analytics.Signal.muscleBreakdownViewed,
            // Backup
            Analytics.Signal.backupExportedJSON,
            Analytics.Signal.backupExportedCSV,
            Analytics.Signal.backupImported,
            // Settings
            Analytics.Signal.settingsUnitChanged,
            Analytics.Signal.settingsRestTimerToggled,
            Analytics.Signal.settingsRestDurationChanged,
            Analytics.Signal.settingsWeeklyGoalChanged,
            Analytics.Signal.settingsNotificationToggled,
            Analytics.Signal.settingsCameraHandsFreeToggled,
            Analytics.Signal.settingsTempoChanged,
            // Profile
            Analytics.Signal.profileViewed,
            Analytics.Signal.upgradePromptViewed,
            Analytics.Signal.upgradePromptTapped,
            // Summary
            Analytics.Signal.workoutSummaryViewed,
            Analytics.Signal.workoutSummaryDismissed,
        ]
    }
}
