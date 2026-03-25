//
//  PersonalRecordManager.swift
//  TheLogger
//
//  Manager for detecting and saving personal records
//

import Foundation
import SwiftData

/// Manager for detecting and saving personal records
struct PersonalRecordManager {

    /// Check if a set is a new PR and save it if so.
    /// Returns true only when a genuine cross-workout PR is beaten (triggers celebration).
    /// First-time records and within-workout improvements are saved silently (return false).
    @discardableResult
    static func checkAndSavePR(
        exerciseName: String,
        weight: Double,
        reps: Int,
        workoutId: UUID,
        modelContext: ModelContext,
        setType: SetType = .working
    ) -> Bool {
        let normalizedName = exerciseName.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        // Only consider valid sets that count for PRs (reps > 0, not warmup).
        // weight == 0 is allowed for bodyweight exercises (pull-ups, dips, etc.).
        guard reps > 0, setType.countsForPR else {
            #if DEBUG
            debugLog("[PR] checkAndSavePR SKIP guard reps=\(reps) setType=\(setType)")
            #endif
            return false
        }

        // Fetch existing PR for this exercise
        let descriptor = FetchDescriptor<PersonalRecord>(
            predicate: #Predicate { $0.exerciseName == normalizedName }
        )

        let existingPRs = (try? modelContext.fetch(descriptor)) ?? []

        // Score for comparison: 1RM for weighted sets, raw reps for bodyweight
        let newScore = prScore(weight: weight, reps: reps)

        if let existingPR = existingPRs.first {
            let existingScore = existingPR.prScore

            if newScore > existingScore {
                // Capture BEFORE updating, so we can check if this is a cross-workout improvement
                let previousWorkoutId = existingPR.workoutId

                existingPR.weight = weight
                existingPR.reps = reps
                existingPR.date = Date()
                existingPR.workoutId = workoutId
                try? modelContext.save()

                Analytics.send(Analytics.Signal.prAchieved, parameters: [
                    "exerciseName": exerciseName,
                    "type": weight > 0 ? "estimated1RM" : "reps"
                ])

                // Only celebrate when beating a record from a PREVIOUS workout.
                // Same-workout improvements (e.g. set 3 beats set 1) are saved silently.
                let fromPreviousWorkout = previousWorkoutId != workoutId
                #if DEBUG
                debugLog("[PR] checkAndSavePR UPDATED \(normalizedName) -> \(weight)x\(reps) score \(existingScore)->\(newScore) celebrate=\(fromPreviousWorkout)")
                #endif
                return fromPreviousWorkout
            }
            #if DEBUG
            debugLog("[PR] checkAndSavePR NO beat \(normalizedName) newScore=\(newScore) existingScore=\(existingScore)")
            #endif
        } else {
            // First time ever logging this exercise — establish baseline record silently.
            // There is no previous record to beat, so no celebration is warranted.
            let newPR = PersonalRecord(
                exerciseName: normalizedName,
                weight: weight,
                reps: reps,
                workoutId: workoutId
            )
            modelContext.insert(newPR)
            try? modelContext.save()
            #if DEBUG
            debugLog("[PR] checkAndSavePR BASELINE \(normalizedName) \(weight)x\(reps) score=\(newScore)")
            #endif
            return false
        }

        return false
    }

    /// PR comparison score: 1RM for weighted sets, raw reps for bodyweight.
    static func prScore(weight: Double, reps: Int) -> Double {
        if weight == 0 { return Double(reps) }
        return calculateEstimated1RM(weight: weight, reps: reps)
    }

