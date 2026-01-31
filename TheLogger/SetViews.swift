//
//  SetViews.swift
//  TheLogger
//
//  Set input and editing views
//

import SwiftUI
import SwiftData
import UIKit

// MARK: - Shared Enum for Set Field Focus
enum SetInputField: Hashable {
    case reps, weight
}

// MARK: - Select All Text Field
/// UITextField-backed field that selects all on focus. Dismiss via tap-overlay or scroll.
struct SelectAllTextField: UIViewRepresentable {
    @Binding var text: String
    var focusWhenAppear: Bool
    var placeholder: String
    var keyboardType: UIKeyboardType
    var onFocusTriggered: () -> Void
    var onCommit: () -> Void

    func makeUIView(context: Context) -> UITextField {
        let field = UITextField()
        field.delegate = context.coordinator
        field.placeholder = placeholder
        field.keyboardType = keyboardType
        field.borderStyle = .none
        field.backgroundColor = .clear
        field.font = .systemFont(ofSize: 17, weight: .semibold)
        field.textAlignment = .natural
        field.addTarget(context.coordinator, action: #selector(Coordinator.editingChanged), for: .editingChanged)
        return field
    }

    func updateUIView(_ uiView: UITextField, context: Context) {
        if uiView.text != text {
            uiView.text = text
        }
        if focusWhenAppear && !context.coordinator.didTriggerFocus {
            context.coordinator.didTriggerFocus = true
            onFocusTriggered()
            DispatchQueue.main.async {
                uiView.becomeFirstResponder()
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    final class Coordinator: NSObject, UITextFieldDelegate {
        var parent: SelectAllTextField
        var didTriggerFocus = false

        init(_ parent: SelectAllTextField) {
            self.parent = parent
        }

        @objc func editingChanged(_ field: UITextField) {
            parent.text = field.text ?? ""
        }

        func textFieldDidBeginEditing(_ textField: UITextField) {
            DispatchQueue.main.async {
                textField.selectAll(nil)
            }
        }

        func textFieldDidEndEditing(_ textField: UITextField) {
            parent.text = textField.text ?? ""
            parent.onCommit()
        }
    }
}

// MARK: - Inline Set Row View
struct InlineSetRowView: View {
    @Bindable var set: WorkoutSet
    let setNumber: Int
    let exerciseName: String
    let currentWorkout: Workout
    let modelContext: ModelContext
    let onUpdate: (Int, Double) -> Void
    var onPRSet: (() -> Void)? = nil

    // Observe unit system changes to trigger view refresh
    @AppStorage("unitSystem") private var unitSystem: String = "Imperial"
    @State private var isEditingReps = false
    @State private var isEditingWeight = false
    @State private var isTypingWeight = false  // True when TextField is shown for manual input
    @State private var repsText = ""
    @State private var weightText = ""
    @State private var originalReps: Int = 0
    @State private var originalWeight: Double = 0.0
    @State private var showFeedback = false
    @State private var feedbackMessage = "Set logged"
    @State private var focusRepsWhenAppear = false
    @State private var focusWeightWhenAppear = false
    @State private var didAdjustViaButton = false

    private let feedbackMessages = ["Set logged", "Saved", "Got it", "That counts", "Nice"]

    // Get previous set data for this set number
    private var previousSet: (reps: Int, weight: Double)? {
        let normalizedName = exerciseName.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        // Fetch all completed workouts
        let descriptor = FetchDescriptor<Workout>(
            sortBy: [SortDescriptor(\Workout.date, order: .reverse)]
        )

        guard let workouts = try? modelContext.fetch(descriptor) else { return nil }

        // Find most recent completed workout with same exercise
        for workout in workouts where workout.id != currentWorkout.id && !workout.isTemplate && workout.endTime != nil {
            if let previousExercise = workout.exercises.first(where: { ex in
                ex.name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) == normalizedName
            }) {
                // Get the set at the same position (setNumber - 1) using ordered sets
                let ordered = previousExercise.setsByOrder
                let setIndex = setNumber - 1
                if setIndex >= 0 && setIndex < ordered.count {
                    let previous = ordered[setIndex]
                    return (reps: previous.reps, weight: previous.weight)
                }
            }
        }

        return nil
    }

    var body: some View {
        HStack(spacing: 8) {
            // Set number indicator with type toggle
            Button {
                set.type = set.isWarmup ? .working : .warmup
                onUpdate(set.reps, set.weight)
                if set.type == .working { runPRCheckAndNotify(weight: set.weight, reps: set.reps, setType: set.type) }
            } label: {
                ZStack {
                    Circle()
                        .fill(set.isWarmup ? Color.orange.opacity(0.2) : Color(.systemGray5))
                        .frame(width: 32, height: 32)

                    if set.isWarmup {
                        Image(systemName: "flame.fill")
                            .font(.system(.caption2, weight: .semibold))
                            .foregroundStyle(.orange)
                    } else {
                        Text("\(setNumber)")
                            .font(.system(.caption, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .buttonStyle(.plain)

            // Reps - inline editable
            HStack(spacing: 6) {
                Image(systemName: "repeat")
                    .font(.system(.caption, weight: .medium))
                    .foregroundStyle(.secondary)

                if isEditingReps {
                    SelectAllTextField(
                        text: $repsText,
                        focusWhenAppear: focusRepsWhenAppear,
                        placeholder: "Reps",
                        keyboardType: .numberPad,
                        onFocusTriggered: { focusRepsWhenAppear = false },
                        onCommit: { saveReps() }
                    )
                    .frame(width: 60, height: 24)
                } else {
                    Text("\(set.reps)")
                        .font(.system(.body, weight: .semibold))
                        .foregroundStyle(set.isWarmup ? .secondary : .primary)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            startEditingReps()
                        }
                }
            }

            Spacer()

            // Weight - inline editable with quick adjust
            HStack(spacing: 4) {
                if isEditingWeight {
                    // Quick adjust buttons (decrease)
                    HStack(spacing: 0) {
                        Image(systemName: "minus.circle.fill")
                            .font(.system(.title3, weight: .medium))
                            .foregroundStyle(.red.opacity(0.8))
                            .frame(width: 36, height: 36)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                adjustWeight(-5)
                            }

                        Image(systemName: "minus.circle")
                            .font(.system(.subheadline, weight: .medium))
                            .foregroundStyle(.orange.opacity(0.8))
                            .frame(width: 32, height: 32)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                adjustWeight(-2.5)
                            }
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
                                    .fill(Color.blue.opacity(0.15))
                            )
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

                    // Quick adjust buttons (increase)
                    HStack(spacing: 0) {
                        Image(systemName: "plus.circle")
                            .font(.system(.subheadline, weight: .medium))
                            .foregroundStyle(.green.opacity(0.8))
                            .frame(width: 32, height: 32)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                adjustWeight(2.5)
                            }

                        Image(systemName: "plus.circle.fill")
                            .font(.system(.title3, weight: .medium))
                            .foregroundStyle(.blue.opacity(0.8))
                            .frame(width: 36, height: 36)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                adjustWeight(5)
                            }
                    }

                    // Done button to exit editing mode
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(.body, weight: .medium))
                        .foregroundStyle(.green)
                        .frame(width: 32, height: 32)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            isEditingWeight = false
                            isTypingWeight = false
                        }
                } else {
                    Text("\(String(format: "%.1f", UnitFormatter.convertToDisplay(set.weight)))")
                        .font(.system(.body, weight: .semibold))
                        .foregroundStyle(set.isWarmup ? .secondary : .primary)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            startEditingWeight()
                        }
                    Text(UnitFormatter.weightUnit)
                        .font(.system(.caption, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(set.isWarmup
                      ? Color.orange.opacity(isEditingReps || isEditingWeight ? 0.15 : 0.08)
                      : Color(.systemGray6).opacity(isEditingReps || isEditingWeight ? 0.8 : 0.5))
                .animation(.spring(response: 0.35, dampingFraction: 0.82), value: isEditingReps || isEditingWeight)
        )
        .overlay(alignment: .bottomLeading) {
            // Previous set indicator
            if let previous = previousSet, !isEditingReps && !isEditingWeight {
                HStack(spacing: 4) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(.caption2, weight: .medium))
                    Text("Last: \(previous.reps) × \(UnitFormatter.formatWeightCompact(previous.weight))")
                        .font(.system(.caption2, weight: .regular))
                }
                .foregroundStyle(.tertiary)
                .padding(.leading, 48)
                .padding(.bottom, 2)
            }
        }
        .overlay(alignment: .trailing) {
            if showFeedback {
                HStack(spacing: 3) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.green)
                        .symbolEffect(.bounce, value: showFeedback)
                    Text(feedbackMessage)
                        .font(.system(.caption2, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(
                    Capsule()
                        .fill(Color(.systemBackground).opacity(0.95))
                        .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
                )
                .padding(.trailing, 4)
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
                .animation(.easeOut(duration: 0.28), value: showFeedback)
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
        .onDisappear {
            if isEditingReps { saveReps() }
            if isEditingWeight { saveWeight() }
        }
    }

    private func startEditingReps() {
        originalReps = set.reps
        repsText = "\(set.reps)"
        isEditingReps = true
        focusRepsWhenAppear = true
    }

    private func startEditingWeight() {
        originalWeight = set.weight
        weightText = String(format: "%.1f", UnitFormatter.convertToDisplay(set.weight))
        isEditingWeight = true
        focusWeightWhenAppear = true
    }

    private func adjustWeight(_ delta: Double) {
        // Dismiss keyboard first to avoid race condition
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)

        // Set flag to prevent saveWeight() from overwriting
        didAdjustViaButton = true

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
            runPRCheckAndNotify(weight: newStorage, reps: set.reps, setType: set.type)

            // Keep editing mode active so user can continue adjusting
            isEditingWeight = true

            let impact = UIImpactFeedbackGenerator(style: .light)
            impact.impactOccurred()

            showMicroFeedback()
        }
    }

    private func runPRCheckAndNotify(weight: Double, reps: Int, setType: SetType) {
        let isNew = PersonalRecordManager.checkAndSavePR(
            exerciseName: exerciseName,
            weight: weight,
            reps: reps,
            workoutId: currentWorkout.id,
            modelContext: modelContext,
            setType: setType
        )
        #if DEBUG
        print("[PR] checkAndSavePR weight=\(weight) reps=\(reps) setType=\(setType) isNew=\(isNew) hasCallback=\(onPRSet != nil)")
        #endif
        if isNew { onPRSet?() }
    }

    private func saveReps() {
        defer { isEditingReps = false }
        if let value = Int(repsText.trimmingCharacters(in: .whitespaces)), value > 0 && value <= 1000 {
            set.reps = value
            onUpdate(set.reps, set.weight)
            runPRCheckAndNotify(weight: set.weight, reps: value, setType: set.type)
            showMicroFeedback()
        } else {
            set.reps = originalReps
            repsText = "\(originalReps)"
        }
    }

    private func saveWeight() {
        // If weight was just adjusted via +/- button, skip - the button already handled everything
        if didAdjustViaButton {
            didAdjustViaButton = false
            // Don't close editing mode - let user continue adjusting
            return
        }

        defer { isEditingWeight = false }

        let trimmed = weightText.trimmingCharacters(in: .whitespaces)
        guard let displayValue = parseWeight(trimmed), displayValue >= 0 && displayValue <= 10000 else {
            #if DEBUG
            print("[PR] saveWeight REJECTED trimmed=\"\(trimmed)\"")
            #endif
            set.weight = originalWeight
            weightText = String(format: "%.1f", UnitFormatter.convertToDisplay(originalWeight))
            return
        }
        let storageValue = UnitFormatter.convertToStorage(displayValue)
        set.weight = storageValue
        onUpdate(set.reps, set.weight)
        #if DEBUG
        print("[PR] saveWeight OK display=\(displayValue) storage=\(storageValue) reps=\(set.reps)")
        #endif
        runPRCheckAndNotify(weight: storageValue, reps: set.reps, setType: set.type)
        showMicroFeedback()
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

        feedbackMessage = feedbackMessages.randomElement() ?? "Set logged"
        withAnimation(.easeOut(duration: 0.28)) {
            showFeedback = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation(.easeOut(duration: 0.28)) {
                showFeedback = false
            }
        }
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
    @FocusState.Binding var focusedField: SetInputField?
    let onSave: () -> Void
    let onCancel: () -> Void

    @State private var repsText: String = ""
    @State private var weightText: String = ""
    @State private var showFeedback = false
    @State private var feedbackMessage = "Set logged"

    private let feedbackMessages = ["Set logged", "Added", "Saved", "Got it", "That counts", "Nice"]

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
                Text(UnitFormatter.weightUnit)
                    .font(.system(.caption, weight: .medium))
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
        .padding(.vertical, 8)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.blue.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.blue.opacity(0.25), lineWidth: 1)
                )
        )
        .overlay(alignment: .trailing) {
            if showFeedback {
                HStack(spacing: 3) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.green)
                        .symbolEffect(.bounce, value: showFeedback)
                    Text(feedbackMessage)
                        .font(.system(.caption2, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(
                    Capsule()
                        .fill(Color(.systemBackground).opacity(0.95))
                        .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
                )
                .padding(.trailing, 4)
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
                .animation(.easeOut(duration: 0.28), value: showFeedback)
                .opacity(showFeedback ? 1 : 0)
            }
        }
        .onChange(of: focusedField) { oldValue, newValue in
            if newValue == nil && oldValue != nil {
                repsText = "\(reps)"
                weightText = String(format: "%.1f", weight)
            }
        }
    }

    private func saveAndContinue() {
        // Validate reps - must be >= 1
        guard let repsValue = Int(repsText), repsValue >= 1 && repsValue <= 1000 else {
            // Invalid reps - don't save, provide feedback
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.warning)
            repsText = "\(max(1, reps))"
            return
        }

        // Light haptic on set save
        let impact = UIImpactFeedbackGenerator(style: .light)
        impact.impactOccurred()

        // Apply validated values
        reps = repsValue
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
        withAnimation(.easeOut(duration: 0.28)) {
            showFeedback = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation(.easeOut(duration: 0.28)) {
                showFeedback = false
            }
        }
    }
}

// MARK: - Add Set View
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
                                Text(UnitFormatter.formatWeight(weight))
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
                    Text("Weight (\(UnitFormatter.weightUnit))")
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

// MARK: - Edit Set View
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
                                Text(UnitFormatter.formatWeight(weight))
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
                    Text("Weight (\(UnitFormatter.weightUnit))")
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
