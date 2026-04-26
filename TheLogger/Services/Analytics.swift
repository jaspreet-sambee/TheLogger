//
//  Analytics.swift
//  TheLogger
//
//  Thin wrapper around TelemetryDeck signals.
//  Centralizes signal names and keeps TelemetryDeck imports out of view files.
//

import TelemetryDeck

enum Analytics {
    private(set) static var isInitialized = false

    static func initialize(appID: String) {
        let config = TelemetryDeck.Config(appID: appID)
        TelemetryDeck.initialize(config: config)
        isInitialized = true
    }

    static func send(_ signal: String, parameters: [String: String] = [:]) {
        guard isInitialized else { return }
        TelemetryDeck.signal(signal, parameters: parameters)
    }

    // MARK: - Signal Name Constants

    enum Signal {
        // Onboarding
        static let onboardingStarted     = "Onboarding.Started"
        static let onboardingStepViewed  = "Onboarding.StepViewed"
        static let onboardingCompleted   = "Onboarding.Completed"

        // Navigation
        static let tabSelected           = "Tab.Selected"

        // Workout lifecycle
        static let workoutStarted        = "Workout.Started"
        static let workoutCompleted      = "Workout.Completed"
        static let workoutDiscarded      = "Workout.Discarded"
        static let workoutResumed        = "Workout.Resumed"

        // Exercise
        static let exerciseAdded         = "Exercise.Added"
        static let exerciseSearched      = "Exercise.Searched"
        static let exerciseNoteEdited    = "Exercise.NoteEdited"
        static let exerciseDetailViewed  = "Exercise.DetailViewed"
        static let setLogged             = "Set.Logged"
        static let setDeleted            = "Set.Deleted"

        // Templates & supersets
        static let templateCreated       = "Template.Created"
        static let templateEdited        = "Template.Edited"
        static let templateDeleted       = "Template.Deleted"
        static let templateStarted       = "Template.Started"
        static let supersetCreated       = "Superset.Created"

        // PRs
        static let prAchieved            = "PR.Achieved"
        static let prTimelineViewed      = "PR.TimelineViewed"
        static let prFilterChanged       = "PR.FilterChanged"

        // Rest timer
        static let restTimerCompleted    = "RestTimer.Completed"
        static let restTimerSkipped      = "RestTimer.Skipped"
        static let restTimerExtended     = "RestTimer.Extended"

        // Camera
        static let cameraOpened          = "Camera.Opened"
        static let cameraSetLogged       = "Camera.SetLogged"
        static let cameraRepRejected     = "Camera.RepRejected"
        static let cameraClosed          = "Camera.Closed"
        static let cameraExerciseChanged = "Camera.ExerciseChanged"
        static let cameraSensitivityChanged = "Camera.SensitivityChanged"
        static let cameraSkeletonToggled = "Camera.SkeletonToggled"

        // Share cards
        static let shareCardCreated      = "ShareCard.Created"
        static let shareCardShared       = "ShareCard.Shared"
        static let shareCardSaved        = "ShareCard.Saved"

        // Gamification
        static let achievementUnlocked   = "Achievement.Unlocked"
        static let achievementsViewed    = "Achievements.Viewed"
        static let streakMilestone       = "Streak.Milestone"
        static let weeklyGoalAchieved    = "WeeklyGoal.Achieved"
        static let restDayChallengeStarted  = "RestDayChallenge.Started"
        static let restDayChallengeCompleted = "RestDayChallenge.Completed"
        static let levelUp               = "Level.Up"

        // Stats & dashboard
        static let statsDashboardViewed  = "Stats.DashboardViewed"
        static let statsPeriodChanged    = "Stats.PeriodChanged"
        static let weeklyRecapViewed     = "WeeklyRecap.Viewed"
        static let muscleBreakdownViewed = "Stats.MuscleBreakdownViewed"

        // Data & backup
        static let backupExportedJSON    = "Backup.Exported.JSON"
        static let backupExportedCSV     = "Backup.Exported.CSV"
        static let backupImported        = "Backup.Imported"

        // Settings
        static let settingsUnitChanged   = "Settings.UnitChanged"
        static let settingsRestTimerToggled = "Settings.RestTimer.Toggled"
        static let settingsRestDurationChanged = "Settings.RestDuration.Changed"
        static let settingsWeeklyGoalChanged   = "Settings.WeeklyGoal.Changed"
        static let settingsNotificationToggled = "Settings.Notification.Toggled"
        static let settingsCameraHandsFreeToggled = "Settings.Camera.HandsFreeToggled"
        static let settingsTempoChanged  = "Settings.Tempo.Changed"

        // Profile
        static let profileViewed         = "Profile.Viewed"
        static let upgradePromptViewed   = "Upgrade.PromptViewed"
        static let upgradePromptTapped   = "Upgrade.PromptTapped"

        // Workout summary
        static let workoutSummaryViewed  = "WorkoutSummary.Viewed"
        static let workoutSummaryDismissed = "WorkoutSummary.Dismissed"
    }
}
