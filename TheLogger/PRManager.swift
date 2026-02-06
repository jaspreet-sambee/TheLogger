//
//  PRManager.swift
//  TheLogger
//
//  Personal Record management and data queries
//

import Foundation
import SwiftData

// MARK: - PR Entry Model

/// Represents a personal record for display in timeline/charts
struct PREntry: Identifiable {
    let id = UUID()
    let exerciseName: String
    let displayName: String  // Original capitalization for display
    let weight: Double       // In lbs (storage unit)
    let reps: Int
    let date: Date
    let workoutId: UUID
    let estimated1RM: Double

    /// Relative time string ("2 days ago")
    var relativeTimeString: String {
        let calendar = Calendar.current
        let now = Date()

        let components = calendar.dateComponents([.day, .hour], from: date, to: now)

        if let days = components.day {
            if days == 0 {
                if let hours = components.hour {
                    if hours == 0 {
                        return "Just now"
                    } else if hours == 1 {
                        return "1 hour ago"
                    } else {
                        return "\(hours) hours ago"
                    }
                }
                return "Today"
            } else if days == 1 {
                return "Yesterday"
            } else if days < 7 {
                return "\(days) days ago"
            } else if days < 14 {
                return "1 week ago"
            } else if days < 30 {
                return "\(days / 7) weeks ago"
            } else if days < 60 {
                return "1 month ago"
            } else {
                return "\(days / 30) months ago"
            }
        }

        return "Recently"
    }

    /// Warning flag if PR is stale (>14 days old)
    var isStale: Bool {
        let daysSincePR = Calendar.current.dateComponents([.day], from: date, to: Date()).day ?? 0
        return daysSincePR > 14
    }
}

// MARK: - Chart Data Point

/// Represents a single data point for progress charts
struct ChartDataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let weight: Double       // In lbs
    let reps: Int
    let estimated1RM: Double
    let workoutId: UUID

    /// Formatted display string for tooltip
    var displayString: String {
        let weightStr = UnitFormatter.formatWeightCompact(weight, showUnit: true)
        return "\(weightStr) × \(reps)"
    }
}

// MARK: - PR Breakthrough

/// Represents a moment when user beat their previous PR
struct PRBreakthrough: Identifiable {
    let id = UUID()
    let date: Date
    let weight: Double       // In lbs
    let reps: Int
    let estimated1RM: Double
    let workoutId: UUID
    let improvementPercent: Double?  // nil if first PR
    let previousBest1RM: Double?     // nil if first PR
}

// MARK: - PR Manager

/// Manager for querying and caching PR data
@MainActor
class PRManager {
    static let shared = PRManager()

    // Cache
    private var cachedPRs: [PREntry] = []
    private var cachedExerciseHistory: [String: [ChartDataPoint]] = [:]
    private var lastCacheUpdate: Date = .distantPast
    private let cacheValidityDuration: TimeInterval = 300  // 5 minutes

    private init() {}

    // MARK: - Public API

    /// Get all PRs (one per exercise), sorted by date
    func getPRTimeline(modelContext: ModelContext, forceRefresh: Bool = false) -> [PREntry] {
        // Return cached if valid
        if !forceRefresh && isCacheValid() {
            return cachedPRs
        }

        // Recompute from workouts
        cachedPRs = computePRsFromWorkouts(modelContext: modelContext)
        lastCacheUpdate = Date()

        return cachedPRs
    }

    /// Get full history for a specific exercise (for charts)
    func getExerciseHistory(exerciseName: String, modelContext: ModelContext, forceRefresh: Bool = false) -> [ChartDataPoint] {
        let normalizedName = exerciseName.lowercased().trimmingCharacters(in: .whitespaces)

        // Return cached if valid
        if !forceRefresh, isCacheValid(), let cached = cachedExerciseHistory[normalizedName] {
            return cached
        }

        // Compute from workouts
        let history = computeExerciseHistory(exerciseName: exerciseName, modelContext: modelContext)
        cachedExerciseHistory[normalizedName] = history

        return history
    }

