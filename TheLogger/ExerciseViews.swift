//
//  ExerciseViews.swift
//  TheLogger
//
//  Exercise row, card, and edit views
//

import SwiftUI
import SwiftData

// MARK: - Exercise Row View
struct ExerciseRowView: View {
    let exercise: Exercise
    let currentWorkout: Workout
    let modelContext: ModelContext
    var isActive: Bool = false

    // Normalize exercise name for comparison (lowercase, trimmed)
    private var normalizedName: String {
        exercise.name.lowercased().trimmingCharacters(in: .whitespaces)
    }

    // Get note from ExerciseMemory
    private var exerciseNote: String? {
        let descriptor = FetchDescriptor<ExerciseMemory>()
        guard let memories = try? modelContext.fetch(descriptor) else { return nil }
        if let memory = memories.first(where: { $0.normalizedName == normalizedName }),
           let note = memory.note, !note.isEmpty {
            return note
        }
        return nil
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

        // Only compare PR-eligible sets (excludes warmup)
        let currentWorkingSets = exercise.sets.filter { $0.type.countsForPR }
        let previousWorkingSets = previous.sets.filter { $0.type.countsForPR }

        guard !currentWorkingSets.isEmpty, !previousWorkingSets.isEmpty else { return nil }

        let currentMaxWeight = currentWorkingSets.map { $0.weight }.max() ?? 0
        let previousMaxWeight = previousWorkingSets.map { $0.weight }.max() ?? 0

        let currentTotalSets = currentWorkingSets.count
        let previousTotalSets = previousWorkingSets.count

        let currentTotalReps = currentWorkingSets.reduce(0) { $0 + $1.reps }
        let previousTotalReps = previousWorkingSets.reduce(0) { $0 + $1.reps }

        // Priority 1: Weight increase
        if currentMaxWeight > previousMaxWeight {
            let increase = currentMaxWeight - previousMaxWeight
            return "+\(UnitFormatter.formatWeight(increase))"
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
                HStack(spacing: 8) {
                    // Active indicator
                    if isActive {
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 6, height: 6)
                    }

                    Text(exercise.name)
                        .font(.system(.headline, weight: .semibold))
                        .foregroundStyle(isActive ? .primary : .secondary)

                    // Subtle indicator for auto-filled data
                    if exercise.isAutoFilled {
                        Text("· from last workout")
                            .font(.system(.caption2, weight: .regular))
                            .foregroundStyle(.secondary.opacity(0.7))
                    }

                    // Set type badges (show non-working types)
                    ForEach(SetType.allCases.filter { $0 != .working }, id: \.self) { type in
                        let count = exercise.sets.filter { $0.type == type }.count
                        if count > 0 {
                            HStack(spacing: 2) {
                                Image(systemName: type.icon)
                                    .font(.system(.caption2, weight: .medium))
                                Text("\(count)")
                                    .font(.system(.caption2, weight: .semibold))
                            }
                            .foregroundStyle(type.color.opacity(0.9))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill(type.color.opacity(0.12))
                            )
                        }
                    }
                }

                // Note snippet (from ExerciseMemory)
                if let note = exerciseNote {
                    HStack(spacing: 4) {
                        Image(systemName: "note.text")
                            .font(.system(.caption2, weight: .medium))
                        Text(note)
                            .lineLimit(1)
                    }
                    .font(.system(.caption2, weight: .regular))
                    .foregroundStyle(.tertiary)
                }

