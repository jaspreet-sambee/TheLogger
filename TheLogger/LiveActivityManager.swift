//
//  LiveActivityManager.swift
//  TheLogger
//
//  Live Activity for logging sets from lock screen
//

import Foundation
import ActivityKit
import SwiftUI
import Combine
import UIKit

// Darwin notification name (must match widget extension)
private let kUpdateLiveActivityNotification = "com.thelogger.updateLiveActivity"

// MARK: - Activity Attributes

/// Defines the data structure for the workout Live Activity
struct WorkoutActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var exerciseName: String        // Current exercise name
        var exerciseId: String          // Current exercise ID
        var exerciseSets: Int           // Sets for THIS exercise only
        var lastReps: Int               // Last logged reps
        var lastWeight: Double          // Last logged weight
        var elapsedSeconds: Int         // Workout duration
    }

    var workoutId: String
    var workoutName: String
    var startTime: Date
}

// MARK: - Live Activity Manager

@MainActor
final class LiveActivityManager: ObservableObject {
    static let shared = LiveActivityManager()

    @Published private(set) var currentActivity: Activity<WorkoutActivityAttributes>?
    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid
    private var fileMonitorSource: DispatchSourceFileSystemObject?
    private let monitorQueue = DispatchQueue(label: "com.thelogger.fileMonitor", qos: .userInitiated)
    private var lastSetCount = 0

    private init() {
        // Start listening for widget notifications (Darwin as backup)
        startListeningForWidgetUpdates()

        // Listen for app going to background
        NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.startBackgroundTask()
        }

        NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.endBackgroundTask()
        }
    }

    /// Start background task to keep app alive during workout
    private func startBackgroundTask() {
        guard currentActivity != nil else { return }

        backgroundTask = UIApplication.shared.beginBackgroundTask { [weak self] in
            self?.endBackgroundTask()
        }
    }

    private func endBackgroundTask() {
        if backgroundTask != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTask)
            backgroundTask = .invalid
        }
    }

    /// Listen for Darwin notifications from the widget extension (backup)
    private func startListeningForWidgetUpdates() {
        let center = CFNotificationCenterGetDarwinNotifyCenter()
        let observer = Unmanaged.passUnretained(self).toOpaque()

        CFNotificationCenterAddObserver(
            center,
            observer,
            { (_, observer, _, _, _) in
                guard let observer = observer else { return }
                let manager = Unmanaged<LiveActivityManager>.fromOpaque(observer).takeUnretainedValue()
                Task { @MainActor in
                    manager.handleWidgetUpdate()
                }
            },
            kUpdateLiveActivityNotification as CFString,
            nil,
            .deliverImmediately
        )
    }

    /// Start file system monitoring for instant updates
    private func startFileSystemMonitoring() {
        // Stop any existing monitor
        stopFileSystemMonitoring()

        let appGroupId = "group.SDL-Tutorial.TheLogger"

        guard let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupId
        ) else {
            print("[LiveActivity] Failed to get App Group container")
            return
        }

        // Watch a dedicated signal file (more reliable than UserDefaults plist)
        let signalFile = containerURL.appendingPathComponent("update_signal.txt")

        // Create the file if it doesn't exist
        if !FileManager.default.fileExists(atPath: signalFile.path) {
            try? "0".write(to: signalFile, atomically: true, encoding: .utf8)
        }

        print("[LiveActivity] Monitoring signal file: \(signalFile.path)")

        let fd = open(signalFile.path, O_EVTONLY)
        guard fd != -1 else {
            print("[LiveActivity] Failed to open signal file")
            return
        }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .extend, .attrib, .rename, .delete],
            queue: monitorQueue
        )

        source.setEventHandler { [weak self] in
            print("[LiveActivity] SIGNAL FILE CHANGED - triggering update")
            Task { @MainActor in
                self?.handleWidgetUpdate()
            }
        }

        source.setCancelHandler {
            close(fd)
        }

        source.resume()
        fileMonitorSource = source
        print("[LiveActivity] Signal file monitoring ACTIVE")
    }

    private func stopFileSystemMonitoring() {
        fileMonitorSource?.cancel()
        fileMonitorSource = nil
    }

    /// Handle update request from widget
    @MainActor
    private func handleWidgetUpdate() {
        guard let activity = currentActivity else { return }
        guard let defaults = UserDefaults(suiteName: "group.SDL-Tutorial.TheLogger") else { return }

        let newSetCount = defaults.integer(forKey: "liveActivitySetCount")

        // Only update if changed
        guard newSetCount > 0 && newSetCount != lastSetCount else { return }
        lastSetCount = newSetCount

        // Update with high priority
        Task {
            var state = activity.content.state
            state.exerciseSets = newSetCount

            // Use staleDate in the past to hint this is urgent
            await activity.update(
                ActivityContent(state: state, staleDate: Date(timeIntervalSinceNow: -1))
            )
            print("[LiveActivity] Updated from widget - sets: \(newSetCount)")
        }
    }

    var isSupported: Bool {
        ActivityAuthorizationInfo().areActivitiesEnabled
    }

    /// Start a new Live Activity for a workout
    func startActivity(
        workoutId: UUID,
        workoutName: String,
        exerciseName: String,
        exerciseId: UUID,
        exerciseSets: Int = 0,
        lastReps: Int = 0,
        lastWeight: Double = 0
    ) {
        print("[LiveActivity] Starting for workout: \(workoutName)")

        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            print("[LiveActivity] Not enabled in Settings")
            return
        }

        // End any existing activity
        Task {
            await endActivity()

            let attributes = WorkoutActivityAttributes(
                workoutId: workoutId.uuidString,
                workoutName: workoutName,
                startTime: Date()
            )

            let state = WorkoutActivityAttributes.ContentState(
                exerciseName: exerciseName,
                exerciseId: exerciseId.uuidString,
                exerciseSets: exerciseSets,
                lastReps: lastReps,
                lastWeight: lastWeight,
                elapsedSeconds: 0
            )

            do {
                let activity = try Activity.request(
                    attributes: attributes,
                    content: .init(state: state, staleDate: nil),
                    pushType: nil
                )
                self.currentActivity = activity
                self.lastSetCount = exerciseSets
                print("[LiveActivity] Started: \(activity.id)")
                startElapsedTimeUpdater()
                startFileSystemMonitoring()
            } catch {
                print("[LiveActivity] Failed: \(error.localizedDescription)")
            }
        }
    }

    /// Update Live Activity with current exercise info
    func updateActivity(
        exerciseName: String,
        exerciseId: UUID,
        exerciseSets: Int,
        lastReps: Int,
        lastWeight: Double
    ) async {
        guard let activity = currentActivity else {
            print("[LiveActivity] No active activity to update")
            return
        }

        let elapsed = Int(Date().timeIntervalSince(activity.attributes.startTime))

        let state = WorkoutActivityAttributes.ContentState(
            exerciseName: exerciseName,
            exerciseId: exerciseId.uuidString,
            exerciseSets: exerciseSets,
            lastReps: lastReps,
            lastWeight: lastWeight,
            elapsedSeconds: elapsed
        )

        await activity.update(ActivityContent(state: state, staleDate: nil))
        print("[LiveActivity] Updated: \(exerciseName) - \(exerciseSets) sets")
    }

    /// End the Live Activity
    func endActivity() async {
        stopFileSystemMonitoring()

        guard let activity = currentActivity else { return }

        await activity.end(
            ActivityContent(state: activity.content.state, staleDate: nil),
            dismissalPolicy: .immediate
        )
        currentActivity = nil
        lastSetCount = 0
        print("[LiveActivity] Ended")
    }

    private func startElapsedTimeUpdater() {
        Task {
            while currentActivity != nil {
                try? await Task.sleep(nanoseconds: 60_000_000_000)
                guard let activity = currentActivity else { break }

                var state = activity.content.state
                state.elapsedSeconds = Int(Date().timeIntervalSince(activity.attributes.startTime))

                await activity.update(ActivityContent(state: state, staleDate: nil))
            }
        }
    }

}

// MARK: - Formatted Helpers

extension WorkoutActivityAttributes.ContentState {
    var formattedWeight: String {
        let useMetric = UserDefaults.standard.string(forKey: "unitSystem") == "Metric"
        let weight = useMetric ? lastWeight * 0.453592 : lastWeight
        let unit = useMetric ? "kg" : "lbs"
        return String(format: "%.0f %@", weight, unit)
    }

    var formattedElapsedTime: String {
        let hours = elapsedSeconds / 3600
        let minutes = (elapsedSeconds % 3600) / 60
        return hours > 0 ? String(format: "%d:%02d", hours, minutes) : "\(minutes)m"
    }

    var lastSetSummary: String {
        "\(formattedWeight) × \(lastReps)"
    }
}
