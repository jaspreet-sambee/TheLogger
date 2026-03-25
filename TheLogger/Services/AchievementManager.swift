//
//  AchievementManager.swift
//  TheLogger
//
//  Defines all achievements and checks unlock conditions against workout data
//

import Foundation
import SwiftData

// MARK: - Achievement Definition

enum AchievementTier: String, CaseIterable {
    case bronze = "Bronze"
    case silver = "Silver"
    case gold = "Gold"
    case platinum = "Platinum"

    var icon: String {
        switch self {
        case .bronze: return "medal"
        case .silver: return "medal.fill"
        case .gold: return "trophy"
        case .platinum: return "crown"
        }
    }
}

enum AchievementCategory: String, CaseIterable, Identifiable {
    case consistency = "Consistency"
    case strength = "Strength"
    case volume = "Volume"
    case variety = "Variety"
    case dedication = "Dedication"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .consistency: return "flame.fill"
        case .strength: return "bolt.fill"
        case .volume: return "chart.bar.fill"
        case .variety: return "square.grid.3x3.fill"
        case .dedication: return "heart.fill"
        }
    }
}

struct AchievementDefinition: Identifiable {
    let id: String
    let name: String
    let description: String
    let category: AchievementCategory
    let tier: AchievementTier
    let icon: String
    /// Returns current progress (0.0 - 1.0) and whether unlocked
    let check: (AchievementContext) -> (progress: Double, unlocked: Bool)
}

struct AchievementContext {
    let workouts: [Workout]
    let prs: [PersonalRecord]
    let streakData: StreakData
    let totalSets: Int
    let totalVolume: Double
    let uniqueExercises: Set<String>
    let muscleGroupsTrained: Set<MuscleGroup>
    let compoundExercises: Set<String>
    let weekendWorkoutsThisMonth: Int
    let hasEarlyBirdWorkout: Bool
    let hasNightOwlWorkout: Bool
}

// MARK: - Achievement Manager

struct AchievementManager {
    static let definitions: [AchievementDefinition] = buildDefinitions()

    /// Check all achievements and return newly unlocked ones
    static func checkAll(context: AchievementContext, alreadyUnlocked: Set<String>) -> [AchievementDefinition] {
        var newlyUnlocked: [AchievementDefinition] = []

        for definition in definitions {
            guard !alreadyUnlocked.contains(definition.id) else { continue }
            let result = definition.check(context)
            if result.unlocked {
                newlyUnlocked.append(definition)
            }
        }

        return newlyUnlocked
    }

    /// Get progress for a specific achievement
    static func progress(for id: String, context: AchievementContext) -> Double {
        guard let definition = definitions.first(where: { $0.id == id }) else { return 0 }
        return definition.check(context).progress
    }

    /// Build context from raw data
    static func buildContext(workouts: [Workout], prs: [PersonalRecord], streakData: StreakData) -> AchievementContext {
        let completed = workouts.filter { $0.isCompleted && !$0.isTemplate }
        let calendar = Calendar.current

        var totalSets = 0
        var totalVolume: Double = 0
        var uniqueExercises: Set<String> = []
        var muscleGroupsTrained: Set<MuscleGroup> = []
        var compoundExercises: Set<String> = []
        var hasEarlyBird = false
        var hasNightOwl = false
        var weekendWorkoutsThisMonth = 0

        let monthAgo = calendar.date(byAdding: .month, value: -1, to: Date()) ?? Date()

        for workout in completed {
            for exercise in workout.exercises ?? [] {
                let sets = exercise.sets ?? []
                totalSets += sets.count
                totalVolume += sets.reduce(0.0) { $0 + ($1.weight * Double($1.reps)) }
                uniqueExercises.insert(exercise.name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines))

                if let lib = ExerciseLibrary.shared.find(name: exercise.name) {
                    muscleGroupsTrained.insert(lib.muscleGroup)
                    if lib.isCompound {
                        compoundExercises.insert(exercise.name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines))
                    }
                }
            }

            if let startTime = workout.startTime {
                let hour = calendar.component(.hour, from: startTime)
                if hour < 7 { hasEarlyBird = true }
                if hour >= 21 { hasNightOwl = true }
            }

