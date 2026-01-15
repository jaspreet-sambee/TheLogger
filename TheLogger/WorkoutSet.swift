//
//  WorkoutSet.swift
//  TheLogger
//
//  Model representing a single set in a workout exercise
//

import Foundation
import SwiftData

@Model
final class WorkoutSet: Identifiable {
    var id: UUID
    var reps: Int
    var weight: Double
    
    init(id: UUID = UUID(), reps: Int, weight: Double) {
        self.id = id
        self.reps = reps
        self.weight = weight
    }
}

