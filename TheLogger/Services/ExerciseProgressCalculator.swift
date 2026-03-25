//
//  ExerciseProgressCalculator.swift
//  TheLogger
//
//  Compares current exercise performance against previous workouts
//

import Foundation
import SwiftData

// MARK: - Exercise Progress Comparison

/// Represents the comparison result between current and previous exercise performance
enum ExerciseProgressComparison: Equatable {
    case firstTime
    case improved(deltaWeight: Double?, deltaReps: Int?)
    case matched
    case regressed

    /// Human-readable description
    var displayText: String {
        switch self {
        case .firstTime:
            return "First time"
        case .improved(let deltaWeight, let deltaReps):
            var parts: [String] = []
            if let dw = deltaWeight, dw > 0 {
                parts.append("+\(UnitFormatter.formatWeight(dw))")
            }
            if let dr = deltaReps, dr > 0 {
                parts.append("+\(dr) reps")
            }
            return parts.isEmpty ? "Improved" : parts.joined(separator: ", ")
        case .matched:
            return "Matched last time"
        case .regressed:
            return "Below previous"
        }
    }

    /// Whether this represents positive progress
    var isPositive: Bool {
        switch self {
        case .firstTime, .improved, .matched:
            return true
        case .regressed:
            return false
        }
    }
}

/// Calculator for exercise progress comparison - keeps logic outside View layer
struct ExerciseProgressCalculator {

    /// Represents a single set's performance value
    struct SetPerformance: Comparable {
        let weight: Double
        let reps: Int

        /// Performance score: weight × reps
        var score: Double {
            weight * Double(reps)
        }

        static func < (lhs: SetPerformance, rhs: SetPerformance) -> Bool {
            lhs.score < rhs.score
        }
    }

    /// Compare current exercise against the most recent past workout with the same exercise
    /// - Parameters:
    ///   - exercise: The current exercise instance
    ///   - currentWorkoutId: ID of the active workout (to exclude from comparison)
    ///   - completedWorkouts: All completed workouts (sorted by date, most recent first)
    /// - Returns: The comparison result
    static func compare(
        exercise: Exercise,
        currentWorkoutId: UUID,
        completedWorkouts: [Workout]
    ) -> ExerciseProgressComparison {

        let normalizedName = exercise.name.lowercased().trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)

        // Find the most recent completed workout (not current, not template) with this exercise
        guard let previousWorkout = completedWorkouts.first(where: { workout in
            workout.id != currentWorkoutId &&
            !workout.isTemplate &&
            workout.endTime != nil &&
            (workout.exercises ?? []).contains { ex in
                ex.name.lowercased().trimmingCharacters(in: CharacterSet.whitespacesAndNewlines) == normalizedName
            }
        }) else {
            return .firstTime
        }

        // Find the matching exercise in the previous workout
        guard let previousExercise = (previousWorkout.exercises ?? []).first(where: { ex in
            ex.name.lowercased().trimmingCharacters(in: CharacterSet.whitespacesAndNewlines) == normalizedName
        }) else {
            return .firstTime
        }

        // Get best set from previous exercise (ignoring sets with 0 reps as "incomplete")
        let previousSets = (previousExercise.sets ?? []).filter { $0.reps > 0 }
        guard let previousBest = previousSets.map({ SetPerformance(weight: $0.weight, reps: $0.reps) }).max() else {
            return .firstTime
        }

        // Get best set from current exercise
        let currentSets = (exercise.sets ?? []).filter { $0.reps > 0 }
        guard let currentBest = currentSets.map({ SetPerformance(weight: $0.weight, reps: $0.reps) }).max() else {
            // No completed sets yet in current workout
            return .firstTime
        }

        // Compare
        return comparePerformance(current: currentBest, previous: previousBest)
    }

    /// Compare two set performances and return the result
    private static func comparePerformance(
        current: SetPerformance,
        previous: SetPerformance
    ) -> ExerciseProgressComparison {

        let weightDelta = current.weight - previous.weight
        let repsDelta = current.reps - previous.reps

        // Exact match
        if current.weight == previous.weight && current.reps == previous.reps {
            return .matched
        }

        // Check for improvement (either weight or reps increased, without the other decreasing significantly)
        if current.score > previous.score {
            // Overall improvement
            let deltaWeight: Double? = weightDelta > 0 ? weightDelta : nil
            let deltaReps: Int? = repsDelta > 0 ? repsDelta : nil
            return .improved(deltaWeight: deltaWeight, deltaReps: deltaReps)
        }

        if current.score < previous.score {
            return .regressed
        }

        // Same score but different distribution - consider it matched
        return .matched
    }

    /// Get previous exercise data for display purposes
    /// - Returns: Tuple of (weight, reps, setCount) from best previous set, or nil if first time
    static func getPreviousBest(
        exerciseName: String,
        currentWorkoutId: UUID,
        completedWorkouts: [Workout]
    ) -> (weight: Double, reps: Int, totalSets: Int)? {

        let normalizedName = exerciseName.lowercased().trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)

        guard let previousWorkout = completedWorkouts.first(where: { workout in
            workout.id != currentWorkoutId &&
            !workout.isTemplate &&
            workout.endTime != nil &&
            (workout.exercises ?? []).contains { ex in
                ex.name.lowercased().trimmingCharacters(in: CharacterSet.whitespacesAndNewlines) == normalizedName
            }
        }),
        let previousExercise = (previousWorkout.exercises ?? []).first(where: { ex in
            ex.name.lowercased().trimmingCharacters(in: CharacterSet.whitespacesAndNewlines) == normalizedName
        }) else {
            return nil
        }

        let validSets = (previousExercise.sets ?? []).filter { $0.reps > 0 }
        guard let bestSet = validSets.map({ SetPerformance(weight: $0.weight, reps: $0.reps) }).max() else {
            return nil
        }

        return (weight: bestSet.weight, reps: bestSet.reps, totalSets: validSets.count)
    }
}
