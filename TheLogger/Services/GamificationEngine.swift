//
//  GamificationEngine.swift
//  TheLogger
//
//  Computes dashboard stats from workout data: weekly stats, streaks, volume trends, muscle breakdown
//

import Foundation
import SwiftData

// MARK: - Data Types

struct WeeklyStats {
    let totalVolume: Double        // lbs (internal unit)
    let totalSets: Int
    let totalReps: Int
    let totalDurationMinutes: Int
    let workoutCount: Int
    let muscleBreakdown: [MuscleGroup: Int]  // muscle group -> set count

    // Week-over-week deltas (positive = improvement)
    let volumeDelta: Double?       // percentage change
    let setsDelta: Int?
    let repsDelta: Int?
    let workoutCountDelta: Int?

    static let empty = WeeklyStats(
        totalVolume: 0, totalSets: 0, totalReps: 0,
        totalDurationMinutes: 0, workoutCount: 0,
        muscleBreakdown: [:],
        volumeDelta: nil, setsDelta: nil, repsDelta: nil, workoutCountDelta: nil
    )
}

struct StreakData {
    let current: Int
    let bestEver: Int
    let weeklyGoalStreak: Int      // consecutive weeks hitting goal
    let workoutDays: [Date: Int]   // date -> workout count (for heatmap)

    static let empty = StreakData(current: 0, bestEver: 0, weeklyGoalStreak: 0, workoutDays: [:])
}

struct VolumeTrendPoint: Identifiable {
    let id = UUID()
    let weekStart: Date
    let volume: Double
}

// MARK: - GamificationEngine

