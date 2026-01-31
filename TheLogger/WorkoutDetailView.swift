//
//  WorkoutDetailView.swift
//  TheLogger
//
//  Main workout detail and editing view
//

import SwiftUI
import SwiftData

// MARK: - Workout Detail View
struct WorkoutDetailView: View {
    @Bindable var workout: Workout
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Namespace private var exerciseTransition
    @Query(sort: \ExerciseMemory.lastUpdated, order: .reverse) private var exerciseMemories: [ExerciseMemory]
    // Observe unit system changes to trigger view refresh
    @AppStorage("unitSystem") private var unitSystem: String = "Imperial"
    @State private var showingAddExercise = false
    @State private var exerciseName = ""
    @State private var showingEndWorkoutConfirmation = false
    @State private var showingSaveAsTemplate = false
    @State private var isEditingWorkoutName = false
    @State private var workoutNameText = ""
    @State private var showingEndSummary = false
    @State private var prExercises: [String] = []
    @FocusState private var workoutNameFocused: Bool
    @State private var emptyExercisesAppeared = false
    @State private var showingDeleteExerciseConfirmation = false
    @State private var pendingDeleteIndices: IndexSet = []
    @State private var elapsedTime: TimeInterval = 0
    @State private var timerTask: Task<Void, Never>? = nil

    // Get recently used exercises (top 5, preserving order from @Query sort)
    private var recentlyUsedExercises: [String] {
        var seen = Set<String>()
        return exerciseMemories.compactMap { memory -> String? in
            let name = memory.name
            if seen.contains(name) { return nil }
            seen.insert(name)
            return name
        }.prefix(5).map { $0 }
    }

