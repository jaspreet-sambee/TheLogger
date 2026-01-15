//
//  ContentView.swift
//  TheLogger
//
//  Created by Jaspreet Singh Sambee on 2026-01-01.
//

import SwiftUI
import SwiftData

// ContentView is kept for supporting views
// The root screen is now WorkoutListView
// WorkoutRowView is now defined in WorkoutListView.swift

struct WorkoutDetailView: View {
    @Bindable var workout: Workout
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var showingAddExercise = false
    @State private var exerciseName = ""
    @State private var showingEndWorkoutConfirmation = false
    @State private var showingSaveAsTemplate = false
    @State private var isEditingWorkoutName = false
    @State private var workoutNameText = ""
    @FocusState private var workoutNameFocused: Bool
    
    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    // Inline editable workout name
                    HStack(spacing: 8) {
                        if isEditingWorkoutName {
                            TextField("Workout Name", text: $workoutNameText)
                        .font(.system(.title2, weight: .semibold))
                        .foregroundStyle(.primary)
                                .focused($workoutNameFocused)
                                .textFieldStyle(.plain)
                                .onSubmit {
                                    saveWorkoutName()
                                }
                                .onChange(of: workoutNameFocused) { oldValue, newValue in
                                    if !newValue && isEditingWorkoutName {
                                        saveWorkoutName()
                                    }
                                }
                        } else {
                            Text(workout.name.isEmpty ? "Untitled Workout" : workout.name)
                                .font(.system(.title2, weight: .semibold))
                                .foregroundStyle(.primary)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    startEditingWorkoutName()
                                }
                        }
                        