            if workout.date >= monthAgo {
                let weekday = calendar.component(.weekday, from: workout.date)
                if weekday == 1 || weekday == 7 {
                    weekendWorkoutsThisMonth += 1
                }
            }
        }

        return AchievementContext(
            workouts: completed,
            prs: prs,
            streakData: streakData,
            totalSets: totalSets,
            totalVolume: totalVolume,
            uniqueExercises: uniqueExercises,
            muscleGroupsTrained: muscleGroupsTrained,
            compoundExercises: compoundExercises,
            weekendWorkoutsThisMonth: weekendWorkoutsThisMonth,
            hasEarlyBirdWorkout: hasEarlyBird,
            hasNightOwlWorkout: hasNightOwl
        )
    }

    // MARK: - Definition Builder

    private static func buildDefinitions() -> [AchievementDefinition] {
        var defs: [AchievementDefinition] = []

        // MARK: Consistency
        defs.append(contentsOf: [
            AchievementDefinition(id: "streak-3", name: "Hat Trick", description: "3-day workout streak", category: .consistency, tier: .bronze, icon: "flame.fill") { ctx in
                (min(Double(ctx.streakData.bestEver) / 3.0, 1.0), ctx.streakData.bestEver >= 3)
            },
            AchievementDefinition(id: "streak-7", name: "Week Warrior", description: "7-day workout streak", category: .consistency, tier: .silver, icon: "flame.fill") { ctx in
                (min(Double(ctx.streakData.bestEver) / 7.0, 1.0), ctx.streakData.bestEver >= 7)
            },
            AchievementDefinition(id: "streak-14", name: "Two Weeks Strong", description: "14-day workout streak", category: .consistency, tier: .silver, icon: "flame.fill") { ctx in
                (min(Double(ctx.streakData.bestEver) / 14.0, 1.0), ctx.streakData.bestEver >= 14)
            },
            AchievementDefinition(id: "streak-30", name: "Monthly Machine", description: "30-day workout streak", category: .consistency, tier: .gold, icon: "flame.fill") { ctx in
                (min(Double(ctx.streakData.bestEver) / 30.0, 1.0), ctx.streakData.bestEver >= 30)
            },
            AchievementDefinition(id: "streak-100", name: "Centurion", description: "100-day workout streak", category: .consistency, tier: .platinum, icon: "flame.fill") { ctx in
                (min(Double(ctx.streakData.bestEver) / 100.0, 1.0), ctx.streakData.bestEver >= 100)
            },
            AchievementDefinition(id: "goal-4", name: "Goal Getter", description: "Hit weekly goal 4 weeks in a row", category: .consistency, tier: .silver, icon: "target") { ctx in
                (min(Double(ctx.streakData.weeklyGoalStreak) / 4.0, 1.0), ctx.streakData.weeklyGoalStreak >= 4)
            },
            AchievementDefinition(id: "goal-12", name: "Quarterly Crush", description: "Hit weekly goal 12 weeks in a row", category: .consistency, tier: .gold, icon: "target") { ctx in
                (min(Double(ctx.streakData.weeklyGoalStreak) / 12.0, 1.0), ctx.streakData.weeklyGoalStreak >= 12)
            },
        ])

        // MARK: Strength
        defs.append(contentsOf: [
            AchievementDefinition(id: "first-pr", name: "New Record", description: "Set your first personal record", category: .strength, tier: .bronze, icon: "medal.fill") { ctx in
                (ctx.prs.isEmpty ? 0 : 1.0, !ctx.prs.isEmpty)
            },
            AchievementDefinition(id: "pr-10", name: "PR Hunter", description: "Achieve 10 personal records", category: .strength, tier: .silver, icon: "medal.fill") { ctx in
                (min(Double(ctx.prs.count) / 10.0, 1.0), ctx.prs.count >= 10)
            },
            AchievementDefinition(id: "pr-25", name: "PR Machine", description: "Achieve 25 personal records", category: .strength, tier: .gold, icon: "medal.fill") { ctx in
                (min(Double(ctx.prs.count) / 25.0, 1.0), ctx.prs.count >= 25)
            },
            AchievementDefinition(id: "pr-50", name: "Record Breaker", description: "Achieve 50 personal records", category: .strength, tier: .platinum, icon: "medal.fill") { ctx in
                (min(Double(ctx.prs.count) / 50.0, 1.0), ctx.prs.count >= 50)
            },
            AchievementDefinition(id: "bodyweight-pr", name: "Own Weight", description: "Set a bodyweight exercise PR", category: .strength, tier: .bronze, icon: "figure.walk") { ctx in
                let hasBW = ctx.prs.contains { $0.isBodyweight }
                return (hasBW ? 1.0 : 0.0, hasBW)
            },
        ])

        // MARK: Volume
        defs.append(contentsOf: [
            AchievementDefinition(id: "sets-100", name: "Century Sets", description: "Complete 100 total sets", category: .volume, tier: .bronze, icon: "square.stack.3d.up") { ctx in
                (min(Double(ctx.totalSets) / 100.0, 1.0), ctx.totalSets >= 100)
            },
            AchievementDefinition(id: "sets-500", name: "Set Collector", description: "Complete 500 total sets", category: .volume, tier: .silver, icon: "square.stack.3d.up") { ctx in
                (min(Double(ctx.totalSets) / 500.0, 1.0), ctx.totalSets >= 500)
            },
            AchievementDefinition(id: "sets-1000", name: "Thousand Club", description: "Complete 1,000 total sets", category: .volume, tier: .gold, icon: "square.stack.3d.up") { ctx in
                (min(Double(ctx.totalSets) / 1000.0, 1.0), ctx.totalSets >= 1000)
            },
            AchievementDefinition(id: "volume-10k", name: "10K Club", description: "Lift 10,000 lbs total volume", category: .volume, tier: .bronze, icon: "scalemass") { ctx in
                (min(ctx.totalVolume / 10_000.0, 1.0), ctx.totalVolume >= 10_000)
            },
            AchievementDefinition(id: "volume-100k", name: "Heavy Lifter", description: "Lift 100,000 lbs total volume", category: .volume, tier: .silver, icon: "scalemass") { ctx in
                (min(ctx.totalVolume / 100_000.0, 1.0), ctx.totalVolume >= 100_000)
            },
            AchievementDefinition(id: "volume-1m", name: "Million Pounder", description: "Lift 1,000,000 lbs total volume", category: .volume, tier: .gold, icon: "scalemass") { ctx in
                (min(ctx.totalVolume / 1_000_000.0, 1.0), ctx.totalVolume >= 1_000_000)
            },
        ])

        // MARK: Variety
        defs.append(contentsOf: [
            AchievementDefinition(id: "exercises-10", name: "Explorer", description: "Try 10 unique exercises", category: .variety, tier: .bronze, icon: "magnifyingglass") { ctx in
                (min(Double(ctx.uniqueExercises.count) / 10.0, 1.0), ctx.uniqueExercises.count >= 10)
            },
            AchievementDefinition(id: "exercises-25", name: "Well-Rounded", description: "Try 25 unique exercises", category: .variety, tier: .silver, icon: "magnifyingglass") { ctx in
                (min(Double(ctx.uniqueExercises.count) / 25.0, 1.0), ctx.uniqueExercises.count >= 25)
            },
            AchievementDefinition(id: "exercises-50", name: "Exercise Encyclopedia", description: "Try 50 unique exercises", category: .variety, tier: .gold, icon: "magnifyingglass") { ctx in
                (min(Double(ctx.uniqueExercises.count) / 50.0, 1.0), ctx.uniqueExercises.count >= 50)
            },
            AchievementDefinition(id: "all-muscles", name: "Full Body", description: "Train all 6 muscle groups", category: .variety, tier: .silver, icon: "figure.arms.open") { ctx in
                (Double(ctx.muscleGroupsTrained.count) / 6.0, ctx.muscleGroupsTrained.count >= 6)
            },
            AchievementDefinition(id: "compound-king", name: "Compound King", description: "Perform 10 different compound exercises", category: .variety, tier: .silver, icon: "figure.strengthtraining.traditional") { ctx in
                (min(Double(ctx.compoundExercises.count) / 10.0, 1.0), ctx.compoundExercises.count >= 10)
            },
        ])

        // MARK: Dedication
        defs.append(contentsOf: [
            AchievementDefinition(id: "first-workout", name: "First Step", description: "Complete your first workout", category: .dedication, tier: .bronze, icon: "figure.walk") { ctx in
                (ctx.workouts.isEmpty ? 0 : 1.0, !ctx.workouts.isEmpty)
            },
            AchievementDefinition(id: "workouts-10", name: "Getting Started", description: "Complete 10 workouts", category: .dedication, tier: .bronze, icon: "checkmark.circle.fill") { ctx in
                (min(Double(ctx.workouts.count) / 10.0, 1.0), ctx.workouts.count >= 10)
            },
            AchievementDefinition(id: "workouts-50", name: "Committed", description: "Complete 50 workouts", category: .dedication, tier: .silver, icon: "checkmark.circle.fill") { ctx in
                (min(Double(ctx.workouts.count) / 50.0, 1.0), ctx.workouts.count >= 50)
            },
            AchievementDefinition(id: "workouts-100", name: "Centurion", description: "Complete 100 workouts", category: .dedication, tier: .gold, icon: "checkmark.circle.fill") { ctx in
                (min(Double(ctx.workouts.count) / 100.0, 1.0), ctx.workouts.count >= 100)
            },
            AchievementDefinition(id: "workouts-500", name: "Legend", description: "Complete 500 workouts", category: .dedication, tier: .platinum, icon: "crown") { ctx in
                (min(Double(ctx.workouts.count) / 500.0, 1.0), ctx.workouts.count >= 500)
            },
            AchievementDefinition(id: "early-bird", name: "Early Bird", description: "Start a workout before 7 AM", category: .dedication, tier: .bronze, icon: "sunrise.fill") { ctx in
                (ctx.hasEarlyBirdWorkout ? 1.0 : 0.0, ctx.hasEarlyBirdWorkout)
            },
            AchievementDefinition(id: "night-owl", name: "Night Owl", description: "Start a workout after 9 PM", category: .dedication, tier: .bronze, icon: "moon.fill") { ctx in
                (ctx.hasNightOwlWorkout ? 1.0 : 0.0, ctx.hasNightOwlWorkout)
            },
            AchievementDefinition(id: "weekend-warrior", name: "Weekend Warrior", description: "4 weekend workouts in a month", category: .dedication, tier: .silver, icon: "calendar.badge.clock") { ctx in
                (min(Double(ctx.weekendWorkoutsThisMonth) / 4.0, 1.0), ctx.weekendWorkoutsThisMonth >= 4)
            },
        ])

        return defs
    }
}
