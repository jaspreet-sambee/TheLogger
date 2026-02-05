//
//  Exercise.swift
//  TheLogger
//
//  Model representing an exercise within a workout
//

import Foundation
import SwiftData

@Model
final class Exercise: Identifiable {
    var id: UUID = UUID()
    var name: String = ""
    @Relationship(deleteRule: .cascade, inverse: \WorkoutSet.exercise) var sets: [WorkoutSet]?

    /// Inverse relationship to parent workout (required for CloudKit)
    var workout: Workout?

    /// Groups exercises into supersets. Exercises with the same groupId are performed back-to-back.
    /// nil = standalone exercise, same UUID = part of same superset
    var supersetGroupId: UUID?

    /// Position within a superset (0, 1, 2...). Used to maintain order within a group.
    var supersetOrder: Int = 0

    /// Position within the workout (0, 1, 2...). SwiftData relationships don't preserve order; this ensures display order.
    var order: Int = 0

    /// Indicates if sets were auto-filled from exercise memory (transient, not persisted)
    @Transient var isAutoFilled: Bool = false

    init(id: UUID = UUID(), name: String, sets: [WorkoutSet] = [], supersetGroupId: UUID? = nil, supersetOrder: Int = 0, order: Int = 0) {
        self.id = id
        self.name = name
        self.sets = sets
        self.supersetGroupId = supersetGroupId
        self.supersetOrder = supersetOrder
        self.order = order
    }

    /// Whether this exercise is part of a superset
    var isInSuperset: Bool {
        supersetGroupId != nil
    }
    
    /// Add a new set to this exercise
    /// - Parameters:
    ///   - reps: Rep count (ignored when durationSeconds is non-nil)
    ///   - weight: Weight (ignored when durationSeconds is non-nil)
    ///   - durationSeconds: For time-based exercises (e.g. Plank). When non-nil, set is time-based.
    func addSet(reps: Int, weight: Double, durationSeconds: Int? = nil) {
        let currentSets = sets ?? []
        let nextOrder = (currentSets.map(\.sortOrder).max() ?? -1) + 1
        let newSet = WorkoutSet(reps: reps, weight: weight, durationSeconds: durationSeconds, sortOrder: nextOrder)
        if sets == nil {
            sets = [newSet]
        } else {
            sets?.append(newSet)
        }
    }

    /// Sets in stable display order (SwiftData relationship order is not guaranteed)
    var setsByOrder: [WorkoutSet] {
        (sets ?? []).sorted { $0.sortOrder < $1.sortOrder }
    }

    /// Remove a set by ID
    func removeSet(id: UUID) {
        sets?.removeAll { $0.id == id }
    }

    /// Get total reps across all sets
    var totalReps: Int {
        (sets ?? []).reduce(0) { $0 + $1.reps }
    }

    /// Total duration in seconds (for time-based exercises)
    var totalDurationSeconds: Int {
        (sets ?? []).compactMap { $0.durationSeconds }.reduce(0, +)
    }

    /// Whether this exercise has any time-based sets
    var hasTimeBasedSets: Bool {
        (sets ?? []).contains { $0.isTimeBased }
    }
}