                        if workout.isActive {
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(Color.blue)
                                    .frame(width: 6, height: 6)
                                Text("Active")
                                    .font(.system(.caption2, weight: .semibold))
                                    .foregroundStyle(.blue)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(Color.blue.opacity(0.12))
                            )
                        }
                        
                        if !isEditingWorkoutName {
                    Button {
                                startEditingWorkoutName()
                    } label: {
                        Image(systemName: "pencil")
                                    .font(.system(.caption, weight: .medium))
                                    .foregroundStyle(.blue)
                                    .padding(6)
                            }
                        }
                    }
                    
                    // Date & Time info
                    if workout.isActive, let startTime = workout.startTime {
                        HStack(spacing: 6) {
                            Image(systemName: "clock.fill")
                                .font(.system(.caption2, weight: .medium))
                                .foregroundStyle(.blue)
                            Text("Started \(startTime, style: .relative)")
                                .font(.system(.caption, weight: .regular))
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        HStack(spacing: 6) {
                            Image(systemName: "calendar")
                                .font(.system(.caption2, weight: .medium))
                                .foregroundStyle(.secondary)
                            Text(workout.formattedDate)
                                .font(.system(.caption, weight: .regular))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.vertical, 8)
                .listRowBackground(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.black.opacity(0.6))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.blue.opacity(0.25), lineWidth: 1)
                        )
                )
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            } header: {
                Text("Workout Info")
                    .font(.system(.caption, weight: .medium))
                    .foregroundStyle(.secondary)
                    .textCase(nil)
            }
            
            // Summary stats section
            Section {
                VStack(spacing: 12) {
                    // Stats row
                    HStack(alignment: .top, spacing: 20) {
                        // Exercises stat
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 6) {
                                Image(systemName: "figure.strengthtraining.traditional")
                                    .font(.system(.caption, weight: .medium))
                                    .foregroundStyle(.green)
                                Text("Exercises")
                                    .font(.system(.caption, weight: .medium))
                                    .foregroundStyle(.secondary)
                            }
                            Text("\(workout.exerciseCount)")
                                .font(.system(.title2, weight: .bold))
                                .foregroundStyle(.primary)
                        }
                        
                        Divider()
                            .frame(height: 40)
                        
                        // Sets stat
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 6) {
                                Image(systemName: "list.bullet")
                                    .font(.system(.caption, weight: .medium))
                                    .foregroundStyle(.orange)
                                Text("Sets")
                                    .font(.system(.caption, weight: .medium))
                                    .foregroundStyle(.secondary)
                            }
                            Text("\(workout.totalSets)")
                                .font(.system(.title2, weight: .bold))
                                .foregroundStyle(.primary)
                        }
                        
                        Spacer()
                    }
                    
                    // Date picker row (only show when exercises exist)
                    if !workout.exercises.isEmpty {
                        HStack {
                            HStack(spacing: 6) {
                                Image(systemName: "calendar")
                                    .font(.system(.caption, weight: .medium))
                                    .foregroundStyle(.secondary)
                                Text("Date & Time")
                                    .font(.system(.caption, weight: .medium))
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            DatePicker("", selection: $workout.date, displayedComponents: [.date, .hourAndMinute])
                                .labelsHidden()
                                .datePickerStyle(.compact)
                        }
                        .padding(.top, 4)
                    }
                }
                .padding(.vertical, 8)
                .listRowBackground(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.black.opacity(0.6))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.blue.opacity(0.25), lineWidth: 1)
                        )
                )
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            } header: {
                Text("Summary")
                    .font(.system(.caption, weight: .medium))
                    .foregroundStyle(.secondary)
                    .textCase(nil)
            }
            
            // End Workout Section (only show when workout is active)
            if workout.isActive {
                Section {
                    Button {
                        showingEndWorkoutConfirmation = true
                    } label: {
                        Text("End Workout")
                            .font(.system(.body, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                }
            }
            
            // Save as Template Section (only show when workout is completed)
            if !workout.isActive && workout.isCompleted {
                Section {
                    Button {
                        saveAsTemplate()
                        showingSaveAsTemplate = true
                    } label: {
                HStack {
                            Image(systemName: "square.and.arrow.down")
                        .font(.system(.body, weight: .medium))
                            Text("Save as Template")
                                .font(.system(.body, weight: .medium))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                    }
                    .buttonStyle(.bordered)
                    .tint(.blue)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                }
            }
            
            Section {
                if workout.exercises.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "figure.strengthtraining.traditional")
                            .font(.system(size: 40))
                            .foregroundStyle(.tertiary)
                        Text("Add your first exercise to start logging")
                        .font(.system(.subheadline, weight: .regular))
                        .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 32)
                    .listRowBackground(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.black.opacity(0.6))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.blue.opacity(0.25), lineWidth: 1)
                        )
                )
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                } else {
                    ForEach(workout.exercises) { exercise in
                        NavigationLink {
                            ExerciseEditView(exercise: exercise, workout: workout)
                        } label: {
                            ExerciseRowView(
                                exercise: exercise,
                                currentWorkout: workout,
                                modelContext: modelContext
                            )
                        }
                    }
                    .onDelete { indexSet in
                        for index in indexSet {
                            workout.removeExercise(id: workout.exercises[index].id)
                        }
                        saveWorkout()
                    }
                    .listRowBackground(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.black.opacity(0.6))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.blue.opacity(0.25), lineWidth: 1)
                            )
                            .padding(.vertical, 4)
                    )
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                }
                
                // Only show button in section if workout is not active
                if !workout.isActive {
                Button {
                    showingAddExercise = true
                } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(.body, weight: .medium))
                            Text("Add Exercise")
                        .font(.system(.body, weight: .medium))
                }
                        .foregroundStyle(.blue)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.black.opacity(0.6))
                        )
                    }
                }
            } header: {
                HStack {
                Text("Exercises")
                    .font(.system(.caption, weight: .medium))
                    if !workout.exercises.isEmpty {
                        Spacer()
                        Text("\(workout.exercises.count)")
                            .font(.system(.caption, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill(Color(.systemGray5))
                            )
                    }
                }
                    .foregroundStyle(.secondary)
                    .textCase(nil)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color(.systemBackground))
        .safeAreaInset(edge: .bottom) {
            if workout.isActive {
                Button {
                    showingAddExercise = true
                } label: {
                    Label("Add Exercise", systemImage: "plus.circle")
                        .font(.system(.body, weight: .medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.borderedProminent)
                .padding(.horizontal)
                .padding(.bottom, 8)
            }
        }
        .navigationTitle("Workout Details")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Add Exercise", isPresented: $showingAddExercise) {
            TextField("Exercise Name", text: $exerciseName)
            Button("Add") {
                if !exerciseName.trimmingCharacters(in: .whitespaces).isEmpty {
                    workout.addExercise(name: exerciseName.trimmingCharacters(in: .whitespaces))
                    exerciseName = ""
                    saveWorkout()
                }
            }
            Button("Cancel", role: .cancel) {
                exerciseName = ""
            }
        } message: {
            Text("Enter the name of the exercise")
        }
        .onChange(of: workout.date) {
            saveWorkout()
        }
        .onAppear {
            workoutNameText = workout.name
        }
        .alert("End Workout", isPresented: $showingEndWorkoutConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("End", role: .destructive) {
                endWorkout()
            }
            Button("Save as Template & End") {
                saveAsTemplate()
                endWorkout()
            }
        } message: {
            Text("Are you sure you want to end this workout?")
        }
        .alert("Template Saved", isPresented: $showingSaveAsTemplate) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("This workout has been saved as a template. You can use it to start future workouts.")
        }
    }
    
    private func startEditingWorkoutName() {
        workoutNameText = workout.name
        isEditingWorkoutName = true
        workoutNameFocused = true
    }
    
    private func saveWorkoutName() {
        defer {
            isEditingWorkoutName = false
            workoutNameFocused = false
        }
        
        let trimmed = workoutNameText.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty {
            workout.name = trimmed
            saveWorkout()
        } else {
            // Revert to original if empty
            workoutNameText = workout.name
        }
    }
    
    private func saveWorkout() {
        do {
            try modelContext.save()
        } catch {
            print("Error saving workout: \(error)")
        }
    }
    
    private func endWorkout() {
        workout.endTime = Date()
        
        do {
            try modelContext.save()
            dismiss()
        } catch {
            print("Error ending workout: \(error)")
        }
    }
    
    private func saveAsTemplate() {
        // Create a template from the current workout (exercise names only, no sets)
        let template = Workout(name: workout.name, date: Date(), isTemplate: true)
        
        // Copy only exercise names (no sets or performance data)
        for exercise in workout.exercises {
            let templateExercise = Exercise(name: exercise.name)
            // Templates don't have sets - they're just the structure
            template.exercises.append(templateExercise)
        }
        
        modelContext.insert(template)
        
        do {
            try modelContext.save()
        } catch {
            print("Error saving template: \(error)")
        }
    }
}

// MARK: - Template Edit View
struct TemplateEditView: View {
    let template: Workout?
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var templateWorkout: Workout
    @State private var showingAddExercise = false
    @State private var exerciseName: String = ""
    @State private var showingEditName = false
    @State private var editedName: String = ""
    private var isNewTemplate: Bool
    