                // Progress comparison (inline under exercise name)
                if let message = progressMessage {
                    Text(message)
                        .font(.system(.caption, weight: .medium))
                        .foregroundStyle(isActive ? .secondary : .tertiary)
                }
            }

            if exercise.sets.isEmpty {
                Text("No sets added")
                    .font(.system(.subheadline, weight: .regular))
                    .foregroundStyle(isActive ? .secondary : .tertiary)
                    .padding(.top, 2)
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(exercise.setsByOrder) { set in
                        HStack {
                            Text("\(set.reps) reps")
                                .font(.system(.subheadline, weight: .regular))
                                .foregroundStyle(isActive ? .primary : .secondary)
                            Spacer()
                            Text(UnitFormatter.formatWeight(set.weight))
                                .font(.system(.subheadline, weight: .regular))
                                .foregroundStyle(isActive ? .secondary : .tertiary)
                        }
                    }
                }
                .padding(.top, 4)
            }

            HStack {
                Text("Total: \(exercise.totalReps) reps")
                    .font(.system(.caption, weight: .medium))
                    .foregroundStyle(isActive ? .secondary : .tertiary)
                Spacer()
            }
            .padding(.top, 4)
        }
        .padding(.vertical, 8)
        .opacity(isActive ? 1.0 : 0.7)
    }
}

// MARK: - Exercise Card (Apple Health style, matched geometry)
struct ExerciseCard: View {
    let exercise: Exercise
    let workout: Workout
    let namespace: Namespace.ID
    var isActive: Bool = false

    private var setsSummary: String {
        if exercise.sets.isEmpty { return "No sets" }
        let count = exercise.sets.count
        let total = exercise.totalReps
        return "\(count) \(count == 1 ? "set" : "sets") · \(total) reps"
    }

    // Determine accent color based on exercise type
    private var accentColor: Color {
        let name = exercise.name.lowercased()
        // Compound exercises (warm tones)
        let compounds = ["squat", "deadlift", "bench", "press", "row", "pull-up", "pullup", "chin-up", "dip"]
        if compounds.contains(where: { name.contains($0) }) {
            return Color.orange.opacity(0.7)
        }
        // Default (neutral)
        return Color.white.opacity(0.3)
    }

    var body: some View {
        HStack(spacing: 0) {
            // Left accent bar
            RoundedRectangle(cornerRadius: 2)
                .fill(isActive ? Color.blue : accentColor)
                .frame(width: 3)
                .padding(.vertical, 8)

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Text(exercise.name)
                        .font(.system(.headline, weight: .semibold))
                        .foregroundStyle(.primary)
                        .matchedGeometryEffect(id: "title-\(exercise.id)", in: namespace)
                    Spacer(minLength: 0)

                    if isActive {
                        Text("Current")
                            .font(.system(.caption2, weight: .medium))
                            .foregroundStyle(.blue)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(
                                Capsule()
                                    .fill(Color.blue.opacity(0.12))
                            )
                    }

                    // Sets count badge
                    if !exercise.sets.isEmpty {
                        Text("\(exercise.sets.count)")
                            .font(.system(.caption, weight: .bold))
                            .foregroundStyle(.secondary)
                            .frame(width: 24, height: 24)
                            .background(
                                Circle()
                                    .fill(Color.white.opacity(0.06))
                            )
                    }
                }

                Text(setsSummary)
                    .font(.system(.subheadline, weight: .regular))
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 14)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.black.opacity(0.4))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(isActive ? Color.blue.opacity(0.06) : Color.white.opacity(0.02))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(isActive ? Color.blue.opacity(0.15) : Color.white.opacity(0.06), lineWidth: 1)
                )
                .matchedGeometryEffect(id: "card-\(exercise.id)", in: namespace)
        )
    }
}

// MARK: - Exercise Edit View
struct ExerciseEditView: View {
    @Bindable var exercise: Exercise
    let workout: Workout
    var namespace: Namespace.ID? = nil
    @Environment(\.modelContext) private var modelContext
    @AppStorage("autoStartRestTimer") private var autoStartRestTimer: Bool = false
    @AppStorage("unitSystem") private var unitSystem: String = "Imperial"
    @State private var isAddingSet = false
    @State private var newSetReps: Int = 10
    @State private var newSetWeight: Double = 135.0
    @State private var isEditingExerciseName = false
    @State private var exerciseNameText = ""
    @State private var showingProgress = false
    @State private var showingPRCelebration = false
    @State private var currentPR: PersonalRecord?
    @FocusState private var focusedField: SetInputField?
    @FocusState private var exerciseNameFocused: Bool
    @State private var isNoteExpanded = false
    @State private var noteText = ""
    @FocusState private var noteFocused: Bool
    @State private var keyboardVisible = false

