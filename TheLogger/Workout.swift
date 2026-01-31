//
//  Workout.swift
//  TheLogger
//
//  Model representing a complete workout session
//

import Foundation
import SwiftData
import UIKit
import SwiftUI

// MARK: - Unit System

enum UnitSystem: String, CaseIterable, Identifiable {
    case imperial = "Imperial"
    case metric = "Metric"
    
    var id: String { rawValue }
    
    var weightUnit: String {
        switch self {
        case .imperial: return "lbs"
        case .metric: return "kg"
        }
    }
    
    var weightUnitFull: String {
        switch self {
        case .imperial: return "pounds"
        case .metric: return "kilograms"
        }
    }
}

/// Global unit formatting helper
struct UnitFormatter {
    /// Current unit system from UserDefaults
    static var currentSystem: UnitSystem {
        let stored = UserDefaults.standard.string(forKey: "unitSystem") ?? "Imperial"
        return UnitSystem(rawValue: stored) ?? .imperial
    }
    
    /// Format weight for display with unit
    static func formatWeight(_ weight: Double, showUnit: Bool = true) -> String {
        let displayWeight = convertToDisplay(weight)
        if showUnit {
            return String(format: "%.1f %@", displayWeight, currentSystem.weightUnit)
        }
        return String(format: "%.1f", displayWeight)
    }
    
    /// Format weight without decimals
    static func formatWeightCompact(_ weight: Double, showUnit: Bool = true) -> String {
        let displayWeight = convertToDisplay(weight)
        if showUnit {
            return String(format: "%.0f %@", displayWeight, currentSystem.weightUnit)
        }
        return String(format: "%.0f", displayWeight)
    }
    
    /// Convert stored weight (always in lbs) to display unit
    static func convertToDisplay(_ weightInLbs: Double) -> Double {
        switch currentSystem {
        case .imperial:
            return weightInLbs
        case .metric:
            return weightInLbs * 0.453592  // lbs to kg
        }
    }
    
    /// Convert display weight to storage (always lbs)
    static func convertToStorage(_ displayWeight: Double) -> Double {
        switch currentSystem {
        case .imperial:
            return displayWeight
        case .metric:
            return displayWeight / 0.453592  // kg to lbs
        }
    }
    
    /// Get the weight unit abbreviation
    static var weightUnit: String {
        currentSystem.weightUnit
    }
}

/// Environment key for unit system
struct UnitSystemKey: EnvironmentKey {
    static let defaultValue: UnitSystem = .imperial
}

