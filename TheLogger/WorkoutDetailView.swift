//
//  WorkoutDetailView.swift
//  TheLogger
//
//  Main workout detail and editing view
//

import SwiftUI
import SwiftData

/// Data passed to the end-workout summary sheet (ensures PRs are captured before sheet opens)
struct EndSummaryData: Identifiable {
    let id = UUID()
    let summary: WorkoutSummary
    let workoutName: String
    let workoutDate: Date
    let prExercises: [String]
    let prDetails: [(name: String, weight: Double, reps: Int)]
}

// MARK: - Workout Detail View
struct WorkoutDetailView: View {
    @Bindable var workout: Workout
    /// Called when user taps "Log Again" on a completed workout. Parent owns navigation.
    var onLogAgain: ((Workout) -> Void)? = nil
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Namespace private var exerciseTransition
    // Observe unit system changes to trigger view refresh
    @AppStorage("unitSystem") private var unitSystem: String = "Imperial"
    @AppStorage("autoPopulateSetsFromHistory") private var autoPopulateSets: Bool = true
    @State private var showingAddExercise = false
    @State private var exerciseName = ""
    @State private var showingEndWorkoutConfirmation = false
    @State private var showingSaveAsTemplate = false
    @State private var showingOverwriteTemplateAlert = false
    @State private var pendingEndAfterSave = false
    @State private var isEditingWorkoutName = false
    @State private var workoutNameText = ""
    @State private var endSummaryData: EndSummaryData?
    @FocusState private var workoutNameFocused: Bool
    @State private var emptyExercisesAppeared = false
    @State private var showingDeleteExerciseConfirmation = false
    @State private var pendingDeleteIndices: IndexSet = []
    @State private var elapsedTime: TimeInterval = 0
    @State private var timerTask: Task<Void, Never>? = nil
    @State private var showingSettings = false
    @State private var exerciseToNavigate: Exercise?

    // Smart suggestions: library exercises (by muscle group) ranked by usage frequency
    private var suggestedExercises: [String] {
        ExerciseSuggester.suggest(for: workout, modelContext: modelContext, limit: 5)
    }

