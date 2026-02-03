//
//  WidgetShared.swift
//  TheLogger
//
//  Shared data structures for widget communication
//

import Foundation
import WidgetKit

// MARK: - App Group Configuration

enum AppGroup {
    static let identifier = "group.SDL-Tutorial.TheLogger"

    static var userDefaults: UserDefaults? {
        UserDefaults(suiteName: identifier)
    }
}

// MARK: - Widget Data Model

/// Data shared between the main app and widget
struct WidgetWorkoutData: Codable {
    let workoutId: UUID
    let workoutName: String
    let currentExerciseId: UUID?
    let currentExerciseName: String?
    let setsCompleted: Int
    let totalExercises: Int
    let startTime: Date
    let lastUpdated: Date

    /// Whether there's an active workout
    var isActive: Bool {
        currentExerciseName != nil
    }

    /// Formatted elapsed time
    var elapsedTime: String {
        let elapsed = Date().timeIntervalSince(startTime)
        let hours = Int(elapsed) / 3600
        let minutes = (Int(elapsed) % 3600) / 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }

    /// Empty state when no workout is active
    static let empty = WidgetWorkoutData(
        workoutId: UUID(),
        workoutName: "",
        currentExerciseId: nil,
        currentExerciseName: nil,
        setsCompleted: 0,
        totalExercises: 0,
        startTime: Date(),
        lastUpdated: Date()
    )
}

// MARK: - Widget Data Manager

/// Manages reading/writing widget data to the shared App Group
struct WidgetDataManager {
    private static let dataKey = "activeWorkoutData"

    /// Save current workout state for the widget
    static func save(_ data: WidgetWorkoutData) {
        guard let defaults = AppGroup.userDefaults else {
            print("[Widget] Failed to access App Group UserDefaults")
            return
        }

        do {
            let encoded = try JSONEncoder().encode(data)
            defaults.set(encoded, forKey: dataKey)
            defaults.synchronize()

            // Trigger widget refresh
            WidgetCenter.shared.reloadAllTimelines()

            #if DEBUG
            print("[Widget] Saved workout data: \(data.currentExerciseName ?? "nil")")
            #endif
        } catch {
            print("[Widget] Failed to encode workout data: \(error)")
        }
    }

    /// Load current workout state from the widget
    static func load() -> WidgetWorkoutData? {
        guard let defaults = AppGroup.userDefaults,
              let data = defaults.data(forKey: dataKey) else {
            return nil
        }

        do {
            return try JSONDecoder().decode(WidgetWorkoutData.self, from: data)
        } catch {
            print("[Widget] Failed to decode workout data: \(error)")
            return nil
        }
    }

    /// Clear widget data (when workout ends)
    static func clear() {
        guard let defaults = AppGroup.userDefaults else { return }
        defaults.removeObject(forKey: dataKey)
        defaults.synchronize()
        WidgetCenter.shared.reloadAllTimelines()

        #if DEBUG
        print("[Widget] Cleared workout data")
        #endif
    }
}

// MARK: - Deep Link URLs

enum WidgetDeepLink {
    static let scheme = "thelogger"

    /// URL to open current exercise
    static func exerciseURL(workoutId: UUID, exerciseId: UUID) -> URL? {
        URL(string: "\(scheme)://workout/\(workoutId.uuidString)/exercise/\(exerciseId.uuidString)")
    }

    /// URL to open current workout
    static func workoutURL(workoutId: UUID) -> URL? {
        URL(string: "\(scheme)://workout/\(workoutId.uuidString)")
    }

    /// Parse a deep link URL
    static func parse(_ url: URL) -> DeepLinkDestination? {
        guard url.scheme == scheme else { return nil }

        let components = url.pathComponents.filter { $0 != "/" }

        // thelogger://workout/{workoutId}/exercise/{exerciseId}
        if components.count >= 4,
           components[0] == "workout",
           let workoutId = UUID(uuidString: components[1]),
           components[2] == "exercise",
           let exerciseId = UUID(uuidString: components[3]) {
            return .exercise(workoutId: workoutId, exerciseId: exerciseId)
        }

        // thelogger://workout/{workoutId}
        if components.count >= 2,
           components[0] == "workout",
           let workoutId = UUID(uuidString: components[1]) {
            return .workout(workoutId: workoutId)
        }

        return nil
    }
}

enum DeepLinkDestination {
    case workout(workoutId: UUID)
    case exercise(workoutId: UUID, exerciseId: UUID)
}

// MARK: - Pending Set Model

/// Represents a set logged from the widget that needs to be synced to the main app
struct PendingSet: Codable, Identifiable {
    let id: String
    let workoutId: String
    let exerciseId: String
    let reps: Int
    let weight: Double
    let timestamp: Date
}

// MARK: - Pending Set Manager

/// Manages pending sets that were logged from the widget
struct PendingSetManager {
    private static let key = "pendingSets"

    /// Get all pending sets
    static func getPendingSets() -> [PendingSet] {
        guard let defaults = AppGroup.userDefaults,
              let data = defaults.data(forKey: key) else {
            return []
        }

        do {
            return try JSONDecoder().decode([PendingSet].self, from: data)
        } catch {
            print("[Widget] Failed to decode pending sets: \(error)")
            return []
        }
    }

    /// Clear all pending sets (after main app syncs them)
    static func clearPendingSets() {
        AppGroup.userDefaults?.removeObject(forKey: key)
        AppGroup.userDefaults?.synchronize()
        print("[Widget] Cleared pending sets")
    }

    /// Check if there are pending sets to sync
    static var hasPendingSets: Bool {
        !getPendingSets().isEmpty
    }
}
