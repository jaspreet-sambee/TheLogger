//
//  Workout.swift
//  TheLogger
//
//  Model representing a complete workout session
//

import Foundation
import SwiftData

@Model
final class Workout: Identifiable {
    var id: UUID
    var name: String = ""
    var date: Date
    var startTime: Date?
    var endTime: Date?
    var isTemplate: Bool = false  // True for reusable templates, false for workout history
    @Relationship(deleteRule: .cascade) var exercises: [Exercise]
    
    init(id: UUID = UUID(), name: String = "", date: Date = Date(), exercises: [Exercise] = [], isTemplate: Bool = false) {
        self.id = id
        self.name = name.isEmpty ? Self.defaultName(for: date) : name
        self.date = date
        self.startTime = nil
        self.endTime = nil
        self.isTemplate = isTemplate
        self.exercises = exercises
    }
    
    /// Generate default name from date
    private static func defaultName(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    /// Add a new exercise to this workout
    func addExercise(name: String) {
        let newExercise = Exercise(name: name)
        exercises.append(newExercise)
    }
    
    /// Remove an exercise by ID
    func removeExercise(id: UUID) {
        exercises.removeAll { $0.id == id }
    }
    
    /// Get exercise by ID
    func getExercise(id: UUID) -> Exercise? {
        exercises.first { $0.id == id }
    }
    
    /// Get total number of exercises
    var exerciseCount: Int {
        exercises.count
    }
    
    /// Get total number of sets across all exercises
    var totalSets: Int {
        exercises.reduce(0) { $0 + $1.sets.count }
    }
    
    /// Formatted date string
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    /// Check if workout is currently active
    var isActive: Bool {
        startTime != nil && endTime == nil
    }
    
    /// Check if workout is completed (has endTime)
    var isCompleted: Bool {
        endTime != nil
    }
    
    /// Check if workout is a template (reusable structure)
    var isWorkoutTemplate: Bool {
        isTemplate
    }
    
    /// Formatted start time string
    var formattedStartTime: String {
        guard let startTime = startTime else { return "" }
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: startTime)
    }
    
