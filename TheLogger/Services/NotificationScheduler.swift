//
//  NotificationScheduler.swift
//  TheLogger
//
//  Smart push notification scheduling: max 1/day, priority-based.
//  See project memory project_notifications.md for full design.
//

import Foundation
import UserNotifications
import SwiftData

// MARK: - Near Miss PR Storage

struct NearMissPR: Codable {
    let exerciseName: String
    let missedByLbs: Double   // always stored in lbs (internal unit)
    let date: Date
}

// MARK: - Notification Scheduler

final class NotificationScheduler {
    static let shared = NotificationScheduler()
    private init() {}

    // MARK: - UserDefaults Keys

    private let lastScheduledKey  = "notifLastScheduledDate"
    private let nearMissPRKey     = "lastNearMissPR"
    private let installDateKey    = "appInstallDate"

    // MARK: - Permission

    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            if granted {
                UserDefaults.standard.set(true, forKey: "notificationsEnabled")
            }
        }
    }

    // MARK: - First Launch Setup

    /// Call once on app launch to record install date (for new-user suppression).
    func recordInstallDateIfNeeded() {
        if UserDefaults.standard.object(forKey: installDateKey) == nil {
            UserDefaults.standard.set(Date(), forKey: installDateKey)
        }
    }

    // MARK: - Workout End Hook

    /// Call when a workout ends to store near-miss PR data for tomorrow's notification.
    /// - Parameters:
    ///   - workout: The completed workout
    ///   - prExercises: Names of exercises that actually hit a new PR this session (skip these)
    ///   - modelContext: Model context to fetch existing PRs
    func onWorkoutEnded(workout: Workout, prExercises: [String], modelContext: ModelContext) {
        guard let exercises = workout.exercises else {
            UserDefaults.standard.removeObject(forKey: nearMissPRKey)
            return
        }

        var bestMiss: NearMissPR? = nil

        for exercise in exercises {
            // Skip exercises that already set a new PR this session
            let normalizedName = exercise.name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            if prExercises.map({ $0.lowercased() }).contains(normalizedName) { continue }

            guard let sets = exercise.sets, !sets.isEmpty else { continue }

            // Fetch existing PR for this exercise
            let descriptor = FetchDescriptor<PersonalRecord>(
                predicate: #Predicate { $0.exerciseName == normalizedName }
            )
            guard let pr = try? modelContext.fetch(descriptor).first,
                  !pr.isBodyweight, pr.weight > 0, pr.estimated1RM > 0 else { continue }

            // Find best 1RM from qualifying sets in this session
            let best1RM = sets.compactMap { set -> Double? in
                guard let type = SetType(rawValue: set.setType), type.countsForPR,
                      set.weight > 0, set.reps > 0 else { return nil }
                return set.weight * (1.0 + Double(set.reps) / 30.0)
            }.max() ?? 0

            guard best1RM > 0 else { continue }

            let diff = pr.estimated1RM - best1RM

            // Within 5 lbs of PR (in lbs — internal unit) but didn't beat it
            if diff > 0 && diff <= 5 {
                if bestMiss == nil || diff < bestMiss!.missedByLbs {
                    bestMiss = NearMissPR(
                        exerciseName: exercise.name,
                        missedByLbs: diff,
                        date: Date()
                    )
                }
            }
        }

        if let miss = bestMiss, let data = try? JSONEncoder().encode(miss) {
            UserDefaults.standard.set(data, forKey: nearMissPRKey)
        } else {
            UserDefaults.standard.removeObject(forKey: nearMissPRKey)
        }
    }

    // MARK: - Daily Scheduling (call on app active, once per day)

    func scheduleIfNeeded(modelContext: ModelContext) {
        // Master toggle (defaults to false until permission granted)
        guard isEnabled("notificationsEnabled") else { return }

        let calendar = Calendar.current

        // Only run once per day
        if let lastDate = UserDefaults.standard.object(forKey: lastScheduledKey) as? Date,
           calendar.isDateInToday(lastDate) { return }

        // New user check: suppress for first 3 days
        if let installDate = UserDefaults.standard.object(forKey: installDateKey) as? Date {
            let daysSince = calendar.dateComponents([.day], from: installDate, to: Date()).day ?? 0
            if daysSince < 3 { return }
        }

        // Fetch completed workouts (non-template)
        let descriptor = FetchDescriptor<Workout>(
            predicate: #Predicate { $0.isTemplate == false }
        )
        guard let allWorkouts = try? modelContext.fetch(descriptor) else { return }
        let completed = allWorkouts.filter { $0.isCompleted }

        // Mark as scheduled today (do this early to prevent double-scheduling)
        UserDefaults.standard.set(Date(), forKey: lastScheduledKey)

        // Cancel any existing pending notifications
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()

        let today = calendar.startOfDay(for: Date())
        let hasWorkedOutToday = completed.contains { calendar.isDateInToday($0.date) }

        // --- Sunday: Weekly recap (exempt from daily budget) ---
        let weekday = calendar.component(.weekday, from: Date())
        if weekday == 1 && isEnabled("notifRecapEnabled") { // Sunday = 1
            let thisWeekWorkouts = completed.filter {
                guard let interval = calendar.dateInterval(of: .weekOfYear, for: Date()) else { return false }
                return interval.contains($0.date)
            }
            if !thisWeekWorkouts.isEmpty {
                // Count PRs set this week
                let prDescriptor = FetchDescriptor<PersonalRecord>()
                let allPRs = (try? modelContext.fetch(prDescriptor)) ?? []
                let weekPRCount = allPRs.filter {
                    guard let interval = calendar.dateInterval(of: .weekOfYear, for: Date()) else { return false }
                    return interval.contains($0.date)
                }.count
                scheduleWeeklyRecap(workouts: thisWeekWorkouts, prCount: weekPRCount)
                return // No other notification on recap Sunday
            }
        }

        // Already worked out today → nothing needed
        if hasWorkedOutToday { return }

        // --- Priority 1: Streak at risk ---
        if isEnabled("notifStreakEnabled") {
            let engine = GamificationEngine()
            let goal = max(1, UserDefaults.standard.integer(forKey: "weeklyWorkoutGoal") > 0
                          ? UserDefaults.standard.integer(forKey: "weeklyWorkoutGoal") : 4)
            let streakData = engine.computeStreakData(from: completed, weeklyGoal: goal)
            if streakData.current >= 3 {
                scheduleStreakAtRisk(streak: streakData.current)
                return
            }
        }

        // --- Priority 2: PR proximity (from yesterday's session) ---
        if isEnabled("notifPREnabled"),
           let data = UserDefaults.standard.data(forKey: nearMissPRKey),
           let miss = try? JSONDecoder().decode(NearMissPR.self, from: data),
           calendar.isDateInYesterday(miss.date) {
            schedulePRProximity(miss: miss)
            return
        }

        // --- Priority 3: Comeback (5+ day gap) ---
        if isEnabled("notifComebackEnabled"),
           let lastWorkout = completed.sorted(by: { $0.date > $1.date }).first {
            let days = calendar.dateComponents(
                [.day],
                from: calendar.startOfDay(for: lastWorkout.date),
                to: today
            ).day ?? 0
            if days >= 5 {
                scheduleComeback(daysSince: days)
                return
            }
        }

        // --- Priority 4: Muscle neglect ---
        if isEnabled("notifNeglectEnabled"),
           let neglect = findNeglectedMuscle(from: completed, today: today, calendar: calendar) {
            scheduleMuscleNeglect(group: neglect.group, daysSince: neglect.days)
            return
        }

        // --- Priority 5: Rest day challenge (fallback) ---
        if isEnabled("notifChallengeEnabled") {
            scheduleRestDayChallenge()
        }
    }

    // MARK: - Individual Notification Builders

    private func scheduleStreakAtRisk(streak: Int) {
        let name = userName
        let variants: [(title: String, body: String)] = [
            (
                "\(streak) days. Don't let up now 🔥",
                "You're \(streak) days in. Log a quick session or do today's rest day challenge to keep it alive."
            ),
            (
                "\(streak)-day streak on the line 🔥",
                name.isEmpty
                    ? "\(streak) days straight. Tonight's the night you almost quit. Don't."
                    : "Hey \(name), \(streak) days straight. Don't let tonight be the one that breaks it."
            ),
            (
                "Don't end it here 🔥",
                name.isEmpty
                    ? "\(streak)-day streak. Log a workout before midnight or do the rest day challenge."
                    : "\(name), your \(streak)-day streak ends at midnight. Don't let it."
            ),
        ]
        let v = pick(variants)
        let content = UNMutableNotificationContent()
        content.title = v.title
        content.body = v.body
        content.sound = .default
        schedule(content: content, identifier: "streak-at-risk", hour: 19, minute: 0)
    }

    private func schedulePRProximity(miss: NearMissPR) {
        let unitSystem = UnitSystem(rawValue: UserDefaults.standard.string(forKey: "unitSystem") ?? "Imperial") ?? .imperial
        let displayValue = unitSystem == .imperial ? miss.missedByLbs : miss.missedByLbs * 0.453592
        let n = String(format: "%.1f", displayValue)
        let unit = unitSystem.weightUnit
        let exercise = miss.exerciseName.capitalized
        let name = userName
        let variants: [(title: String, body: String)] = [
            (
                "\(exercise) PR: \(n) \(unit) away 💪",
                "That's it. \(n) \(unit) between you and a new record. Come get it."
            ),
            (
                "\(n) \(unit). That's all. 💪",
                name.isEmpty
                    ? "\(n) \(unit) stood between you and a \(exercise) PR yesterday. One more session."
                    : "\(name), \(n) \(unit) stood between you and a \(exercise) PR. One more session."
            ),
            (
                "So close on \(exercise) 💪",
                name.isEmpty
                    ? "Your \(exercise) PR is right there. \(n) \(unit) away."
                    : "Hey \(name), your \(exercise) PR is right there. Just \(n) \(unit) away."
            ),
        ]
        let v = pick(variants)
        let content = UNMutableNotificationContent()
        content.title = v.title
        content.body = v.body
        content.sound = .default
        schedule(content: content, identifier: "pr-proximity", hour: 9, minute: 0)
    }

    private func scheduleComeback(daysSince: Int) {
        let name = userName
        let variants: [(title: String, body: String)] = [
            (
                "The bar misses you 🏋️",
                "\(daysSince) days off. No pressure — even a short session counts."
            ),
            (
                "Still here when you're ready 💪",
                name.isEmpty
                    ? "It's been \(daysSince) days. Whenever you're ready, we're ready."
                    : "Hey \(name), it's been \(daysSince) days. Whenever you're ready."
            ),
            (
                "\(daysSince) days. Time to get back. 💪",
                name.isEmpty
                    ? "\(daysSince) days is a long time. Even a quick session gets the momentum back."
                    : "\(name), \(daysSince) days is a long time. Even a 20-minute session gets it back."
            ),
        ]
        let v = pick(variants)
        let content = UNMutableNotificationContent()
        content.title = v.title
        content.body = v.body
        content.sound = .default
        schedule(content: content, identifier: "comeback", hour: 9, minute: 0)
    }

    private func scheduleMuscleNeglect(group: MuscleGroup, daysSince: Int) {
        let name = userName
        let g = group.rawValue
        let gl = g.lowercased()
        let variants: [(title: String, body: String)] = [
            (
                "Your \(gl) called 😅",
                "They feel forgotten. \(daysSince) days since your last \(gl) session."
            ),
            (
                "\(g) day is \(daysSince) days overdue",
                name.isEmpty
                    ? "Your future self is not happy. Fix it today."
                    : "\(name), your future self is not happy. Fix it today."
            ),
            (
                "\(daysSince) days, no \(gl) 👀",
                name.isEmpty
                    ? "\(g) hasn't been touched in \(daysSince) days. Just saying."
                    : "Hey \(name), \(gl) hasn't been touched in \(daysSince) days. Just saying."
            ),
        ]
        let v = pick(variants)
        let content = UNMutableNotificationContent()
        content.title = v.title
        content.body = v.body
        content.sound = .default
        schedule(content: content, identifier: "muscle-neglect", hour: 9, minute: 0)
    }

    private func scheduleRestDayChallenge() {
        let name = userName
        let variants: [(title: String, body: String)] = [
            (
                "Rest day. Streak day. ✅",
                "Rest day doesn't mean streak day is off. Today's challenge takes 2 minutes."
            ),
            (
                "Keep the streak alive ✅",
                name.isEmpty
                    ? "No gym needed. Today's rest day challenge keeps your streak going — 2 minutes."
                    : "Hey \(name), no gym needed. Today's challenge keeps your streak alive — 2 minutes."
            ),
            (
                "Active recovery counts ✅",
                "2 minutes. That's all today's challenge takes. Streak stays alive."
            ),
        ]
        let v = pick(variants)
        let content = UNMutableNotificationContent()
        content.title = v.title
        content.body = v.body
        content.sound = .default
        schedule(content: content, identifier: "rest-day-challenge", hour: 14, minute: 0)
    }

    private func scheduleWeeklyRecap(workouts: [Workout], prCount: Int) {
        let count = workouts.count
        let totalVolume = workouts.reduce(0.0) { $0 + WorkoutSummary(workout: $1).totalVolume }
        let unitSystem = UnitSystem(rawValue: UserDefaults.standard.string(forKey: "unitSystem") ?? "Imperial") ?? .imperial
        let displayVolume = unitSystem == .imperial ? totalVolume : totalVolume * 0.453592
        let formatted = displayVolume >= 1000
            ? String(format: "%.1fk", displayVolume / 1000)
            : String(format: "%.0f", displayVolume)
        let unit = unitSystem.weightUnit
        let prText = prCount > 0 ? ", \(prCount) PR\(prCount == 1 ? "" : "s")" : ""
        let name = userName

        let variants: [(title: String, body: String)] = [
            (
                "Week closed 🏆",
                "\(count) workout\(count == 1 ? "" : "s"). \(formatted) \(unit)\(prText). That's your week."
            ),
            (
                "That was a solid week 🏆",
                name.isEmpty
                    ? "\(count) sessions, \(formatted) \(unit) lifted\(prText). Keep building."
                    : "Hey \(name), \(count) sessions, \(formatted) \(unit) lifted\(prText). Keep building."
            ),
            (
                "\(count) workouts. \(formatted) \(unit). 🏆",
                name.isEmpty
                    ? "\(prCount > 0 ? "\(prCount) PR\(prCount == 1 ? "" : "s") this week. " : "")Solid work. See you next week."
                    : "\(prCount > 0 ? "\(prCount) PR\(prCount == 1 ? "" : "s") this week. " : "")Solid work \(name). See you next week."
            ),
        ]
        let v = pick(variants)
        let content = UNMutableNotificationContent()
        content.title = v.title
        content.body = v.body
        content.sound = .default
        schedule(content: content, identifier: "weekly-recap", hour: 19, minute: 0)
    }

    // MARK: - Scheduling Helper

    private func schedule(content: UNMutableNotificationContent, identifier: String, hour: Int, minute: Int) {
        #if DEBUG
        if debugMode {
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
            let request = UNNotificationRequest(identifier: identifier + "-debug", content: content, trigger: trigger)
            UNUserNotificationCenter.current().add(request)
            return
        }
        #endif
        var components = DateComponents()
        components.hour = hour
        components.minute = minute
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Muscle Neglect Calculation

    private struct NeglectedMuscle {
        let group: MuscleGroup
        let days: Int
    }

    private func findNeglectedMuscle(from workouts: [Workout], today: Date, calendar: Calendar) -> NeglectedMuscle? {
        // Primary groups: train every 10 days; secondary: every 14 days
        let primaryGroups: Set<MuscleGroup> = [.chest, .back, .legs, .shoulders]

        var lastTrained: [MuscleGroup: Date] = [:]

        for workout in workouts {
            for exercise in workout.exercises ?? [] {
                guard let lib = ExerciseLibrary.shared.find(name: exercise.name) else { continue }
                let day = calendar.startOfDay(for: workout.date)
                if let existing = lastTrained[lib.muscleGroup] {
                    if day > existing { lastTrained[lib.muscleGroup] = day }
                } else {
                    lastTrained[lib.muscleGroup] = day
                }
            }
        }

        var mostNeglected: NeglectedMuscle? = nil

        for group in MuscleGroup.allCases {
            let threshold = primaryGroups.contains(group) ? 10 : 14
            if let last = lastTrained[group] {
                let days = calendar.dateComponents([.day], from: last, to: today).day ?? 0
                if days >= threshold {
                    if mostNeglected == nil || days > mostNeglected!.days {
                        mostNeglected = NeglectedMuscle(group: group, days: days)
                    }
                }
            }
        }

        return mostNeglected
    }

    // MARK: - Debug Firing (bypasses daily schedule guard, calls real builders)

    #if DEBUG
    func debugFire(_ type: DebugNotifType) {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        debugMode = true
        switch type {
        case .streakAtRisk:
            scheduleStreakAtRisk(streak: 7)
        case .prProximity:
            let miss = NearMissPR(exerciseName: "Bench Press", missedByLbs: 3.0, date: Date())
            schedulePRProximity(miss: miss)
        case .comeback:
            scheduleComeback(daysSince: 6)
        case .muscleNeglect:
            scheduleMuscleNeglect(group: .legs, daysSince: 12)
        case .restDayChallenge:
            scheduleRestDayChallenge()
        case .weeklyRecap:
            scheduleWeeklyRecapDebug(workoutCount: 4, volumeLbs: 15200, prCount: 2)
        }
        debugMode = false
    }

    // When true, `schedule` fires in 5 seconds instead of at a fixed time
    private var debugMode = false

    enum DebugNotifType {
        case streakAtRisk, prProximity, comeback, muscleNeglect, restDayChallenge, weeklyRecap
    }

    private func scheduleWeeklyRecapDebug(workoutCount: Int, volumeLbs: Double, prCount: Int) {
        let unitSystem = UnitSystem(rawValue: UserDefaults.standard.string(forKey: "unitSystem") ?? "Imperial") ?? .imperial
        let displayVolume = unitSystem == .imperial ? volumeLbs : volumeLbs * 0.453592
        let formatted = displayVolume >= 1000
            ? String(format: "%.1fk", displayVolume / 1000)
            : String(format: "%.0f", displayVolume)
        let unit = unitSystem.weightUnit
        let prText = prCount > 0 ? ", \(prCount) PR\(prCount == 1 ? "" : "s")" : ""
        let name = userName

        let variants: [(title: String, body: String)] = [
            (
                "Week closed 🏆",
                "\(workoutCount) workout\(workoutCount == 1 ? "" : "s"). \(formatted) \(unit)\(prText). That's your week."
            ),
            (
                "That was a solid week 🏆",
                name.isEmpty
                    ? "\(workoutCount) sessions, \(formatted) \(unit) lifted\(prText). Keep building."
                    : "Hey \(name), \(workoutCount) sessions, \(formatted) \(unit) lifted\(prText). Keep building."
            ),
            (
                "\(workoutCount) workouts. \(formatted) \(unit). 🏆",
                name.isEmpty
                    ? "\(prCount > 0 ? "\(prCount) PR\(prCount == 1 ? "" : "s") this week. " : "")Solid work. See you next week."
                    : "\(prCount > 0 ? "\(prCount) PR\(prCount == 1 ? "" : "s") this week. " : "")Solid work \(name). See you next week."
            ),
        ]
        let v = pick(variants)
        let content = UNMutableNotificationContent()
        content.title = v.title
        content.body = v.body
        content.sound = .default
        schedule(content: content, identifier: "weekly-recap-debug", hour: 0, minute: 0)
    }
    #endif  // end DEBUG block

    // MARK: - Helpers

    /// Returns true if the key is unset (defaults to enabled) or explicitly set to true.
    private func isEnabled(_ key: String) -> Bool {
        guard UserDefaults.standard.object(forKey: key) != nil else { return true }
        return UserDefaults.standard.bool(forKey: key)
    }

    /// User's display name from settings (empty string if not set).
    private var userName: String {
        UserDefaults.standard.string(forKey: "userName")?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    /// Pick a random element from an array.
    private func pick<T>(_ variants: [T]) -> T {
        variants[Int.random(in: 0..<variants.count)]
    }
}