    init(template: Workout?) {
        self.template = template
        // Create a workout for editing
        if let existingTemplate = template {
            _templateWorkout = State(initialValue: existingTemplate)
            self.isNewTemplate = false
        } else {
            // For new templates, create a workout (will be inserted into context in onAppear)
            let newWorkout = Workout(name: "", date: Date(), isTemplate: true)
            _templateWorkout = State(initialValue: newWorkout)
            self.isNewTemplate = true
        }
    }
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 12) {
                        Text(templateWorkout.name.isEmpty ? "Template Name" : templateWorkout.name)
                            .font(.system(.title2, weight: .semibold))
                            .foregroundStyle(templateWorkout.name.isEmpty ? .secondary : .primary)
                        Spacer()
                        Button {
                            editedName = templateWorkout.name
                            showingEditName = true
                        } label: {
                            Image(systemName: "pencil")
                                .font(.system(.body, weight: .medium))
                        }
                        .tint(.blue)
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("Template Name")
                        .font(.system(.caption, weight: .medium))
                        .foregroundStyle(.secondary)
                        .textCase(nil)
                }
                
                Section {
                    if templateWorkout.exercises.isEmpty {
                        Text("Add your first exercise to start logging")
                            .font(.system(.subheadline, weight: .regular))
                            .foregroundStyle(.secondary)
                            .padding(.vertical, 8)
                    } else {
                        ForEach(templateWorkout.exercises) { exercise in
                            NavigationLink {
                                ExerciseEditView(exercise: exercise, workout: templateWorkout)
                            } label: {
                                ExerciseRowView(
                                    exercise: exercise,
                                    currentWorkout: templateWorkout,
                                    modelContext: modelContext
                                )
                            }
                        }
                        .onDelete { indexSet in
                            for index in indexSet {
                                templateWorkout.removeExercise(id: templateWorkout.exercises[index].id)
                            }
                            autoSaveTemplate()
                        }
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
            .navigationTitle(template == nil ? "New Template" : "Edit Template")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        // If it's a new template and user cancels, remove it from context
                        if isNewTemplate {
                            modelContext.delete(templateWorkout)
                        }
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveTemplate()
                    }
                    .disabled(templateWorkout.name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .alert("Add Exercise", isPresented: $showingAddExercise) {
                TextField("Exercise Name", text: $exerciseName)
                Button("Add") {
                    if !exerciseName.trimmingCharacters(in: .whitespaces).isEmpty {
                        templateWorkout.addExercise(name: exerciseName.trimmingCharacters(in: .whitespaces))
                        exerciseName = ""
                        autoSaveTemplate()
                    }
                }
                Button("Cancel", role: .cancel) {
                    exerciseName = ""
                }
            } message: {
                Text("Enter the name of the exercise")
            }
            .alert("Edit Template Name", isPresented: $showingEditName) {
                TextField("Template Name", text: $editedName)
            Button("Save") {
                if !editedName.trimmingCharacters(in: .whitespaces).isEmpty {
                        templateWorkout.name = editedName.trimmingCharacters(in: .whitespaces)
                        autoSaveTemplate()
                }
            }
            Button("Cancel", role: .cancel) {
                editedName = ""
            }
        } message: {
                Text("Enter a name for this template")
            }
            .onAppear {
                // For new templates, insert into context so relationships work
                if isNewTemplate {
                    // Check if it's already in the context
                    let descriptor = FetchDescriptor<Workout>()
                    if let workouts = try? modelContext.fetch(descriptor),
                       workouts.contains(where: { $0.id == templateWorkout.id }) == false {
                        modelContext.insert(templateWorkout)
                    }
                }
            }
        }
    }
    
    private func autoSaveTemplate() {
        // Ensure it's marked as a template
        templateWorkout.isTemplate = true
        templateWorkout.startTime = nil
        templateWorkout.endTime = nil
        
        // For new templates, make sure it's in the context
        if isNewTemplate {
            let descriptor = FetchDescriptor<Workout>()
            if let workouts = try? modelContext.fetch(descriptor),
               workouts.contains(where: { $0.id == templateWorkout.id }) == false {
                modelContext.insert(templateWorkout)
            }
        }
        
        do {
            try modelContext.save()
        } catch {
            print("Error auto-saving template: \(error)")
        }
    }
    
    private func saveTemplate() {
        // Ensure it's marked as a template
        templateWorkout.isTemplate = true
        templateWorkout.startTime = nil
        templateWorkout.endTime = nil
        
        // For new templates, make sure it's in the context
        if isNewTemplate {
            let descriptor = FetchDescriptor<Workout>()
            if let workouts = try? modelContext.fetch(descriptor),
               workouts.contains(where: { $0.id == templateWorkout.id }) == false {
                modelContext.insert(templateWorkout)
            }
        }
        
        do {
            try modelContext.save()
            dismiss()
        } catch {
            print("Error saving template: \(error)")
            // If save failed and it's a new template, remove it from context
            if isNewTemplate {
                modelContext.delete(templateWorkout)
            }
        }
    }
}

struct ExerciseRowView: View {
    let exercise: Exercise
    let currentWorkout: Workout
    let modelContext: ModelContext
    
    // Normalize exercise name for comparison (lowercase, trimmed)
    private var normalizedName: String {
        exercise.name.lowercased().trimmingCharacters(in: .whitespaces)
    }
    
    // Find most recent workout with same exercise name
    private var previousExercise: Exercise? {
        // Fetch all completed workouts (not templates, not current)
        let descriptor = FetchDescriptor<Workout>(
            sortBy: [SortDescriptor(\.endTime, order: .reverse)]
        )
        
        guard let allWorkouts = try? modelContext.fetch(descriptor) else { return nil }
        
        // Filter: not current workout, not template, has endTime
        let completedWorkouts = allWorkouts.filter { workout in
            workout.id != currentWorkout.id && 
            !workout.isTemplate && 
            workout.endTime != nil
        }
        
        // Find most recent workout containing the same normalized exercise name
        for workout in completedWorkouts {
            if let previous = workout.exercises.first(where: {
                $0.name.lowercased().trimmingCharacters(in: .whitespaces) == normalizedName
            }), !previous.sets.isEmpty {
                return previous
            }
        }
        
        return nil
    }
    
