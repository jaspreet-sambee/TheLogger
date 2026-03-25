//
//  InlineSetRowView.swift
//  TheLogger
//
//  Inline set row view for editing sets within a workout, plus AddExerciseNameView
//

import SwiftUI
import SwiftData

// MARK: - Inline Set Row View
struct InlineSetRowView: View {
    @Bindable var set: WorkoutSet
    let setNumber: Int
    let exerciseName: String
    let currentWorkout: Workout
    let modelContext: ModelContext
    let onUpdate: (Int, Double) -> Void
    var onPRSet: (() -> Void)? = nil
    var onDelete: (() -> Void)? = nil
    var isInsideGroup: Bool = false

    // Observe unit system changes to trigger view refresh
    @AppStorage("unitSystem") private var unitSystem: String = "Imperial"
    @State private var isEditingReps = false
    @State private var isTypingReps = false   // True when TextField is shown for manual reps input
    @State private var isEditingWeight = false
    @State private var isTypingWeight = false  // True when TextField is shown for manual weight input
    @State private var repsText = ""
    @State private var weightText = ""
    @State private var originalReps: Int = 0
    @State private var originalWeight: Double = 0.0
    @State private var focusRepsWhenAppear = false
    @State private var focusWeightWhenAppear = false
    @State private var didAdjustViaButton = false
    @State private var didAdjustRepsViaButton = false
    @State private var isEditingDuration = false
    @State private var durationText = ""
    @State private var cachedPreviousSet: (reps: Int, weight: Double)?
    @State private var cachedPreviousDuration: Int?
    @State private var hasFetchedPrevious = false

    private var isTimeBased: Bool {
        ExerciseLibrary.shared.find(name: exerciseName)?.isTimeBased ?? false
    }

    private var isEditing: Bool {
        isEditingReps || isEditingWeight || isEditingDuration
    }

    private var isLogged: Bool {
        self.set.reps > 0 && !isEditingReps && !isEditingWeight && !isEditingDuration
    }

    private var rowBackgroundFill: Color {
        if set.type == .working {
            if isLogged { return AppColors.accentGold.opacity(0.05) }
            return isEditing ? AppColors.accent.opacity(0.08) : Color.white.opacity(0.06)
        } else {
            return set.type.color.opacity(isEditing ? 0.15 : 0.10)
        }
    }

