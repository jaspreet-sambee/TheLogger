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
        let timestamp = Date().timeIntervalSince1970
        let newSetCount = currentSets + 1

        logger.info("🎯 LogSetIntent START: \(reps) × \(weight) lbs")

        // STEP 1: Save pending set first (ensures data persistence)
        let pendingSet = PendingSet(
            id: UUID().uuidString,
            workoutId: workoutId,
            exerciseId: exerciseId,
            reps: reps,
            weight: weight,
            timestamp: Date()
        )
        PendingSetManager.addPendingSet(pendingSet)

        // STEP 2: Update metadata (including weight/reps for main app to read)
        if let defaults = UserDefaults(suiteName: "group.SDL-Tutorial.TheLogger") {
            defaults.set(newSetCount, forKey: "liveActivitySetCount")
            defaults.set(exerciseId, forKey: "liveActivityExerciseId")
            defaults.set(weight, forKey: "liveActivityLastWeight")
            defaults.set(reps, forKey: "liveActivityLastReps")
        }

        // STEP 3: Update Live Activity UI (fast path)
        await updateActivityDirect(newSetCount: newSetCount, reps: reps, weight: weight)

        // STEP 4: Signal main app (async, non-blocking)
        Task.detached(priority: .userInitiated) {
            Self.signalMainApp(setCount: newSetCount, timestamp: timestamp)
        }

        logger.info("✅ LogSetIntent COMPLETE: Set \(newSetCount)")

        return .result()
    }

    private func updateActivityDirect(newSetCount: Int, reps: Int, weight: Double) async {
        // Find and update activity directly
        for activity in Activity<WorkoutActivityAttributes>.activities {
            if activity.attributes.workoutId == workoutId {
                var state = activity.content.state
                state.exerciseSets = newSetCount
                state.lastReps = reps
                state.lastWeight = weight

                logger.info("📱 Updating UI: \(newSetCount) sets, \(weight) lbs × \(reps)")

                // Update with nil stale date for immediate display
                await activity.update(
                    ActivityContent(state: state, staleDate: nil)
                )

                logger.info("✅ UI Updated")
                return
            }
        }
        logger.warning("⚠️ No matching activity found")
    }

    private static func signalMainApp(setCount: Int, timestamp: TimeInterval) {
        let appGroupId = "group.SDL-Tutorial.TheLogger"

        // Write signal file
        if let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupId) {
            let signalFile = containerURL.appendingPathComponent("update_signal.txt")
            let data = "\(setCount):\(timestamp)".data(using: .utf8)
            try? data?.write(to: signalFile, options: .atomic)
        }

        // Darwin notification (backup mechanism)
        let center = CFNotificationCenterGetDarwinNotifyCenter()
        CFNotificationCenterPostNotification(
            center,
            CFNotificationName(kUpdateLiveActivityNotification),
            nil,
            nil,
            true
        )
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

// MARK: - Adjust Weight Intent

struct AdjustWeightIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Adjust Weight"
    static var description = IntentDescription("Log a set with adjusted weight")

    @Parameter(title: "Workout ID")
    var workoutId: String

    @Parameter(title: "Exercise ID")
    var exerciseId: String

    @Parameter(title: "Current Sets")
    var currentSets: Int

    @Parameter(title: "Base Reps")
    var baseReps: Int

    @Parameter(title: "Base Weight")
    var baseWeight: Double

    @Parameter(title: "Weight Change")
    var weightChange: Double  // +5 or -5

    init() {
        self.workoutId = ""
        self.exerciseId = ""
        self.currentSets = 0
        self.baseReps = 10
        self.baseWeight = 135
        self.weightChange = 0
    }

    init(workoutId: String, exerciseId: String, currentSets: Int, reps: Int, weight: Double, weightChange: Double) {
        self.workoutId = workoutId
        self.exerciseId = exerciseId
        self.currentSets = currentSets
        self.baseReps = reps
        self.baseWeight = weight
        self.weightChange = weightChange
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        let startTime = Date()
        logger.info("⚡ AdjustWeight START: weightChange=\(weightChange)")

        // Read CURRENT values from metadata (not from stale Live Activity state)
        guard let defaults = UserDefaults(suiteName: "group.SDL-Tutorial.TheLogger") else {
            logger.error("❌ No App Group access")
            return .result()
        }

        let currentWeight = defaults.double(forKey: "liveActivityLastWeight")
        let currentReps = defaults.integer(forKey: "liveActivityLastReps")
        let setCount = defaults.integer(forKey: "liveActivitySetCount")

        // Use metadata values if available, otherwise fall back to passed values
        let actualWeight = currentWeight > 0 ? currentWeight : baseWeight
        let actualReps = currentReps > 0 ? currentReps : baseReps
        let actualSetCount = setCount > 0 ? setCount : currentSets

        let newWeight = max(0, actualWeight + weightChange)
        let timestamp = Date().timeIntervalSince1970

        logger.info("💡 Current values from metadata: weight=\(actualWeight), reps=\(actualReps)")
        logger.info("💡 New weight: \(actualWeight) → \(newWeight) (\(weightChange > 0 ? "+" : "")\(Int(weightChange)))")

        // Save new values to metadata (don't increment set count)
        defaults.set(actualSetCount, forKey: "liveActivitySetCount")  // Keep same count
        defaults.set(newWeight, forKey: "liveActivityLastWeight")
        defaults.set(actualReps, forKey: "liveActivityLastReps")
        logger.info("💾 Saved: count=\(actualSetCount), weight=\(newWeight), reps=\(actualReps)")

        // Try to update ALL active workout activities (there should only be one)
        // This is faster than signaling the main app
        let allActivities = Activity<WorkoutActivityAttributes>.activities
        logger.info("🔍 Found \(allActivities.count) activities to update")

        for activity in allActivities {
            var state = activity.content.state
            state.exerciseSets = actualSetCount
            state.lastReps = actualReps
            state.lastWeight = newWeight

            logger.info("📱 Direct update attempt for activity: \(activity.id)")

            // Try immediate update
            await activity.update(ActivityContent(state: state, staleDate: nil), alertConfiguration: nil)
            logger.info("✅ Direct update sent")
        }

        // Also signal main app as backup (for database sync)
        defaults.set(timestamp, forKey: "liveActivityLastUpdate")
        if let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.SDL-Tutorial.TheLogger") {
            let signalFile = containerURL.appendingPathComponent("update_signal.txt")
            let data = "\(actualSetCount):\(timestamp)".data(using: .utf8)
            try? data?.write(to: signalFile, options: .atomic)
        }

        let center = CFNotificationCenterGetDarwinNotifyCenter()
        CFNotificationCenterPostNotification(center, CFNotificationName(kUpdateLiveActivityNotification), nil, nil, true)

        let elapsedMs = Int(Date().timeIntervalSince(startTime) * 1000)
        logger.info("✅ AdjustWeight COMPLETE in \(elapsedMs)ms")
        return .result()
    }
}

