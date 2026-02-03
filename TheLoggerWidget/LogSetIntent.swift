//
//  LogSetIntent.swift
//  TheLoggerWidget
//
//  App Intent for logging sets from Live Activity
//

import AppIntents
import ActivityKit
import Foundation
import os.log
import Darwin

private let logger = Logger(subsystem: "com.thelogger.widget", category: "LogSetIntent")

// Darwin notification to signal main app
private let kUpdateLiveActivityNotification = "com.thelogger.updateLiveActivity" as CFString

// MARK: - Log Set Intent

struct LogSetIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Log Set"
    static var description = IntentDescription("Log a set to your current workout")

    @Parameter(title: "Workout ID")
    var workoutId: String

    @Parameter(title: "Exercise ID")
    var exerciseId: String

    @Parameter(title: "Current Sets")
    var currentSets: Int

    @Parameter(title: "Reps")
    var reps: Int

    @Parameter(title: "Weight")
    var weight: Double

    init() {
        self.workoutId = ""
        self.exerciseId = ""
        self.currentSets = 0
        self.reps = 10
        self.weight = 135
    }

    init(workoutId: String, exerciseId: String, currentSets: Int, reps: Int, weight: Double) {
        self.workoutId = workoutId
        self.exerciseId = exerciseId
        self.currentSets = currentSets
        self.reps = reps
        self.weight = weight
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        let appGroupId = "group.SDL-Tutorial.TheLogger"
        let debugDefaults = UserDefaults(suiteName: appGroupId)

        // Save pending set to shared storage
        let pendingSet = PendingSet(
            id: UUID().uuidString,
            workoutId: workoutId,
            exerciseId: exerciseId,
            reps: reps,
            weight: weight,
            timestamp: Date()
        )
        PendingSetManager.addPendingSet(pendingSet)

        // Save the updated set count for the Live Activity to read
        let newSetCount = currentSets + 1
        debugDefaults?.set(newSetCount, forKey: "liveActivitySetCount")
        debugDefaults?.set(exerciseId, forKey: "liveActivityExerciseId")

        // Write a signal file directly (more reliable than UserDefaults file watching)
        if let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupId) {
            let signalFile = containerURL.appendingPathComponent("update_signal.txt")
            let data = "\(newSetCount):\(Date().timeIntervalSince1970)".data(using: .utf8)
            try? data?.write(to: signalFile, options: .atomic)
        }

        // Send Darwin notification as backup
        let center = CFNotificationCenterGetDarwinNotifyCenter()
        CFNotificationCenterPostNotification(center, CFNotificationName(kUpdateLiveActivityNotification), nil, nil, true)

        return .result()
    }
}

// MARK: - Pending Set

struct PendingSet: Codable, Identifiable {
    let id: String
    let workoutId: String
    let exerciseId: String
    let reps: Int
    let weight: Double
    let timestamp: Date
}

// MARK: - Pending Set Manager

struct PendingSetManager {
    private static let key = "pendingSets"
    private static let appGroupId = "group.SDL-Tutorial.TheLogger"

    static var userDefaults: UserDefaults? {
        UserDefaults(suiteName: appGroupId)
    }

    static func addPendingSet(_ set: PendingSet) {
        guard let defaults = userDefaults else {
            logger.error("No App Group access")
            return
        }

        var sets = getPendingSets()
        sets.append(set)

        if let data = try? JSONEncoder().encode(sets) {
            defaults.set(data, forKey: key)
            defaults.synchronize()
            logger.info("Saved \(sets.count) pending sets")
        }
    }

    static func getPendingSets() -> [PendingSet] {
        guard let defaults = userDefaults,
              let data = defaults.data(forKey: key),
              let sets = try? JSONDecoder().decode([PendingSet].self, from: data) else {
            return []
        }
        return sets
    }

    static func clearPendingSets() {
        userDefaults?.removeObject(forKey: key)
        userDefaults?.synchronize()
    }
}
