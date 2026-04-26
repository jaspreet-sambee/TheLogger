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

    private enum EditField: Hashable { case reps, weight, duration }
    @FocusState private var activeEditField: EditField?

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
        VStack(spacing: 0) {
            // MARK: Display row — always visible
            displayRow

            // MARK: Editing controls — shown when tapped
            if isEditing {
                editingControls
                    .transition(.asymmetric(
                        insertion: .move(edge: .top).combined(with: .opacity),
                        removal: .opacity
                    ))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, isEditing ? 12 : (isInsideGroup ? 10 : 12))
        .onChange(of: activeEditField) { oldField, newField in
            // When focus moves between fields, save the old field's value
            if oldField == .reps && newField != .reps { commitRepsValue() }
            if oldField == .weight && newField != .weight { commitWeightValue() }
        }
        .id("setRow-\(set.id.uuidString)")
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

    // MARK: - Display Row (mockup: [circle] [weight × reps] [type pill] [✓])

    private var displayRow: some View {
        HStack(spacing: 10) {
            // Set type circle (Menu for type change + delete)
            setTypeCircle

            // Combined weight × reps label
            performanceLabel

            Spacer(minLength: 0)

            // Type pill
            typePill

            // Checkmark (only when not editing)
            if !isEditing {
                Image(systemName: set.reps > 0 ? "checkmark" : "circle")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(set.reps > 0 ? AppColors.accentGold : Color.white.opacity(0.15))
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if !isEditing { enterEditingMode() }
        }
    }

    private var setTypeCircle: some View {
        Menu {
            ForEach(SetType.allCases, id: \.self) { type in
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) { set.type = type }
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
            ZStack {
                Circle()
                    .fill(set.type.color.opacity(0.15))
                    .frame(width: 28, height: 28)
                if set.type == .working {
                    Text("\(setNumber)")
                        .font(.system(size: 12, weight: .heavy))
                        .foregroundStyle(set.reps > 0 ? AppColors.accentGold : Color.white.opacity(0.45))
                } else {
                    Image(systemName: set.type.icon)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(set.type.color)
                }
            }
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var performanceLabel: some View {
        if isTimeBased {
            HStack(spacing: 4) {
                Text(UnitFormatter.formatDuration(set.durationSeconds ?? 0))
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.88))
                Text("sec")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.28))
            }
        } else {
            HStack(spacing: 4) {
                if set.weight > 0 {
                    let displayWeight = UnitFormatter.convertToDisplay(set.weight)
                    let weightStr = displayWeight.truncatingRemainder(dividingBy: 1) == 0
                        ? "\(Int(displayWeight))" : String(format: "%.1f", displayWeight)
                    Text(weightStr)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Color.white.opacity(0.88))
                    Text(UnitFormatter.weightUnit)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.28))
                } else {
                    Text("BW")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Color.white.opacity(0.88))
                }
                Text("×")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.25))
                Text("\(set.reps)")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.88))
            }
        }
    }

    private var typePill: some View {
        Text(set.type == .dropSet ? "Drop" : set.type.rawValue)
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(set.type.color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(
                Capsule()
                    .fill(set.type.color.opacity(0.12))
                    .overlay(Capsule().stroke(set.type.color.opacity(0.25), lineWidth: 1))
            )
    }

    // MARK: - Editing Controls (two rows: reps, weight, then action buttons)

    private var editingControls: some View {
        VStack(spacing: 10) {
            if isTimeBased {
                HStack(spacing: 8) {
                    Text("Duration")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color.white.opacity(0.40))
                        .frame(width: 52, alignment: .leading)
                    editCircleButton("−", color: .red) {
                        let current = Int(durationText) ?? (set.durationSeconds ?? 30)
                        set.durationSeconds = max(5, current - 5)
                        durationText = "\(set.durationSeconds ?? 5)"
                        onUpdate(0, 0)
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    }
                    editValuePill($durationText, field: .duration, isActive: true)
                    editCircleButton("+", color: AppColors.accent) {
                        let current = Int(durationText) ?? (set.durationSeconds ?? 30)
                        set.durationSeconds = current + 5
                        durationText = "\(set.durationSeconds ?? 35)"
                        onUpdate(0, 0)
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    }
                }
            } else {
                HStack(spacing: 8) {
                    Text("Reps")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color.white.opacity(0.40))
                        .frame(width: 52, alignment: .leading)
                    editCircleButton("−", color: .red) { adjustReps(-1) }
                    editValuePill($repsText, field: .reps, isActive: true)
                    editCircleButton("+", color: AppColors.accent) { adjustReps(1) }
                }
                HStack(spacing: 8) {
                    Text("Weight")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color.white.opacity(0.40))
                        .frame(width: 52, alignment: .leading)
                    editCircleButton("−", color: .red) { adjustWeight(-5) }
                    editValuePill($weightText, field: .weight, isActive: true)
                    editCircleButton("+", color: AppColors.accent) { adjustWeight(5) }
                }
            }
            editActionButtons
        }
        .padding(.top, 12)
    }

    private var editActionButtons: some View {
        HStack(spacing: 10) {
            Button {
                finishEditing()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                    Text("Done")
                        .font(.system(size: 13, weight: .bold))
                }
                .foregroundStyle(AppColors.accentGold)
                .frame(maxWidth: .infinity)
                .frame(height: 36)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(AppColors.accentGold.opacity(0.12))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(AppColors.accentGold.opacity(0.25), lineWidth: 1))
                )
            }
            .buttonStyle(.plain)

            if let onDelete {
                Button(role: .destructive) {
                    onDelete()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "trash")
                            .font(.system(size: 12, weight: .bold))
                        Text("Delete")
                            .font(.system(size: 13, weight: .bold))
                    }
                    .foregroundStyle(Color.red.opacity(0.7))
                    .frame(maxWidth: .infinity)
                    .frame(height: 36)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.red.opacity(0.08))
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.red.opacity(0.18), lineWidth: 1))
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Edit Helpers

    private func editCircleButton(_ label: String, color: Color, action: @escaping () -> Void) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        } label: {
            Text(label)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(color.opacity(0.8))
                .frame(width: 34, height: 34)
                .background(
                    Circle()
                        .fill(color.opacity(0.12))
                        .overlay(Circle().stroke(color.opacity(0.25), lineWidth: 1))
                )
        }
        .buttonStyle(.plain)
    }

    private func editValuePill(_ text: Binding<String>, field: EditField, isActive: Bool, keyboard: UIKeyboardType = .decimalPad, onTap: (() -> Void)? = nil) -> some View {
        let isFocused = activeEditField == field
        return TextField("0", text: text)
            .keyboardType(.decimalPad)  // Same keyboard for both to avoid dismiss on switch
            .font(.system(size: 22, weight: .heavy))
            .monospacedDigit()
            .multilineTextAlignment(.center)
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .frame(maxWidth: .infinity, minHeight: 40)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isFocused ? AppColors.accent.opacity(0.20) : AppColors.accent.opacity(0.12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(isFocused ? AppColors.accent.opacity(0.45) : Color.white.opacity(0.08), lineWidth: 1)
                    )
            )
            .focused($activeEditField, equals: field)
    }

    private func enterEditingMode() {
        originalReps = set.reps
        originalWeight = set.weight
        repsText = "\(set.reps)"
        weightText = String(format: "%.1f", UnitFormatter.convertToDisplay(set.weight))
        if isTimeBased { durationText = "\(set.durationSeconds ?? 0)" }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
            isEditingReps = true
            isEditingWeight = true
            if isTimeBased { isEditingDuration = true }
        }
    }

    private func activateWeightEditing() {
        commitRepsValue()
        activeEditField = .weight
    }

    private func commitRepsValue() {
        if let v = Int(repsText.trimmingCharacters(in: .whitespaces)), v >= 0, v <= 1000 {
            set.reps = v
        }
        repsText = "\(set.reps)"
    }

    private func commitWeightValue() {
        let clean = weightText.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: ".")
        if let v = Double(clean), v >= 0, v <= 10000 {
            set.weight = UnitFormatter.convertToStorage(v)
        }
        weightText = String(format: "%.1f", UnitFormatter.convertToDisplay(set.weight))
    }

    private func finishEditing() {
        // Save both values
        commitRepsValue()
        commitWeightValue()

        // Save duration
        if isTimeBased, let v = Int(durationText.trimmingCharacters(in: .whitespaces)), v > 0 {
            set.durationSeconds = v
        }

        activeEditField = nil
        onUpdate(set.reps, set.weight)

        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
            isEditingReps = false
            isEditingWeight = false
            isEditingDuration = false
            isTypingReps = false
            isTypingWeight = false
        }

        DispatchQueue.main.async {
            runPRCheckAndNotify(weight: set.weight, reps: set.reps, setType: set.type)
        }
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
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