    private func fetchPreviousSetData() {
        guard !hasFetchedPrevious else { return }
        hasFetchedPrevious = true

        let normalizedName = exerciseName.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let descriptor = FetchDescriptor<Workout>(
            sortBy: [SortDescriptor(\Workout.date, order: .reverse)]
        )
        guard let workouts = try? modelContext.fetch(descriptor) else { return }

        for workout in workouts where workout.id != currentWorkout.id && !workout.isTemplate && workout.endTime != nil {
            if let previousExercise = workout.exercises?.first(where: { ex in
                ex.name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) == normalizedName
            }) {
                let ordered = previousExercise.setsByOrder
                let setIndex = setNumber - 1
                if setIndex >= 0 && setIndex < ordered.count {
                    let previous = ordered[setIndex]
                    cachedPreviousSet = (reps: previous.reps, weight: previous.weight)
                    if isTimeBased, let d = previous.durationSeconds {
                        cachedPreviousDuration = d
                    }
                }
                return
            }
        }
    }

    var body: some View {
        HStack(spacing: 8) {
            // Set type picker menu
            Menu {
                ForEach(SetType.allCases, id: \.self) { type in
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                            set.type = type
                        }
                        onUpdate(set.reps, set.weight)
                        runPRCheckAndNotify(weight: set.weight, reps: set.reps, setType: type)
                    } label: {
                        Label(type.rawValue, systemImage: type.icon)
                    }
                }
                if let onDelete {
                    Divider()
                    Button(role: .destructive, action: onDelete) {
                        Label("Delete Set", systemImage: "trash")
                    }
                }
            } label: {
                VStack(spacing: 1) {
                    ZStack {
                        Circle()
                            .fill(set.type.color.opacity(0.15))
                            .frame(width: 32, height: 32)
                            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: set.type)

                        if set.type == .working {
                            Text("\(setNumber)")
                                .font(.system(.caption, weight: .semibold))
                                .foregroundStyle(isLogged ? AppColors.accentGold : .secondary)
                                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isLogged)
                        } else {
                            Image(systemName: set.type.icon)
                                .font(.system(.caption2, weight: .semibold))
                                .foregroundStyle(set.type.color)
                                .animation(.spring(response: 0.3, dampingFraction: 0.8), value: set.type)
                        }
                    }
                    Image(systemName: "chevron.down")
                        .font(.system(size: 7, weight: .medium))
                        .foregroundStyle(.tertiary)
                }
            }
            .buttonStyle(.plain)

            if isTimeBased {
                // Duration - inline editable for time-based exercises
                HStack(spacing: 6) {
                    Image(systemName: "clock")
                        .font(.system(.caption, weight: .medium))
                        .foregroundStyle(.secondary)

                    if isEditingDuration {
                        SelectAllTextField(
                            text: $durationText,
                            focusWhenAppear: true,
                            placeholder: "Sec",
                            keyboardType: .numberPad,
                            onFocusTriggered: { },
                            onCommit: { saveDuration() }
                        )
                        .frame(width: 60, height: 24)
                    } else {
                        Text(UnitFormatter.formatDuration(set.durationSeconds ?? 0))
                            .font(.system(.body, weight: .semibold))
                            .foregroundStyle(set.type.countsForPR ? .primary : .secondary)
                            .contentShape(Rectangle())
                            .onTapGesture { startEditingDuration() }
                    }
                }
            } else {
                // Reps - inline editable
                HStack(spacing: 6) {
                    Image(systemName: "repeat")
                        .font(.system(.caption, weight: .medium))
                        .foregroundStyle(.secondary)

                    if isEditingReps {
                        HStack(spacing: 6) {
                            // Step button -1
                            Image(systemName: "minus.circle.fill")
                                .font(.system(.subheadline, weight: .medium))
                                .foregroundStyle(.red.opacity(0.8))
                                .frame(width: 28, height: 28)
                                .contentShape(Rectangle())
                                .onTapGesture { adjustReps(-1) }

                            if isTypingReps {
                                SelectAllTextField(
                                    text: $repsText,
                                    focusWhenAppear: focusRepsWhenAppear,
                                    placeholder: "Reps",
                                    keyboardType: .numberPad,
                                    onFocusTriggered: { focusRepsWhenAppear = false },
                                    onCommit: { saveReps() }
                                )
                                .frame(width: 50, height: 24)
                            } else {
                                // Tappable value — tap to open keyboard for custom input
                                Text(repsText)
                                    .font(.system(.body, weight: .bold))
                                    .foregroundStyle(.primary)
                                    .frame(minWidth: 30)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(AppColors.accent.opacity(0.15))
                                    )
                                    .contentTransition(.numericText(value: Double(set.reps)))
                                    .animation(.spring(response: 0.3, dampingFraction: 0.8), value: set.reps)
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        isTypingReps = true
                                        focusRepsWhenAppear = true
                                    }
                            }

                            // Step button +1
                            Image(systemName: "plus.circle.fill")
                                .font(.system(.subheadline, weight: .medium))
                                .foregroundStyle(AppColors.accent.opacity(0.8))
                                .frame(width: 28, height: 28)
                                .contentShape(Rectangle())
                                .onTapGesture { adjustReps(1) }

                            // Done button
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(.subheadline, weight: .medium))
                                .foregroundStyle(AppColors.accentGold)
                                .frame(width: 28, height: 28)
                                .contentShape(Rectangle())
                                .onTapGesture { saveReps() }
                        }
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.9, anchor: .leading).combined(with: .opacity),
                            removal: .scale(scale: 0.9, anchor: .leading).combined(with: .opacity)
                        ))
                    } else {
                        Text("\(set.reps)")
                            .font(.system(.body, weight: .semibold))
                            .foregroundStyle(set.type.countsForPR ? .primary : .secondary)
                            .contentTransition(.numericText(value: Double(set.reps)))
                            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: set.reps)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                startEditingReps()
                            }
                            .transition(.opacity)
                    }
                }
            }

            Spacer()

            // Weight - inline editable (hidden for time-based)
            if !isTimeBased {
            HStack(spacing: 4) {
                if isEditingWeight {
                    HStack(spacing: 4) {
                        // Quick adjust button (decrease)
                        Image(systemName: "minus.circle.fill")
                            .font(.system(.subheadline, weight: .medium))
                            .foregroundStyle(.red.opacity(0.8))
                            .frame(width: 28, height: 28)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                adjustWeight(-5)
                            }

                        if isTypingWeight {
                            // TextField for manual input
                            SelectAllTextField(
                                text: $weightText,
                                focusWhenAppear: focusWeightWhenAppear,
                                placeholder: "Weight",
                                keyboardType: .decimalPad,
                                onFocusTriggered: { focusWeightWhenAppear = false },
                                onCommit: { saveWeight() }
                            )
                            .frame(width: 70, height: 24)
                        } else {
                            // Tappable value - tap to type custom value
                            Text(String(format: "%.1f", UnitFormatter.convertToDisplay(set.weight)))
                                .font(.system(.body, weight: .bold))
                                .foregroundStyle(.primary)
                                .frame(minWidth: 50)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(AppColors.accent.opacity(0.15))
                                )
                                .contentTransition(.numericText(value: set.weight))
                                .animation(.spring(response: 0.3, dampingFraction: 0.8), value: set.weight)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    // Switch to typing mode
                                    weightText = String(format: "%.1f", UnitFormatter.convertToDisplay(set.weight))
                                    isTypingWeight = true
                                    focusWeightWhenAppear = true
                                }
                        }

                        Text(UnitFormatter.weightUnit)
                            .font(.system(.caption2, weight: .medium))
                            .foregroundStyle(.secondary)

                        // Quick adjust button (increase)
                        Image(systemName: "plus.circle.fill")
                            .font(.system(.subheadline, weight: .medium))
                            .foregroundStyle(AppColors.accent.opacity(0.8))
                            .frame(width: 28, height: 28)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                adjustWeight(5)
                            }

                        // Done button to exit editing mode
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(.body, weight: .medium))
                            .foregroundStyle(AppColors.accentGold)
                            .frame(width: 32, height: 32)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                                    isEditingWeight = false
                                    isTypingWeight = false
                                }
                                DispatchQueue.main.async {
                                    runPRCheckAndNotify(weight: set.weight, reps: set.reps, setType: set.type)
                                }
                            }
                    }
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.9, anchor: .trailing).combined(with: .opacity),
                        removal: .scale(scale: 0.9, anchor: .trailing).combined(with: .opacity)
                    ))
                } else {
                    HStack(spacing: 4) {
                        Text("\(String(format: "%.1f", UnitFormatter.convertToDisplay(set.weight)))")
                            .font(.system(.body, weight: .semibold))
                            .foregroundStyle(set.type.countsForPR ? .primary : .secondary)
                            .contentTransition(.numericText(value: set.weight))
                            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: set.weight)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                startEditingWeight()
                            }
                        Text(UnitFormatter.weightUnit)
                            .font(.system(.caption, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                    .transition(.opacity)
                }
            }
            }
        }
        .padding(.top, isInsideGroup ? 6 : 8)
        .padding(.bottom, isInsideGroup ? 6 : 16)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: isInsideGroup ? 0 : 12)
                .fill(rowBackgroundFill)
                .animation(.spring(response: 0.35, dampingFraction: 0.82), value: isEditing)
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isLogged)
        )
        .overlay {
            if !isInsideGroup {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        set.type == .working
                            ? (isLogged ? AppColors.accentGold.opacity(0.25) : AppColors.accent.opacity(0.2))
                            : set.type.color.opacity(0.15),
                        lineWidth: 1
                    )
            }
        }
        .overlay(alignment: .bottomLeading) {
            // Previous set indicator
            if isTimeBased, let prev = cachedPreviousDuration, !isEditingDuration {
                HStack(spacing: 4) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(.caption2, weight: .medium))
                    Text("Last: \(UnitFormatter.formatDuration(prev))")
                        .font(.system(.caption2, weight: .regular))
                }
                .foregroundStyle(.tertiary)
                .padding(.leading, 48)
                .padding(.bottom, 4)
                .transition(.opacity.combined(with: .offset(y: 2)))
            } else if let previous = cachedPreviousSet, !isEditingReps && !isEditingWeight {
                HStack(spacing: 4) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(.caption2, weight: .medium))
                    Text("Last: \(previous.reps) \u{00d7} \(UnitFormatter.formatWeightCompact(previous.weight))")
                        .font(.system(.caption2, weight: .regular))
                }
                .foregroundStyle(.tertiary)
                .padding(.leading, 48)
                .padding(.bottom, 4)
                .transition(.opacity.combined(with: .offset(y: 2)))
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
        .onChange(of: set.durationSeconds) { oldValue, newValue in
            if !isEditingDuration {
                durationText = "\(newValue ?? 0)"
            }
        }
        .onAppear {
            originalReps = set.reps
            originalWeight = set.weight
            if isTimeBased {
                durationText = "\(set.durationSeconds ?? 0)"
            }
            fetchPreviousSetData()
        }
        .onDisappear {
            if isEditingReps { saveReps() }
            if isEditingWeight { saveWeight() }
            if isEditingDuration { saveDuration() }
        }
    }

    private func startEditingReps() {
        // Close weight editing first to prevent layout overflow
        if isEditingWeight {
            runPRCheckAndNotify(weight: set.weight, reps: set.reps, setType: set.type)
            withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                isEditingWeight = false
                isTypingWeight = false
            }
        }
        originalReps = set.reps
        repsText = "\(set.reps)"
        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
            isEditingReps = true
        }
        isTypingReps = false  // Start in button mode — no keyboard until user taps the value
    }

    private func startEditingDuration() {
        durationText = "\(set.durationSeconds ?? 0)"
        isEditingDuration = true
    }

    private func saveDuration() {
        defer { isEditingDuration = false }
        let secs = Int(durationText.trimmingCharacters(in: .whitespaces)) ?? 0
        let clamped = min(9999, max(1, secs))
        set.durationSeconds = clamped
        durationText = "\(clamped)"
        onUpdate(0, 0)
        showMicroFeedback()
    }

    private func startEditingWeight() {
        // Close reps editing first to prevent layout overflow
        if isEditingReps {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                isEditingReps = false
                isTypingReps = false
            }
        }
        originalWeight = set.weight
        weightText = String(format: "%.1f", UnitFormatter.convertToDisplay(set.weight))
        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
            isEditingWeight = true
        }
        focusWeightWhenAppear = true
    }

    private func adjustWeight(_ delta: Double) {
        // Set flag before resign to ensure saveWeight() sees it synchronously
        didAdjustViaButton = true
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)

        // Use the current weightText if user typed something, otherwise use set.weight
        let baseDisplay: Double
        if let parsed = parseWeight(weightText), parsed >= 0 {
            baseDisplay = parsed
        } else {
            baseDisplay = UnitFormatter.convertToDisplay(set.weight)
        }

        let newDisplay = max(0, baseDisplay + delta)
        let newStorage = UnitFormatter.convertToStorage(newDisplay)

        // Update after a tiny delay to ensure keyboard dismiss completes
        DispatchQueue.main.async { [self] in
            set.weight = newStorage
            weightText = String(format: "%.1f", newDisplay)
            onUpdate(set.reps, set.weight)

            // Keep editing mode active so user can continue adjusting
            isEditingWeight = true

            let impact = UIImpactFeedbackGenerator(style: .light)
            impact.impactOccurred()
        }
    }

    private func runPRCheckAndNotify(weight: Double, reps: Int, setType: SetType) {
        let oldPR = PersonalRecordManager.getPR(for: exerciseName, modelContext: modelContext)
        let oldScore = oldPR.map { PersonalRecordManager.prScore(weight: $0.weight, reps: $0.reps) } ?? 0

        let changed = PersonalRecordManager.recalculatePR(exerciseName: exerciseName, modelContext: modelContext)
        #if DEBUG
        debugLog("[PR] recalculatePR exercise=\(exerciseName) changed=\(changed) hasCallback=\(onPRSet != nil)")
        #endif

        if changed {
            let newPR = PersonalRecordManager.getPR(for: exerciseName, modelContext: modelContext)
            let newScore = newPR.map { PersonalRecordManager.prScore(weight: $0.weight, reps: $0.reps) } ?? 0
            if newScore > oldScore {
                onPRSet?()
            }
        }
    }

    private func adjustReps(_ delta: Int) {
        let current: Int
        if let parsed = Int(repsText.trimmingCharacters(in: .whitespaces)), parsed > 0 {
            current = parsed
        } else {
            current = set.reps
        }
        let newReps = max(1, current + delta)

        if isTypingReps {
            // Keyboard is up — block onCommit/saveReps, dismiss keyboard, apply step
            didAdjustRepsViaButton = true
            isTypingReps = false
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            DispatchQueue.main.async { [self] in
                didAdjustRepsViaButton = false
                set.reps = newReps
                repsText = "\(newReps)"
                onUpdate(set.reps, set.weight)
                isEditingReps = true
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }
        } else {
            // Button mode — no keyboard, update directly
            set.reps = newReps
            repsText = "\(newReps)"
            onUpdate(set.reps, set.weight)
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
    }

    private func saveReps() {
        if didAdjustRepsViaButton {
            didAdjustRepsViaButton = false
            return
        }
        if let value = Int(repsText.trimmingCharacters(in: .whitespaces)), value > 0 && value <= 1000 {
            set.reps = value
            onUpdate(set.reps, set.weight)
            if value != originalReps {
                showMicroFeedback()
            }
        } else {
            set.reps = originalReps
            repsText = "\(originalReps)"
        }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
            isEditingReps = false
            isTypingReps = false
        }
        DispatchQueue.main.async {
            runPRCheckAndNotify(weight: set.weight, reps: set.reps, setType: set.type)
        }
    }

    private func saveWeight() {
        // If weight was just adjusted via +/- button, skip - the button already handled everything
        if didAdjustViaButton {
            didAdjustViaButton = false
            // Don't close editing mode - let user continue adjusting
            return
        }

        let trimmed = weightText.trimmingCharacters(in: .whitespaces)
        guard let displayValue = parseWeight(trimmed), displayValue >= 0 && displayValue <= 10000 else {
            #if DEBUG
            debugLog("[PR] saveWeight REJECTED trimmed=\"\(trimmed)\"")
            #endif
            set.weight = originalWeight
            weightText = String(format: "%.1f", UnitFormatter.convertToDisplay(originalWeight))
            withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                isEditingWeight = false
            }
            return
        }
        let storageValue = UnitFormatter.convertToStorage(displayValue)
        set.weight = storageValue
        onUpdate(set.reps, set.weight)
        #if DEBUG
        debugLog("[PR] saveWeight OK display=\(displayValue) storage=\(storageValue) reps=\(set.reps)")
        #endif
        showMicroFeedback()
        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
            isEditingWeight = false
        }
        DispatchQueue.main.async {
            runPRCheckAndNotify(weight: storageValue, reps: set.reps, setType: set.type)
        }
    }

    /// Parse weight string; accepts both "." and "," as decimal separator.
    private func parseWeight(_ s: String) -> Double? {
        let t = s.trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty else { return nil }
        let normalized = t.replacingOccurrences(of: ",", with: ".")
        return Double(normalized)
    }

    private func showMicroFeedback() {
        let impact = UIImpactFeedbackGenerator(style: .soft)
        impact.impactOccurred()
    }
}

// MARK: - Add Exercise Name View
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
            .background(AppColors.background)
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
                    .tint(AppColors.accent)
                    .disabled(exerciseName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}