    // Get progress message based on comparison
    private var progressMessage: String? {
        guard let previous = previousExercise, !exercise.sets.isEmpty else { return nil }
        
        let currentMaxWeight = exercise.sets.map { $0.weight }.max() ?? 0
        let previousMaxWeight = previous.sets.map { $0.weight }.max() ?? 0
        
        let currentTotalSets = exercise.sets.count
        let previousTotalSets = previous.sets.count
        
        let currentTotalReps = exercise.totalReps
        let previousTotalReps = previous.totalReps
        
        // Priority 1: Weight increase
        if currentMaxWeight > previousMaxWeight {
            let increase = currentMaxWeight - previousMaxWeight
            return String(format: "+%.1f lbs", increase)
        }
        
        // Priority 2: Sets or reps increase
        if currentTotalSets > previousTotalSets {
            let increase = currentTotalSets - previousTotalSets
            return "+\(increase) \(increase == 1 ? "set" : "sets")"
        }
        
        if currentTotalReps > previousTotalReps {
            let increase = currentTotalReps - previousTotalReps
            return "+\(increase) reps"
        }
        
        // Fallback: Matched last time
        return "Matched last time"
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
            Text(exercise.name)
                .font(.system(.headline, weight: .semibold))
                .foregroundStyle(.primary)
                
                // Progress comparison (inline under exercise name)
                if let message = progressMessage {
                    Text(message)
                        .font(.system(.caption, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }
            
            if exercise.sets.isEmpty {
                Text("No sets added")
                    .font(.system(.subheadline, weight: .regular))
                    .foregroundStyle(.secondary)
                    .padding(.top, 2)
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(exercise.sets) { set in
                        HStack {
                            Text("\(set.reps) reps")
                                .font(.system(.subheadline, weight: .regular))
                            Spacer()
                            Text("\(String(format: "%.1f", set.weight)) lbs")
                                .font(.system(.subheadline, weight: .regular))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.top, 4)
            }
            
            HStack {
                Text("Total: \(exercise.totalReps) reps")
                    .font(.system(.caption, weight: .medium))
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.top, 4)
        }
        .padding(.vertical, 8)
    }
}

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
    @State private var setReps = 10  // Default value
    @State private var setWeight = 135.0  // Default value
    
    // Get unique exercise names from all workouts
    private var recentlyUsedExercises: [String] {
        var exerciseNames: Set<String> = []
        
        // Collect all unique exercise names from all workouts
        for workout in allWorkouts {
            for exercise in workout.exercises {
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
                                    Button {
                                        // Check if exercise already exists in current workout
                                        if !newWorkout.exercises.contains(where: { $0.name == exerciseName }) {
                                            newWorkout.addExercise(name: exerciseName)
                                        }
                                    } label: {
                                        Text(exerciseName)
                                            .font(.system(.subheadline, weight: .medium))
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 12)
                                            .background(
                                                newWorkout.exercises.contains(where: { $0.name == exerciseName })
                                                    ? Color.blue.opacity(0.15)
                                                    : Color(.systemGray5)
                                            )
                                            .foregroundColor(
                                                newWorkout.exercises.contains(where: { $0.name == exerciseName })
                                                    ? .blue
                                                    : .primary
                                            )
                                            .cornerRadius(10)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 10)
                                                    .stroke(
                                                        newWorkout.exercises.contains(where: { $0.name == exerciseName })
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
                
                if !newWorkout.exercises.isEmpty {
                    ForEach(Array(newWorkout.exercises.enumerated()), id: \.element.id) { index, exercise in
                        Section {
                            if exercise.sets.isEmpty {
                                Text("No sets added yet")
                                    .font(.system(.subheadline, weight: .regular))
                                    .foregroundStyle(.secondary)
                                    .padding(.vertical, 8)
                            } else {
                                ForEach(exercise.sets) { set in
                                    InlineSetRowView(
                                        set: set,
                                        setNumber: (exercise.sets.firstIndex(where: { $0.id == set.id }) ?? 0) + 1,
                                        onUpdate: { newReps, newWeight in
                                            set.reps = newReps
                                            set.weight = newWeight
                                        }
                                    )
                                }
                                .onDelete { indexSet in
                                    for setIndex in indexSet {
                                        newWorkout.exercises[index].removeSet(id: exercise.sets[setIndex].id)
                                    }
                                }
                            }
                            
                            Button {
                                addingSetToExerciseIndex = index
                                setReps = 10
                                setWeight = 135.0
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
                        for index in indexSet {
                            newWorkout.removeExercise(id: newWorkout.exercises[index].id)
                        }
                    }
                }
                
                Section {
                    if newWorkout.exercises.isEmpty {
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
                        // Save to persist
                        do {
                            try modelContext.save()
                        } catch {
                            print("Error saving workout: \(error)")
                        }
                        // Dismiss after saving
                        dismiss()
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
                AddSetView(reps: $setReps, weight: $setWeight) {
                    // Add the set to the exercise at the tracked index
                    if let exerciseIndex = addingSetToExerciseIndex,
                       exerciseIndex < newWorkout.exercises.count {
                        newWorkout.exercises[exerciseIndex].addSet(reps: setReps, weight: setWeight)
                    }
                    addingSetToExerciseIndex = nil
                }
            }
        }
        .onAppear {
            newWorkout.date = workoutDate
        }
    }
}

struct ExerciseEditView: View {
    @Bindable var exercise: Exercise
    let workout: Workout
    @Environment(\.modelContext) private var modelContext
    @State private var isAddingSet = false
    @State private var newSetReps: Int = 10
    @State private var newSetWeight: Double = 135.0
    @State private var isEditingExerciseName = false
    @State private var exerciseNameText = ""
    @FocusState private var focusedField: AddSetField?
    @FocusState private var exerciseNameFocused: Bool
    
    enum AddSetField {
        case reps, weight
    }
    
    var body: some View {
        Form {
            Section {
                HStack(spacing: 12) {
                    if isEditingExerciseName {
                        TextField("Exercise Name", text: $exerciseNameText)
                            .font(.system(.title3, weight: .semibold))
                            .foregroundStyle(.primary)
                            .focused($exerciseNameFocused)
                            .textFieldStyle(.plain)
                            .onSubmit {
                                saveExerciseName()
                            }
                            .onChange(of: exerciseNameFocused) { oldValue, newValue in
                                if !newValue && isEditingExerciseName {
                                    saveExerciseName()
                                }
                            }
                    } else {
                    Text(exercise.name)
                        .font(.system(.title3, weight: .semibold))
                        .foregroundStyle(.primary)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                startEditingExerciseName()
                            }
                    }
                    
                    Spacer()
                    
                    if !isEditingExerciseName {
                    Button {
                            startEditingExerciseName()
                    } label: {
                        Image(systemName: "pencil")
                                .font(.system(.caption, weight: .medium))
                    }
                    .tint(.blue)
                    }
                }
                .padding(.vertical, 4)
            } header: {
                Text("Exercise Name")
                    .font(.system(.caption, weight: .medium))
                    .foregroundStyle(.secondary)
                    .textCase(nil)
            }
            
            Section {
                if exercise.sets.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "circle.dashed")
                            .font(.system(size: 32))
                            .foregroundStyle(.tertiary)
                    Text("No sets added yet")
                        .font(.system(.subheadline, weight: .regular))
                        .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                } else {
                    ForEach(exercise.sets) { set in
                        InlineSetRowView(
                            set: set,
                            setNumber: (exercise.sets.firstIndex(where: { $0.id == set.id }) ?? 0) + 1,
                            onUpdate: { newReps, newWeight in
                                set.reps = newReps
                                set.weight = newWeight
                                saveChanges()
                            }
                        )
                    }
                    .onDelete { indexSet in
                        for index in indexSet {
                            exercise.removeSet(id: exercise.sets[index].id)
                        }
                        saveChanges()
                    }
                }
                
                if isAddingSet {
                    // Inline add set form
                    InlineAddSetView(
                        reps: $newSetReps,
                        weight: $newSetWeight,
                        focusedField: $focusedField,
                        onSave: {
                            exercise.addSet(reps: newSetReps, weight: newSetWeight)
                            saveChanges()
                            // Reset for next set (inherit from the one just added)
                            if workout.isActive {
                                newSetReps = newSetReps  // Keep same as last added
                                newSetWeight = newSetWeight
                            } else {
                                newSetReps = 10
                                newSetWeight = 135.0
                            }
                            // Keep form open for quick successive adds
                        },
                        onCancel: {
                            isAddingSet = false
                            focusedField = nil
                            // Reset to previous set values or defaults
                            if workout.isActive, let lastSet = exercise.sets.last {
                                newSetReps = lastSet.reps
                                newSetWeight = lastSet.weight
                            } else {
                                newSetReps = 10
                                newSetWeight = 135.0
                            }
                        }
                    )
                } else {
                Button {
                        // Inherit from previous set if workout is active and sets exist
                        if workout.isActive, let lastSet = exercise.sets.last {
                            newSetReps = lastSet.reps
                            newSetWeight = lastSet.weight
                        } else {
                            // Default values when no previous set or workout is not active
                            newSetReps = 10
                            newSetWeight = 135.0
                        }
                        isAddingSet = true
                        // Small delay to ensure view is rendered before focusing
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            focusedField = .reps
                        }
                } label: {
                    Label("Add Set", systemImage: "plus.circle")
                        .font(.system(.body, weight: .medium))
                }
                .tint(.blue)
                }
            } header: {
                Text("Sets")
                    .font(.system(.caption, weight: .medium))
                    .foregroundStyle(.secondary)
                    .textCase(nil)
            }
            
            Section {
                HStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 6) {
                            Image(systemName: "number")
                                .font(.system(.caption, weight: .medium))
                    Text("Total Reps")
                                .font(.system(.caption, weight: .medium))
                        }
                        .foregroundStyle(.secondary)
                        Text("\(exercise.totalReps)")
                            .font(.system(.title2, weight: .semibold))
                            .foregroundStyle(.primary)
                }
                
                    Spacer()
                    
                }
                .padding(.vertical, 8)
                .listRowBackground(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.black.opacity(0.6))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.blue.opacity(0.25), lineWidth: 1)
                        )
                )
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            } header: {
                Text("Summary")
                    .font(.system(.caption, weight: .medium))
                    .foregroundStyle(.secondary)
                    .textCase(nil)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color(.systemBackground))
        .navigationTitle(exercise.name)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            exerciseNameText = exercise.name
        }
        .onChange(of: exercise.name) { oldValue, newValue in
            if !isEditingExerciseName {
                exerciseNameText = newValue
            }
        }
    }
    
    private func startEditingExerciseName() {
        exerciseNameText = exercise.name
        isEditingExerciseName = true
        exerciseNameFocused = true
    }
    
    private func saveExerciseName() {
        defer {
            isEditingExerciseName = false
            exerciseNameFocused = false
        }
        
        let trimmed = exerciseNameText.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty {
            exercise.name = trimmed
                    saveChanges()
        } else {
            // Revert to original if empty
            exerciseNameText = exercise.name
        }
    }
    
    private func saveChanges() {
        do {
            try modelContext.save()
        } catch {
            print("Error saving exercise: \(error)")
        }
    }
}