    var body: some View {
        Form {
            if let ns = namespace {
                Section {
                    exerciseDetailMatchedHeader(namespace: ns)
                }
                .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            } else {
                Section {
                    exerciseNameRow
                } header: {
                    Text("Exercise Name")
                        .font(.system(.caption, weight: .medium))
                        .foregroundStyle(.secondary)
                        .textCase(nil)
                }
            }

            // Note section - collapsed by default
            Section {
                if isNoteExpanded {
                    VStack(alignment: .leading, spacing: 8) {
                        TextField("Add a note (e.g., grip width, tempo)", text: $noteText, axis: .vertical)
                            .font(.system(.subheadline))
                            .foregroundStyle(.primary)
                            .focused($noteFocused)
                            .lineLimit(3...6)
                            .textFieldStyle(.plain)
                            .onChange(of: noteFocused) { oldValue, newValue in
                                if !newValue {
                                    saveNote()
                                }
                            }
                            .onSubmit {
                                saveNote()
                            }

                        HStack {
                            Text("Persists across workouts")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Button("Done") {
                                saveNote()
                                isNoteExpanded = false
                            }
                            .font(.caption)
                        }
                    }
                    .padding(.vertical, 4)
                } else {
                    Button {
                        isNoteExpanded = true
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: noteText.isEmpty ? "note.text.badge.plus" : "note.text")
                                .font(.system(.subheadline))
                                .foregroundStyle(noteText.isEmpty ? Color.secondary : Color.blue)

                            if noteText.isEmpty {
                                Text("Add note")
                                    .font(.system(.subheadline))
                                    .foregroundStyle(.secondary)
                            } else {
                                Text(noteText)
                                    .font(.system(.subheadline))
                                    .foregroundStyle(.primary)
                                    .lineLimit(1)
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .buttonStyle(.plain)
                }
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
                    let orderedSets = exercise.setsByOrder
                    ForEach(Array(orderedSets.enumerated()), id: \.element.id) { index, set in
                        InlineSetRowView(
                            set: set,
                            setNumber: index + 1,
                            exerciseName: exercise.name,
                            currentWorkout: workout,
                            modelContext: modelContext,
                            onUpdate: { newReps, newWeight in
                                set.reps = newReps
                                set.weight = newWeight
                                saveChanges()
                            },
                            onPRSet: {
                                // Defer fetch to next run loop so context has processed save
                                DispatchQueue.main.async {
                                    loadPR()
                                }
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                                    showingPRCelebration = true
                                }
                                let g = UINotificationFeedbackGenerator()
                                g.notificationOccurred(.success)
                            }
                        )
                    }
                    .onDelete { indexSet in
                        let ordered = exercise.setsByOrder
                        for index in indexSet where index < ordered.count {
                            exercise.removeSet(id: ordered[index].id)
                        }
                        saveChanges()
                    }

                    // Rest timer (shows below sets when active)
                    if workout.isActive {
                        RestTimerView(exerciseId: exercise.id)
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
                            // Check for PR
                            checkForPR(weight: newSetWeight, reps: newSetReps)
                            // Offer rest option (only for active workouts)
                            if workout.isActive {
                                let restDuration = Self.suggestedRestDuration(for: exercise.name)
                                RestTimerManager.shared.offerRest(for: exercise.id, duration: restDuration, autoStart: autoStartRestTimer)
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
                            // Resume rest timer if it was paused
                            RestTimerManager.shared.resume()
                            // Reset to previous set values or defaults
                            if workout.isActive, let lastSet = exercise.setsByOrder.last {
                                newSetReps = lastSet.reps
                                newSetWeight = lastSet.weight
                            } else {
                                newSetReps = 10
                                newSetWeight = 135.0
                            }
                        }
                    )
                } else {
                    HStack(spacing: 16) {
                        // Add Set button (opens inline form)
                        Button {
                            // Pause rest timer when adding new set
                            RestTimerManager.shared.pause()

                            // Inherit from previous set if workout is active and sets exist
                            if workout.isActive, let lastSet = exercise.setsByOrder.last {
                                newSetReps = lastSet.reps
                                newSetWeight = lastSet.weight
                            } else {
                                newSetReps = 10
                                newSetWeight = 135.0
                            }
                            isAddingSet = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                focusedField = .reps
                            }
                        } label: {
                            Label("Add Set", systemImage: "plus.circle")
                                .font(.system(.body, weight: .medium))
                        }
                        .buttonStyle(.borderless)
                        .tint(.blue)

                        // Quick Repeat button (one-tap duplicate of last set)
                        if let lastSet = exercise.setsByOrder.last {
                            Button {
                                // Haptic feedback
                                let impact = UIImpactFeedbackGenerator(style: .light)
                                impact.impactOccurred()

                                withAnimation(.easeOut(duration: 0.2)) {
                                    exercise.addSet(reps: lastSet.reps, weight: lastSet.weight)
                                }
                                saveChanges()
                                // Check for PR
                                checkForPR(weight: lastSet.weight, reps: lastSet.reps)

                                // Offer rest option (only for active workouts)
                                if workout.isActive {
                                    let restDuration = Self.suggestedRestDuration(for: exercise.name)
                                    RestTimerManager.shared.offerRest(for: exercise.id, duration: restDuration, autoStart: autoStartRestTimer)
                                }
                            } label: {
                                Label("Repeat", systemImage: "arrow.counterclockwise")
                                    .font(.system(.body, weight: .medium))
                            }
                            .buttonStyle(.borderless)
                            .tint(.secondary)
                        }
                    }
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

            // Personal Record section
            if let pr = currentPR {
                Section {
                    HStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(Color.yellow.opacity(0.15))
                                .frame(width: 44, height: 44)
                            Image(systemName: "trophy.fill")
                                .font(.system(size: 20, weight: .medium))
                                .foregroundStyle(.yellow)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Personal Record")
                                .font(.system(.caption, weight: .semibold))
                                .foregroundStyle(.secondary)
                            Text(pr.displayString)
                                .font(.system(.title3, weight: .bold))
                                .foregroundStyle(.primary)
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 4) {
                            Text("Est. 1RM")
                                .font(.system(.caption2, weight: .medium))
                                .foregroundStyle(.tertiary)
                            Text(UnitFormatter.formatWeightCompact(pr.estimated1RM))
                                .font(.system(.subheadline, weight: .semibold))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 8)
                    .listRowBackground(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.black.opacity(0.6))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.yellow.opacity(0.25), lineWidth: 1)
                            )
                    )
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                } header: {
                    Label("Personal Best", systemImage: "trophy")
                        .font(.system(.caption, weight: .medium))
                        .foregroundStyle(.secondary)
                        .textCase(nil)
                }
            }

            // Progress section
            Section {
                Button {
                    showingProgress = true
                } label: {
                    HStack {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.system(.body, weight: .medium))
                            .foregroundStyle(.blue)

                        Text("View Progress")
                            .font(.system(.body, weight: .medium))
                            .foregroundStyle(.primary)

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
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
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .scrollDismissesKeyboard(.immediately)
        .background(namespace != nil ? Color(.systemGroupedBackground) : Color(.systemBackground))
        .navigationTitle(exercise.name)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingProgress) {
            ExerciseProgressView(exerciseName: exercise.name)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationBackground(Color.black)
        }
        .overlay {
            // PR Celebration overlay (confetti + card)
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
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        withAnimation(.easeOut(duration: 0.28)) {
                            showingPRCelebration = false
                        }
                    }
                }
            }
        }
        .overlay {
            if keyboardVisible {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }
                    .allowsHitTesting(true)
                    .transition(.opacity)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
            withAnimation(.easeOut(duration: 0.28)) { keyboardVisible = true }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            withAnimation(.easeOut(duration: 0.28)) { keyboardVisible = false }
        }
        .onAppear {
            exerciseNameText = exercise.name
            loadNote()
            loadPR()
        }
        .onChange(of: exercise.name) { oldValue, newValue in
            if !isEditingExerciseName {
                exerciseNameText = newValue
            }
        }
        .onChange(of: exerciseNameFocused) { oldValue, newValue in
            if !newValue && isEditingExerciseName {
                saveExerciseName()
            }
        }
        .onChange(of: isNoteExpanded) { _, expanded in
            if expanded {
                noteFocused = true
            }
        }
    }

    private var exerciseNameRow: some View {
        HStack(spacing: 12) {
            if isEditingExerciseName {
                TextField("Exercise Name", text: $exerciseNameText)
                    .font(.system(.title3, weight: .semibold))
                    .foregroundStyle(.primary)
                    .focused($exerciseNameFocused)
                    .textFieldStyle(.plain)
                    .onSubmit { saveExerciseName() }
            } else {
                Text(exercise.name)
                    .font(.system(.title3, weight: .semibold))
                    .foregroundStyle(.primary)
                    .contentShape(Rectangle())
                    .onTapGesture { startEditingExerciseName() }
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
    }

    @ViewBuilder
    private func exerciseDetailMatchedHeader(namespace: Namespace.ID) -> some View {
        HStack(spacing: 12) {
            if isEditingExerciseName {
                TextField("Exercise Name", text: $exerciseNameText)
                    .font(.system(.headline, weight: .semibold))
                    .foregroundStyle(.primary)
                    .focused($exerciseNameFocused)
                    .textFieldStyle(.plain)
                    .onSubmit { saveExerciseName() }
            } else {
                Text(exercise.name)
                    .font(.system(.headline, weight: .semibold))
                    .foregroundStyle(.primary)
                    .contentShape(Rectangle())
                    .onTapGesture { startEditingExerciseName() }
                    .matchedGeometryEffect(id: "title-\(exercise.id)", in: namespace)
            }
            Spacer(minLength: 0)
            if !isEditingExerciseName {
                Button {
                    startEditingExerciseName()
                } label: {
                    Image(systemName: "pencil")
                        .font(.system(.caption, weight: .medium))
                }
                .tint(.accentColor)
            }
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemGroupedBackground))
                .shadow(color: Color.primary.opacity(0.06), radius: 8, x: 0, y: 2)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                )
                .matchedGeometryEffect(id: "card-\(exercise.id)", in: namespace)
        )
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

    /// Suggest rest duration based on exercise type (uses library)
    private static func suggestedRestDuration(for exerciseName: String) -> Int {
        ExerciseLibrary.shared.restDuration(for: exerciseName)
    }

    private func loadNote() {
        let normalizedName = exercise.name.lowercased().trimmingCharacters(in: .whitespaces)
        let descriptor = FetchDescriptor<ExerciseMemory>()

        do {
            let memories = try modelContext.fetch(descriptor)
            if let memory = memories.first(where: { $0.normalizedName == normalizedName }) {
                noteText = memory.note ?? ""
            }
        } catch {
            print("Error loading note: \(error)")
        }
    }

    private func saveNote() {
        let normalizedName = exercise.name.lowercased().trimmingCharacters(in: .whitespaces)
        let descriptor = FetchDescriptor<ExerciseMemory>()

        do {
            let memories = try modelContext.fetch(descriptor)
            if let memory = memories.first(where: { $0.normalizedName == normalizedName }) {
                memory.updateNote(noteText)
                try modelContext.save()
            } else if !noteText.isEmpty {
                // Create new memory with note
                let newMemory = ExerciseMemory(name: exercise.name, note: noteText)
                modelContext.insert(newMemory)
                try modelContext.save()
            }
        } catch {
            print("Error saving note: \(error)")
        }
    }

    private func loadPR() {
        currentPR = PersonalRecordManager.getPR(for: exercise.name, modelContext: modelContext)
    }

    private func checkForPR(weight: Double, reps: Int) {
        let isNewPR = PersonalRecordManager.checkAndSavePR(
            exerciseName: exercise.name,
            weight: weight,
            reps: reps,
            workoutId: workout.id,
            modelContext: modelContext
        )

        if isNewPR {
            // Reload PR and show celebration
            loadPR()
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                showingPRCelebration = true
            }

            // Haptic feedback for PR
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
        }
    }
}
