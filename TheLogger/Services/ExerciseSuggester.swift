//
//  ExerciseSuggester.swift
//  TheLogger
//
//  Smart exercise suggestions: library-based candidates ranked by usage frequency
//

import Foundation
import SwiftData

enum ExerciseSuggester {
    /// Suggests exercises for Quick Add: library candidates (by muscle group) ranked by how often
    /// the user has done them in past workouts. Excludes exercises already in the current workout.
    /// - Parameters:
    ///   - workout: Current workout (used to infer context and exclude existing exercises)
    ///   - modelContext: SwiftData context for fetching workout history
    ///   - limit: Max suggestions to return (default 5)
    /// - Returns: Exercise names, ordered by relevance (context match) then frequency (most used first)
    static func suggest(
        for workout: Workout,
        modelContext: ModelContext,
        limit: Int = 5
    ) -> [String] {
        let currentNames = Set((workout.exercises ?? []).map { $0.name })
        let library = ExerciseLibrary.shared

        // 1. Infer relevant muscle groups from current workout exercises
        let relevantGroups = inferMuscleGroups(from: workout.exercises ?? [], library: library)

        // 2. Get library candidates matching those groups, excluding current
        let candidates: [LibraryExercise]
        if relevantGroups.isEmpty {
            // Empty workout: use all library exercises (will rank by frequency)
            candidates = library.exercises.filter { !currentNames.contains($0.name) }
        } else {
            candidates = library.exercises.filter { exercise in
                !currentNames.contains(exercise.name) && relevantGroups.contains(exercise.muscleGroup)
            }
        }

        if candidates.isEmpty { return [] }

        // 3. Compute frequency: how many past workouts contain each exercise
        let frequency = computeExerciseFrequency(modelContext: modelContext)

        // 4. Sort by frequency (desc), then by name for ties; take top limit
        let sorted = candidates.sorted { a, b in
            let freqA = frequency[a.name] ?? 0
            let freqB = frequency[b.name] ?? 0
            if freqA != freqB { return freqA > freqB }
            return a.name.localizedStandardCompare(b.name) == .orderedAscending
        }

        return Array(sorted.prefix(limit).map { $0.name })
    }

    // MARK: - Helpers

    /// Infer muscle groups from current exercises using library + keyword fallback for custom exercises
    private static func inferMuscleGroups(from exercises: [Exercise], library: ExerciseLibrary) -> Set<MuscleGroup> {
        var groups = Set<MuscleGroup>()
        var hasPush = false
        var hasPull = false
        var hasLegs = false

        let pushKeywords = ["bench", "press", "shoulder", "tricep", "chest", "push"]
        let pullKeywords = ["pull", "row", "lat", "bicep", "back", "deadlift"]
        let legKeywords = ["squat", "leg", "calf", "lunge", "hip", "thrust"]

        for exercise in exercises {
            if let libEx = library.find(name: exercise.name) {
                groups.insert(libEx.muscleGroup)
                // Map muscle group to push/pull/leg for expanding suggestions
                switch libEx.muscleGroup {
                case .chest, .shoulders: hasPush = true
                case .back: hasPull = true
                case .arms: hasPush = true; hasPull = true // arms can be both
                case .legs: hasLegs = true
                case .core: break
                }
            } else {
                // Custom exercise: use keyword inference
                let name = exercise.name.lowercased()
                if pushKeywords.contains(where: { name.contains($0) }) { hasPush = true }
                if pullKeywords.contains(where: { name.contains($0) }) { hasPull = true }
                if legKeywords.contains(where: { name.contains($0) }) { hasLegs = true }
            }
        }

        // Expand to related muscle groups for push/pull/legs
        if hasPush {
            groups.formUnion([.chest, .shoulders, .arms])
        }
        if hasPull {
            groups.formUnion([.back, .arms])
        }
        if hasLegs {
            groups.insert(.legs)
        }

        return groups
    }

    /// Count how many past (non-template) workouts contain each exercise
    private static func computeExerciseFrequency(modelContext: ModelContext) -> [String: Int] {
        var frequency: [String: Int] = [:]
        let descriptor = FetchDescriptor<Workout>(
            predicate: #Predicate<Workout> { $0.isTemplate == false },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )

        guard let workouts = try? modelContext.fetch(descriptor) else { return frequency }

        for workout in workouts {
            let names = Set((workout.exercises ?? []).map { $0.name })
            for name in names {
                frequency[name, default: 0] += 1
            }
        }
        return frequency
    }
}