// MARK: - Helper Views for Adding/Editing

// MARK: - Inline Set Row View
struct InlineSetRowView: View {
    @Bindable var set: WorkoutSet
    let setNumber: Int
    let onUpdate: (Int, Double) -> Void
    
    @State private var isEditingReps = false
    @State private var isEditingWeight = false
    @State private var repsText = ""
    @State private var weightText = ""
    @State private var originalReps: Int = 0
    @State private var originalWeight: Double = 0.0
    @State private var showFeedback = false
    @State private var feedbackMessage = "Set logged"
    @FocusState private var focusedField: Field?
    
    enum Field {
        case reps, weight
    }
    
    private let feedbackMessages = ["Set logged", "Done", "Saved", "Got it", "That counts", "Nice"]
    
    var body: some View {
        HStack(spacing: 12) {
            // Set number indicator
            Circle()
                .fill(Color(.systemGray5))
                .frame(width: 32, height: 32)
                .overlay(
                    Text("\(setNumber)")
                        .font(.system(.caption, weight: .semibold))
                        .foregroundStyle(.secondary)
                )
            
            // Reps - inline editable
            HStack(spacing: 6) {
                Image(systemName: "repeat")
                    .font(.system(.caption, weight: .medium))
                    .foregroundStyle(.secondary)
                
                if isEditingReps {
                    TextField("Reps", text: $repsText)
                        .keyboardType(.numberPad)
                        .font(.system(.body, weight: .semibold))
                        .focused($focusedField, equals: .reps)
                        .frame(width: 60)
                        .textFieldStyle(.plain)
                        .onSubmit {
                            saveReps()
                        }
                        .onChange(of: focusedField) { oldValue, newValue in
                            if newValue != .reps && isEditingReps {
                                saveReps()
                            }
                        }
                } else {
                    Text("\(set.reps)")
                        .font(.system(.body, weight: .semibold))
                        .foregroundStyle(.primary)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            startEditingReps()
                        }
                }
            }
            
            Spacer()
            
            // Weight - inline editable
            HStack(spacing: 4) {
                if isEditingWeight {
                    TextField("Weight", text: $weightText)
                        .keyboardType(.decimalPad)
                        .font(.system(.body, weight: .semibold))
                        .focused($focusedField, equals: .weight)
                        .frame(width: 70)
                        .textFieldStyle(.plain)
                        .onSubmit {
                            saveWeight()
                        }
                        .onChange(of: focusedField) { oldValue, newValue in
                            if newValue != .weight && isEditingWeight {
                                saveWeight()
                            }
                        }
                    Text("lbs")
                        .font(.system(.caption, weight: .regular))
                        .foregroundStyle(.secondary)
                } else {
                    Text("\(String(format: "%.1f", set.weight))")
                        .font(.system(.body, weight: .semibold))
                        .foregroundStyle(.primary)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            startEditingWeight()
                        }
                    Text("lbs")
                        .font(.system(.caption, weight: .regular))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(.systemGray6).opacity(isEditingReps || isEditingWeight ? 0.8 : 0.5))
                .animation(.easeInOut(duration: 0.25), value: isEditingReps || isEditingWeight)
        )
        .overlay(alignment: .trailing) {
            if showFeedback {
                Text(feedbackMessage)
                    .font(.system(.caption, weight: .medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color(.systemBackground).opacity(0.95))
                            .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
                    )
                    .padding(.trailing, 4)
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    .opacity(showFeedback ? 1 : 0)
            }
        }
        .onChange(of: set.reps) { oldValue, newValue in
            if !isEditingReps {
                originalReps = newValue
            }
        }
        .onChange(of: set.weight) { oldValue, newValue in
            if !isEditingWeight {
                originalWeight = newValue
            }
        }
        .onAppear {
            originalReps = set.reps
            originalWeight = set.weight
        }
    }
    
    private func startEditingReps() {
        originalReps = set.reps
        repsText = "\(set.reps)"
        isEditingReps = true
        focusedField = .reps
    }
    
    private func startEditingWeight() {
        originalWeight = set.weight
        weightText = String(format: "%.1f", set.weight)
        isEditingWeight = true
        focusedField = .weight
    }
    
    private func saveReps() {
        defer {
            isEditingReps = false
            focusedField = nil
        }
        
        if let value = Int(repsText.trimmingCharacters(in: .whitespaces)), value > 0 && value <= 1000 {
            set.reps = value
            onUpdate(set.reps, set.weight)
            showMicroFeedback()
        } else {
            // Revert to original value on invalid input
            set.reps = originalReps
            repsText = "\(originalReps)"
        }
    }
    
    private func saveWeight() {
        defer {
            isEditingWeight = false
            focusedField = nil
        }
        
        let trimmed = weightText.trimmingCharacters(in: .whitespaces)
        if let value = Double(trimmed), value >= 0 && value <= 10000 {
            set.weight = value
            onUpdate(set.reps, set.weight)
            showMicroFeedback()
        } else {
            // Revert to original value on invalid input
            set.weight = originalWeight
            weightText = String(format: "%.1f", originalWeight)
        }
    }
    
    private func showMicroFeedback() {
        feedbackMessage = feedbackMessages.randomElement() ?? "Set logged"
        withAnimation(.easeOut(duration: 0.25)) {
            showFeedback = true
        }
        
        // Auto-hide after 1.2 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation(.easeIn(duration: 0.25)) {
                showFeedback = false
            }
        }
    }
}

