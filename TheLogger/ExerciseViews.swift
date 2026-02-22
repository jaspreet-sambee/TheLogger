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
            if let previous = (workout.exercises ?? []).first(where: {
                $0.name.lowercased().trimmingCharacters(in: .whitespaces) == normalizedName
            }), !(previous.sets ?? []).isEmpty {
                return previous
            }
        }

        return nil
    }

    // Get progress message based on comparison
    private var progressMessage: String? {
        guard let previous = previousExercise, !(exercise.sets ?? []).isEmpty else { return nil }

        // Only compare PR-eligible sets (excludes warmup)
        let currentWorkingSets = (exercise.sets ?? []).filter { $0.type.countsForPR }
        let previousWorkingSets = (previous.sets ?? []).filter { $0.type.countsForPR }

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
                            .fill(AppColors.accent)
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
                        let count = (exercise.sets ?? []).filter { $0.type == type }.count
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

            if (exercise.sets ?? []).isEmpty {
                Text("No sets added")
                    .font(.system(.subheadline, weight: .regular))
                    .foregroundStyle(isActive ? .secondary : .tertiary)
                    .padding(.top, 2)
            } else {
                let isTimeBased = ExerciseLibrary.shared.find(name: exercise.name)?.isTimeBased ?? false
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(exercise.setsByOrder) { set in
                        HStack {
                            if isTimeBased, let d = set.durationSeconds {
                                Text(UnitFormatter.formatDuration(d))
                                    .font(.system(.subheadline, weight: .regular))
                                    .foregroundStyle(isActive ? .primary : .secondary)
                            } else {
                                Text("\(set.reps) reps")
                                    .font(.system(.subheadline, weight: .regular))
                                    .foregroundStyle(isActive ? .primary : .secondary)
                            }
                            Spacer()
                            if !isTimeBased {
                                Text(UnitFormatter.formatWeight(set.weight))
                                    .font(.system(.subheadline, weight: .regular))
                                    .foregroundStyle(isActive ? .secondary : .tertiary)
                            }
                        }
                    }
                }
                .padding(.top, 4)
            }

            HStack {
                let isTimeBased = ExerciseLibrary.shared.find(name: exercise.name)?.isTimeBased ?? false
                Group {
                    if isTimeBased {
                        Text("Total: \(UnitFormatter.formatDuration(exercise.totalDurationSeconds))")
                    } else {
                        Text("Total: \(exercise.totalReps) reps")
                    }
                }
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
    var onSaveWorkout: (() -> Void)?

    private var setsSummary: String {
        let sets = exercise.sets ?? []
        if sets.isEmpty { return "No sets" }
        let count = sets.count
        let isTimeBased = ExerciseLibrary.shared.find(name: exercise.name)?.isTimeBased ?? false
        if isTimeBased {
            return "\(count) \(count == 1 ? "set" : "sets") · \(UnitFormatter.formatDuration(exercise.totalDurationSeconds))"
        }
        return "\(count) \(count == 1 ? "set" : "sets") · \(exercise.totalReps) reps"
    }

    // Determine accent color based on exercise type
    private var accentColor: Color {
        let name = exercise.name.lowercased()
        // Compound exercises (warm tones)
        let compounds = ["squat", "deadlift", "bench", "press", "row", "pull-up", "pullup", "chin-up", "dip"]
        if compounds.contains(where: { name.contains($0) }) {
            return AppColors.accent.opacity(0.7)
        }
        // Default (neutral)
        return Color.white.opacity(0.6)
    }

    var body: some View {
        HStack(spacing: 0) {
            // Left accent bar
            RoundedRectangle(cornerRadius: 2)
                .fill(isActive ? AppColors.accent : accentColor)
                .frame(width: 4)
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
                            .foregroundStyle(AppColors.accent)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(
                                Capsule()
                                    .fill(AppColors.accent.opacity(0.12))
                            )
                    }

                    // Superset menu button
                    if workout.isActive {
                        supersetMenuButton
                    }

                    // Sets count badge
                    let setsList = exercise.sets ?? []
                    if !setsList.isEmpty {
                        Text("\(setsList.count)")
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
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(isFullyLogged ? AppColors.accentGold.opacity(0.05) : (isActive ? AppColors.accent.opacity(0.06) : Color.white.opacity(0.02)))
                )
                .overlay {
                    if isFullyLogged {
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(AppColors.accentGold.opacity(0.4), lineWidth: 1.5)
                    } else if isActive {
                        AnimatedGradientBorder(cornerRadius: 12,
                            colors: AppColors.accentGradient + [AppColors.accentGradient[0]], lineWidth: 1)
                    } else {
                        RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.06), lineWidth: 1)
                    }
                }
                .matchedGeometryEffect(id: "card-\(exercise.id)", in: namespace)
        )
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: isFullyLogged)
    }

    private var isFullyLogged: Bool {
        let sets = exercise.sets ?? []
        return !sets.isEmpty && sets.allSatisfy { $0.reps > 0 }
    }

    @ViewBuilder
    private var supersetMenuButton: some View {
        let otherExercises = (workout.exercises ?? []).filter { $0.id != exercise.id && !$0.isInSuperset }

        Menu {
            if exercise.isInSuperset {
                // Show remove option if already in superset
                Button(role: .destructive) {
                    workout.removeFromSuperset(exerciseId: exercise.id)
                    onSaveWorkout?()
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                } label: {
                    Label("Remove from Superset", systemImage: "link.badge.minus")
                }
            } else if !otherExercises.isEmpty {
                // Show create superset options
                ForEach(otherExercises) { other in
                    Button {
                        workout.createSuperset(from: [exercise.id, other.id])
                        onSaveWorkout?()
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    } label: {
                        Label(other.name, systemImage: "link")
                    }
                }
            } else {
                // No other exercises available
                Text("No other exercises to superset")
                    .foregroundStyle(.secondary)
            }
        } label: {
            Image(systemName: exercise.isInSuperset ? "link.circle.fill" : "link.circle")
                .font(.system(.caption, weight: .medium))
                .foregroundStyle(exercise.isInSuperset ? .purple : .secondary)
                .frame(width: 24, height: 24)
                .contentShape(Rectangle())
        }
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
    @State private var newSetReps: Int = 0
    @State private var newSetWeight: Double = 0
    @State private var newSetDuration: Int = 30
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
    private let restTimer = RestTimerManager.shared
    @State private var restTimerEnabled: Bool? = nil  // nil = global default, true/false = explicit
    @State private var quickLogStripOffset: CGFloat = 50
    @State private var quickLogStripOpacity: Double = 0
    @State private var showCameraRepCounter = false  // Camera-based rep counting
    @State private var showingCameraUnsupported = false

    var body: some View {
        List {
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
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                    isNoteExpanded = false
                                }
                            }
                            .font(.caption)
                        }
                    }
                    .padding(.vertical, 4)
                    .listRowBackground(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.white.opacity(0.06))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
                            )
                    )
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                } else {
                    Button {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            isNoteExpanded = true
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: noteText.isEmpty ? "note.text.badge.plus" : "note.text")
                                .font(.system(.subheadline))
                                .foregroundStyle(noteText.isEmpty ? Color.secondary : AppColors.accent)

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
                    .listRowBackground(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.white.opacity(0.06))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
                            )
                    )
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                }
            }

            // Rest Timer section - dedicated and visible
            Section {
                HStack(spacing: 12) {
                    Image(systemName: "timer")
                        .font(.system(.body))
                        .foregroundStyle(AppColors.accent)
                        .frame(width: 28)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Rest Timer")
                            .font(.system(.body, weight: .medium))
                            .foregroundStyle(.primary)

                        Text("Persists across workouts")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }

                    Spacer()

                    Menu {
                        Button {
                            restTimerEnabled = nil
                            saveRestTimerPreference()
                        } label: {
                            Label("Use Global Default", systemImage: restTimerEnabled == nil ? "checkmark" : "")
                        }

                        Button {
                            restTimerEnabled = true
                            saveRestTimerPreference()
                        } label: {
                            Label("Always Show", systemImage: restTimerEnabled == true ? "checkmark" : "")
                        }

                        Button {
                            restTimerEnabled = false
                            saveRestTimerPreference()
                        } label: {
                            Label("Never Show", systemImage: restTimerEnabled == false ? "checkmark" : "")
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(restTimerStatusText)
                                .font(.system(.subheadline, weight: .medium))
                                .foregroundStyle(AppColors.accent)
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(AppColors.accent.opacity(0.15))
                        )
                    }
                }
                .padding(.vertical, 2)
                .listRowBackground(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.06))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.white.opacity(0.12), lineWidth: 1)
                        )
                )
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
            }

            Section {
                if (exercise.sets ?? []).isEmpty {
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
                    .listRowBackground(Color.white.opacity(0.06))
                    .listRowSeparator(.hidden)
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
                                if !(ExerciseLibrary.shared.find(name: exercise.name)?.isTimeBased ?? false) {
                                    set.reps = newReps
                                    set.weight = newWeight
                                }
                                saveChanges()
                                loadPR()
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
                        .id(set.id)
                        .transition(.asymmetric(
                            insertion: .push(from: .bottom).combined(with: .opacity),
                            removal: .opacity
                        ))
                        .staggeredAppear(index: index, maxStagger: 8)
                        .listRowBackground(Color.white.opacity(0.06))
                        .listRowSeparator(.hidden)
                    }
                    .onDelete { indexSet in
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                            let ordered = exercise.setsByOrder
                            for index in indexSet where index < ordered.count {
                                exercise.removeSet(id: ordered[index].id)
                            }
                        }
                        saveChanges()
                        // Recalculate PR in case the deleted set was the PR set
                        PersonalRecordManager.recalculatePR(exerciseName: exercise.name, modelContext: modelContext)
                        loadPR()
                        // Sync widget + live activity after deletion
                        if workout.isActive {
                            workout.syncToWidget(currentExercise: exercise)
                            let lastSet = exercise.setsByOrder.last
                            let timeBased = ExerciseLibrary.shared.find(name: exercise.name)?.isTimeBased ?? false
                            Task {
                                await LiveActivityManager.shared.updateActivity(
                                    exerciseName: exercise.name,
                                    exerciseId: exercise.id,
                                    exerciseSets: (exercise.sets ?? []).count,
                                    lastReps: timeBased ? 0 : (lastSet?.reps ?? 0),
                                    lastWeight: timeBased ? 0 : (lastSet?.weight ?? 0)
                                )
                            }
                        }
                    }

                    // Rest timer (shows below sets when active)
                    if workout.isActive {
                        RestTimerView(exerciseId: exercise.id)
                            .listRowBackground(Color.white.opacity(0.06))
                            .listRowSeparator(.hidden)
                    }
                }

                if isAddingSet {
                    // Show QuickLogStrip for adding sets — pre-fill from last set if available, else 0/0
                    let exerciseIsTimeBased = ExerciseLibrary.shared.find(name: exercise.name)?.isTimeBased ?? false
                    let setsEmpty = (exercise.sets ?? []).isEmpty
                    HStack(spacing: 6) {
                        // Camera button alongside strip when adding the first set
                        if workout.isActive && !exerciseIsTimeBased && setsEmpty {
                            Button {
                                if ExerciseType.from(exerciseName: exercise.name) != nil {
                                    showCameraRepCounter = true
                                } else {
                                    showingCameraUnsupported = true
                                }
                            } label: {
                                Image(systemName: "camera.viewfinder")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundStyle(.white)
                                    .frame(width: 36, height: 36)
                                    .background(RoundedRectangle(cornerRadius: 8).fill(AppColors.accent.opacity(0.8)))
                            }
                            .buttonStyle(.plain)
                        }
                        QuickLogStrip(
                            lastSet: exercise.setsByOrder.last,  // nil when no sets exist → 0/0 defaults
                            isTimeBased: exerciseIsTimeBased,
                            onLog: { reps, weight, duration in
                                if exerciseIsTimeBased {
                                    logSet(reps: 0, weight: 0, duration: duration)
                                } else {
                                    logSet(reps: reps, weight: weight)
                                }
                                // Close strip after logging
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                    isAddingSet = false
                                }
                            },
                            onCustom: nil  // No custom form needed - auto-chain handles everything
                        )
                    }
                    .transition(.asymmetric(
                        insertion: .move(edge: .bottom).combined(with: .opacity),
                        removal: .opacity.combined(with: .move(edge: .bottom))
                    ))
                    .listRowBackground(Color.white.opacity(0.06))
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 0, leading: 10, bottom: 0, trailing: 10))
                } else if (exercise.sets ?? []).isEmpty {
                    // No sets yet — Add Set + camera button
                    let isTimeBased = ExerciseLibrary.shared.find(name: exercise.name)?.isTimeBased ?? false
                    HStack(spacing: 10) {
                        if workout.isActive && !isTimeBased {
                            Button {
                                if ExerciseType.from(exerciseName: exercise.name) != nil {
                                    showCameraRepCounter = true
                                } else {
                                    showingCameraUnsupported = true
                                }
                            } label: {
                                Image(systemName: "camera.viewfinder")
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundStyle(.white)
                                    .frame(width: 44, height: 44)
                                    .background(RoundedRectangle(cornerRadius: 10).fill(AppColors.accent.opacity(0.8)))
                            }
                            .buttonStyle(.plain)
                        }
                        Button {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                isAddingSet = true
                            }
                        } label: {
                            Label("Add Set", systemImage: "plus.circle")
                                .font(.system(.body, weight: .medium))
                        }
                        .buttonStyle(.borderless)
                        .tint(AppColors.accent)
                        .accessibilityIdentifier("addSetButton")
                    }
                    .listRowBackground(Color.white.opacity(0.06))
                    .listRowSeparator(.hidden)
                } else {
                    // Sets exist — QuickLogStrip, hidden while rest timer is active
                    let shouldShowRest = workout.isActive
                        && restTimer.shouldShowFor(exerciseId: exercise.id)
                        && shouldOfferRestTimer(for: exercise.name)

                    if let lastSet = exercise.setsByOrder.last {
                        HStack(spacing: 6) {
                            // Camera rep counter button (only for supported exercises during active workout)
                            let isTimeBased = ExerciseLibrary.shared.find(name: exercise.name)?.isTimeBased ?? false
                            if workout.isActive && !isTimeBased {
                                Button {
                                    if ExerciseType.from(exerciseName: exercise.name) != nil {
                                        showCameraRepCounter = true
                                    } else {
                                        showingCameraUnsupported = true
                                    }
                                } label: {
                                    Image(systemName: "camera.viewfinder")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundStyle(.white)
                                        .frame(width: 36, height: 36)
                                        .background(
                                            RoundedRectangle(cornerRadius: 8)
                                                .fill(AppColors.accent.opacity(0.8))
                                        )
                                }
                                .buttonStyle(.plain)
                            }

                            QuickLogStrip(
                                lastSet: lastSet,
                                isTimeBased: ExerciseLibrary.shared.find(name: exercise.name)?.isTimeBased ?? false,
                                onLog: { reps, weight, duration in
                                    logSet(reps: reps, weight: weight, duration: duration)
                                },
                                onCustom: { openAddSetForm() }
                            )
                            // Force fresh init with the new lastSet whenever set count changes.
                            // Without this, SwiftUI may reuse the QuickLogStrip instance across the
                            // isAddingSet→sets-exist branch transition, preserving stale 0/0 state.
                            .id(exercise.sets?.count ?? 0)
                        }
                        .onChange(of: shouldShowRest) { oldValue, newValue in
                            if newValue {
                                // Rest timer showing - hide QuickLogStrip immediately (no animation)
                                quickLogStripOffset = 80
                                quickLogStripOpacity = 0
                            } else {
                                // Rest timer dismissed - animate QuickLogStrip in with bounce
                                withAnimation(.interpolatingSpring(stiffness: 150, damping: 12)) {
                                    quickLogStripOffset = 0
                                    quickLogStripOpacity = 1.0
                                }
                            }
                        }
                        .offset(y: quickLogStripOffset)
                        .opacity(quickLogStripOpacity)
                        .onAppear {
                            quickLogStripOffset = shouldShowRest ? 80 : 0
                            quickLogStripOpacity = shouldShowRest ? 0 : 1.0
                        }
                        .listRowBackground(Color.white.opacity(0.06))
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 0, leading: 10, bottom: 0, trailing: 10))
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
                        let isTimeBased = ExerciseLibrary.shared.find(name: exercise.name)?.isTimeBased ?? false
                        HStack(spacing: 6) {
                            Image(systemName: isTimeBased ? "clock" : "number")
                                .font(.system(.caption, weight: .medium))
                            Text(isTimeBased ? "Total Time" : "Total Reps")
                                .font(.system(.caption, weight: .medium))
                        }
                        .foregroundStyle(.secondary)
                        Text(isTimeBased ? UnitFormatter.formatDuration(exercise.totalDurationSeconds) : "\(exercise.totalReps)")
                            .font(.system(.title2, weight: .semibold))
                            .foregroundStyle(.primary)
                    }

                    Spacer()

                }
                .padding(.vertical, 8)
                .listRowBackground(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.06))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(AppColors.accent.opacity(0.25), lineWidth: 1)
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
                            Image(systemName: "medal.fill")
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

                        if !pr.isBodyweight {
                            VStack(alignment: .trailing, spacing: 4) {
                                Text("Est. 1RM")
                                    .font(.system(.caption2, weight: .medium))
                                    .foregroundStyle(.tertiary)
                                Text(UnitFormatter.formatWeightCompact(pr.estimated1RM))
                                    .font(.system(.subheadline, weight: .semibold))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(.vertical, 8)
                    .listRowBackground(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.white.opacity(0.06))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.yellow.opacity(0.25), lineWidth: 1)
                            )
                    )
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                } header: {
                    Label("Personal Best", systemImage: "medal")
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
                            .foregroundStyle(AppColors.accent)

                        Text("View Progress")
                            .font(.system(.body, weight: .medium))
                            .foregroundStyle(.primary)

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
                .buttonStyle(.plain)
                .listRowBackground(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.06))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(AppColors.accent.opacity(0.25), lineWidth: 1)
                        )
                )
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .scrollDismissesKeyboard(.immediately)
        .background(AppColors.background)
        .navigationTitle(exercise.name)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingProgress) {
            ExerciseProgressView(exerciseName: exercise.name)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationBackground(AppColors.background)
        }
        .sheet(isPresented: $showingCameraUnsupported) {
            NavigationStack {
                List {
                    Section {
                        HStack(spacing: 12) {
                            Image(systemName: "camera.viewfinder")
                                .font(.system(size: 28))
                                .foregroundStyle(.secondary)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Not available for \(exercise.name)")
                                    .font(.system(.body, weight: .semibold))
                                Text("Camera rep counting works with these exercises:")
                                    .font(.system(.subheadline))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 8)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                    }

                    Section("Supported Exercises") {
                        ForEach(ExerciseType.allCases, id: \.self) { type in
                            Label(type.rawValue, systemImage: type.systemImage)
                                .font(.system(.subheadline))
                        }
                    }
                }
                .scrollContentBackground(.hidden)
                .background(AppColors.background)
                .navigationTitle("Camera Tracking")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { showingCameraUnsupported = false }
                    }
                }
            }
            .presentationDetents([.medium, .large])
            .presentationBackground(AppColors.background)
        }
        .fullScreenCover(isPresented: $showCameraRepCounter) {
            CameraRepCounterView(
                exerciseName: exercise.name,
                lastWeight: exercise.setsByOrder.last?.weight ?? 0,
                onSetLogged: { reps, weight in
                    logSet(reps: reps, weight: weight)
                }
            )
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
            loadRestTimerPreference()
            // Auto-open QuickLogStrip for new empty exercises during active workouts
            if (exercise.sets ?? []).isEmpty && workout.isActive {
                isAddingSet = true
            }
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
                .tint(AppColors.accent)
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
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.06))
                .shadow(color: Color.primary.opacity(0.06), radius: 8, x: 0, y: 2)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
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

    /// Log a set with all side effects (widget sync, live activity, PR check, rest offer)
    private func logSet(reps: Int, weight: Double, duration: Int? = nil) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        let timeBased = ExerciseLibrary.shared.find(name: exercise.name)?.isTimeBased ?? false

        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            if timeBased, let d = duration {
                exercise.addSet(reps: 0, weight: 0, durationSeconds: d)
            } else {
                exercise.addSet(reps: reps, weight: weight)
            }
        }
        saveChanges()
        workout.syncToWidget(currentExercise: exercise)

        Task {
            await LiveActivityManager.shared.updateActivity(
                exerciseName: exercise.name,
                exerciseId: exercise.id,
                exerciseSets: (exercise.sets ?? []).count,
                lastReps: timeBased ? 0 : reps,
                lastWeight: timeBased ? 0 : weight
            )
        }

        if !timeBased {
            checkForPR(weight: weight, reps: reps)
        }

        if workout.isActive && workout.isLastInSuperset(exercise) {
            // Check per-exercise preference before offering rest
            if shouldOfferRestTimer(for: exercise.name) {
                let restDuration = Self.suggestedRestDuration(for: exercise.name)
                RestTimerManager.shared.offerRest(for: exercise.id, duration: restDuration, autoStart: autoStartRestTimer)
            }
        }
    }

    /// Open the inline add-set form, pre-filled from the last logged set
    private func openAddSetForm() {
        RestTimerManager.shared.pause()
        let timeBased = ExerciseLibrary.shared.find(name: exercise.name)?.isTimeBased ?? false
        if workout.isActive, let lastSet = exercise.setsByOrder.last {
            if timeBased {
                newSetDuration = lastSet.durationSeconds ?? 30
            } else {
                newSetReps = lastSet.reps
                newSetWeight = lastSet.weight
            }
        } else {
            newSetReps = 0
            newSetWeight = 0
            newSetDuration = 30
        }
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            isAddingSet = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            focusedField = timeBased ? .duration : .reps
        }
    }

    /// Suggest rest duration based on exercise type (uses library)
    private static func suggestedRestDuration(for exerciseName: String) -> Int {
        ExerciseLibrary.shared.restDuration(for: exerciseName)
    }

    private var restTimerEnabledIcon: String {
        switch restTimerEnabled {
        case nil: return "circle.dotted"           // Using global default
        case true: return "checkmark.circle.fill"  // Always show
        case false: return "xmark.circle.fill"     // Never show
        }
    }

    private var restTimerEnabledColor: Color {
        switch restTimerEnabled {
        case nil: return .secondary
        case true: return .green
        case false: return .red.opacity(0.7)
        }
    }

    private var restTimerStatusText: String {
        switch restTimerEnabled {
        case nil: return "Default"
        case true: return "Always"
        case false: return "Never"
        }
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

    /// Determine if rest timer should be offered based on per-exercise preference
    private func shouldOfferRestTimer(for exerciseName: String) -> Bool {
        let normalizedName = exerciseName.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let descriptor = FetchDescriptor<ExerciseMemory>()
        let globalEnabled = UserDefaults.standard.bool(forKey: "globalRestTimerEnabled")

        guard let memories = try? modelContext.fetch(descriptor),
              let memory = memories.first(where: { $0.normalizedName == normalizedName }) else {
            return globalEnabled
        }

        // Per-exercise preference takes priority over global default
        if let enabled = memory.restTimerEnabled {
            return enabled
        }

        return globalEnabled
    }

    private func loadRestTimerPreference() {
        let normalizedName = exercise.name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let descriptor = FetchDescriptor<ExerciseMemory>()

        do {
            let memories = try modelContext.fetch(descriptor)
            if let memory = memories.first(where: { $0.normalizedName == normalizedName }) {
                restTimerEnabled = memory.restTimerEnabled
            }
        } catch {
            print("Error loading rest timer preference: \(error)")
        }
    }

    private func saveRestTimerPreference() {
        let normalizedName = exercise.name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let descriptor = FetchDescriptor<ExerciseMemory>()

        do {
            let memories = try modelContext.fetch(descriptor)
            if let memory = memories.first(where: { $0.normalizedName == normalizedName }) {
                memory.updateRestTimerEnabled(restTimerEnabled)
                try modelContext.save()
            } else {
                // Create new memory with rest timer preference
                let newMemory = ExerciseMemory(
                    name: exercise.name,
                    restTimerEnabled: restTimerEnabled
                )
                modelContext.insert(newMemory)
                try modelContext.save()
            }

            // Provide haptic feedback
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } catch {
            print("Error saving rest timer preference: \(error)")
        }
    }

    private func loadPR() {
        currentPR = PersonalRecordManager.getPR(for: exercise.name, modelContext: modelContext)
        if currentPR == nil {
            // No PR record yet — scan all historical workouts to bootstrap one.
            // This handles exercises logged before PR tracking was introduced.
            PersonalRecordManager.recalculatePR(exerciseName: exercise.name, modelContext: modelContext)
            currentPR = PersonalRecordManager.getPR(for: exercise.name, modelContext: modelContext)
        }
    }

    private func checkForPR(weight: Double, reps: Int) {
        print("[PR] checkForPR called - exercise=\(exercise.name), weight=\(weight), reps=\(reps)")
        let isNewPR = PersonalRecordManager.checkAndSavePR(
            exerciseName: exercise.name,
            weight: weight,
            reps: reps,
            workoutId: workout.id,
            modelContext: modelContext
        )
        print("[PR] checkAndSavePR returned isNewPR=\(isNewPR)")

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

// MARK: - Quick Log Strip
/// Stepper row below the set list: shows the last set's values with live
/// reps / weight (or duration) adjustment. Tap ✓ to log.
/// Hidden while rest timer is active; reappears once rest completes.
/// Tap reps or weight to edit inline — no sheet, keyboard appears once.
struct QuickLogStrip: View {
    let lastSet: WorkoutSet?  // Now optional - defaults to 0/0 when nil
    let isTimeBased: Bool
    /// Log a set: (reps, weight-in-storage-units, duration-seconds?)
    let onLog: (Int, Double, Int?) -> Void
    /// Open the full inline add-set form (optional - not needed for auto-chain flow)
    let onCustom: (() -> Void)?

    @AppStorage("unitSystem") private var unitSystem: String = "Imperial"

    @State private var reps: Int
    @State private var weightDisplay: Double   // display units (lbs or kg)
    @State private var duration: Int           // seconds
    @State private var commitScale: CGFloat = 1.0
    @State private var commitRotation: Double = 0

    // Inline editing — replaces sheet-based input for zero-lag keyboard
    private enum StripField: Hashable { case reps, weight, duration }
    @FocusState private var focusedField: StripField?
    @State private var repsText: String = ""
    @State private var weightText: String = ""
    @State private var durationText: String = ""

    init(lastSet: WorkoutSet?, isTimeBased: Bool,
         onLog: @escaping (Int, Double, Int?) -> Void,
         onCustom: (() -> Void)? = nil) {
        self.lastSet = lastSet
        self.isTimeBased = isTimeBased
        self.onLog = onLog
        self.onCustom = onCustom

        let initialReps = lastSet?.reps ?? 0
        let initialWeight = lastSet.map { UnitFormatter.convertToDisplay($0.weight) } ?? 0.0
        let initialDuration = lastSet?.durationSeconds ?? 0

        self._reps = State(initialValue: initialReps)
        self._weightDisplay = State(initialValue: initialWeight)
        self._duration = State(initialValue: initialDuration)

        // Init text states to match display values
        let weightStr = initialWeight == initialWeight.rounded()
            ? "\(Int(initialWeight))"
            : String(format: "%.1f", initialWeight)
        self._repsText = State(initialValue: "\(initialReps)")
        self._weightText = State(initialValue: weightStr)
        self._durationText = State(initialValue: "\(initialDuration)")
    }

    private var smallWeightStep: Double { unitSystem == "Imperial" ? 2.5 : 1.25 }
    private var largeWeightStep: Double { unitSystem == "Imperial" ? 5.0 : 2.5 }

    var body: some View {
        HStack(spacing: 10) {
            if isTimeBased {
                durationGroup
            } else {
                repsGroup
                weightGroup
            }

            Spacer()

            Button {
                withAnimation(.spring(response: 0.2, dampingFraction: 0.5)) {
                    commitScale = 1.3
                    commitRotation = 360
                }
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    commit()
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        commitScale = 1.0
                    }
                }
            } label: {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(.title3))
                    .foregroundStyle(AppColors.accentGold)
                    .scaleEffect(commitScale)
                    .rotationEffect(.degrees(commitRotation))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("quickLogCommitButton")
        }
        .padding(.vertical, 8)
        // Commit text when focus leaves; select all when focus arrives
        .onChange(of: focusedField) { oldField, newField in
            switch oldField {
            case .reps: commitRepsText()
            case .weight: commitWeightText()
            case .duration: commitDurationText()
            case nil: break
            }
            if newField != nil {
                // Select all so typing immediately replaces the existing value
                DispatchQueue.main.async {
                    UIApplication.shared.sendAction(#selector(UIResponder.selectAll(_:)), to: nil, from: nil, for: nil)
                }
            }
        }
        // Keep text in sync when steppers mutate the numeric state
        .onChange(of: reps) { _, newVal in
            if focusedField != .reps { repsText = "\(newVal)" }
        }
        .onChange(of: weightDisplay) { _, newVal in
            if focusedField != .weight { weightText = formatWeight(newVal) }
        }
        .onChange(of: duration) { _, newVal in
            if focusedField != .duration { durationText = "\(newVal)" }
        }
        .onChange(of: lastSet?.reps) { _, newReps in
            if let newReps, focusedField != .reps {
                reps = newReps
                repsText = "\(newReps)"
            }
        }
        .onChange(of: lastSet?.weight) { _, newWeight in
            if let newWeight, focusedField != .weight {
                let w = UnitFormatter.convertToDisplay(newWeight)
                weightDisplay = w
                weightText = formatWeight(w)
            }
        }
        .onChange(of: lastSet?.durationSeconds) { _, newDuration in
            if focusedField != .duration {
                let d = newDuration ?? 30
                duration = d
                durationText = "\(d)"
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    switch focusedField {
                    case .reps:     commitRepsText()
                    case .weight:   commitWeightText()
                    case .duration: commitDurationText()
                    case nil:       break
                    }
                    focusedField = nil
                }
                .fontWeight(.semibold)
            }
        }
    }

    // MARK: - Stepper Groups
    // TextFields are always in the hierarchy — no conditional view swapping.
    // This is required for focus to work reliably inside a List.

    private var repsGroup: some View {
        HStack(spacing: 0) {
            stepButton("−") { reps = max(0, reps - 1) }
            TextField("0", text: $repsText)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.center)
                .font(.system(.subheadline, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(AppColors.accent)
                .frame(width: 36)
                .focused($focusedField, equals: .reps)
                .onSubmit {
                    commitRepsText()
                    focusedField = .weight
                }
            stepButton("+") { reps += 1 }
        }
        .background(Capsule().fill(Color.secondary.opacity(0.1)))
    }

    private var weightGroup: some View {
        HStack(spacing: 4) {
            iconStepButton("minus.circle.fill", size: .large) {
                weightDisplay = max(0, weightDisplay - largeWeightStep)
            }
            iconStepButton("minus.circle", size: .small) {
                weightDisplay = max(0, weightDisplay - smallWeightStep)
            }
            TextField("0", text: $weightText)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.center)
                .font(.system(.subheadline, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(AppColors.accent)
                .frame(width: 56)
                .focused($focusedField, equals: .weight)
                .onSubmit {
                    commitWeightText()
                    focusedField = nil
                }
            iconStepButton("plus.circle", size: .small) {
                weightDisplay += smallWeightStep
            }
            iconStepButton("plus.circle.fill", size: .large) {
                weightDisplay += largeWeightStep
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(Capsule().fill(Color.secondary.opacity(0.1)))
    }

    private var durationGroup: some View {
        HStack(spacing: 0) {
            stepButton("−") { duration = max(5, duration - 5) }
            TextField("0", text: $durationText)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.center)
                .font(.system(.subheadline, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(AppColors.accent)
                .frame(width: 44)
                .focused($focusedField, equals: .duration)
                .onSubmit {
                    commitDurationText()
                    focusedField = nil
                }
            stepButton("+") { duration += 5 }
        }
        .background(Capsule().fill(Color.secondary.opacity(0.1)))
    }

    // MARK: - Text commit helpers

    private func commitRepsText() {
        if let v = Int(repsText.trimmingCharacters(in: .whitespaces)), v >= 0 { reps = v }
    }

    private func commitWeightText() {
        let clean = weightText.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: ".")
        if let v = Double(clean), v >= 0 { weightDisplay = v }
    }

    private func commitDurationText() {
        if let v = Int(durationText.trimmingCharacters(in: .whitespaces)), v > 0 { duration = v }
    }

    // MARK: - Helpers

    private enum ButtonSize { case small, large }

    private func stepButton(_ label: String, action: @escaping () -> Void) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred(intensity: 0.6)
            action()
        } label: {
            Text(label)
                .font(.system(.subheadline, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 26, height: 28)
        }
        .buttonStyle(.plain)
    }

    private func iconStepButton(_ systemName: String, size: ButtonSize = .large, action: @escaping () -> Void) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: size == .large ? .light : .soft).impactOccurred(intensity: size == .large ? 0.7 : 0.5)
            action()
        } label: {
            Image(systemName: systemName)
                .font(.system(size == .large ? .body : .caption, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: size == .large ? 24 : 20, height: size == .large ? 24 : 20)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    /// Integer when whole, one decimal otherwise
    private func formatWeight(_ value: Double) -> String {
        value == value.rounded() ? "\(Int(value))" : String(format: "%.1f", value)
    }

    private func commit() {
        // Commit any pending inline text edit before logging
        switch focusedField {
        case .reps: commitRepsText()
        case .weight: commitWeightText()
        case .duration: commitDurationText()
        case nil: break
        }
        focusedField = nil
        if isTimeBased {
            onLog(0, 0, duration)
        } else {
            onLog(reps, UnitFormatter.convertToStorage(weightDisplay), nil)
        }
    }
}
