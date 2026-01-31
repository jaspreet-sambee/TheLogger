//
//  WorkoutSet.swift
//  TheLogger
//
//  Model representing a single set in a workout exercise
//

import Foundation
import SwiftData

enum SetType: String, Codable {
    case warmup = "Warmup"
    case working = "Working"
    
    var icon: String {
        switch self {
        case .warmup: return "flame.fill"
        case .working: return "dumbbell.fill"
        }
    }
    
    var color: String {
        switch self {
        case .warmup: return "orange"
        case .working: return "blue"
        }
    }
}

@Model
final class WorkoutSet: Identifiable {
    var id: UUID
    var reps: Int
    var weight: Double
    var setType: String  // Store as String for SwiftData compatibility
    var sortOrder: Int   // Ensures consistent display order (SwiftData doesn't guarantee relationship order)
    
    init(id: UUID = UUID(), reps: Int, weight: Double, setType: SetType = .working, sortOrder: Int = 0) {
        self.id = id
        self.reps = reps
        self.weight = weight
        self.setType = setType.rawValue
        self.sortOrder = sortOrder
    }
    
    var type: SetType {
        get {
            SetType(rawValue: setType) ?? .working
        }
        set {
            setType = newValue.rawValue
        }
    }
    
    var isWarmup: Bool {
        type == .warmup
    }
}

