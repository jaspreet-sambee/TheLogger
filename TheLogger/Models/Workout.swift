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
    var id: UUID = UUID()
    var name: String = ""
    var date: Date = Date()
    var startTime: Date?
    var endTime: Date?
    var isTemplate: Bool = false  // True for reusable templates, false for workout history
    @Relationship(deleteRule: .cascade, inverse: \Exercise.workout) var exercises: [Exercise]?

    init(id: UUID = UUID(), name: String = "", date: Date = Date(), exercises: [Exercise] = [], isTemplate: Bool = false) {
        self.id = id
        self.name = name.isEmpty ? Self.defaultName(for: date, exercises: exercises) : name
        self.date = date
        self.startTime = nil
        self.endTime = nil
        self.isTemplate = isTemplate
        for (index, ex) in exercises.enumerated() {
            ex.order = index
        }
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
            let exerciseList = exercises ?? []
            if exerciseList.count > 1 {
                // Multiple exercises — detect workout type (Push Day, Pull Day, Leg Day, etc.)
                name = detectWorkoutType()
            } else if let firstExercise = exerciseList.first, !firstExercise.name.isEmpty {
                // Single exercise — name after it
                name = "\(firstExercise.name) Workout"
            }
        }
    }

    /// Detect workout type from exercises
    private func detectWorkoutType() -> String {
        let exerciseNames = (exercises ?? []).map { $0.name.lowercased() }

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

    /// Exercises in display order (SwiftData relationships don't preserve order)
    var exercisesByOrder: [Exercise] {
        (exercises ?? []).sorted { $0.order < $1.order }
    }

    /// Add a new exercise to this workout
    func addExercise(name: String) {
        let nextOrder = (exercises ?? []).map(\.order).max().map { $0 + 1 } ?? 0
        let newExercise = Exercise(name: name, order: nextOrder)
        if exercises == nil {
            exercises = [newExercise]
        } else {
            exercises?.append(newExercise)
        }
        // Auto-update name if it's still default
        updateNameFromExercises()
    }

    /// Remove an exercise by ID
    func removeExercise(id: UUID) {
        exercises?.removeAll { $0.id == id }
    }

    /// Get exercise by ID
    func getExercise(id: UUID) -> Exercise? {
        exercises?.first { $0.id == id }
    }

    // MARK: - Superset Management

    /// Create a superset from multiple exercises
    /// - Parameter exerciseIds: IDs of exercises to group (order matters)
    func createSuperset(from exerciseIds: [UUID]) {
        guard exerciseIds.count >= 2 else { return }

        let groupId = UUID()
        for (index, exerciseId) in exerciseIds.enumerated() {
            if let exercise = exercises?.first(where: { $0.id == exerciseId }) {
                exercise.supersetGroupId = groupId
                exercise.supersetOrder = index
            }
        }
    }

    /// Break apart a superset, making all exercises standalone
    /// - Parameter groupId: The superset group ID to dissolve
    func breakSuperset(groupId: UUID) {
        for exercise in (exercises ?? []) where exercise.supersetGroupId == groupId {
            exercise.supersetGroupId = nil
            exercise.supersetOrder = 0
        }
    }

    /// Add an exercise to an existing superset
    /// - Parameters:
    ///   - exerciseId: ID of exercise to add
    ///   - groupId: The superset group to join
    func addToSuperset(exerciseId: UUID, groupId: UUID) {
        guard let exercise = exercises?.first(where: { $0.id == exerciseId }) else { return }

        // Find current max order in the group
        let maxOrder = (exercises ?? [])
            .filter { $0.supersetGroupId == groupId }
            .map(\.supersetOrder)
            .max() ?? -1

        exercise.supersetGroupId = groupId
        exercise.supersetOrder = maxOrder + 1
    }

    /// Remove an exercise from its superset (make it standalone)
    /// If only one exercise remains in the superset, it's also made standalone
    func removeFromSuperset(exerciseId: UUID) {
        guard let exercise = exercises?.first(where: { $0.id == exerciseId }),
              let groupId = exercise.supersetGroupId else { return }

        exercise.supersetGroupId = nil
        exercise.supersetOrder = 0

        // Check if only one exercise remains in the group
        let remaining = (exercises ?? []).filter { $0.supersetGroupId == groupId }
        if remaining.count == 1 {
            remaining.first?.supersetGroupId = nil
            remaining.first?.supersetOrder = 0
        }
    }

    /// Get exercises in a superset, ordered by their position
    func exercisesInSuperset(groupId: UUID) -> [Exercise] {
        (exercises ?? [])
            .filter { $0.supersetGroupId == groupId }
            .sorted { $0.supersetOrder < $1.supersetOrder }
    }

    /// Get all unique superset group IDs
    var supersetGroupIds: [UUID] {
        Array(Set((exercises ?? []).compactMap(\.supersetGroupId)))
    }

    /// Get exercises grouped for display (standalone + superset groups)
    /// Returns items in order: standalone exercises appear in their original position,
    /// superset groups appear at the position of their first exercise
    var exercisesGroupedForDisplay: [ExerciseDisplayItem] {
        var result: [ExerciseDisplayItem] = []
        var processedGroupIds: Set<UUID> = []

        for (_, exercise) in exercisesByOrder.enumerated() {
            if let groupId = exercise.supersetGroupId {
                // Part of a superset - only process once per group
                if !processedGroupIds.contains(groupId) {
                    processedGroupIds.insert(groupId)
                    let groupExercises = exercisesInSuperset(groupId: groupId)
                    result.append(.superset(id: groupId, exercises: groupExercises))
                }
            } else {
                // Standalone exercise
                result.append(.standalone(exercise))
            }
        }

        return result
    }

    /// Check if an exercise is the last one in its superset
    func isLastInSuperset(_ exercise: Exercise) -> Bool {
        guard let groupId = exercise.supersetGroupId else { return true }
        let group = exercisesInSuperset(groupId: groupId)
        return group.last?.id == exercise.id
    }

    /// Get total number of exercises
    var exerciseCount: Int {
        (exercises ?? []).count
    }

    /// Get total number of sets across all exercises
    var totalSets: Int {
        (exercises ?? []).reduce(0) { $0 + ($1.sets ?? []).count }
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

    /// Create widget data from this workout
    func toWidgetData(currentExercise: Exercise? = nil) -> WidgetWorkoutData {
        // Use provided exercise, or find the most recent one with sets
        let exercise = currentExercise ?? exercises?.last

        return WidgetWorkoutData(
            workoutId: id,
            workoutName: name,
            currentExerciseId: exercise?.id,
            currentExerciseName: exercise?.name,
            setsCompleted: totalSets,
            totalExercises: (exercises ?? []).count,
            startTime: startTime ?? date,
            lastUpdated: Date()
        )
    }

    /// Sync this workout's state to the widget
    func syncToWidget(currentExercise: Exercise? = nil) {
        guard isActive else {
            WidgetDataManager.clear()
            return
        }
        WidgetDataManager.save(toWidgetData(currentExercise: currentExercise))
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