    var body: some View {
        workoutList
            .navigationTitle("Workout Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                            .foregroundStyle(.secondary)
                    }
                }
                if workout.isActive {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("End") {
                            showingEndWorkoutConfirmation = true
                        }
                        .fontWeight(.semibold)
                        .foregroundStyle(AppColors.accent)
                        .accessibilityIdentifier("endWorkoutButton")
                    }
                } else if workout.isCompleted {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Log Again") {
                            onLogAgain?(workout)
                        }
                        .fontWeight(.semibold)
                        .foregroundStyle(AppColors.accent)
                    }
                }
            }
            .sheet(isPresented: $showingAddExercise) {
                ExerciseSearchView { selectedName in
                    let exercise = addExerciseWithMemory(name: selectedName)
                    saveWorkout()
                    // Delay navigation to allow sheet to dismiss first
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        exerciseToNavigate = exercise
                    }
                }
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
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
                Button("Save as Template & End") {
                    saveAsTemplate(thenEnd: true)
                }
                Button("End") {
                    endWorkout()
                }
                Button("Discard workout", role: .destructive) {
                    discardWorkout()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Are you sure you want to end this workout?")
            }
            .alert("Template Saved", isPresented: $showingSaveAsTemplate) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Your workout has been saved as a template.")
            }
            .alert("Overwrite Template?", isPresented: $showingOverwriteTemplateAlert) {
                Button("Overwrite", role: .destructive) {
                    performSaveAsTemplate(thenEnd: pendingEndAfterSave)
                }
                Button("Cancel", role: .cancel) {
                    pendingEndAfterSave = false
                }
            } message: {
                Text("A template named \"\(workout.name)\" already exists. Do you want to overwrite it?")
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
            .sheet(item: $endSummaryData) { data in
                WorkoutEndSummaryView(
                    summary: data.summary,
                    workoutName: data.workoutName,
                    workoutDate: data.workoutDate,
                    prExercises: data.prExercises,
                    prDetails: data.prDetails
                ) {
                    endSummaryData = nil
                    dismiss()
                }
                .presentationDetents([.large])
                .presentationBackground(AppColors.background)
            }
            .navigationDestination(item: $exerciseToNavigate) { exercise in
                ExerciseEditView(exercise: exercise, workout: workout, namespace: exerciseTransition)
            }
    }

    private var workoutList: some View {
        List {
            workoutInfoSection
            summarySection
            exercisesSection
            saveAsTemplateSection
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(AppColors.background)
        .safeAreaInset(edge: .bottom) {
            if workout.isActive {
                addExerciseButton
            }
        }
    }

    private var saveAsTemplateSection: some View {
        Group {
            if !workout.isActive && workout.isCompleted {
                Section {
                    Button {
                        saveAsTemplate()
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
                    .tint(AppColors.accent)
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
                        .foregroundStyle(AppColors.accent)
                        .padding(6)
                }
            }
        }
    }

    private var activeBadge: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(AppColors.accent)
                .frame(width: 6, height: 6)
            Text("Active")
                .font(.system(.caption2, weight: .semibold))
                .foregroundStyle(AppColors.accent)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(AppColors.accent.opacity(0.12))
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
                            .foregroundStyle(AppColors.accent)
                        Text(formatElapsedTime(elapsedTime))
                            .font(.system(size: 20, weight: .bold, design: .monospaced))
                            .foregroundStyle(.primary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(AppColors.accent.opacity(0.12))
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
            .fill(Color.white.opacity(0.06))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(variant.borderColor, lineWidth: 1)
            )
    }

    private var summarySection: some View {
        Section {
            VStack(spacing: 12) {
                summaryStatsRow
                if !(workout.exercises ?? []).isEmpty {
                    datePickerRow
                }
            }
            .padding(.vertical, 8)
            .listRowBackground(cardBackground(variant: workout.isActive ? .active : .neutral))
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
            if (workout.exercises ?? []).isEmpty {
                emptyExercisesView
            } else {
                if !suggestedExercises.isEmpty {
                    recentExercisesQuickAdd
                        .listRowBackground(cardBackground(variant: .neutral))
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                }
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

            if !suggestedExercises.isEmpty {
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
            if (workout.exercises ?? []).isEmpty { emptyExercisesAppeared = true }
        }
        .onChange(of: (workout.exercises ?? []).isEmpty) { _, isEmpty in
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
                    ForEach(suggestedExercises, id: \.self) { exerciseName in
                        Button {
                            let exercise = addExerciseWithMemory(name: exerciseName)
                            saveWorkout()
                            exerciseToNavigate = exercise
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(.caption, weight: .medium))
                                Text(exerciseName)
                                    .font(.system(.subheadline, weight: .medium))
                            }
                            .foregroundStyle(AppColors.accent)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(
                                Capsule()
                                    .fill(AppColors.accent.opacity(0.12))
                                    .overlay(
                                        Capsule()
                                            .stroke(AppColors.accent.opacity(0.25), lineWidth: 1)
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
        // Active workouts: newest exercise at top (reversed) so current work is always visible.
        // Templates and completed workouts: natural ascending order matches creation/template order.
        let ordered = workout.exercisesGroupedForDisplay
        let displayItems = workout.isActive ? Array(ordered.reversed()) : ordered
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
                            isActive: workout.isActive && index == 0,
                            onSaveWorkout: saveWorkout
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
            .transition(.asymmetric(
                insertion: .move(edge: .bottom).combined(with: .opacity),
                removal: .opacity
            ))
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
            // Set as Current — moves this exercise to the top of the active list
            let maxOrder = (workout.exercises ?? []).map(\.order).max() ?? 0
            let isAlreadyCurrent = exercise.order == maxOrder
            if !isAlreadyCurrent {
                Button {
                    setAsCurrent(exercise: exercise)
                } label: {
                    Label("Set as Current", systemImage: "arrow.up.circle")
                }
            }

            // Superset options
            let otherExercises = (workout.exercises ?? []).filter { $0.id != exercise.id && !$0.isInSuperset }

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

    private func setAsCurrent(exercise: Exercise) {
        let maxOrder = (workout.exercises ?? []).map(\.order).max() ?? 0
        exercise.order = maxOrder + 1
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        saveWorkout()
    }

    private var exercisesSectionHeader: some View {
        HStack {
            Text("Exercises")
                .font(.system(.caption, weight: .medium))
            if !(workout.exercises ?? []).isEmpty {
                Spacer()
                Text("\((workout.exercises ?? []).count)")
                    .font(.system(.caption, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(
                        Capsule()
                            .fill(Color.white.opacity(0.12))
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
            Label("Add Exercise", systemImage: "plus.circle.fill")
                .font(.system(.body, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(AppColors.accent)
                .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("addExerciseButton")
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
                .foregroundStyle(AppColors.accent.opacity(0.7))

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
                .fill(AppColors.accent.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(AppColors.accent.opacity(0.25), lineWidth: 1)
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
                .environment(\.colorScheme, .dark)
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
        // Map display item indices to exercise IDs (must match the order used in exercisesList)
        let ordered = workout.exercisesGroupedForDisplay
        let displayItems = workout.isActive ? Array(ordered.reversed()) : ordered
        let exerciseIdsToDelete = indexSet.flatMap { index -> [UUID] in
            guard index < displayItems.count else { return [] }
            return displayItems[index].allExercises.map(\.id)
        }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            for id in exerciseIdsToDelete {
                workout.removeExercise(id: id)
            }
        }
        saveWorkout()
    }

    @discardableResult
    private func addExerciseWithMemory(name: String) -> Exercise {
        // Haptic feedback on add
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()

        let nextOrder = (workout.exercises ?? []).map(\.order).max().map { $0 + 1 } ?? 0
        let exercise = Exercise(name: name, order: nextOrder)
        let normalizedName = name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        // Look for exercise memory
        let descriptor = FetchDescriptor<ExerciseMemory>()

        do {
            let memories = try modelContext.fetch(descriptor)

            // Find matching exercise memory
            if let memory = memories.first(where: { $0.normalizedName == normalizedName }) {
                if autoPopulateSets {
                    let isTimeBased = ExerciseLibrary.shared.find(name: name)?.isTimeBased ?? false
                    for _ in 0..<memory.lastSets {
                        if isTimeBased, let d = memory.lastDuration {
                            exercise.addSet(reps: 0, weight: 0, durationSeconds: d)
                        } else {
                            exercise.addSet(reps: memory.lastReps, weight: memory.lastWeight)
                        }
                    }
                    exercise.isAutoFilled = true
                }
            } else {
                // Create new exercise memory immediately so it appears in search
                let newMemory = ExerciseMemory(
                    name: name,
                    lastReps: 0,
                    lastWeight: 0,
                    lastSets: 1
                )
                modelContext.insert(newMemory)
                try modelContext.save()
            }
        } catch {
            print("Error with exercise memory: \(error)")
        }

        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            if workout.exercises == nil {
                workout.exercises = [exercise]
            } else {
                workout.exercises?.append(exercise)
            }
        }
        workout.updateNameFromExercises()

        // Update LiveActivity with the new exercise
        if workout.isActive {
            let sets = exercise.setsByOrder
            let lastSet = sets.last
            Task {
                await LiveActivityManager.shared.updateActivity(
                    exerciseName: exercise.name,
                    exerciseId: exercise.id,
                    exerciseSets: sets.count,
                    lastReps: lastSet?.reps ?? 0,
                    lastWeight: lastSet?.weight ?? 0
                )
            }
            workout.syncToWidget(currentExercise: exercise)
        }

        return exercise
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
        let prExercises = PersonalRecordManager.processWorkoutForPRs(workout: workout, modelContext: modelContext)
        let prDetails = prExercises.compactMap { name -> (name: String, weight: Double, reps: Int)? in
            guard let pr = PersonalRecordManager.getPR(for: name, modelContext: modelContext) else { return nil }
            return (name: name, weight: pr.weight, reps: pr.reps)
        }

        do {
            try modelContext.save()
            // Invalidate PR cache and notify so Recent PRs section updates
            PRManager.shared.invalidateCache()
            NotificationCenter.default.post(name: .workoutEnded, object: nil)
            // Clear widget data since workout ended
            WidgetDataManager.clear()
            // End Live Activity
            Task {
                await LiveActivityManager.shared.endActivity()
            }
            // Show summary with captured PR data
            endSummaryData = EndSummaryData(
                summary: workout.summary,
                workoutName: workout.name,
                workoutDate: workout.date,
                prExercises: prExercises,
                prDetails: prDetails
            )
        } catch {
            print("Error ending workout: \(error)")
        }
    }

    private func discardWorkout() {
        // Stop rest timer
        RestTimerManager.shared.stop()

        // Clear widget data
        WidgetDataManager.clear()

        // End Live Activity
        Task {
            await LiveActivityManager.shared.endActivity()
        }

        // Collect exercise names before deletion — live PR checks may have written PRs
        // using this workout's sets. After deletion those sets are gone, so we must
        // re-scan history to restore the true previous best.
        let affectedExerciseNames = (workout.exercises ?? []).map { $0.name }

        // Delete the workout
        modelContext.delete(workout)

        do {
            try modelContext.save()
            // Workout and its sets are now gone from the store.
            // Recalculate PRs so they reflect the true best across remaining history.
            for name in affectedExerciseNames {
                PersonalRecordManager.recalculatePR(exerciseName: name, modelContext: modelContext)
            }
            dismiss()
        } catch {
            print("Error discarding workout: \(error)")
        }
    }

    private func saveExerciseMemory() {
        for exercise in (workout.exercises ?? []) {
            let sets = exercise.sets ?? []
            guard !sets.isEmpty else { continue }

            // Get the last set's values as the "memory" (highest sortOrder)
            guard let lastSet = sets.max(by: { $0.sortOrder < $1.sortOrder }) else { continue }
            let normalizedName = exercise.name.lowercased().trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)

            // Try to find existing memory
            let descriptor = FetchDescriptor<ExerciseMemory>(
                predicate: #Predicate { $0.name.localizedStandardContains(normalizedName) }
            )

            do {
                let existingMemories = try modelContext.fetch(descriptor)

                // Find exact match
                let isTimeBased = ExerciseLibrary.shared.find(name: exercise.name)?.isTimeBased ?? false
                let duration = lastSet.durationSeconds
                if let memory = existingMemories.first(where: { $0.normalizedName == normalizedName }) {
                    memory.update(
                        reps: lastSet.reps,
                        weight: lastSet.weight,
                        sets: sets.count,
                        durationSeconds: isTimeBased ? duration : nil
                    )
                } else {
                    let newMemory = ExerciseMemory(
                        name: exercise.name,
                        lastReps: lastSet.reps,
                        lastWeight: lastSet.weight,
                        lastSets: sets.count,
                        lastDuration: isTimeBased ? duration : nil
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
        exercises.reduce(0) { $0 + ($1.sets ?? []).count }
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
                .foregroundStyle(AppColors.accentGold)
            Text(groupLabel)
                .font(.system(.caption, weight: .bold))
                .foregroundStyle(AppColors.accentGold)
            Spacer()
            Text("\(totalSets) sets · \(totalReps) reps")
                .font(.system(.caption2, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.05))
    }

    private var exercisesListView: some View {
        ForEach(Array(exercises.enumerated()), id: \.element.id) { index, exercise in
            exerciseRowWithConnector(exercise: exercise, index: index)
        }
    }

    @ViewBuilder
    private func exerciseRowWithConnector(exercise: Exercise, index: Int) -> some View {
        let isCurrentExercise = isActive && index == 0
        let hasSets = !(exercise.sets ?? []).isEmpty
        let isCompleted = hasSets && !isCurrentExercise

        VStack(spacing: 0) {
            NavigationLink {
                ExerciseEditView(exercise: exercise, workout: workout, namespace: namespace)
            } label: {
                SupersetExerciseRow(
                    exercise: exercise,
                    position: index + 1,
                    total: exercises.count,
                    isActive: isCurrentExercise
                )
            }
            .buttonStyle(.plain)
            // Active exercise: slight scale up + glow
            .scaleEffect(isCurrentExercise ? 1.02 : 1.0)
            .shadow(color: isCurrentExercise ? AppColors.accentGold.opacity(0.25) : .clear, radius: 8, x: 0, y: 0)
            // Completed exercises: fade back slightly
            .opacity(isCompleted ? 0.7 : 1.0)
            .animation(.spring(response: 0.4, dampingFraction: 0.7), value: isCurrentExercise)
            .animation(.easeInOut(duration: 0.3), value: hasSets)

            if index < exercises.count - 1 {
                connectorView
            }
        }
    }

    private var connectorView: some View {
        HStack(spacing: 8) {
            Rectangle()
                .fill(AppColors.accentGold.opacity(0.3))
                .frame(width: 2, height: 16)
                .padding(.leading, 20)

            Image(systemName: "arrow.down")
                .font(.system(.caption2, weight: .medium))
                .foregroundStyle(AppColors.accentGold.opacity(0.5))

            Spacer()
        }
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 14)
            .fill(Color.white.opacity(0.05))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .fill(isActive ? AppColors.accentGold.opacity(0.06) : Color.white.opacity(0.02))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isActive ? AppColors.accentGold.opacity(0.25) : AppColors.accentGold.opacity(0.12), lineWidth: 1)
            )
    }
}

struct SupersetExerciseRow: View {
    let exercise: Exercise
    let position: Int
    let total: Int
    var isActive: Bool = false

    private var setsSummary: String {
        let sets = exercise.sets ?? []
        if sets.isEmpty { return "No sets" }
        let count = sets.count
        let reps = exercise.totalReps
        return "\(count) \(count == 1 ? "set" : "sets") · \(reps) reps"
    }

    var body: some View {
        HStack(spacing: 12) {
            // Position indicator
            ZStack {
                Circle()
                    .fill(isActive ? AppColors.accentGold.opacity(0.2) : Color.white.opacity(0.06))
                    .frame(width: 28, height: 28)
                Text("\(position)")
                    .font(.system(.caption, weight: .bold))
                    .foregroundStyle(isActive ? AppColors.accentGold : .secondary)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(exercise.name)
                        .font(.system(.subheadline, weight: .semibold))
                        .foregroundStyle(.primary)

                    if isActive {
                        Text("Current")
                            .font(.system(.caption2, weight: .medium))
                            .foregroundStyle(AppColors.accentGold)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill(AppColors.accentGold.opacity(0.12))
                            )
                    }
                }

                Text(setsSummary)
                    .font(.system(.caption, weight: .regular))
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            // Sets count badge
            if !(exercise.sets ?? []).isEmpty {
                Text("\((exercise.sets ?? []).count)")
                    .font(.system(.caption2, weight: .bold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .frame(minWidth: 20, minHeight: 20)
                    .background(
                        Capsule()
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

    private func saveAsTemplate(thenEnd: Bool = false) {
        let trimmedName = workout.name.trimmingCharacters(in: .whitespaces).lowercased()
        do {
            let allWorkouts = try modelContext.fetch(FetchDescriptor<Workout>())
            let hasDuplicate = allWorkouts.contains { t in
                t.isTemplate && t.name.trimmingCharacters(in: .whitespaces).lowercased() == trimmedName
            }
            if hasDuplicate {
                pendingEndAfterSave = thenEnd
                showingOverwriteTemplateAlert = true
                return
            }
        } catch {
            print("Error checking for duplicate template: \(error)")
        }
        performSaveAsTemplate(thenEnd: thenEnd)
    }

    private func performSaveAsTemplate(thenEnd: Bool = false) {
        let sourceExercises = workout.exercisesByOrder
        let trimmedName = workout.name.trimmingCharacters(in: .whitespaces).lowercased()

        do {
            let allWorkouts = try modelContext.fetch(FetchDescriptor<Workout>())
            if let existingTemplate = allWorkouts.first(where: {
                $0.isTemplate && $0.name.trimmingCharacters(in: .whitespaces).lowercased() == trimmedName
            }) {
                existingTemplate.exercises = []
                for (orderIndex, exercise) in sourceExercises.enumerated() {
                    var copiedSets: [WorkoutSet] = []
                    for (index, set) in exercise.setsByOrder.enumerated() {
                        let copiedSet = WorkoutSet(reps: set.reps, weight: set.weight, durationSeconds: set.durationSeconds, setType: set.type, sortOrder: index)
                        copiedSets.append(copiedSet)
                    }
                    existingTemplate.exercises?.append(Exercise(name: exercise.name, sets: copiedSets, order: orderIndex))
                }
            } else {
                let template = Workout(name: workout.name, date: Date(), isTemplate: true)
                for (orderIndex, exercise) in sourceExercises.enumerated() {
                    var copiedSets: [WorkoutSet] = []
                    for (index, set) in exercise.setsByOrder.enumerated() {
                        let copiedSet = WorkoutSet(reps: set.reps, weight: set.weight, durationSeconds: set.durationSeconds, setType: set.type, sortOrder: index)
                        copiedSets.append(copiedSet)
                    }
                    template.exercises?.append(Exercise(name: exercise.name, sets: copiedSets, order: orderIndex))
                }
                modelContext.insert(template)
            }
            try modelContext.save()
        } catch {
            print("Error saving template: \(error)")
        }

        showingSaveAsTemplate = true
        if thenEnd {
            endWorkout()
        }
    }
}