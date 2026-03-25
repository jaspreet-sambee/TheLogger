//
//  WorkoutSummary.swift
//  TheLogger
//
//  Computed summary of workout statistics
//

import Foundation

// MARK: - Workout Summary

/// Computed summary of workout statistics - derived automatically, no user input required
struct WorkoutSummary {
    let duration: TimeInterval?
    let totalExercises: Int
    let totalSets: Int
    let totalVolume: Double
    let totalReps: Int

    init(workout: Workout) {
        // Duration: only available if both start and end times exist
        if let start = workout.startTime, let end = workout.endTime {
            self.duration = end.timeIntervalSince(start)
        } else if let start = workout.startTime {
            // Active workout - duration from start until now
            self.duration = Date().timeIntervalSince(start)
        } else {
            self.duration = nil
        }

        let exercisesList = workout.exercises ?? []
        self.totalExercises = exercisesList.count
        self.totalSets = exercisesList.reduce(0) { $0 + ($1.sets ?? []).count }
        self.totalReps = exercisesList.reduce(0) { $0 + $1.totalReps }

        // Volume = sum of (weight × reps) for all sets
        self.totalVolume = exercisesList.reduce(0.0) { exerciseSum, exercise in
            exerciseSum + (exercise.sets ?? []).reduce(0.0) { setSum, set in
                setSum + (set.weight * Double(set.reps))
            }
        }
    }

    // MARK: - Formatted Outputs

    /// Duration formatted as "Xh Ym" or "Xm Ys"
    var formattedDuration: String {
        guard let duration = duration else { return "--" }

        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        let seconds = Int(duration) % 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        } else {
            return "\(seconds)s"
        }
    }

    /// Duration in minutes (for calculations)
    var durationMinutes: Int {
        guard let duration = duration else { return 0 }
        return Int(duration / 60)
    }

    /// Volume formatted with units
    var formattedVolume: String {
        let displayVolume = UnitFormatter.convertToDisplay(totalVolume)
        if displayVolume >= 1000 {
            return String(format: "%.1fk %@", displayVolume / 1000, UnitFormatter.weightUnit)
        } else {
            return String(format: "%.0f %@", displayVolume, UnitFormatter.weightUnit)
        }
    }

    /// Quick summary string
    var quickSummary: String {
        "\(totalExercises) exercises · \(totalSets) sets · \(formattedDuration)"
    }

    /// Check if summary has meaningful data
    var isEmpty: Bool {
        totalExercises == 0 && totalSets == 0
    }
}
