//
//  WidgetShared.swift
//  TheLoggerWidget
//
//  Shared data structures for widget (copy of main app's WidgetShared.swift)
//

import Foundation

// MARK: - App Group Configuration

enum AppGroup {
    static let identifier = "group.SDL-Tutorial.TheLogger"

    static var userDefaults: UserDefaults? {
        UserDefaults(suiteName: identifier)
    }
}

// MARK: - Widget Data Model

struct WidgetWorkoutData: Codable {
    let workoutId: UUID
    let workoutName: String
    let currentExerciseId: UUID?
    let currentExerciseName: String?
    let setsCompleted: Int
    let totalExercises: Int
    let startTime: Date
    let lastUpdated: Date

    var isActive: Bool {
        currentExerciseName != nil
    }

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

struct WidgetDataManager {
    private static let dataKey = "activeWorkoutData"

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
}

// MARK: - Deep Link URLs

enum WidgetDeepLink {
    static let scheme = "thelogger"

    static func exerciseURL(workoutId: UUID, exerciseId: UUID) -> URL? {
        URL(string: "\(scheme)://workout/\(workoutId.uuidString)/exercise/\(exerciseId.uuidString)")
    }

    static func workoutURL(workoutId: UUID) -> URL? {
        URL(string: "\(scheme)://workout/\(workoutId.uuidString)")
    }
}