    /// Get PR breakthroughs for a specific exercise (moments when PR was beaten)
    func getPRBreakthroughs(exerciseName: String, modelContext: ModelContext) -> [PRBreakthrough] {
        let history = getExerciseHistory(exerciseName: exerciseName, modelContext: modelContext)

        guard !history.isEmpty else { return [] }

        var breakthroughs: [PRBreakthrough] = []
        var currentBest1RM: Double = 0

        // Sort chronologically (oldest first)
        let sortedHistory = history.sorted(by: { $0.date < $1.date })

        for point in sortedHistory {
            if point.estimated1RM > currentBest1RM {
                // This is a PR breakthrough!
                let improvementPercent: Double?
                let previousBest: Double?

                if currentBest1RM > 0 {
                    improvementPercent = ((point.estimated1RM - currentBest1RM) / currentBest1RM) * 100
                    previousBest = currentBest1RM
                } else {
                    // First PR
                    improvementPercent = nil
                    previousBest = nil
                }

                breakthroughs.append(PRBreakthrough(
                    date: point.date,
                    weight: point.weight,
                    reps: point.reps,
                    estimated1RM: point.estimated1RM,
                    workoutId: point.workoutId,
                    improvementPercent: improvementPercent,
                    previousBest1RM: previousBest
                ))

                currentBest1RM = point.estimated1RM
            }
        }

        // Return in reverse chronological order (most recent first)
        return breakthroughs.reversed()
    }

    /// Invalidate cache (call after new workout)
    func invalidateCache() {
        lastCacheUpdate = .distantPast
        cachedPRs = []
        cachedExerciseHistory = [:]
    }

    // MARK: - Private Helpers

    private func isCacheValid() -> Bool {
        return Date().timeIntervalSince(lastCacheUpdate) < cacheValidityDuration
    }

    /// Compute PRs by querying all workouts
    private func computePRsFromWorkouts(modelContext: ModelContext) -> [PREntry] {
        // Fetch all completed workouts
        let descriptor = FetchDescriptor<Workout>(
            predicate: #Predicate { !$0.isTemplate && $0.endTime != nil },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )

        guard let workouts = try? modelContext.fetch(descriptor) else {
            return []
        }

        // Build exercise history: [exerciseName: [(date, weight, reps, workoutId)]]
        var exerciseHistory: [String: [(date: Date, weight: Double, reps: Int, workoutId: UUID, displayName: String)]] = [:]

        for workout in workouts {
            guard let exercises = workout.exercises else { continue }

            for exercise in exercises {
                let normalizedName = exercise.name.lowercased().trimmingCharacters(in: .whitespaces)

                guard let sets = exercise.sets else { continue }

                for set in sets {
                    // Only consider working sets for PRs
                    guard set.type == .working && set.weight > 0 && set.reps > 0 else {
                        continue
                    }

                    if exerciseHistory[normalizedName] == nil {
                        exerciseHistory[normalizedName] = []
                    }

                    exerciseHistory[normalizedName]?.append((
                        date: workout.date,
                        weight: set.weight,
                        reps: set.reps,
                        workoutId: workout.id,
                        displayName: exercise.name  // Keep original capitalization
                    ))
                }
            }
        }

        // For each exercise, find the best set (by 1RM)
        var prEntries: [PREntry] = []

        for (normalizedName, sets) in exerciseHistory {
            // Calculate 1RM for each set
            let setsWithRM = sets.map { set in
                let rm = calculateEstimated1RM(weight: set.weight, reps: set.reps)
                return (set: set, rm: rm)
            }

            // Find max 1RM
            guard let best = setsWithRM.max(by: { $0.rm < $1.rm }) else {
                continue
            }

            prEntries.append(PREntry(
                exerciseName: normalizedName,
                displayName: best.set.displayName,
                weight: best.set.weight,
                reps: best.set.reps,
                date: best.set.date,
                workoutId: best.set.workoutId,
                estimated1RM: best.rm
            ))
        }

        // Sort by date (most recent first)
        return prEntries.sorted { $0.date > $1.date }
    }

    /// Compute full history for a specific exercise (for charts)
    private func computeExerciseHistory(exerciseName: String, modelContext: ModelContext) -> [ChartDataPoint] {
        let normalizedName = exerciseName.lowercased().trimmingCharacters(in: .whitespaces)

        // Fetch all completed workouts
        let descriptor = FetchDescriptor<Workout>(
            predicate: #Predicate { !$0.isTemplate && $0.endTime != nil },
            sortBy: [SortDescriptor(\.date, order: .forward)]  // Oldest first for charts
        )

        guard let workouts = try? modelContext.fetch(descriptor) else {
            return []
        }

        var dataPoints: [ChartDataPoint] = []

        for workout in workouts {
            guard let exercises = workout.exercises else { continue }

            // Find this exercise in the workout
            for exercise in exercises {
                let exerciseNormalizedName = exercise.name.lowercased().trimmingCharacters(in: .whitespaces)

                guard exerciseNormalizedName == normalizedName else { continue }
                guard let sets = exercise.sets else { continue }

                // Find the best set (by 1RM) in this workout
                let workingSets = sets.filter { $0.type == .working && $0.weight > 0 && $0.reps > 0 }

                guard !workingSets.isEmpty else { continue }

                let bestSet = workingSets.max(by: { set1, set2 in
                    let rm1 = calculateEstimated1RM(weight: set1.weight, reps: set1.reps)
                    let rm2 = calculateEstimated1RM(weight: set2.weight, reps: set2.reps)
                    return rm1 < rm2
                })

                if let best = bestSet {
                    let rm = calculateEstimated1RM(weight: best.weight, reps: best.reps)

                    dataPoints.append(ChartDataPoint(
                        date: workout.date,
                        weight: best.weight,
                        reps: best.reps,
                        estimated1RM: rm,
                        workoutId: workout.id
                    ))
                }
            }
        }

        return dataPoints
    }

    /// Calculate estimated 1RM using Brzycki formula
    private func calculateEstimated1RM(weight: Double, reps: Int) -> Double {
        guard reps > 0 && reps <= 10 else { return weight }
        return weight * (36.0 / (37.0 - Double(reps)))
    }
}

// MARK: - Filter Options

enum PRFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case push = "Push"
    case pull = "Pull"
    case legs = "Legs"
    case core = "Core"

