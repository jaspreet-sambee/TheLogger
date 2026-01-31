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
    
    /// Indicates if sets were auto-filled from exercise memory (transient, not persisted)
    @Transient var isAutoFilled: Bool = false
    
    init(id: UUID = UUID(), name: String, sets: [WorkoutSet] = []) {
        self.id = id
        self.name = name
        self.sets = sets
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

