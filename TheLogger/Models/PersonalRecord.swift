//
//  PersonalRecord.swift
//  TheLogger
//
//  Model for tracking personal records (PRs) per exercise
//

import Foundation
import SwiftData

// MARK: - Personal Record

/// Model for tracking personal records (PRs) per exercise
@Model
final class PersonalRecord {
    var exerciseName: String = ""  // Normalized exercise name
    var weight: Double = 0        // Weight in lbs (storage unit)
    var reps: Int = 0             // Reps at that weight
    var date: Date = Date()       // When the PR was set
    var workoutId: UUID = UUID()  // Which workout it was set in

    init(exerciseName: String, weight: Double, reps: Int, date: Date = Date(), workoutId: UUID) {
        self.exerciseName = exerciseName.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        self.weight = weight
        self.reps = reps
        self.date = date
        self.workoutId = workoutId
    }

    /// True when the PR was set without added weight (bodyweight exercises like pull-ups)
    var isBodyweight: Bool { weight == 0 }

    /// Estimated 1RM using Epley formula. Returns 0 for bodyweight sets (use prScore instead).
    var estimated1RM: Double {
        guard weight > 0, reps > 0 else { return 0 }
        return weight * (1.0 + Double(reps) / 30.0)
    }

    /// Comparison score used to rank PRs.
    /// Weighted sets: estimated 1RM. Bodyweight sets: raw reps (more = better).
    var prScore: Double {
        isBodyweight ? Double(reps) : estimated1RM
    }

    /// Formatted display string
    var displayString: String {
        if isBodyweight {
            return "BW × \(reps)"
        }
        return "\(UnitFormatter.formatWeight(weight, showUnit: false)) × \(reps)"
    }
}
