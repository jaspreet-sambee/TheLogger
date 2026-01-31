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
    var id: UUID
    var name: String
    @Relationship(deleteRule: .cascade) var sets: [WorkoutSet]

    /// Groups exercises into supersets. Exercises with the same groupId are performed back-to-back.
    /// nil = standalone exercise, same UUID = part of same superset
    var supersetGroupId: UUID?

    /// Position within a superset (0, 1, 2...). Used to maintain order within a group.
    var supersetOrder: Int

    /// Indicates if sets were auto-filled from exercise memory (transient, not persisted)
    @Transient var isAutoFilled: Bool = false

    init(id: UUID = UUID(), name: String, sets: [WorkoutSet] = [], supersetGroupId: UUID? = nil, supersetOrder: Int = 0) {
        self.id = id
        self.name = name
        self.sets = sets
        self.supersetGroupId = supersetGroupId
        self.supersetOrder = supersetOrder
    }

    /// Whether this exercise is part of a superset
    var isInSuperset: Bool {
        supersetGroupId != nil
    }
    
    /// Add a new set to this exercise
    func addSet(reps: Int, weight: Double) {
        let nextOrder = (sets.map(\.sortOrder).max() ?? -1) + 1
        let newSet = WorkoutSet(reps: reps, weight: weight, sortOrder: nextOrder)
        sets.append(newSet)
    }
    
    /// Sets in stable display order (SwiftData relationship order is not guaranteed)
    var setsByOrder: [WorkoutSet] {
        sets.sorted { $0.sortOrder < $1.sortOrder }
    }
    
    /// Remove a set by ID
    func removeSet(id: UUID) {
        sets.removeAll { $0.id == id }
    }
    
    /// Get total reps across all sets
    var totalReps: Int {
        sets.reduce(0) { $0 + $1.reps }
    }
}