@Observable
nonisolated final class GamificationEngine {
    var weeklyStats: WeeklyStats = .empty
    var streakData: StreakData = .empty
    var volumeTrend: [VolumeTrendPoint] = []
    var thisWeekPRCount: Int = 0

    func refresh(workouts: [Workout], prs: [PersonalRecord], weeklyGoal: Int = 4) {
        let completed = workouts.filter { $0.isCompleted && !$0.isTemplate }
        weeklyStats = computeWeeklyStats(from: completed)
        streakData = computeStreakData(from: completed, weeklyGoal: weeklyGoal)
        volumeTrend = computeVolumeTrend(from: completed, weeks: 8)
        thisWeekPRCount = computeThisWeekPRCount(from: prs)
    }

    // MARK: - Weekly Stats

    func computeWeeklyStats(from workouts: [Workout]) -> WeeklyStats {
        let calendar = Calendar.current
        guard let thisWeekInterval = calendar.dateInterval(of: .weekOfYear, for: Date()) else {
            return .empty
        }

        let thisWeekWorkouts = workouts.filter { $0.date >= thisWeekInterval.start && $0.date < thisWeekInterval.end }
        let thisWeek = statsForWorkouts(thisWeekWorkouts)

        // Last week for deltas
        guard let lastWeekStart = calendar.date(byAdding: .weekOfYear, value: -1, to: thisWeekInterval.start),
              let lastWeekInterval = calendar.dateInterval(of: .weekOfYear, for: lastWeekStart) else {
            return WeeklyStats(
                totalVolume: thisWeek.volume, totalSets: thisWeek.sets,
                totalReps: thisWeek.reps, totalDurationMinutes: thisWeek.duration,
                workoutCount: thisWeekWorkouts.count,
                muscleBreakdown: thisWeek.muscleBreakdown,
                volumeDelta: nil, setsDelta: nil, repsDelta: nil, workoutCountDelta: nil
            )
        }

        let lastWeekWorkouts = workouts.filter { $0.date >= lastWeekInterval.start && $0.date < lastWeekInterval.end }
        let lastWeek = statsForWorkouts(lastWeekWorkouts)

        let volumeDelta: Double? = lastWeek.volume > 0 ? ((thisWeek.volume - lastWeek.volume) / lastWeek.volume) * 100 : nil

        return WeeklyStats(
            totalVolume: thisWeek.volume, totalSets: thisWeek.sets,
            totalReps: thisWeek.reps, totalDurationMinutes: thisWeek.duration,
            workoutCount: thisWeekWorkouts.count,
            muscleBreakdown: thisWeek.muscleBreakdown,
            volumeDelta: volumeDelta,
            setsDelta: lastWeekWorkouts.isEmpty ? nil : thisWeek.sets - lastWeek.sets,
            repsDelta: lastWeekWorkouts.isEmpty ? nil : thisWeek.reps - lastWeek.reps,
            workoutCountDelta: lastWeekWorkouts.isEmpty ? nil : thisWeekWorkouts.count - lastWeekWorkouts.count
        )
    }

    private struct WorkoutAggregates {
        let volume: Double
        let sets: Int
        let reps: Int
        let duration: Int
        let muscleBreakdown: [MuscleGroup: Int]
    }

    private func statsForWorkouts(_ workouts: [Workout]) -> WorkoutAggregates {
        var totalVolume: Double = 0
        var totalSets = 0
        var totalReps = 0
        var totalDuration = 0
        var muscleBreakdown: [MuscleGroup: Int] = [:]

        for workout in workouts {
            let summary = WorkoutSummary(workout: workout)
            totalVolume += summary.totalVolume
            totalSets += summary.totalSets
            totalReps += summary.totalReps
            totalDuration += summary.durationMinutes

            for exercise in workout.exercises ?? [] {
                let setCount = (exercise.sets ?? []).count
                if let libraryExercise = ExerciseLibrary.shared.find(name: exercise.name) {
                    muscleBreakdown[libraryExercise.muscleGroup, default: 0] += setCount
                }
            }
        }

        return WorkoutAggregates(
            volume: totalVolume, sets: totalSets, reps: totalReps,
            duration: totalDuration, muscleBreakdown: muscleBreakdown
        )
    }

    // MARK: - Streak Data

    func computeStreakData(from workouts: [Workout], weeklyGoal: Int) -> StreakData {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // Build set of workout days
        let workoutDaySet = Set(workouts.map { calendar.startOfDay(for: $0.date) })

        // Current streak
        let current = computeCurrentStreak(workoutDays: workoutDaySet, from: today, calendar: calendar)

        // Best ever streak
        let bestEver = computeBestStreak(workoutDays: workoutDaySet, calendar: calendar)

        // Weekly goal streak
        let weeklyGoalStreak = computeWeeklyGoalStreak(workouts: workouts, goal: weeklyGoal, calendar: calendar)

        // Workout days for heatmap (last 28 days)
        var heatmapDays: [Date: Int] = [:]
        for dayOffset in 0..<28 {
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: today) else { continue }
            let dayStart = calendar.startOfDay(for: date)
            let count = workouts.filter { calendar.startOfDay(for: $0.date) == dayStart }.count
            heatmapDays[dayStart] = count
        }

        return StreakData(
            current: current, bestEver: bestEver,
            weeklyGoalStreak: weeklyGoalStreak, workoutDays: heatmapDays
        )
    }

    func computeCurrentStreak(workoutDays: Set<Date>, from today: Date, calendar: Calendar) -> Int {
        var streak = 0
        let hasWorkoutToday = workoutDays.contains(today)
        var currentDate = hasWorkoutToday ? today : calendar.date(byAdding: .day, value: -1, to: today)!

        while workoutDays.contains(currentDate) {
            streak += 1
            currentDate = calendar.date(byAdding: .day, value: -1, to: currentDate)!
        }
        return streak
    }

    func computeBestStreak(workoutDays: Set<Date>, calendar: Calendar) -> Int {
        guard !workoutDays.isEmpty else { return 0 }

        let sorted = workoutDays.sorted()
        var best = 1
        var current = 1

        for i in 1..<sorted.count {
            let daysBetween = calendar.dateComponents([.day], from: sorted[i-1], to: sorted[i]).day ?? 0
            if daysBetween == 1 {
                current += 1
                best = max(best, current)
            } else if daysBetween > 1 {
                current = 1
            }
            // daysBetween == 0 means same day, don't count twice
        }

        return best
    }

    func computeWeeklyGoalStreak(workouts: [Workout], goal: Int, calendar: Calendar) -> Int {
        guard goal > 0 else { return 0 }

        var streak = 0
        var weekDate = Date()

        // Check up to 52 weeks back
        for _ in 0..<52 {
            guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: weekDate) else { break }
            let weekWorkouts = workouts.filter { $0.date >= weekInterval.start && $0.date < weekInterval.end }

            if weekWorkouts.count >= goal {
                streak += 1
            } else {
                break
            }

            // Go to previous week
            guard let prevWeek = calendar.date(byAdding: .weekOfYear, value: -1, to: weekInterval.start) else { break }
            weekDate = prevWeek
        }

        return streak
    }

    // MARK: - Volume Trend

    func computeVolumeTrend(from workouts: [Workout], weeks: Int) -> [VolumeTrendPoint] {
        let calendar = Calendar.current
        var points: [VolumeTrendPoint] = []

        for weekOffset in (0..<weeks).reversed() {
            guard let weekStart = calendar.date(byAdding: .weekOfYear, value: -weekOffset, to: Date()),
                  let weekInterval = calendar.dateInterval(of: .weekOfYear, for: weekStart) else { continue }

            let weekWorkouts = workouts.filter { $0.date >= weekInterval.start && $0.date < weekInterval.end }
            let volume = weekWorkouts.reduce(0.0) { sum, workout in
                sum + WorkoutSummary(workout: workout).totalVolume
            }

            points.append(VolumeTrendPoint(weekStart: weekInterval.start, volume: volume))
        }

        return points
    }

    // MARK: - PR Count

    private func computeThisWeekPRCount(from prs: [PersonalRecord]) -> Int {
        let calendar = Calendar.current
        guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: Date()) else { return 0 }
        return prs.filter { $0.date >= weekInterval.start && $0.date < weekInterval.end }.count
    }
}