struct AddExerciseNameView: View {
    @Binding var exerciseName: String
    @Environment(\.dismiss) var dismiss
    let onAdd: () -> Void
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Enter exercise name", text: $exerciseName)
                        .font(.system(.body, weight: .regular))
                } header: {
                    Text("Exercise Name")
                        .font(.system(.caption, weight: .medium))
                        .foregroundStyle(.secondary)
                        .textCase(nil)
                }
            }
            .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color(.systemBackground))
            .navigationTitle("Add Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        exerciseName = ""
                        dismiss()
                    }
                    .font(.system(.body, weight: .regular))
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        onAdd()
                        dismiss()
                    }
                    .font(.system(.body, weight: .semibold))
                    .tint(.blue)
                    .disabled(exerciseName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}

// MARK: - Inline Add Set View
struct InlineAddSetView: View {
    @Binding var reps: Int
    @Binding var weight: Double
    @FocusState.Binding var focusedField: ExerciseEditView.AddSetField?
    let onSave: () -> Void
    let onCancel: () -> Void
    
    @State private var repsText: String = ""
    @State private var weightText: String = ""
    @State private var showFeedback = false
    @State private var feedbackMessage = "Set logged"
    
    private let feedbackMessages = ["Set logged", "Done", "Added", "Got it", "That counts", "Nice"]
    
