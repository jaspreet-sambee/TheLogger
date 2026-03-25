//
//  ExerciseMemory.swift
//  TheLogger
//
//  Persistent storage for user's exercise history
//

import Foundation
import SwiftData

// MARK: - Exercise Memory

@Model
final class ExerciseMemory {
    var name: String = ""
    var lastReps: Int = 0
    var lastWeight: Double = 0
    var lastSets: Int = 1
    /// For time-based exercises (e.g. Plank), last duration in seconds
    var lastDuration: Int?
    var lastUpdated: Date = Date()
    var note: String?
    /// Per-exercise rest timer preference. nil = use global default, true/false = explicit choice
    var restTimerEnabled: Bool?

    init(name: String, lastReps: Int = 0, lastWeight: Double = 0, lastSets: Int = 1, lastDuration: Int? = nil, lastUpdated: Date = Date(), note: String? = nil, restTimerEnabled: Bool? = nil) {
        self.name = name
        self.lastReps = lastReps
        self.lastWeight = lastWeight
        self.lastSets = lastSets
        self.lastDuration = lastDuration
        self.lastUpdated = lastUpdated
        self.note = note
        self.restTimerEnabled = restTimerEnabled
    }

    /// Normalized name for comparison (lowercase, trimmed)
    var normalizedName: String {
        name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Update memory with new exercise data
    func update(reps: Int, weight: Double, sets: Int, durationSeconds: Int? = nil, note: String? = nil) {
        self.lastReps = reps
        self.lastWeight = weight
        self.lastSets = sets
        self.lastDuration = durationSeconds
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

    /// Update rest timer preference
    func updateRestTimerEnabled(_ enabled: Bool?) {
        self.restTimerEnabled = enabled
        self.lastUpdated = Date()
    }
}
