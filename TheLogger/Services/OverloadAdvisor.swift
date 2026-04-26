//
//  OverloadAdvisor.swift
//  TheLogger
//
//  Detects when a user is ready to increase weight and surfaces a suggestion.
//  Only fires when signal is clear: same weight hit for 2+ consecutive sessions.
//  Suppressed per-exercise for 7 days after showing.
//

import Foundation
import SwiftData

// MARK: - Suggestion Model

struct OverloadSuggestion {
    let exerciseName: String
    let currentWeight: Double   // lbs (internal unit)
    let suggestedWeight: Double // lbs
    let reps: Int               // reps they've been consistently hitting
    let sessionCount: Int       // how many sessions they hit this (2 or 3)
}

// MARK: - Overload Advisor

struct OverloadAdvisor {

    // MARK: - Public API

    /// Returns a suggestion if the user is ready to increase weight for this exercise.
    /// Returns nil if conditions aren't met or the tip was shown recently.
    static func suggestion(for exerciseName: String, modelContext: ModelContext) -> OverloadSuggestion? {
        let name = exerciseName.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        // Check 7-day suppression first (cheap check before fetching data)
        guard !wasShownRecently(for: name) else { return nil }

        // Fetch last 5 completed workouts containing this exercise, most recent first
        let descriptor = FetchDescriptor<Workout>(
            predicate: #Predicate<Workout> { $0.isTemplate == false },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        guard let allWorkouts = try? modelContext.fetch(descriptor) else { return nil }

        let completed = allWorkouts.filter { $0.isCompleted }

        // Filter to workouts that contain this exercise, limit to last 5
        let relevantWorkouts = completed
            .filter { workout in
                workout.exercises?.contains { $0.name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) == name } == true
            }
            .prefix(5)

        // Need at least 3 sessions of history
        guard relevantWorkouts.count >= 3 else { return nil }

        // Must have trained within last 3 weeks (stale data = bad advice)
        if let mostRecent = relevantWorkouts.first?.date {
            let daysSince = Calendar.current.dateComponents([.day], from: mostRecent, to: Date()).day ?? 0
            guard daysSince <= 21 else { return nil }
        }

        // Extract best working set per session (highest weight among sets that count for PR)
        let sessionBests: [(weight: Double, reps: Int)] = relevantWorkouts.compactMap { workout in
            guard let exercise = workout.exercises?.first(where: {
                $0.name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) == name
            }) else { return nil }

            let workingSets = (exercise.sets ?? []).filter { set in
                guard let type = SetType(rawValue: set.setType) else { return false }
                return type.countsForPR && set.weight > 0 && set.reps > 0
            }

            // Best set = highest 1RM estimate
            guard let best = workingSets.max(by: {
                $0.weight * (1 + Double($0.reps) / 30.0) < $1.weight * (1 + Double($1.reps) / 30.0)
            }) else { return nil }

            return (weight: best.weight, reps: best.reps)
        }

        guard sessionBests.count >= 3 else { return nil }

        // Check: last 2 sessions used the same weight
        let s0 = sessionBests[0] // most recent
        let s1 = sessionBests[1] // one before

        guard s0.weight == s1.weight else { return nil }

        // Skip bodyweight (weight == 0) — can't suggest "add weight" here
        guard s0.weight > 0 else { return nil }

        // Both sessions must have hit at least the same reps (not regressing)
        guard s0.reps >= s1.reps else { return nil }

        // Suggested weight: standard +5 lbs increment
        let suggested = s0.weight + 5.0

        // Don't suggest if the user has already done this weight or higher in any recent session
        // (they may have tried it, backed off, and we'd be re-suggesting something they already crossed)
        let maxRecentWeight = sessionBests.map(\.weight).max() ?? 0
        guard suggested > maxRecentWeight else { return nil }

        // Count how many consecutive sessions they hit this weight
        let consecutiveCount = sessionBests.prefix(3).filter { $0.weight == s0.weight }.count

        return OverloadSuggestion(
            exerciseName: exerciseName,
            currentWeight: s0.weight,
            suggestedWeight: suggested,
            reps: s0.reps,
            sessionCount: consecutiveCount
        )
    }

    // MARK: - Suppression

    /// Record that a tip was shown for this exercise (starts 7-day cooldown).
    static func markShown(for exerciseName: String) {
        let name = exerciseName.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        var shown = loadShownDates()
        shown[name] = Date()
        saveShownDates(shown)
    }

    private static func wasShownRecently(for normalizedName: String) -> Bool {
        let shown = loadShownDates()
        guard let lastShown = shown[normalizedName] else { return false }
        let days = Calendar.current.dateComponents([.day], from: lastShown, to: Date()).day ?? 0
        return days < 7
    }

    private static let shownDatesKey = "overloadAdvisorShownDates"

    private static func loadShownDates() -> [String: Date] {
        guard let data = UserDefaults.standard.data(forKey: shownDatesKey),
              let decoded = try? JSONDecoder().decode([String: Date].self, from: data)
        else { return [:] }
        return decoded
    }

    private static func saveShownDates(_ dates: [String: Date]) {
        if let data = try? JSONEncoder().encode(dates) {
            UserDefaults.standard.set(data, forKey: shownDatesKey)
        }
    }
}