    /// Recalculate PR for an exercise by scanning all workouts. Use when a set is edited
    /// (especially lowered) so the PR reflects the true best set across all data.
    /// Returns true if the PR changed (updated, created, or removed).
    @discardableResult
    static func recalculatePR(exerciseName: String, modelContext: ModelContext) -> Bool {
        let normalizedName = exerciseName.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        // Fetch all non-template workouts
        let workoutDescriptor = FetchDescriptor<Workout>(
            predicate: #Predicate<Workout> { $0.isTemplate == false }
        )
        guard let workouts = try? modelContext.fetch(workoutDescriptor) else { return false }

        // Collect all valid working sets for this exercise
        var bestSet: (weight: Double, reps: Int, workoutId: UUID)? = nil
        var best1RM: Double = 0

        for workout in workouts {
            for exercise in (workout.exercises ?? []) {
                guard exercise.name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) == normalizedName else { continue }
                for set in (exercise.sets ?? []) {
                    // Allow weight == 0 for bodyweight exercises; require reps > 0 and a PR-eligible type
                    guard set.reps > 0, set.type.countsForPR else { continue }
                    let score = prScore(weight: set.weight, reps: set.reps)
                    if score > best1RM {
                        best1RM = score
                        bestSet = (set.weight, set.reps, workout.id)
                    }
                }
            }
        }

        let prDescriptor = FetchDescriptor<PersonalRecord>(
            predicate: #Predicate<PersonalRecord> { $0.exerciseName == normalizedName }
        )
        let existingPRs = (try? modelContext.fetch(prDescriptor)) ?? []
        let existingPR = existingPRs.first

        if let best = bestSet {
            let changed: Bool
            if let pr = existingPR {
                changed = pr.weight != best.weight || pr.reps != best.reps
                pr.weight = best.weight
                pr.reps = best.reps
                pr.date = Date()
                pr.workoutId = best.workoutId
            } else {
                let newPR = PersonalRecord(
                    exerciseName: normalizedName,
                    weight: best.weight,
                    reps: best.reps,
                    workoutId: best.workoutId
                )
                modelContext.insert(newPR)
                changed = true
            }
            try? modelContext.save()
            #if DEBUG
            debugLog("[PR] recalculatePR \(normalizedName) -> \(best.weight)x\(best.reps) 1RM=\(best1RM)")
            #endif
            return changed
        } else {
            // No valid sets - remove existing PR if any
            if let pr = existingPR {
                modelContext.delete(pr)
                try? modelContext.save()
                #if DEBUG
                debugLog("[PR] recalculatePR \(normalizedName) REMOVED (no valid sets)")
                #endif
                return true
            }
            return false
        }
    }

    /// Get PR for an exercise
    static func getPR(for exerciseName: String, modelContext: ModelContext) -> PersonalRecord? {
        let normalizedName = exerciseName.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        let descriptor = FetchDescriptor<PersonalRecord>(
            predicate: #Predicate { $0.exerciseName == normalizedName }
        )

        return try? modelContext.fetch(descriptor).first
    }

    /// Calculate estimated 1RM using Epley formula
    private static func calculateEstimated1RM(weight: Double, reps: Int) -> Double {
        guard reps > 0 else { return weight }
        return weight * (1.0 + Double(reps) / 30.0)
    }

    /// Check all sets in a workout for PRs (call when workout ends)
    static func processWorkoutForPRs(workout: Workout, modelContext: ModelContext) -> [String] {
        for exercise in (workout.exercises ?? []) {
            for set in (exercise.sets ?? []) {
                _ = checkAndSavePR(
                    exerciseName: exercise.name,
                    weight: set.weight,
                    reps: set.reps,
                    workoutId: workout.id,
                    modelContext: modelContext,
                    setType: set.type
                )
            }
        }
        return exercisesWithPRsInWorkout(workout, modelContext: modelContext)
    }

    /// Exercises whose current PR was achieved in this workout (workoutId match).
    /// Use this to show "PRs achieved this workout" - PRs are often saved when the set is
    /// logged (via checkAndSavePR or recalculatePR), so processWorkoutForPRs' return value
    /// would miss them since checkAndSavePR returns false when the PR already exists.
    static func exercisesWithPRsInWorkout(_ workout: Workout, modelContext: ModelContext) -> [String] {
        var result: [String] = []
        for exercise in (workout.exercises ?? []) {
            guard let pr = getPR(for: exercise.name, modelContext: modelContext) else { continue }
            if pr.workoutId == workout.id, !result.contains(exercise.name) {
                result.append(exercise.name)
            }
        }
        return result
    }
}