    /// Computed summary of workout stats (available after workout ends)
    var summary: WorkoutSummary {
        WorkoutSummary(workout: self)
    }
}

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
        
        self.totalExercises = workout.exercises.count
        self.totalSets = workout.exercises.reduce(0) { $0 + $1.sets.count }
        self.totalReps = workout.exercises.reduce(0) { $0 + $1.totalReps }
        
        // Volume = sum of (weight × reps) for all sets
        self.totalVolume = workout.exercises.reduce(0.0) { exerciseSum, exercise in
            exerciseSum + exercise.sets.reduce(0.0) { setSum, set in
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
        if totalVolume >= 1000 {
            return String(format: "%.1fk lbs", totalVolume / 1000)
        } else {
            return String(format: "%.0f lbs", totalVolume)
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

// MARK: - Exercise Memory
// Persistent storage for user's exercise history

@Model
final class ExerciseMemory {
    var name: String
    var lastReps: Int
    var lastWeight: Double
    var lastSets: Int
    var lastUpdated: Date
    var note: String?
    
    init(name: String, lastReps: Int = 10, lastWeight: Double = 0, lastSets: Int = 1, lastUpdated: Date = Date(), note: String? = nil) {
        self.name = name
        self.lastReps = lastReps
        self.lastWeight = lastWeight
        self.lastSets = lastSets
        self.lastUpdated = lastUpdated
        self.note = note
    }
    
    /// Normalized name for comparison (lowercase, trimmed)
    var normalizedName: String {
        name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    /// Update memory with new exercise data
    func update(reps: Int, weight: Double, sets: Int, note: String? = nil) {
        self.lastReps = reps
        self.lastWeight = weight
        self.lastSets = sets
        self.lastUpdated = Date()
        if let note = note {
            self.note = note.isEmpty ? nil : note
        }
    }
    
    /// Update note only
    func updateNote(_ note: String?) {
        self.note = note?.isEmpty == true ? nil : note
        self.lastUpdated = Date()
    }
}

// MARK: - Exercise Progress Comparison

/// Represents the comparison result between current and previous exercise performance
enum ExerciseProgressComparison: Equatable {
    case firstTime
    case improved(deltaWeight: Double?, deltaReps: Int?)
    case matched
    case regressed
    
    /// Human-readable description
    var displayText: String {
        switch self {
        case .firstTime:
            return "First time"
        case .improved(let deltaWeight, let deltaReps):
            var parts: [String] = []
            if let dw = deltaWeight, dw > 0 {
                parts.append("+\(String(format: "%.1f", dw)) lbs")
            }
            if let dr = deltaReps, dr > 0 {
                parts.append("+\(dr) reps")
            }
            return parts.isEmpty ? "Improved" : parts.joined(separator: ", ")
        case .matched:
            return "Matched last time"
        case .regressed:
            return "Below previous"
        }
    }
    
    /// Whether this represents positive progress
    var isPositive: Bool {
        switch self {
        case .firstTime, .improved, .matched:
            return true
        case .regressed:
            return false
        }
    }
}

/// Calculator for exercise progress comparison - keeps logic outside View layer
struct ExerciseProgressCalculator {
    
    /// Represents a single set's performance value
    struct SetPerformance: Comparable {
        let weight: Double
        let reps: Int
        
        /// Performance score: weight × reps
        var score: Double {
            weight * Double(reps)
        }
        
        static func < (lhs: SetPerformance, rhs: SetPerformance) -> Bool {
            lhs.score < rhs.score
        }
    }
    
    /// Compare current exercise against the most recent past workout with the same exercise
    /// - Parameters:
    ///   - exercise: The current exercise instance
    ///   - currentWorkoutId: ID of the active workout (to exclude from comparison)
    ///   - completedWorkouts: All completed workouts (sorted by date, most recent first)
    /// - Returns: The comparison result
    static func compare(
        exercise: Exercise,
        currentWorkoutId: UUID,
        completedWorkouts: [Workout]
    ) -> ExerciseProgressComparison {
        
        let normalizedName = exercise.name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Find the most recent completed workout (not current, not template) with this exercise
        guard let previousWorkout = completedWorkouts.first(where: { workout in
            workout.id != currentWorkoutId &&
            !workout.isTemplate &&
            workout.endTime != nil &&
            workout.exercises.contains { ex in
                ex.name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) == normalizedName
            }
        }) else {
            return .firstTime
        }
        
        // Find the matching exercise in the previous workout
        guard let previousExercise = previousWorkout.exercises.first(where: { ex in
            ex.name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) == normalizedName
        }) else {
            return .firstTime
        }
        
        // Get best set from previous exercise (ignoring sets with 0 reps as "incomplete")
        let previousSets = previousExercise.sets.filter { $0.reps > 0 }
        guard let previousBest = previousSets.map({ SetPerformance(weight: $0.weight, reps: $0.reps) }).max() else {
            return .firstTime
        }
        
        // Get best set from current exercise
        let currentSets = exercise.sets.filter { $0.reps > 0 }
        guard let currentBest = currentSets.map({ SetPerformance(weight: $0.weight, reps: $0.reps) }).max() else {
            // No completed sets yet in current workout
            return .firstTime
        }
        
        // Compare
        return comparePerformance(current: currentBest, previous: previousBest)
    }
    
    /// Compare two set performances and return the result
    private static func comparePerformance(
        current: SetPerformance,
        previous: SetPerformance
    ) -> ExerciseProgressComparison {
        
        let weightDelta = current.weight - previous.weight
        let repsDelta = current.reps - previous.reps
        
        // Exact match
        if current.weight == previous.weight && current.reps == previous.reps {
            return .matched
        }
        
        // Check for improvement (either weight or reps increased, without the other decreasing significantly)
        if current.score > previous.score {
            // Overall improvement
            let deltaWeight: Double? = weightDelta > 0 ? weightDelta : nil
            let deltaReps: Int? = repsDelta > 0 ? repsDelta : nil
            return .improved(deltaWeight: deltaWeight, deltaReps: deltaReps)
        }
        
        if current.score < previous.score {
            return .regressed
        }
        
        // Same score but different distribution - consider it matched
        return .matched
    }
    
    /// Get previous exercise data for display purposes
    /// - Returns: Tuple of (weight, reps, setCount) from best previous set, or nil if first time
    static func getPreviousBest(
        exerciseName: String,
        currentWorkoutId: UUID,
        completedWorkouts: [Workout]
    ) -> (weight: Double, reps: Int, totalSets: Int)? {
        
        let normalizedName = exerciseName.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard let previousWorkout = completedWorkouts.first(where: { workout in
            workout.id != currentWorkoutId &&
            !workout.isTemplate &&
            workout.endTime != nil &&
            workout.exercises.contains { ex in
                ex.name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) == normalizedName
            }
        }),
        let previousExercise = previousWorkout.exercises.first(where: { ex in
            ex.name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) == normalizedName
        }) else {
            return nil
        }
        
        let validSets = previousExercise.sets.filter { $0.reps > 0 }
        guard let bestSet = validSets.map({ SetPerformance(weight: $0.weight, reps: $0.reps) }).max() else {
            return nil
        }
        
        return (weight: bestSet.weight, reps: bestSet.reps, totalSets: validSets.count)
    }
}

