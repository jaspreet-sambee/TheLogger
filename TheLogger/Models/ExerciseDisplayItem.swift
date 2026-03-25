//
//  ExerciseDisplayItem.swift
//  TheLogger
//
//  Display model for exercises and superset groups
//

import Foundation

// MARK: - Superset Display Model

/// Represents an item in the exercise list for display purposes
enum ExerciseDisplayItem: Identifiable {
    case standalone(Exercise)
    case superset(id: UUID, exercises: [Exercise])

    var id: UUID {
        switch self {
        case .standalone(let exercise):
            return exercise.id
        case .superset(let id, _):
            return id
        }
    }

    /// Whether this is a superset group
    var isSuperset: Bool {
        if case .superset = self { return true }
        return false
    }

    /// Get all exercises (1 for standalone, multiple for superset)
    var allExercises: [Exercise] {
        switch self {
        case .standalone(let exercise):
            return [exercise]
        case .superset(_, let exercises):
            return exercises
        }
    }

    /// Display name for the group
    var displayName: String {
        switch self {
        case .standalone(let exercise):
            return exercise.name
        case .superset(_, let exercises):
            if exercises.count == 2 {
                return "Superset"
            } else if exercises.count == 3 {
                return "Tri-set"
            } else {
                return "Giant Set"
            }
        }
    }
}
