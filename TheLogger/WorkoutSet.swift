//
//  WorkoutSet.swift
//  TheLogger
//
//  Model representing a single set in a workout exercise
//

import Foundation
import SwiftData
import SwiftUI

enum SetType: String, Codable, CaseIterable {
    case warmup = "Warmup"
    case working = "Working"
    case dropSet = "Drop Set"
    case failure = "Failure"
    case pause = "Rest-Pause"

    var icon: String {
        switch self {
        case .warmup: return "flame.fill"
        case .working: return "dumbbell.fill"
        case .dropSet: return "arrow.down.circle.fill"
        case .failure: return "bolt.fill"
        case .pause: return "pause.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .warmup: return .orange
        case .working: return .blue
        case .dropSet: return .purple
        case .failure: return .red
        case .pause: return .teal
        }
    }

    /// Whether this set type should count towards personal records
    var countsForPR: Bool {
        switch self {
        case .warmup: return false
        case .working, .dropSet, .failure, .pause: return true
        }
    }

    /// Short label for badges
    var shortLabel: String {
        switch self {
        case .warmup: return "W"
        case .working: return ""
        case .dropSet: return "D"
        case .failure: return "F"
        case .pause: return "P"
        }
    }
}

@Model
final class WorkoutSet: Identifiable {
    var id: UUID = UUID()
    var reps: Int = 0
    var weight: Double = 0
    var setType: String = "Working"  // Store as String for SwiftData compatibility
    var sortOrder: Int = 0   // Ensures consistent display order (SwiftData doesn't guarantee relationship order)

    /// Inverse relationship to parent exercise (required for CloudKit)
    var exercise: Exercise?
    
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