    var id: String { rawValue }

    /// Filter PRs by muscle group
    func filter(_ prs: [PREntry]) -> [PREntry] {
        switch self {
        case .all:
            return prs
        case .push:
            return prs.filter { exerciseMatchesPush($0.exerciseName) }
        case .pull:
            return prs.filter { exerciseMatchesPull($0.exerciseName) }
        case .legs:
            return prs.filter { exerciseMatchesLegs($0.exerciseName) }
        case .core:
            return prs.filter { exerciseMatchesCore($0.exerciseName) }
        }
    }

    private func exerciseMatchesPush(_ name: String) -> Bool {
        let pushKeywords = ["bench", "press", "chest", "shoulder", "dip", "tricep", "fly", "flye", "pushup", "push-up"]
        return pushKeywords.contains { name.contains($0) }
    }

    private func exerciseMatchesPull(_ name: String) -> Bool {
        let pullKeywords = ["row", "pull", "lat", "back", "bicep", "curl", "chin", "deadlift"]
        return pullKeywords.contains { name.contains($0) }
    }

    private func exerciseMatchesLegs(_ name: String) -> Bool {
        let legKeywords = ["squat", "leg", "quad", "hamstring", "calf", "lunge", "glute"]
        return legKeywords.contains { name.contains($0) }
    }

    private func exerciseMatchesCore(_ name: String) -> Bool {
        let coreKeywords = ["ab", "core", "plank", "crunch", "sit-up", "situp"]
        return coreKeywords.contains { name.contains($0) }
    }
}

// MARK: - Sort Options

enum PRSort: String, CaseIterable, Identifiable {
    case recent = "Most Recent"
    case oldest = "Oldest"
    case highest1RM = "Highest 1RM"
    case lowest1RM = "Lowest 1RM"
    case alphabetical = "A-Z"
    case reverseAlphabetical = "Z-A"

    var id: String { rawValue }

    /// Sort PRs
    func sort(_ prs: [PREntry]) -> [PREntry] {
        switch self {
        case .recent:
            return prs.sorted { $0.date > $1.date }
        case .oldest:
            return prs.sorted { $0.date < $1.date }
        case .highest1RM:
            return prs.sorted { $0.estimated1RM > $1.estimated1RM }
        case .lowest1RM:
            return prs.sorted { $0.estimated1RM < $1.estimated1RM }
        case .alphabetical:
            return prs.sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
        case .reverseAlphabetical:
            return prs.sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedDescending }
        }
    }
}

// MARK: - Time Range for Charts

enum TimeRange: String, CaseIterable, Identifiable {
    case threeMonths = "3 Months"
    case sixMonths = "6 Months"
    case oneYear = "1 Year"
    case allTime = "All Time"

    var id: String { rawValue }

    /// Get start date for filtering (nil = all time)
    var startDate: Date? {
        let calendar = Calendar.current
        let now = Date()

        switch self {
        case .threeMonths:
            return calendar.date(byAdding: .month, value: -3, to: now)
        case .sixMonths:
            return calendar.date(byAdding: .month, value: -6, to: now)
        case .oneYear:
            return calendar.date(byAdding: .year, value: -1, to: now)
        case .allTime:
            return nil
        }
    }

    /// Filter chart data points by time range
    func filter(_ dataPoints: [ChartDataPoint]) -> [ChartDataPoint] {
        guard let startDate = startDate else {
            return dataPoints  // All time
        }

        return dataPoints.filter { $0.date >= startDate }
    }
}