    var body: some View {
        workoutList
            .navigationTitle("Workout Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !workout.exercises.isEmpty {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        EditButton()
                    }
                }
            }
            .sheet(isPresented: $showingAddExercise) {
                ExerciseSearchView { selectedName in
                    addExerciseWithMemory(name: selectedName)
                    saveWorkout()
                }
            }
            .onChange(of: workout.date) {
                saveWorkout()
            }
            .onAppear {
                workoutNameText = workout.name
                startTimer()
            }
            .onDisappear {
                stopTimer()
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
                Text("Your workout has been saved as a template.")
            }
            .alert("Delete Exercise", isPresented: $showingDeleteExerciseConfirmation) {
                Button("Cancel", role: .cancel) {
                    pendingDeleteIndices = []
                }
                Button("Delete", role: .destructive) {
                    deleteExercises(at: pendingDeleteIndices)
                    pendingDeleteIndices = []
                }
            } message: {
                Text("Are you sure you want to delete \(pendingDeleteIndices.count == 1 ? "this exercise" : "these exercises")? This cannot be undone.")
            }
            .sheet(isPresented: $showingEndSummary) {
                if workout.isCompleted {
                    WorkoutEndSummaryView(summary: workout.summary, prExercises: prExercises) {
                        showingEndSummary = false
                    }
                }
            }
    }

    private var workoutList: some View {
        List {
            workoutInfoSection
            summarySection
            exercisesSection
            saveAsTemplateSection
            endWorkoutSection
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color(.systemGroupedBackground))
        .safeAreaInset(edge: .bottom) {
            if workout.isActive {
                addExerciseButton
            }
        }
    }

    private var endWorkoutSection: some View {
        Group {
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
        }
    }

    private var saveAsTemplateSection: some View {
        Group {
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
        }
    }

    // MARK: - View Components

    private var workoutInfoSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                workoutNameRow
                dateTimeRow
            }
            .padding(.vertical, 8)
            .listRowBackground(cardBackground(variant: workout.isActive ? .active : .neutral))
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
        } header: {
            Text("Workout Info")
                .font(.system(.caption, weight: .medium))
                .foregroundStyle(.secondary)
                .textCase(nil)
        }
    }

    private var workoutNameRow: some View {
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
                activeBadge
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
    }

    private var activeBadge: some View {
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

    private var dateTimeRow: some View {
        Group {
            if workout.isActive, let _ = workout.startTime {
                HStack(spacing: 8) {
                    // Live elapsed timer
                    HStack(spacing: 6) {
                        Image(systemName: "timer")
                            .font(.system(.caption, weight: .semibold))
                            .foregroundStyle(.blue)
                        Text(formatElapsedTime(elapsedTime))
                            .font(.system(size: 20, weight: .bold, design: .monospaced))
                            .foregroundStyle(.primary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(Color.blue.opacity(0.12))
                    )
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
    }

    private func formatElapsedTime(_ interval: TimeInterval) -> String {
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60
        let seconds = Int(interval) % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }

    private func startTimer() {
        guard workout.isActive, let startTime = workout.startTime else { return }

        // Calculate initial elapsed time
        elapsedTime = Date().timeIntervalSince(startTime)

        // Start updating every second
        timerTask = Task {
            while !Task.isCancelled && workout.isActive {
                try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
                if let start = workout.startTime {
                    await MainActor.run {
                        elapsedTime = Date().timeIntervalSince(start)
                    }
                }
            }
        }
    }

    private func stopTimer() {
        timerTask?.cancel()
        timerTask = nil
    }

    private func cardBackground(variant: CardVariant) -> some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(Color.black.opacity(0.5))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .fill(variant.backgroundColor)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(variant.borderColor, lineWidth: 1)
            )
    }

    private var summarySection: some View {
        Section {
            VStack(spacing: 12) {
                summaryStatsRow
                if !workout.exercises.isEmpty {
                    datePickerRow
                }
            }
            .padding(.vertical, 8)
            .listRowBackground(cardBackground(variant: .stats))
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
        } header: {
            Text("Summary")
                .font(.system(.caption, weight: .medium))
                .foregroundStyle(.secondary)
                .textCase(nil)
        }
    }

    private var exercisesSection: some View {
        Section {
            if workout.exercises.isEmpty {
                emptyExercisesView
            } else {
                exercisesList
            }
        } header: {
            exercisesSectionHeader
        }
    }

    private var emptyExercisesView: some View {
        VStack(spacing: 20) {
            Image(systemName: "figure.strengthtraining.traditional")
                .font(.system(size: 40))
                .foregroundStyle(.tertiary)
                .symbolEffect(.bounce, value: emptyExercisesAppeared)

            Text("Add your first exercise to start logging")
                .font(.system(.subheadline, weight: .regular))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            if !recentlyUsedExercises.isEmpty {
                recentExercisesQuickAdd
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .opacity(emptyExercisesAppeared ? 1 : 0)
        .animation(.easeOut(duration: 0.4), value: emptyExercisesAppeared)
        .listRowBackground(cardBackground(variant: .neutral))
        .listRowSeparator(.hidden)
        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
        .onAppear {
            if workout.exercises.isEmpty { emptyExercisesAppeared = true }
        }
        .onChange(of: workout.exercises.isEmpty) { _, isEmpty in
            // Reset animation state when exercises change
            emptyExercisesAppeared = isEmpty
        }
    }

    private var recentExercisesQuickAdd: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Add")
                .font(.system(.caption, weight: .semibold))
                .foregroundStyle(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(recentlyUsedExercises, id: \.self) { exerciseName in
                        Button {
                            addExerciseWithMemory(name: exerciseName)
                            saveWorkout()
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(.caption, weight: .medium))
                                Text(exerciseName)
                                    .font(.system(.subheadline, weight: .medium))
                            }
                            .foregroundStyle(.blue)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(
                                Capsule()
                                    .fill(Color.blue.opacity(0.12))
                                    .overlay(
                                        Capsule()
                                            .stroke(Color.blue.opacity(0.25), lineWidth: 1)
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var exercisesList: some View {
        let displayItems = workout.exercisesGroupedForDisplay.reversed()
        return ForEach(Array(displayItems.enumerated()), id: \.element.id) { index, item in
            Group {
                switch item {
                case .standalone(let exercise):
                    NavigationLink {
                        ExerciseEditView(exercise: exercise, workout: workout, namespace: exerciseTransition)
                    } label: {
                        ExerciseCard(
                            exercise: exercise,
                            workout: workout,
                            namespace: exerciseTransition,
                            isActive: workout.isActive && index == 0
                        )
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        exerciseContextMenu(for: exercise)
                    }

                case .superset(let groupId, let exercises):
                    SupersetGroupCard(
                        groupId: groupId,
                        exercises: exercises,
                        workout: workout,
                        namespace: exerciseTransition,
                        isActive: workout.isActive && index == 0,
                        onBreakSuperset: {
                            workout.breakSuperset(groupId: groupId)
                            saveWorkout()
                        }
                    )
                }
            }
            .staggeredAppear(index: index, maxStagger: 5)
        }
        .onDelete { indexSet in
            // Store indices and show confirmation
            pendingDeleteIndices = indexSet
            showingDeleteExerciseConfirmation = true
        }
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
    }

    @ViewBuilder
    private func exerciseContextMenu(for exercise: Exercise) -> some View {
        if workout.isActive {
            // Superset options
            let otherExercises = workout.exercises.filter { $0.id != exercise.id && !$0.isInSuperset }

            if !otherExercises.isEmpty {
                Menu {
                    ForEach(otherExercises) { other in
                        Button {
                            workout.createSuperset(from: [exercise.id, other.id])
                            saveWorkout()
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        } label: {
                            Label(other.name, systemImage: "link")
                        }
                    }
                } label: {
                    Label("Create Superset With...", systemImage: "link.badge.plus")
                }
            }

            // If exercise is in superset, show option to remove
            if exercise.isInSuperset {
                Button {
                    workout.removeFromSuperset(exerciseId: exercise.id)
                    saveWorkout()
                } label: {
                    Label("Remove from Superset", systemImage: "link.badge.minus")
                }
            }
        }
    }

    private var exercisesSectionHeader: some View {
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

    private var addExerciseButton: some View {
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

    private var summaryStatsRow: some View {
        HStack(spacing: 12) {
            // Exercises stat pill
            statPill(
                value: "\(workout.exerciseCount)",
                label: "Exercises",
                icon: "figure.strengthtraining.traditional"
            )

            // Sets stat pill
            statPill(
                value: "\(workout.totalSets)",
                label: "Sets",
                icon: "checkmark.circle"
            )

            Spacer()
        }
    }

    private func statPill(value: String, label: String, icon: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(.body, weight: .medium))
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 1) {
                Text(value)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                Text(label)
                    .font(.system(.caption2, weight: .medium))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                )
        )
    }

    private var datePickerRow: some View {
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

    private func deleteExercises(at indexSet: IndexSet) {
        // The list displays exercises in reversed order, so we need to map indices
        // Collect exercise IDs first (before any mutations)
        let reversedExercises = Array(workout.exercises.reversed())
        let exerciseIdsToDelete = indexSet.compactMap { index -> UUID? in
            guard index < reversedExercises.count else { return nil }
            return reversedExercises[index].id
        }
        // Delete by ID to avoid index issues
        for id in exerciseIdsToDelete {
            workout.removeExercise(id: id)
        }
        saveWorkout()
    }

    private func addExerciseWithMemory(name: String) {
        // Haptic feedback on add
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()

        let exercise = Exercise(name: name)
        let normalizedName = name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        // Look for exercise memory
        let descriptor = FetchDescriptor<ExerciseMemory>()

        do {
            let memories = try modelContext.fetch(descriptor)

            // Find matching exercise memory
            if let memory = memories.first(where: { $0.normalizedName == normalizedName }) {
                // Auto-create sets from memory (addSet assigns sortOrder)
                for _ in 0..<memory.lastSets {
                    exercise.addSet(reps: memory.lastReps, weight: memory.lastWeight)
                }
                // Mark as auto-filled
                exercise.isAutoFilled = true
            } else {
                // Create new exercise memory immediately so it appears in search
                let newMemory = ExerciseMemory(
                    name: name,
                    lastReps: 10,
                    lastWeight: 0,
                    lastSets: 1
                )
                modelContext.insert(newMemory)
                try modelContext.save()
            }
        } catch {
            print("Error with exercise memory: \(error)")
        }

        workout.exercises.append(exercise)
        // Auto-update workout name based on exercises
        workout.updateNameFromExercises()
    }

    private func endWorkout() {
        // Stop rest timer
        RestTimerManager.shared.stop()

        // Success haptic
        let notification = UINotificationFeedbackGenerator()
        notification.notificationOccurred(.success)

        workout.endTime = Date()

        // Save exercise memory for each exercise
        saveExerciseMemory()

        // Capture PRs from this workout
        prExercises = PersonalRecordManager.processWorkoutForPRs(workout: workout, modelContext: modelContext)

        do {
            try modelContext.save()
            // Show summary instead of immediate dismiss
            showingEndSummary = true
        } catch {
            print("Error ending workout: \(error)")
        }
    }

    private func saveExerciseMemory() {
        for exercise in workout.exercises {
            guard !exercise.sets.isEmpty else { continue }

            // Get the last set's values as the "memory" (highest sortOrder)
            guard let lastSet = exercise.sets.max(by: { $0.sortOrder < $1.sortOrder }) else { continue }
            let normalizedName = exercise.name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

            // Try to find existing memory
            let descriptor = FetchDescriptor<ExerciseMemory>(
                predicate: #Predicate { $0.name.localizedStandardContains(normalizedName) }
            )

            do {
                let existingMemories = try modelContext.fetch(descriptor)

                // Find exact match
                if let memory = existingMemories.first(where: { $0.normalizedName == normalizedName }) {
                    // Update existing
                    memory.update(reps: lastSet.reps, weight: lastSet.weight, sets: exercise.sets.count)
                } else {
                    // Create new
                    let newMemory = ExerciseMemory(
                        name: exercise.name,
                        lastReps: lastSet.reps,
                        lastWeight: lastSet.weight,
                        lastSets: exercise.sets.count
                    )
                    modelContext.insert(newMemory)
                }
            } catch {
                print("Error fetching exercise memory: \(error)")
            }
        }
    }

    // MARK: - Superset Group Card
struct SupersetGroupCard: View {
    let groupId: UUID
    let exercises: [Exercise]
    let workout: Workout
    let namespace: Namespace.ID
    var isActive: Bool = false
    var onBreakSuperset: () -> Void

    private var groupLabel: String {
        switch exercises.count {
        case 2: return "SUPERSET"
        case 3: return "TRI-SET"
        default: return "GIANT SET"
        }
    }

    private var totalSets: Int {
        exercises.reduce(0) { $0 + $1.sets.count }
    }

    private var totalReps: Int {
        exercises.reduce(0) { $0 + $1.totalReps }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerView
            exercisesListView
        }
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .contextMenu {
            Button {
                onBreakSuperset()
            } label: {
                Label("Break Apart Superset", systemImage: "link.badge.minus")
            }
        }
    }

    private var headerView: some View {
        HStack(spacing: 8) {
            Image(systemName: "link")
                .font(.system(.caption, weight: .bold))
                .foregroundStyle(.purple)
            Text(groupLabel)
                .font(.system(.caption, weight: .bold))
                .foregroundStyle(.purple)
            Spacer()
            Text("\(totalSets) sets · \(totalReps) reps")
                .font(.system(.caption2, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.purple.opacity(0.08))
    }

    private var exercisesListView: some View {
        ForEach(Array(exercises.enumerated()), id: \.element.id) { index, exercise in
            exerciseRowWithConnector(exercise: exercise, index: index)
        }
    }

    @ViewBuilder
    private func exerciseRowWithConnector(exercise: Exercise, index: Int) -> some View {
        VStack(spacing: 0) {
            NavigationLink {
                ExerciseEditView(exercise: exercise, workout: workout, namespace: namespace)
            } label: {
                SupersetExerciseRow(
                    exercise: exercise,
                    position: index + 1,
                    total: exercises.count,
                    isActive: isActive && index == 0
                )
            }
            .buttonStyle(.plain)

            if index < exercises.count - 1 {
                connectorView
            }
        }
    }

    private var connectorView: some View {
        HStack(spacing: 8) {
            Rectangle()
                .fill(Color.purple.opacity(0.3))
                .frame(width: 2, height: 16)
                .padding(.leading, 20)

            Image(systemName: "arrow.down")
                .font(.system(.caption2, weight: .medium))
                .foregroundStyle(.purple.opacity(0.5))

            Spacer()
        }
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 14)
            .fill(Color.black.opacity(0.4))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .fill(isActive ? Color.purple.opacity(0.04) : Color.white.opacity(0.02))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isActive ? Color.purple.opacity(0.2) : Color.purple.opacity(0.12), lineWidth: 1)
            )
    }
}

struct SupersetExerciseRow: View {
    let exercise: Exercise
    let position: Int
    let total: Int
    var isActive: Bool = false

    private var setsSummary: String {
        if exercise.sets.isEmpty { return "No sets" }
        let count = exercise.sets.count
        let reps = exercise.totalReps
        return "\(count) \(count == 1 ? "set" : "sets") · \(reps) reps"
    }

    var body: some View {
        HStack(spacing: 12) {
            // Position indicator
            ZStack {
                Circle()
                    .fill(isActive ? Color.purple.opacity(0.2) : Color.white.opacity(0.06))
                    .frame(width: 28, height: 28)
                Text("\(position)")
                    .font(.system(.caption, weight: .bold))
                    .foregroundStyle(isActive ? .purple : .secondary)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(exercise.name)
                        .font(.system(.subheadline, weight: .semibold))
                        .foregroundStyle(.primary)

                    if isActive {
                        Text("Current")
                            .font(.system(.caption2, weight: .medium))
                            .foregroundStyle(.purple)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill(Color.purple.opacity(0.12))
                            )
                    }
                }

                Text(setsSummary)
                    .font(.system(.caption, weight: .regular))
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            // Sets count badge
            if !exercise.sets.isEmpty {
                Text("\(exercise.sets.count)")
                    .font(.system(.caption2, weight: .bold))
                    .foregroundStyle(.secondary)
                    .frame(width: 20, height: 20)
                    .background(
                        Circle()
                            .fill(Color.white.opacity(0.06))
                    )
            }

            Image(systemName: "chevron.right")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }
}

    private func saveAsTemplate() {
        // Check if a template with this name already exists
        let templateName = workout.name
        let descriptor = FetchDescriptor<Workout>(
            predicate: #Predicate { $0.isTemplate == true && $0.name == templateName }
        )
        if let existing = try? modelContext.fetch(descriptor), !existing.isEmpty {
            // Template with this name already exists, update it instead
            if let existingTemplate = existing.first {
                // Remove old exercises
                existingTemplate.exercises.removeAll()
                // Copy exercises with their sets
                for exercise in workout.exercises {
                    var copiedSets: [WorkoutSet] = []
                    for (index, set) in exercise.setsByOrder.enumerated() {
                        let copiedSet = WorkoutSet(reps: set.reps, weight: set.weight, setType: set.type, sortOrder: index)
                        copiedSets.append(copiedSet)
                    }
                    let templateExercise = Exercise(name: exercise.name, sets: copiedSets)
                    existingTemplate.exercises.append(templateExercise)
                }
            }
        } else {
            // Create a new template from the current workout
            let template = Workout(name: workout.name, date: Date(), isTemplate: true)

            // Copy exercises with their sets
            for exercise in workout.exercises {
                var copiedSets: [WorkoutSet] = []
                for (index, set) in exercise.setsByOrder.enumerated() {
                    let copiedSet = WorkoutSet(reps: set.reps, weight: set.weight, setType: set.type, sortOrder: index)
                    copiedSets.append(copiedSet)
                }
                let templateExercise = Exercise(name: exercise.name, sets: copiedSets)
                template.exercises.append(templateExercise)
            }

            modelContext.insert(template)
        }

        do {
            try modelContext.save()
        } catch {
            print("Error saving template: \(error)")
        }
    }
}