    var body: some View {
        HStack(spacing: 12) {
            // Plus icon indicator
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.12))
                    .frame(width: 32, height: 32)
                
                Image(systemName: "plus")
                    .font(.system(.caption, weight: .semibold))
                    .foregroundStyle(.blue)
            }
            
            // Reps input
            HStack(spacing: 6) {
                Image(systemName: "repeat")
                    .font(.system(.caption, weight: .medium))
                    .foregroundStyle(.secondary)
                
                TextField("Reps", text: $repsText)
                    .keyboardType(.numberPad)
                    .font(.system(.body, weight: .semibold))
                    .focused($focusedField, equals: .reps)
                    .frame(width: 60)
                    .textFieldStyle(.plain)
                    .onAppear {
                        repsText = "\(reps)"
                    }
                    .onChange(of: repsText) { oldValue, newValue in
                        if let value = Int(newValue), value > 0 && value <= 1000 {
                            reps = value
                        }
                    }
                    .onSubmit {
                        focusedField = .weight
                    }
            }
            
            Spacer()
            
            // Weight input
            HStack(spacing: 4) {
                TextField("Weight", text: $weightText)
                    .keyboardType(.decimalPad)
                    .font(.system(.body, weight: .semibold))
                    .focused($focusedField, equals: .weight)
                    .frame(width: 70)
                    .textFieldStyle(.plain)
                    .onAppear {
                        weightText = String(format: "%.1f", weight)
                    }
                    .onChange(of: weightText) { oldValue, newValue in
                        if let value = Double(newValue), value >= 0 && value <= 10000 {
                            weight = value
                        }
                    }
                    .onSubmit {
                        saveAndContinue()
                    }
                Text("lbs")
                    .font(.system(.caption, weight: .regular))
                    .foregroundStyle(.secondary)
            }
            
            // Action buttons
            HStack(spacing: 8) {
                Button {
                    onCancel()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(.body, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                
                Button {
                    saveAndContinue()
                } label: {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(.body, weight: .medium))
                        .foregroundStyle(.blue)
                }
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.blue.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.blue.opacity(0.25), lineWidth: 1)
                )
        )
        .overlay(alignment: .trailing) {
            if showFeedback {
                Text(feedbackMessage)
                    .font(.system(.caption, weight: .medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color(.systemBackground).opacity(0.95))
                            .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
                    )
                    .padding(.trailing, 4)
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    .opacity(showFeedback ? 1 : 0)
            }
        }
        .onChange(of: focusedField) { oldValue, newValue in
            if newValue == nil && oldValue != nil {
                // Field lost focus, update text values
                repsText = "\(reps)"
                weightText = String(format: "%.1f", weight)
            }
        }
    }
    
    private func saveAndContinue() {
        // Validate and save
        if let repsValue = Int(repsText), repsValue > 0 && repsValue <= 1000 {
            reps = repsValue
        }
        if let weightValue = Double(weightText), weightValue >= 0 && weightValue <= 10000 {
            weight = weightValue
        }
        onSave()
        showMicroFeedback()
        // Keep form open and focus back on reps for next set
        repsText = "\(reps)"
        weightText = String(format: "%.1f", weight)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            focusedField = .reps
        }
    }
    
    private func showMicroFeedback() {
        feedbackMessage = feedbackMessages.randomElement() ?? "Set logged"
        withAnimation(.easeOut(duration: 0.25)) {
            showFeedback = true
        }
        
        // Auto-hide after 1.2 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation(.easeIn(duration: 0.25)) {
                showFeedback = false
            }
        }
    }
}

struct AddSetView: View {
    @Binding var reps: Int
    @Binding var weight: Double
    @Environment(\.dismiss) var dismiss
    let onAdd: () -> Void
    
    @State private var isEditingReps = false
    @State private var isEditingWeight = false
    @State private var repsText = ""
    @State private var weightText = ""
    @FocusState private var focusedField: Field?
    
