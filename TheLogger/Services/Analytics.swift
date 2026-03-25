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
        static let workoutStarted = "Workout.Started"
        static let workoutCompleted = "Workout.Completed"
        static let workoutDiscarded = "Workout.Discarded"
        static let exerciseAdded = "Exercise.Added"
        static let templateCreated = "Template.Created"
        static let supersetCreated = "Superset.Created"
        static let prAchieved = "PR.Achieved"
        static let backupExportedJSON = "Backup.Exported.JSON"
        static let backupImported = "Backup.Imported"
        static let settingsUnitChanged = "Settings.UnitChanged"
        static let settingsRestTimerToggled = "Settings.RestTimer.Toggled"
        static let restTimerCompleted = "RestTimer.Completed"
        static let cameraOpened = "Camera.Opened"
        static let cameraSetLogged = "Camera.SetLogged"
        static let cameraRepRejected = "Camera.RepRejected"
        static let cameraClosed = "Camera.Closed"
        static let achievementUnlocked = "Achievement.Unlocked"
        static let weeklyRecapViewed = "WeeklyRecap.Viewed"
        static let achievementsViewed = "Achievements.Viewed"
    }
}
