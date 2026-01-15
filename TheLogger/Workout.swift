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
}