    enum Field {
        case reps, weight
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Stepper(value: $reps, in: 1...100, step: 1) {
                        HStack {
                            if isEditingReps {
                                TextField("Reps", text: $repsText)
                                    .keyboardType(.numberPad)
                                    .font(.system(.title3, weight: .semibold))
                                    .focused($focusedField, equals: .reps)
                                    .onSubmit {
                                        saveReps()
                                    }
                                    .onChange(of: focusedField) {
                                        if focusedField != .reps {
                                            saveReps()
                                        }
                                    }
                            } else {
                        Text("\(reps) reps")
                            .font(.system(.title3, weight: .semibold))
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        startEditingReps()
                                    }
                            }
                            Spacer()
                        }
                    }
                } header: {
                    Text("Reps")
                        .font(.system(.caption, weight: .medium))
                        .foregroundStyle(.secondary)
                        .textCase(nil)
                }
                
                Section {
                    Stepper(value: $weight, in: 0...1000, step: 2.5) {
                        HStack {
                            if isEditingWeight {
                                TextField("Weight", text: $weightText)
                                    .keyboardType(.decimalPad)
                                    .font(.system(.title3, weight: .semibold))
                                    .focused($focusedField, equals: .weight)
                                    .onSubmit {
                                        saveWeight()
                                    }
                                    .onChange(of: focusedField) {
                                        if focusedField != .weight {
                                            saveWeight()
                                        }
                                    }
                            } else {
                        Text(String(format: "%.1f lbs", weight))
                            .font(.system(.title3, weight: .semibold))
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        startEditingWeight()
                                    }
                            }
                            Spacer()
                        }
                    }
                } header: {
                    Text("Weight")
                        .font(.system(.caption, weight: .medium))
                        .foregroundStyle(.secondary)
                        .textCase(nil)
                }
            }
            .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color(.systemBackground))
            .navigationTitle("Add Set")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        cancelEditing()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        saveAll()
                        onAdd()
                        dismiss()
                    }
                    .tint(.blue)
                }
            }
        }
    }
    
    private func startEditingReps() {
        repsText = "\(reps)"
        isEditingReps = true
        focusedField = .reps
    }
    
    private func startEditingWeight() {
        weightText = String(format: "%.1f", weight)
        isEditingWeight = true
        focusedField = .weight
    }
    
    private func saveReps() {
        if let value = Int(repsText), value > 0 {
            reps = value
        }
        isEditingReps = false
        focusedField = nil
    }
    
    private func saveWeight() {
        if let value = Double(weightText), value > 0 {
            weight = value
        }
        isEditingWeight = false
        focusedField = nil
    }
    
    private func saveAll() {
        if isEditingReps {
            saveReps()
        }
        if isEditingWeight {
            saveWeight()
        }
    }
    
    private func cancelEditing() {
        isEditingReps = false
        isEditingWeight = false
        focusedField = nil
    }
}

struct EditSetView: View {
    let set: WorkoutSet
    @Binding var reps: Int
    @Binding var weight: Double
    @Environment(\.dismiss) var dismiss
    let onSave: () -> Void
    
    @State private var isEditingReps = false
    @State private var isEditingWeight = false
    @State private var repsText = ""
    @State private var weightText = ""
    @FocusState private var focusedField: Field?
    
    enum Field {
        case reps, weight
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Stepper(value: $reps, in: 1...100, step: 1) {
                        HStack {
                            if isEditingReps {
                                TextField("Reps", text: $repsText)
                                    .keyboardType(.numberPad)
                                    .font(.system(.title3, weight: .semibold))
                                    .focused($focusedField, equals: .reps)
                                    .onSubmit {
                                        saveReps()
                                    }
                                    .onChange(of: focusedField) {
                                        if focusedField != .reps {
                                            saveReps()
                                        }
                                    }
                            } else {
                        Text("\(reps) reps")
                            .font(.system(.title3, weight: .semibold))
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        startEditingReps()
                                    }
                            }
                            Spacer()
                        }
                    }
                } header: {
                    Text("Reps")
                        .font(.system(.caption, weight: .medium))
                        .foregroundStyle(.secondary)
                        .textCase(nil)
                }
                
                Section {
                    Stepper(value: $weight, in: 0...1000, step: 2.5) {
                        HStack {
                            if isEditingWeight {
                                TextField("Weight", text: $weightText)
                                    .keyboardType(.decimalPad)
                                    .font(.system(.title3, weight: .semibold))
                                    .focused($focusedField, equals: .weight)
                                    .onSubmit {
                                        saveWeight()
                                    }
                                    .onChange(of: focusedField) {
                                        if focusedField != .weight {
                                            saveWeight()
                                        }
                                    }
                            } else {
                        Text(String(format: "%.1f lbs", weight))
                            .font(.system(.title3, weight: .semibold))
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        startEditingWeight()
                                    }
                            }
                            Spacer()
                        }
                    }
                } header: {
                    Text("Weight")
                        .font(.system(.caption, weight: .medium))
                        .foregroundStyle(.secondary)
                        .textCase(nil)
                }
            }
            .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color(.systemBackground))
            .navigationTitle("Edit Set")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        cancelEditing()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveAll()
                        onSave()
                        dismiss()
                    }
                    .tint(.blue)
                }
            }
        }
    }
    
    private func startEditingReps() {
        repsText = "\(reps)"
        isEditingReps = true
        focusedField = .reps
    }
    
    private func startEditingWeight() {
        weightText = String(format: "%.1f", weight)
        isEditingWeight = true
        focusedField = .weight
    }
    
    private func saveReps() {
        if let value = Int(repsText), value > 0 {
            reps = value
        }
        isEditingReps = false
        focusedField = nil
    }
    
    private func saveWeight() {
        if let value = Double(weightText), value > 0 {
            weight = value
        }
        isEditingWeight = false
        focusedField = nil
    }
    
    private func saveAll() {
        if isEditingReps {
            saveReps()
        }
        if isEditingWeight {
            saveWeight()
        }
    }
    
    private func cancelEditing() {
        isEditingReps = false
        isEditingWeight = false
        focusedField = nil
    }
}

#Preview {
    WorkoutListView()
        .modelContainer(for: [Workout.self, Exercise.self, WorkoutSet.self], inMemory: true)
}