// MARK: - Adjust Reps Intent

struct AdjustRepsIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Adjust Reps"
    static var description = IntentDescription("Log a set with adjusted reps")

    @Parameter(title: "Workout ID")
    var workoutId: String

    @Parameter(title: "Exercise ID")
    var exerciseId: String

    @Parameter(title: "Current Sets")
    var currentSets: Int

    @Parameter(title: "Base Reps")
    var baseReps: Int

    @Parameter(title: "Base Weight")
    var baseWeight: Double

    @Parameter(title: "Reps Change")
    var repsChange: Int  // +1 or -1

    init() {
        self.workoutId = ""
        self.exerciseId = ""
        self.currentSets = 0
        self.baseReps = 10
        self.baseWeight = 135
        self.repsChange = 0
    }

    init(workoutId: String, exerciseId: String, currentSets: Int, reps: Int, weight: Double, repsChange: Int) {
        self.workoutId = workoutId
        self.exerciseId = exerciseId
        self.currentSets = currentSets
        self.baseReps = reps
        self.baseWeight = weight
        self.repsChange = repsChange
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        logger.info("⚡ AdjustReps START: repsChange=\(repsChange)")

        // Read CURRENT values from metadata (not from stale Live Activity state)
        guard let defaults = UserDefaults(suiteName: "group.SDL-Tutorial.TheLogger") else {
            logger.error("❌ No App Group access")
            return .result()
        }

        let currentWeight = defaults.double(forKey: "liveActivityLastWeight")
        let currentReps = defaults.integer(forKey: "liveActivityLastReps")
        let setCount = defaults.integer(forKey: "liveActivitySetCount")

        // Use metadata values if available, otherwise fall back to passed values
        let actualWeight = currentWeight > 0 ? currentWeight : baseWeight
        let actualReps = currentReps > 0 ? currentReps : baseReps
        let actualSetCount = setCount > 0 ? setCount : currentSets

        let newReps = max(1, actualReps + repsChange)
        let timestamp = Date().timeIntervalSince1970

        logger.info("💡 Current values from metadata: weight=\(actualWeight), reps=\(actualReps)")
        logger.info("💡 New reps: \(actualReps) → \(newReps) (\(repsChange > 0 ? "+" : "")\(repsChange))")

        // Save new values to metadata (don't increment set count)
        defaults.set(actualSetCount, forKey: "liveActivitySetCount")  // Keep same count
        defaults.set(actualWeight, forKey: "liveActivityLastWeight")
        defaults.set(newReps, forKey: "liveActivityLastReps")
        logger.info("💾 Saved: count=\(actualSetCount), weight=\(actualWeight), reps=\(newReps)")

        // Try to update ALL active workout activities (there should only be one)
        // This is faster than signaling the main app
        let allActivities = Activity<WorkoutActivityAttributes>.activities
        logger.info("🔍 Found \(allActivities.count) activities to update")

        for activity in allActivities {
            var state = activity.content.state
            state.exerciseSets = actualSetCount
            state.lastReps = newReps
            state.lastWeight = actualWeight

            logger.info("📱 Direct update attempt for activity: \(activity.id)")

            // Try immediate update
            await activity.update(ActivityContent(state: state, staleDate: nil), alertConfiguration: nil)
            logger.info("✅ Direct update sent")
        }

        // Also signal main app as backup (for database sync)
        defaults.set(timestamp, forKey: "liveActivityLastUpdate")
        if let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.SDL-Tutorial.TheLogger") {
            let signalFile = containerURL.appendingPathComponent("update_signal.txt")
            let data = "\(actualSetCount):\(timestamp)".data(using: .utf8)
            try? data?.write(to: signalFile, options: .atomic)
        }

        let center = CFNotificationCenterGetDarwinNotifyCenter()
        CFNotificationCenterPostNotification(center, CFNotificationName(kUpdateLiveActivityNotification), nil, nil, true)

        logger.info("✅ AdjustReps COMPLETE")
        return .result()
    }
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
            // NOTE: Removed synchronize() - happens automatically and synchronously blocks.
            // UserDefaults writes to disk asynchronously in background, which is faster.
            logger.info("Queued \(sets.count) pending sets")
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
        // NOTE: Removed synchronize() for performance - writes happen automatically
    }
}