extension EnvironmentValues {
    var unitSystem: UnitSystem {
        get { self[UnitSystemKey.self] }
        set { self[UnitSystemKey.self] = newValue }
    }
}

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
        self.name = name.isEmpty ? Self.defaultName(for: date, exercises: exercises) : name
        self.date = date
        self.startTime = nil
        self.endTime = nil
        self.isTemplate = isTemplate
        self.exercises = exercises
    }
    
    /// Generate smart default name based on time of day or exercises
    private static func defaultName(for date: Date, exercises: [Exercise] = []) -> String {
        // If exercises exist, use first exercise name
        if let firstExercise = exercises.first, !firstExercise.name.isEmpty {
            return "\(firstExercise.name) Workout"
        }
        
        // Otherwise, use time-based naming
        let hour = Calendar.current.component(.hour, from: date)
        let formatter = DateFormatter()
        
        switch hour {
        case 5..<12:
            formatter.dateStyle = .none
            formatter.timeStyle = .none
            return "Morning Workout"
        case 12..<17:
            formatter.dateStyle = .none
            formatter.timeStyle = .none
            return "Afternoon Workout"
        case 17..<22:
            formatter.dateStyle = .none
            formatter.timeStyle = .none
            return "Evening Workout"
        default:
            formatter.dateStyle = .none
            formatter.timeStyle = .none
            return "Night Workout"
        }
    }
    
    /// Update workout name based on exercises (smart naming)
    func updateNameFromExercises() {
        // Only auto-update if name is still the default timestamp format
        let timestampPattern = #"^[A-Z][a-z]{2} \d{1,2}, \d{4}, \d{1,2}:\d{2} [AP]M$"#
        let isDefaultName = name.range(of: timestampPattern, options: .regularExpression) != nil
        
        if isDefaultName || name.isEmpty {
            if let firstExercise = exercises.first, !firstExercise.name.isEmpty {
                name = "\(firstExercise.name) Workout"
            } else if exercises.count > 1 {
                // Multiple exercises - use workout type
                name = detectWorkoutType()
            }
        }
    }
    
    /// Detect workout type from exercises
    private func detectWorkoutType() -> String {
        let exerciseNames = exercises.map { $0.name.lowercased() }
        
        // Check for common patterns
        let pushExercises = ["bench", "press", "shoulder", "tricep", "chest", "push"]
        let pullExercises = ["pull", "row", "lat", "bicep", "back", "deadlift"]
        let legExercises = ["squat", "leg", "calf", "lunge", "hip", "thrust"]
        
        let pushCount = exerciseNames.filter { name in
            pushExercises.contains { name.contains($0) }
        }.count
        
        let pullCount = exerciseNames.filter { name in
            pullExercises.contains { name.contains($0) }
        }.count
        
        let legCount = exerciseNames.filter { name in
            legExercises.contains { name.contains($0) }
        }.count
        
        if pushCount > pullCount && pushCount > legCount {
            return "Push Day"
        } else if pullCount > pushCount && pullCount > legCount {
            return "Pull Day"
        } else if legCount > pushCount && legCount > pullCount {
            return "Leg Day"
        } else if pushCount > 0 && pullCount > 0 {
            return "Upper Body"
        } else if legCount > 0 && (pushCount > 0 || pullCount > 0) {
            return "Full Body"
        }
        
        return "Workout"
    }
    
    /// Add a new exercise to this workout
    func addExercise(name: String) {
        let newExercise = Exercise(name: name)
        exercises.append(newExercise)
        // Auto-update name if it's still default
        updateNameFromExercises()
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

// MARK: - Data Export

struct WorkoutDataExporter {
    
    /// Generate CSV content from workout history
    static func generateCSV(from workouts: [Workout]) -> String {
        var csv = "Workout Date,Workout Name,Exercise,Set Number,Reps,Weight (lbs)\n"
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .short
        dateFormatter.timeStyle = .short
        
        // Only export completed workouts (not templates)
        let completedWorkouts = workouts
            .filter { !$0.isTemplate && $0.endTime != nil }
            .sorted { $0.date > $1.date }
        
        for workout in completedWorkouts {
            let dateString = dateFormatter.string(from: workout.date)
            let workoutName = escapeCSV(workout.name)
            
            for exercise in workout.exercises {
                let exerciseName = escapeCSV(exercise.name)
                
                for (index, set) in exercise.setsByOrder.enumerated() {
                    let setNumber = index + 1
                    csv += "\(dateString),\(workoutName),\(exerciseName),\(setNumber),\(set.reps),\(set.weight)\n"
                }
            }
        }
        
        return csv
    }
    
    /// Generate summary statistics
    static func generateStats(from workouts: [Workout]) -> ExportStats {
        let completed = workouts.filter { !$0.isTemplate && $0.endTime != nil }
        
        let totalWorkouts = completed.count
        let totalExercises = completed.reduce(0) { $0 + $1.exercises.count }
        let totalSets = completed.reduce(0) { $0 + $1.totalSets }
        
        let firstDate = completed.map { $0.date }.min()
        let lastDate = completed.map { $0.date }.max()
        
        return ExportStats(
            totalWorkouts: totalWorkouts,
            totalExercises: totalExercises,
            totalSets: totalSets,
            firstWorkoutDate: firstDate,
            lastWorkoutDate: lastDate
        )
    }
    
    private static func escapeCSV(_ string: String) -> String {
        if string.contains(",") || string.contains("\"") || string.contains("\n") {
            let escaped = string.replacingOccurrences(of: "\"", with: "\"\"")
            return "\"\(escaped)\""
        }
        return string
    }
}

struct ExportStats {
    let totalWorkouts: Int
    let totalExercises: Int
    let totalSets: Int
    let firstWorkoutDate: Date?
    let lastWorkoutDate: Date?
    
    var dateRangeString: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        
        guard let first = firstWorkoutDate, let last = lastWorkoutDate else {
            return "No workouts yet"
        }
        
        if Calendar.current.isDate(first, inSameDayAs: last) {
            return formatter.string(from: first)
        }
        
        return "\(formatter.string(from: first)) – \(formatter.string(from: last))"
    }
}

// MARK: - Exercise Library

