//
//  ContentView.swift
//  TheLogger
//
//  Created by Jaspreet Singh Sambee on 2026-01-01.
//

import SwiftUI
import SwiftData
import UIKit
import Charts

// ContentView is kept for supporting views
// The root screen is now WorkoutListView
// Main views have been modularized into separate files:
// - WorkoutDetailView.swift
// - ExerciseViews.swift (ExerciseRowView, ExerciseCard, ExerciseEditView)
// - ExerciseSearchView.swift
// - TemplateEditView.swift
// - SetViews.swift (InlineSetRowView, InlineAddSetView, AddSetView, EditSetView, SelectAllTextField, AddExerciseNameView)
// - TimerViews.swift (RestTimerView, PRCelebrationView, ConfettiView)
// - SummaryViews.swift (WorkoutEndSummaryView, ExerciseProgressView)

// MARK: - Add Workout View (Legacy - kept for reference)

struct AddWorkoutView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Workout.date, order: .reverse) private var allWorkouts: [Workout]

    // Optional pre-filled workout (for "Repeat Last Workout" feature)
    let preFilledWorkout: Workout?

    // Initialize with today's date
    @State private var workoutDate = Date()
    @State private var newWorkout: Workout
    @State private var showingAddExercise = false
    @State private var exerciseName = ""
    @State private var showingAddSet = false
    @State private var addingSetToExerciseIndex: Int?
    @State private var setReps = 0
    @State private var setWeight = 0.0
    @State private var setDuration = 30
    @State private var showingPRCelebration = false

    // Get unique exercise names from all workouts
    private var recentlyUsedExercises: [String] {
        var exerciseNames: Set<String> = []

        // Collect all unique exercise names from all workouts
        for workout in allWorkouts {
            for exercise in (workout.exercises ?? []) {
                exerciseNames.insert(exercise.name)
            }
        }

        // Convert to array and sort alphabetically
        return Array(exerciseNames).sorted()
    }

    init(preFilledWorkout: Workout? = nil) {
        self.preFilledWorkout = preFilledWorkout
        // Initialize with pre-filled workout or new empty workout
        if let preFilled = preFilledWorkout {
            _newWorkout = State(initialValue: preFilled)
            _workoutDate = State(initialValue: preFilled.date)
        } else {
            _newWorkout = State(initialValue: Workout(date: Date()))
            _workoutDate = State(initialValue: Date())
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(newWorkout.formattedDate, text: $newWorkout.name)
                        .font(.system(.body, weight: .regular))
                        .onChange(of: workoutDate) {
                            // Update default name if user hasn't entered a custom name
                            if newWorkout.name == Workout(name: "", date: workoutDate).name || newWorkout.name.isEmpty {
                                let formatter = DateFormatter()
                                formatter.dateStyle = .medium
                                formatter.timeStyle = .short
                                newWorkout.name = formatter.string(from: workoutDate)
                            }
                        }
                } header: {
                    Text("Workout Name")
                        .font(.system(.caption, weight: .medium))
                        .foregroundStyle(.secondary)
                        .textCase(nil)
                }

                Section {
                    DatePicker("Date", selection: Binding(
                        get: { workoutDate },
                        set: {
                            workoutDate = $0
                            newWorkout.date = $0
                        }
                    ))
                    .font(.system(.body, weight: .regular))
                } header: {
                    Text("Date & Time")
                        .font(.system(.caption, weight: .medium))
                        .foregroundStyle(.secondary)
                        .textCase(nil)
                }

                if !recentlyUsedExercises.isEmpty {
                    Section {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(recentlyUsedExercises, id: \.self) { exerciseName in
                                    let exerciseExists = (newWorkout.exercises ?? []).contains(where: { $0.name == exerciseName })
                                    Button {
                                        // Check if exercise already exists in current workout
                                        if !exerciseExists {
                                            newWorkout.addExercise(name: exerciseName)
                                        }
                                    } label: {
                                        Text(exerciseName)
                                            .font(.system(.subheadline, weight: .medium))
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 12)
                                            .background(
                                                exerciseExists
                                                    ? Color.blue.opacity(0.15)
                                                    : Color(.systemGray5)
                                            )
                                            .foregroundColor(
                                                exerciseExists
                                                    ? .blue
                                                    : .primary
                                            )
                                            .cornerRadius(10)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 10)
                                                    .stroke(
                                                        exerciseExists
                                                            ? Color.blue.opacity(0.25)
                                                            : Color.clear,
                                                        lineWidth: 1
                                                    )
                                            )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, 4)
                            .padding(.vertical, 4)
                        }
                    } header: {
                        Text("Recently Used Exercises")
                            .font(.system(.caption, weight: .medium))
                            .foregroundStyle(.secondary)
                            .textCase(nil)
                    }
                }

                let workoutExercises = newWorkout.exercisesByOrder
                if !workoutExercises.isEmpty {
                    ForEach(Array(workoutExercises.enumerated()), id: \.element.id) { index, exercise in
                        Section {
                            if (exercise.sets ?? []).isEmpty {
                                Text("No sets added yet")
                                    .font(.system(.subheadline, weight: .regular))
                                    .foregroundStyle(.secondary)
                                    .padding(.vertical, 8)
                            } else {
                                ForEach(exercise.setsByOrder) { set in
                                    InlineSetRowView(
                                        set: set,
                                        setNumber: (exercise.setsByOrder.firstIndex(where: { $0.id == set.id }) ?? 0) + 1,
                                        exerciseName: exercise.name,
                                        currentWorkout: newWorkout,
                                        modelContext: modelContext,
                                        onUpdate: { newReps, newWeight in
                                            if !(ExerciseLibrary.shared.find(name: exercise.name)?.isTimeBased ?? false) {
                                                set.reps = newReps
                                                set.weight = newWeight
                                            }
                                        },
                                        onPRSet: {
                                            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                                                showingPRCelebration = true
                                            }
                                            let g = UINotificationFeedbackGenerator()
                                            g.notificationOccurred(.success)
                                            // Auto-dismiss after 2 seconds
                                            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                                                withAnimation(.easeOut(duration: 0.28)) {
                                                    showingPRCelebration = false
                                                }
                                            }
                                        }
                                    )
                                }
                                .onDelete { indexSet in
                                    let ordered = exercise.setsByOrder
                                    // Sort descending to avoid index shift issues
                                    for setIndex in indexSet.sorted(by: >) where setIndex < ordered.count {
                                        guard index < workoutExercises.count else { continue }
                                        workoutExercises[index].removeSet(id: ordered[setIndex].id)
                                    }
                                }
                            }

                            Button {
                                addingSetToExerciseIndex = index
                                setReps = 0
                                setWeight = 0.0
                                setDuration = 30
                                showingAddSet = true
                            } label: {
                                Label("Add Set", systemImage: "plus.circle")
                                    .font(.system(.body, weight: .medium))
                            }
                            .tint(.blue)
                        } header: {
                            Text(exercise.name)
                                .font(.system(.caption, weight: .medium))
                                .foregroundStyle(.secondary)
                                .textCase(nil)
                        }
                    }
                    .onDelete { indexSet in
                        // Sort descending to avoid index shift issues
                        for index in indexSet.sorted(by: >) {
                            guard index < workoutExercises.count else { continue }
                            newWorkout.removeExercise(id: workoutExercises[index].id)
                        }
                    }
                }

                Section {
                    if workoutExercises.isEmpty {
                        Text("No exercises added yet")
                            .font(.system(.subheadline, weight: .regular))
                            .foregroundStyle(.secondary)
                            .padding(.vertical, 8)
                    }

                    Button {
                        showingAddExercise = true
                    } label: {
                        Label("Add Exercise", systemImage: "plus.circle")
                            .font(.system(.body, weight: .medium))
                    }
                    .tint(.blue)
                } header: {
                    Text("Exercises")
                        .font(.system(.caption, weight: .medium))
                        .foregroundStyle(.secondary)
                        .textCase(nil)
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Color(.systemBackground))
            .navigationTitle(preFilledWorkout != nil ? "Repeat Workout" : "New Workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        // Update date
                        newWorkout.date = workoutDate
                        // Insert into SwiftData context
                        modelContext.insert(newWorkout)
                        // Save to persist and only dismiss on success
                        do {
                            try modelContext.save()
                            dismiss()
                        } catch {
                            print("Error saving workout: \(error)")
                            // Remove from context since save failed
                            modelContext.delete(newWorkout)
                        }
                    }
                    .tint(.blue)
                }
            }
            .sheet(isPresented: $showingAddExercise) {
                AddExerciseNameView(exerciseName: $exerciseName) {
                    if !exerciseName.trimmingCharacters(in: .whitespaces).isEmpty {
                        newWorkout.addExercise(name: exerciseName.trimmingCharacters(in: .whitespaces))
                        exerciseName = ""
                    }
                }
            }
            .sheet(isPresented: $showingAddSet) {
                let exercises = newWorkout.exercisesByOrder
                let exerciseName: String = {
                    guard let idx = addingSetToExerciseIndex, idx < exercises.count else { return "" }
                    return exercises[idx].name
                }()
                let isTimeBased = ExerciseLibrary.shared.find(name: exerciseName)?.isTimeBased ?? false
                AddSetView(
                    reps: $setReps,
                    weight: $setWeight,
                    exerciseName: exerciseName,
                    durationSeconds: isTimeBased ? $setDuration : nil
                ) {
                    if let exerciseIndex = addingSetToExerciseIndex,
                       exerciseIndex < exercises.count {
                        if isTimeBased {
                            exercises[exerciseIndex].addSet(reps: 0, weight: 0, durationSeconds: setDuration)
                        } else {
                            exercises[exerciseIndex].addSet(reps: setReps, weight: setWeight)
                        }
                    }
                    addingSetToExerciseIndex = nil
                }
            }
        }
        .onAppear {
            newWorkout.date = workoutDate
        }
        .overlay {
            // PR Celebration overlay
            if showingPRCelebration {
                ZStack {
                    Color.black.opacity(0.35)
                        .ignoresSafeArea()
                        .allowsHitTesting(false)
                    ConfettiView()
                    PRCelebrationView()
                        .transition(.scale.combined(with: .opacity))
                }
                .transition(.opacity)
            }
        }
    }
}

#Preview {
    WorkoutListView()
        .modelContainer(for: [Workout.self, Exercise.self, WorkoutSet.self], inMemory: true)
}