enum MuscleGroup: String, CaseIterable, Identifiable {
    case chest = "Chest"
    case back = "Back"
    case shoulders = "Shoulders"
    case arms = "Arms"
    case legs = "Legs"
    case core = "Core"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .chest: return "figure.arms.open"
        case .back: return "figure.walk"
        case .shoulders: return "figure.boxing"
        case .arms: return "figure.strengthtraining.traditional"
        case .legs: return "figure.run"
        case .core: return "figure.core.training"
        }
    }
}

struct LibraryExercise: Identifiable, Hashable {
    let id: String
    let name: String
    let muscleGroup: MuscleGroup
    let isCompound: Bool
    
    var normalizedName: String {
        name.lowercased().trimmingCharacters(in: .whitespaces)
    }
}

struct ExerciseLibrary {
    static let shared = ExerciseLibrary()
    
    let exercises: [LibraryExercise]
    
    private init() {
        exercises = Self.buildLibrary()
    }
    
    /// Get exercises grouped by muscle group
    var groupedByMuscle: [MuscleGroup: [LibraryExercise]] {
        Dictionary(grouping: exercises, by: { $0.muscleGroup })
    }
    
    /// Search exercises by name
    func search(_ query: String) -> [LibraryExercise] {
        guard !query.isEmpty else { return exercises }
        let q = query.lowercased()
        return exercises.filter { $0.normalizedName.contains(q) }
    }
    
    /// Find exercise by name
    func find(name: String) -> LibraryExercise? {
        let normalized = name.lowercased().trimmingCharacters(in: .whitespaces)
        return exercises.first { $0.normalizedName == normalized }
    }
    
    /// Get suggested rest duration
    func restDuration(for exerciseName: String) -> Int {
        if let exercise = find(name: exerciseName) {
            return exercise.isCompound ? 120 : 60
        }
        // Fallback heuristics
        let name = exerciseName.lowercased()
        let compoundKeywords = ["squat", "deadlift", "bench", "press", "row", "pull-up", "pullup", "chin-up", "chinup", "dip", "clean", "snatch", "thrust", "lunge"]
        for keyword in compoundKeywords {
            if name.contains(keyword) { return 120 }
        }
        return 60
    }
    
    private static func buildLibrary() -> [LibraryExercise] {
        var list: [LibraryExercise] = []
        
        // CHEST
        list.append(contentsOf: [
            LibraryExercise(id: "bench-press", name: "Bench Press", muscleGroup: .chest, isCompound: true),
            LibraryExercise(id: "incline-bench-press", name: "Incline Bench Press", muscleGroup: .chest, isCompound: true),
            LibraryExercise(id: "decline-bench-press", name: "Decline Bench Press", muscleGroup: .chest, isCompound: true),
            LibraryExercise(id: "dumbbell-bench-press", name: "Dumbbell Bench Press", muscleGroup: .chest, isCompound: true),
            LibraryExercise(id: "incline-dumbbell-press", name: "Incline Dumbbell Press", muscleGroup: .chest, isCompound: true),
            LibraryExercise(id: "chest-fly", name: "Chest Fly", muscleGroup: .chest, isCompound: false),
            LibraryExercise(id: "cable-fly", name: "Cable Fly", muscleGroup: .chest, isCompound: false),
            LibraryExercise(id: "pec-deck", name: "Pec Deck", muscleGroup: .chest, isCompound: false),
            LibraryExercise(id: "push-up", name: "Push-Up", muscleGroup: .chest, isCompound: true),
            LibraryExercise(id: "dips-chest", name: "Dips (Chest)", muscleGroup: .chest, isCompound: true),
        ])
        
        // BACK
        list.append(contentsOf: [
            LibraryExercise(id: "deadlift", name: "Deadlift", muscleGroup: .back, isCompound: true),
            LibraryExercise(id: "barbell-row", name: "Barbell Row", muscleGroup: .back, isCompound: true),
            LibraryExercise(id: "dumbbell-row", name: "Dumbbell Row", muscleGroup: .back, isCompound: true),
            LibraryExercise(id: "pull-up", name: "Pull-Up", muscleGroup: .back, isCompound: true),
            LibraryExercise(id: "chin-up", name: "Chin-Up", muscleGroup: .back, isCompound: true),
            LibraryExercise(id: "lat-pulldown", name: "Lat Pulldown", muscleGroup: .back, isCompound: true),
            LibraryExercise(id: "seated-cable-row", name: "Seated Cable Row", muscleGroup: .back, isCompound: true),
            LibraryExercise(id: "t-bar-row", name: "T-Bar Row", muscleGroup: .back, isCompound: true),
            LibraryExercise(id: "face-pull", name: "Face Pull", muscleGroup: .back, isCompound: false),
            LibraryExercise(id: "straight-arm-pulldown", name: "Straight Arm Pulldown", muscleGroup: .back, isCompound: false),
            LibraryExercise(id: "rack-pull", name: "Rack Pull", muscleGroup: .back, isCompound: true),
            LibraryExercise(id: "romanian-deadlift", name: "Romanian Deadlift", muscleGroup: .back, isCompound: true),
        ])
        
        // SHOULDERS
        list.append(contentsOf: [
            LibraryExercise(id: "overhead-press", name: "Overhead Press", muscleGroup: .shoulders, isCompound: true),
            LibraryExercise(id: "seated-dumbbell-press", name: "Seated Dumbbell Press", muscleGroup: .shoulders, isCompound: true),
            LibraryExercise(id: "arnold-press", name: "Arnold Press", muscleGroup: .shoulders, isCompound: true),
            LibraryExercise(id: "lateral-raise", name: "Lateral Raise", muscleGroup: .shoulders, isCompound: false),
            LibraryExercise(id: "front-raise", name: "Front Raise", muscleGroup: .shoulders, isCompound: false),
            LibraryExercise(id: "rear-delt-fly", name: "Rear Delt Fly", muscleGroup: .shoulders, isCompound: false),
            LibraryExercise(id: "upright-row", name: "Upright Row", muscleGroup: .shoulders, isCompound: true),
            LibraryExercise(id: "shrugs", name: "Shrugs", muscleGroup: .shoulders, isCompound: false),
            LibraryExercise(id: "cable-lateral-raise", name: "Cable Lateral Raise", muscleGroup: .shoulders, isCompound: false),
        ])
        
        // ARMS
        list.append(contentsOf: [
            LibraryExercise(id: "barbell-curl", name: "Barbell Curl", muscleGroup: .arms, isCompound: false),
            LibraryExercise(id: "dumbbell-curl", name: "Dumbbell Curl", muscleGroup: .arms, isCompound: false),
            LibraryExercise(id: "hammer-curl", name: "Hammer Curl", muscleGroup: .arms, isCompound: false),
            LibraryExercise(id: "preacher-curl", name: "Preacher Curl", muscleGroup: .arms, isCompound: false),
            LibraryExercise(id: "concentration-curl", name: "Concentration Curl", muscleGroup: .arms, isCompound: false),
            LibraryExercise(id: "cable-curl", name: "Cable Curl", muscleGroup: .arms, isCompound: false),
            LibraryExercise(id: "tricep-pushdown", name: "Tricep Pushdown", muscleGroup: .arms, isCompound: false),
            LibraryExercise(id: "tricep-dips", name: "Tricep Dips", muscleGroup: .arms, isCompound: true),
            LibraryExercise(id: "skull-crushers", name: "Skull Crushers", muscleGroup: .arms, isCompound: false),
            LibraryExercise(id: "overhead-tricep-extension", name: "Overhead Tricep Extension", muscleGroup: .arms, isCompound: false),
            LibraryExercise(id: "close-grip-bench-press", name: "Close Grip Bench Press", muscleGroup: .arms, isCompound: true),
            LibraryExercise(id: "wrist-curl", name: "Wrist Curl", muscleGroup: .arms, isCompound: false),
        ])
        
        // LEGS
        list.append(contentsOf: [
            LibraryExercise(id: "squat", name: "Squat", muscleGroup: .legs, isCompound: true),
            LibraryExercise(id: "front-squat", name: "Front Squat", muscleGroup: .legs, isCompound: true),
            LibraryExercise(id: "leg-press", name: "Leg Press", muscleGroup: .legs, isCompound: true),
            LibraryExercise(id: "hack-squat", name: "Hack Squat", muscleGroup: .legs, isCompound: true),
            LibraryExercise(id: "goblet-squat", name: "Goblet Squat", muscleGroup: .legs, isCompound: true),
            LibraryExercise(id: "lunges", name: "Lunges", muscleGroup: .legs, isCompound: true),
            LibraryExercise(id: "bulgarian-split-squat", name: "Bulgarian Split Squat", muscleGroup: .legs, isCompound: true),
            LibraryExercise(id: "leg-extension", name: "Leg Extension", muscleGroup: .legs, isCompound: false),
            LibraryExercise(id: "leg-curl", name: "Leg Curl", muscleGroup: .legs, isCompound: false),
            LibraryExercise(id: "hip-thrust", name: "Hip Thrust", muscleGroup: .legs, isCompound: true),
            LibraryExercise(id: "glute-bridge", name: "Glute Bridge", muscleGroup: .legs, isCompound: false),
            LibraryExercise(id: "calf-raise", name: "Calf Raise", muscleGroup: .legs, isCompound: false),
            LibraryExercise(id: "seated-calf-raise", name: "Seated Calf Raise", muscleGroup: .legs, isCompound: false),
            LibraryExercise(id: "sumo-deadlift", name: "Sumo Deadlift", muscleGroup: .legs, isCompound: true),
            LibraryExercise(id: "step-ups", name: "Step-Ups", muscleGroup: .legs, isCompound: true),
        ])
        
        // CORE
        list.append(contentsOf: [
            LibraryExercise(id: "plank", name: "Plank", muscleGroup: .core, isCompound: false),
            LibraryExercise(id: "crunches", name: "Crunches", muscleGroup: .core, isCompound: false),
            LibraryExercise(id: "leg-raise", name: "Leg Raise", muscleGroup: .core, isCompound: false),
            LibraryExercise(id: "hanging-leg-raise", name: "Hanging Leg Raise", muscleGroup: .core, isCompound: false),
            LibraryExercise(id: "russian-twist", name: "Russian Twist", muscleGroup: .core, isCompound: false),
            LibraryExercise(id: "cable-crunch", name: "Cable Crunch", muscleGroup: .core, isCompound: false),
            LibraryExercise(id: "ab-wheel-rollout", name: "Ab Wheel Rollout", muscleGroup: .core, isCompound: false),
            LibraryExercise(id: "dead-bug", name: "Dead Bug", muscleGroup: .core, isCompound: false),
            LibraryExercise(id: "mountain-climbers", name: "Mountain Climbers", muscleGroup: .core, isCompound: false),
            LibraryExercise(id: "woodchop", name: "Woodchop", muscleGroup: .core, isCompound: false),
        ])
        
        return list.sorted { $0.name < $1.name }
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

// MARK: - Personal Record

/// Model for tracking personal records (PRs) per exercise
@Model
final class PersonalRecord {
    var exerciseName: String  // Normalized exercise name
    var weight: Double        // Weight in lbs (storage unit)
    var reps: Int             // Reps at that weight
    var date: Date            // When the PR was set
    var workoutId: UUID       // Which workout it was set in
    
    init(exerciseName: String, weight: Double, reps: Int, date: Date = Date(), workoutId: UUID) {
        self.exerciseName = exerciseName.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        self.weight = weight
        self.reps = reps
        self.date = date
        self.workoutId = workoutId
    }
    
    /// Estimated 1RM using Brzycki formula
    var estimated1RM: Double {
        guard reps > 0 && reps <= 10 else { return weight }
        return weight * (36.0 / (37.0 - Double(reps)))
    }
    
    /// Formatted display string
    var displayString: String {
        "\(UnitFormatter.formatWeightCompact(weight)) × \(reps)"
    }
}

/// Manager for detecting and saving personal records
struct PersonalRecordManager {
    
    /// Check if a set is a new PR and save it if so
    /// Returns true if a new PR was set
    @discardableResult
    static func checkAndSavePR(
        exerciseName: String,
        weight: Double,
        reps: Int,
        workoutId: UUID,
        modelContext: ModelContext,
        setType: SetType = .working
    ) -> Bool {
        let normalizedName = exerciseName.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Only consider valid working sets (weight > 0, reps > 0, not warmup)
        guard weight > 0, reps > 0, setType == .working else {
            #if DEBUG
            print("[PR] checkAndSavePR SKIP guard weight=\(weight) reps=\(reps) setType=\(setType)")
            #endif
            return false
        }
        
        // Fetch existing PR for this exercise
        let descriptor = FetchDescriptor<PersonalRecord>(
            predicate: #Predicate { $0.exerciseName == normalizedName }
        )
        
        let existingPRs = (try? modelContext.fetch(descriptor)) ?? []
        
        // Calculate estimated 1RM for new set
        let newEstimated1RM = calculateEstimated1RM(weight: weight, reps: reps)
        
        // Check if this beats existing PR
        if let existingPR = existingPRs.first {
            let existing1RM = existingPR.estimated1RM
            
            if newEstimated1RM > existing1RM {
                // New PR! Update the record
                existingPR.weight = weight
                existingPR.reps = reps
                existingPR.date = Date()
                existingPR.workoutId = workoutId
                
                try? modelContext.save()
                #if DEBUG
                print("[PR] checkAndSavePR UPDATED \(normalizedName) -> \(weight)x\(reps) 1RM \(existing1RM)->\(newEstimated1RM)")
                #endif
                return true
            }
            #if DEBUG
            print("[PR] checkAndSavePR NO beat \(normalizedName) new1RM=\(newEstimated1RM) existing1RM=\(existing1RM)")
            #endif
        } else {
            // First time logging this exercise - create PR
            let newPR = PersonalRecord(
                exerciseName: normalizedName,
                weight: weight,
                reps: reps,
                workoutId: workoutId
            )
            modelContext.insert(newPR)
            try? modelContext.save()
            #if DEBUG
            print("[PR] checkAndSavePR NEW \(normalizedName) \(weight)x\(reps) 1RM=\(newEstimated1RM)")
            #endif
            return true
        }
        
        return false
    }
    
    /// Get PR for an exercise
    static func getPR(for exerciseName: String, modelContext: ModelContext) -> PersonalRecord? {
        let normalizedName = exerciseName.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        let descriptor = FetchDescriptor<PersonalRecord>(
            predicate: #Predicate { $0.exerciseName == normalizedName }
        )
        
        return try? modelContext.fetch(descriptor).first
    }
    
    /// Calculate estimated 1RM using Brzycki formula
    private static func calculateEstimated1RM(weight: Double, reps: Int) -> Double {
        guard reps > 0 && reps <= 10 else { return weight }
        return weight * (36.0 / (37.0 - Double(reps)))
    }
    
    /// Check all sets in a workout for PRs (call when workout ends)
    static func processWorkoutForPRs(workout: Workout, modelContext: ModelContext) -> [String] {
        var newPRExercises: [String] = []
        
        for exercise in workout.exercises {
            for set in exercise.sets {
                if checkAndSavePR(
                    exerciseName: exercise.name,
                    weight: set.weight,
                    reps: set.reps,
                    workoutId: workout.id,
                    modelContext: modelContext,
                    setType: set.type
                ) {
                    if !newPRExercises.contains(exercise.name) {
                        newPRExercises.append(exercise.name)
                    }
                }
            }
        }
        
        return newPRExercises
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
                parts.append("+\(UnitFormatter.formatWeight(dw))")
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

// MARK: - Rest Timer Manager

/// Observable timer manager for rest periods between sets
@Observable
final class RestTimerManager {
    static let shared = RestTimerManager()
    
    // Timer state
    var isActive: Bool = false
    var remainingSeconds: Int = 0
    var totalSeconds: Int = 90  // Default rest time
    var isComplete: Bool = false
    
    // "Ready to start" state - shows rest option button
    var showRestOption: Bool = false
    var suggestedDuration: Int = 90
    
    // Track which exercise the timer is for
    var activeExerciseId: UUID?
    
    // Background handling
    private var backgroundTime: Date?
    private var timer: Timer?
    
    private init() {
        setupBackgroundObservers()
    }
    
    // MARK: - Public API

    /// Show rest option after a set is logged
    /// - Parameters:
    ///   - exerciseId: The exercise this rest is for
    ///   - duration: Suggested rest duration in seconds (nil = use user's setting)
    ///   - autoStart: If true, timer starts immediately instead of showing option
    func offerRest(for exerciseId: UUID, duration: Int? = nil, autoStart: Bool = false) {
        // Don't interrupt an active timer
        guard !isActive else { return }

        activeExerciseId = exerciseId
        // Use provided duration, or user's setting, or fallback to 90
        let userDefault = UserDefaults.standard.integer(forKey: "defaultRestSeconds")
        suggestedDuration = duration ?? (userDefault > 0 ? userDefault : 90)
        isComplete = false

        if autoStart {
            // Start immediately
            showRestOption = false
            start()
        } else {
            // Show option button
            showRestOption = true
        }
    }
    
    /// Start the timer (user initiated)
    func start() {
        guard let exerciseId = activeExerciseId else { return }
        
        showRestOption = false
        totalSeconds = suggestedDuration
        remainingSeconds = suggestedDuration
        isActive = true
        isComplete = false
        
        startTimer()
    }
    
    /// Start with specific duration
    func start(for exerciseId: UUID, duration: Int) {
        stop()
        
        activeExerciseId = exerciseId
        totalSeconds = duration
        remainingSeconds = duration
        isActive = true
        isComplete = false
        showRestOption = false
        
        startTimer()
    }
    
    /// Stop and hide everything
    func stop() {
        timer?.invalidate()
        timer = nil
        isActive = false
        isComplete = false
        showRestOption = false
        activeExerciseId = nil
    }
    
    /// Dismiss rest option without starting timer
    func dismiss() {
        showRestOption = false
        if !isActive {
            activeExerciseId = nil
        }
    }
    
    /// Adjust suggested duration when offering rest (before start). Clamped 15–600 seconds.
    func adjustSuggestedDuration(delta: Int) {
        guard showRestOption, !isActive else { return }
        suggestedDuration = min(600, max(15, suggestedDuration + delta))
    }
    
    /// Set suggested duration when offering rest. Clamped 15–600 seconds.
    func setSuggestedDuration(_ seconds: Int) {
        guard showRestOption, !isActive else { return }
        suggestedDuration = min(600, max(15, seconds))
    }
    
    /// Add seconds to remaining time when timer is active.
    func addSeconds(_ n: Int) {
        guard isActive, n > 0 else { return }
        remainingSeconds = min(600, remainingSeconds + n)
        totalSeconds = max(totalSeconds, remainingSeconds)
    }
    
    /// Skip the current rest period
    func skip() {
        stop()
    }
    
    /// Pause timer (when user starts adding a set)
    func pause() {
        timer?.invalidate()
        timer = nil
        // Also hide rest option when user starts adding
        showRestOption = false
    }
    
    /// Resume timer after pause
    func resume() {
        guard isActive && remainingSeconds > 0 else { return }
        startTimer()
    }
    
    /// Check if should show anything for this exercise
    func shouldShowFor(exerciseId: UUID) -> Bool {
        activeExerciseId == exerciseId && (showRestOption || isActive)
    }
    
    /// Check if timer is actively running for a specific exercise
    func isActiveFor(exerciseId: UUID) -> Bool {
        isActive && activeExerciseId == exerciseId
    }
    
    /// Check if showing rest option for a specific exercise
    func isOfferingRestFor(exerciseId: UUID) -> Bool {
        showRestOption && activeExerciseId == exerciseId && !isActive
    }
    
    // MARK: - Progress
    
    /// Progress from 0.0 to 1.0
    var progress: Double {
        guard totalSeconds > 0 else { return 0 }
        return 1.0 - (Double(remainingSeconds) / Double(totalSeconds))
    }
    
    /// Formatted time string (mm:ss)
    var formattedTime: String {
        let minutes = remainingSeconds / 60
        let seconds = remainingSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    // MARK: - Private
    
    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }
    
    private func tick() {
        guard remainingSeconds > 0 else {
            complete()
            return
        }
        remainingSeconds -= 1
        
        if remainingSeconds == 0 {
            complete()
        }
    }
    
    private func complete() {
        // Guard against double-completion
        guard isActive && !isComplete else { return }

        timer?.invalidate()
        timer = nil
        isComplete = true

        // Haptic feedback when timer completes
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)

        // Auto-dismiss after 2 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            guard let self = self, self.isComplete else { return }
            self.stop()
        }
    }
    
    // MARK: - Background Handling
    
    private func setupBackgroundObservers() {
        NotificationCenter.default.addObserver(
            forName: UIApplication.willResignActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleBackground()
        }
        
        NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleForeground()
        }
    }
    
    private func handleBackground() {
        guard isActive else { return }
        backgroundTime = Date()
        timer?.invalidate()
        timer = nil
    }
    
    private func handleForeground() {
        guard isActive, !isComplete, let backgroundTime = backgroundTime else { return }

        let elapsed = Int(Date().timeIntervalSince(backgroundTime))
        remainingSeconds = max(0, remainingSeconds - elapsed)
        self.backgroundTime = nil

        if remainingSeconds > 0 {
            startTimer()
        } else {
            complete()
        }
    }
}

