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
    case reps, weight, duration
}

// MARK: - Simple Number Input (for auto-chaining flow)
/// Clean sheet-based input for reps/weight/duration with auto-chaining support
struct SimpleNumberInput: View {
    @Binding var value: Double
    let label: String
    let keyboardType: UIKeyboardType
    @Environment(\.dismiss) private var dismiss

    @State private var text: String = ""
    @FocusState private var isFocused: Bool

    init(value: Binding<Double>, label: String, isInteger: Bool = false) {
        self._value = value
        self.label = label
        self.keyboardType = isInteger ? .numberPad : .decimalPad
    }

    var body: some View {
        VStack(spacing: 20) {
            Text("Enter \(label)")
                .font(.headline)
                .foregroundStyle(.secondary)

            TextField(label, text: $text)
                .keyboardType(keyboardType)
                .textFieldStyle(.roundedBorder)
                .multilineTextAlignment(.center)
                .font(.system(.title2, weight: .semibold))
                .focused($isFocused)
                .onAppear {
                    // Show current value if non-zero, otherwise empty for easy entry
                    if value > 0 {
                        if keyboardType == .numberPad {
                            text = "\(Int(value))"
                        } else {
                            text = String(format: "%.1f", value)
                        }
                    } else {
                        text = ""
                    }
                    isFocused = true
                }

            HStack(spacing: 16) {
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.bordered)

                Button("Done") {
                    if let v = Double(text.replacingOccurrences(of: ",", with: ".")), v >= 0 {
                        value = v
                    }
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(text.isEmpty)
            }
            .font(.body)
        }
        .padding(24)
        .presentationDetents([.height(220)])
        .presentationDragIndicator(.visible)
    }
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

// MARK: - Set Input Text Field with Log Set Keyboard Accessory
/// UITextField with toolbar above keyboard: [Done] dismisses keyboard, [Log Set] saves set.
/// Eliminates the need to tap outside and then tap checkmark when using numberPad/decimalPad.
struct SetInputTextFieldWithAccessory: UIViewRepresentable {
    @Binding var text: String
    var placeholder: String
    var keyboardType: UIKeyboardType
    var focusWhenAppear: Bool
    var onDismissKeyboard: () -> Void
    var onLogSet: () -> Void

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

        let toolbar = UIToolbar(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 44))
        toolbar.sizeToFit()
        let doneButton = UIBarButtonItem(title: "Done", style: .plain, target: context.coordinator, action: #selector(Coordinator.doneTapped))
        let logSetButton = UIBarButtonItem(title: "Log Set", style: .done, target: context.coordinator, action: #selector(Coordinator.logSetTapped))
        let spacer = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        toolbar.items = [doneButton, spacer, logSetButton]
        field.inputAccessoryView = toolbar

        return field
    }

    func updateUIView(_ uiView: UITextField, context: Context) {
        if uiView.text != text {
            uiView.text = text
        }
        if !focusWhenAppear {
            context.coordinator.didTriggerFocus = false
        }
        if focusWhenAppear && !context.coordinator.didTriggerFocus {
            context.coordinator.didTriggerFocus = true
            DispatchQueue.main.async {
                uiView.becomeFirstResponder()
                uiView.selectAll(nil)
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    final class Coordinator: NSObject, UITextFieldDelegate {
        var parent: SetInputTextFieldWithAccessory
        var didTriggerFocus = false

        init(_ parent: SetInputTextFieldWithAccessory) {
            self.parent = parent
        }

        @objc func editingChanged(_ field: UITextField) {
            parent.text = field.text ?? ""
        }

        @objc func doneTapped() {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            parent.onDismissKeyboard()
        }

        @objc func logSetTapped() {
            parent.onLogSet()  // Save first; parent may refocus for next set (no dismiss)
        }

        func textFieldDidBeginEditing(_ textField: UITextField) {
            DispatchQueue.main.async {
                textField.selectAll(nil)
            }
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
    @State private var isTypingReps = false   // True when TextField is shown for manual reps input
    @State private var isEditingWeight = false
    @State private var isTypingWeight = false  // True when TextField is shown for manual weight input
    @State private var repsText = ""
    @State private var weightText = ""
    @State private var originalReps: Int = 0
    @State private var originalWeight: Double = 0.0
    @State private var showFeedback = false
    @State private var feedbackMessage = "Set logged"
    @State private var focusRepsWhenAppear = false
    @State private var focusWeightWhenAppear = false
    @State private var didAdjustViaButton = false
    @State private var didAdjustRepsViaButton = false
    @State private var isEditingDuration = false
    @State private var durationText = ""

    private let feedbackMessages = ["Set logged", "Saved", "Got it", "That counts", "Nice"]

    private var isTimeBased: Bool {
        ExerciseLibrary.shared.find(name: exerciseName)?.isTimeBased ?? false
    }

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
            if let previousExercise = workout.exercises?.first(where: { ex in
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

    private var previousDuration: Int? {
        guard isTimeBased else { return nil }
        let normalizedName = exerciseName.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let descriptor = FetchDescriptor<Workout>(sortBy: [SortDescriptor(\Workout.date, order: .reverse)])
        guard let workouts = try? modelContext.fetch(descriptor) else { return nil }
        for workout in workouts where workout.id != currentWorkout.id && !workout.isTemplate && workout.endTime != nil {
            if let previousExercise = workout.exercises?.first(where: { ex in
                ex.name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) == normalizedName
            }) {
                let ordered = previousExercise.setsByOrder
                let setIndex = setNumber - 1
                if setIndex >= 0, setIndex < ordered.count, let d = ordered[setIndex].durationSeconds {
                    return d
                }
            }
        }
        return nil
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
            } label: {
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
                                runPRCheckAndNotify(weight: set.weight, reps: set.reps, setType: set.type)
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                                    isEditingWeight = false
                                    isTypingWeight = false
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
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(rowBackgroundFill)
                .animation(.spring(response: 0.35, dampingFraction: 0.82), value: isEditing)
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isLogged)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    set.type == .working
                        ? (isLogged ? AppColors.accentGold.opacity(0.25) : AppColors.accent.opacity(0.2))
                        : set.type.color.opacity(0.15),
                    lineWidth: 1
                )
        )
        .overlay(alignment: .bottomLeading) {
            // Previous set indicator
            if isTimeBased, let prev = previousDuration, !isEditingDuration {
                HStack(spacing: 4) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(.caption2, weight: .medium))
                    Text("Last: \(UnitFormatter.formatDuration(prev))")
                        .font(.system(.caption2, weight: .regular))
                }
                .foregroundStyle(.tertiary)
                .padding(.leading, 48)
                .padding(.bottom, 2)
                .transition(.opacity.combined(with: .offset(y: 2)))
            } else if let previous = previousSet, !isEditingReps && !isEditingWeight {
                HStack(spacing: 4) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(.caption2, weight: .medium))
                    Text("Last: \(previous.reps) × \(UnitFormatter.formatWeightCompact(previous.weight))")
                        .font(.system(.caption2, weight: .regular))
                }
                .foregroundStyle(.tertiary)
                .padding(.leading, 48)
                .padding(.bottom, 2)
                .transition(.opacity.combined(with: .offset(y: 2)))
            }
        }
        .overlay(alignment: .trailing) {
            if showFeedback {
                HStack(spacing: 3) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(AppColors.accentGold)
                        .symbolEffect(.bounce, value: showFeedback)
                    Text(feedbackMessage)
                        .font(.system(.caption2, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(
                    Capsule()
                        .fill(Color.white.opacity(0.18))
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
        let changed = PersonalRecordManager.recalculatePR(exerciseName: exerciseName, modelContext: modelContext)
        #if DEBUG
        print("[PR] recalculatePR exercise=\(exerciseName) changed=\(changed) hasCallback=\(onPRSet != nil)")
        #endif
        if changed { onPRSet?() }
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
            runPRCheckAndNotify(weight: set.weight, reps: value, setType: set.type)
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
            print("[PR] saveWeight REJECTED trimmed=\"\(trimmed)\"")
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
        print("[PR] saveWeight OK display=\(displayValue) storage=\(storageValue) reps=\(set.reps)")
        #endif
        runPRCheckAndNotify(weight: storageValue, reps: set.reps, setType: set.type)
        showMicroFeedback()
        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
            isEditingWeight = false
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

// MARK: - Inline Add Set View
struct InlineAddSetView: View {
    @Binding var reps: Int
    @Binding var weight: Double
    @FocusState.Binding var focusedField: SetInputField?
    var exerciseName: String = ""
    var durationSeconds: Binding<Int>? = nil
    let onSave: () -> Void
    let onCancel: () -> Void

    @State private var repsText: String = ""
    @State private var weightText: String = ""
    @State private var durationText: String = ""
    @State private var showFeedback = false
    @State private var feedbackMessage = "Set logged"

    private let feedbackMessages = ["Set logged", "Added", "Saved", "Got it", "That counts", "Nice"]

    private var isTimeBased: Bool {
        !exerciseName.isEmpty && (ExerciseLibrary.shared.find(name: exerciseName)?.isTimeBased ?? false)
    }

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(AppColors.accent.opacity(0.12))
                    .frame(width: 32, height: 32)
                Image(systemName: "plus")
                    .font(.system(.caption, weight: .semibold))
                    .foregroundStyle(AppColors.accent)
            }

            if isTimeBased, let durationBinding = durationSeconds {
                // Duration input for time-based exercises (with keyboard Log Set accessory)
                HStack(spacing: 6) {
                    Image(systemName: "clock")
                        .font(.system(.caption, weight: .medium))
                        .foregroundStyle(.secondary)
                    SetInputTextFieldWithAccessory(
                        text: $durationText,
                        placeholder: "Sec",
                        keyboardType: .numberPad,
                        focusWhenAppear: focusedField == .duration,
                        onDismissKeyboard: { focusedField = nil },
                        onLogSet: { saveAndContinue() }
                    )
                    .frame(width: 70, height: 24)
                    .accessibilityIdentifier("durationInput")
                    .onAppear { durationText = "\(durationBinding.wrappedValue)" }
                    .onChange(of: durationText) { _, newValue in
                        if let v = Int(newValue), v >= 1 && v <= 9999 {
                            durationBinding.wrappedValue = v
                        }
                    }
                }
            } else {
                // Reps input (with keyboard Log Set accessory)
                HStack(spacing: 6) {
                    Image(systemName: "repeat")
                        .font(.system(.caption, weight: .medium))
                        .foregroundStyle(.secondary)
                    SetInputTextFieldWithAccessory(
                        text: $repsText,
                        placeholder: "Reps",
                        keyboardType: .numberPad,
                        focusWhenAppear: focusedField == .reps,
                        onDismissKeyboard: { focusedField = nil },
                        onLogSet: { saveAndContinue() }
                    )
                    .frame(width: 60, height: 24)
                    .accessibilityIdentifier("repsInput")
                    .onAppear { repsText = "\(reps)" }
                    .onChange(of: repsText) { _, newValue in
                        if let value = Int(newValue), value > 0 && value <= 1000 {
                            reps = value
                        }
                    }
                }
            }

            Spacer()

            if !isTimeBased {
                // Weight input (with keyboard Log Set accessory)
                HStack(spacing: 4) {
                    SetInputTextFieldWithAccessory(
                        text: $weightText,
                        placeholder: "Weight",
                        keyboardType: .decimalPad,
                        focusWhenAppear: focusedField == .weight,
                        onDismissKeyboard: { focusedField = nil },
                        onLogSet: { saveAndContinue() }
                    )
                    .frame(width: 70, height: 24)
                    .accessibilityIdentifier("weightInput")
                    .onAppear { weightText = String(format: "%.1f", UnitFormatter.convertToDisplay(weight)) }
                    .onChange(of: weightText) { _, newValue in
                        if let displayValue = Double(newValue), displayValue >= 0 && displayValue <= 10000 {
                            weight = UnitFormatter.convertToStorage(displayValue)
                        }
                    }
                    Text(UnitFormatter.weightUnit)
                        .font(.system(.caption, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }

            // Action buttons
            HStack(spacing: 8) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(.title2, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
                    .highPriorityGesture(
                        TapGesture()
                            .onEnded { _ in
                                focusedField = nil
                                onCancel()
                            }
                    )

                Image(systemName: "checkmark.circle.fill")
                    .font(.system(.title2, weight: .medium))
                    .foregroundStyle(AppColors.accentGold)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
                    .accessibilityIdentifier("saveSetButton")
                    .highPriorityGesture(
                        TapGesture()
                            .onEnded { _ in
                                commitTextValues()
                                saveAndContinue()
                            }
                    )
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(AppColors.accent.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(AppColors.accent.opacity(0.25), lineWidth: 1)
                )
        )
        .overlay(alignment: .trailing) {
            if showFeedback {
                HStack(spacing: 3) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(AppColors.accentGold)
                        .symbolEffect(.bounce, value: showFeedback)
                    Text(feedbackMessage)
                        .font(.system(.caption2, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(
                    Capsule()
                        .fill(Color.white.opacity(0.18))
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
                weightText = String(format: "%.1f", UnitFormatter.convertToDisplay(weight))
                if isTimeBased, let dBinding = durationSeconds {
                    durationText = "\(dBinding.wrappedValue)"
                }
            }
        }
    }

    /// Commit text field values to bindings (called before save to ensure values are captured)
    private func commitTextValues() {
        if isTimeBased, let dBinding = durationSeconds {
            if let v = Int(durationText), v >= 1 && v <= 9999 {
                dBinding.wrappedValue = v
            }
        } else {
            if let repsValue = Int(repsText), repsValue >= 1 && repsValue <= 1000 {
                reps = repsValue
            }
            if let displayValue = Double(weightText), displayValue >= 0 && displayValue <= 10000 {
                weight = UnitFormatter.convertToStorage(displayValue)
            }
        }
    }

    private func saveAndContinue() {
        if isTimeBased, let dBinding = durationSeconds {
            guard let secs = Int(durationText), secs >= 1 && secs <= 9999 else {
                UINotificationFeedbackGenerator().notificationOccurred(.warning)
                durationText = "\(max(1, dBinding.wrappedValue))"
                return
            }
            dBinding.wrappedValue = secs
            onSave()
            showMicroFeedback()
            durationText = "\(secs)"
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                focusedField = .duration
            }
        } else {
            guard let repsValue = Int(repsText), repsValue >= 1 && repsValue <= 1000 else {
                UINotificationFeedbackGenerator().notificationOccurred(.warning)
                repsText = "\(max(1, reps))"
                return
            }
            reps = repsValue
            if let weightValue = Double(weightText), weightValue >= 0 && weightValue <= 10000 {
                weight = weightValue
            }
            onSave()
            showMicroFeedback()
            repsText = "\(reps)"
            weightText = String(format: "%.1f", weight)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                focusedField = .reps
            }
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
    var exerciseName: String = ""
    var durationSeconds: Binding<Int>? = nil
    @Environment(\.dismiss) var dismiss
    let onAdd: () -> Void

    @State private var isEditingReps = false
    @State private var isEditingWeight = false
    @State private var isEditingDuration = false
    @State private var repsText = ""
    @State private var weightText = ""
    @State private var durationText = ""
    @FocusState private var focusedField: Field?

    enum Field {
        case reps, weight, duration
    }

    private var isTimeBased: Bool {
        !exerciseName.isEmpty && (ExerciseLibrary.shared.find(name: exerciseName)?.isTimeBased ?? false)
    }

    var body: some View {
        NavigationStack {
            Form {
                if isTimeBased, let durationBinding = durationSeconds {
                    Section {
                        Stepper(value: durationBinding, in: 5...600, step: 5) {
                            HStack {
                                if isEditingDuration {
                                    TextField("Seconds", text: $durationText)
                                        .keyboardType(.numberPad)
                                        .font(.system(.title3, weight: .semibold))
                                        .focused($focusedField, equals: .duration)
                                        .onSubmit { saveDuration() }
                                        .onChange(of: focusedField) {
                                            if focusedField != .duration { saveDuration() }
                                        }
                                } else {
                                    Text(UnitFormatter.formatDuration(durationBinding.wrappedValue))
                                        .font(.system(.title3, weight: .semibold))
                                        .contentShape(Rectangle())
                                        .onTapGesture { startEditingDuration() }
                                }
                                Spacer()
                            }
                        }
                    } header: {
                        Text("Duration (seconds)")
                            .font(.system(.caption, weight: .medium))
                            .foregroundStyle(.secondary)
                            .textCase(nil)
                    }
                } else {
                Section {
                    Stepper(value: $reps, in: 0...100, step: 1) {
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
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(AppColors.background)
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
                    .tint(AppColors.accent)
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
        if isTimeBased && isEditingDuration {
            saveDuration()
        } else {
            if isEditingReps { saveReps() }
            if isEditingWeight { saveWeight() }
        }
    }

    private func cancelEditing() {
        isEditingReps = false
        isEditingWeight = false
        isEditingDuration = false
        focusedField = nil
    }

    private func startEditingDuration() {
        if let dBinding = durationSeconds {
            durationText = "\(dBinding.wrappedValue)"
        }
        isEditingDuration = true
        focusedField = .duration
    }

    private func saveDuration() {
        if let dBinding = durationSeconds, let v = Int(durationText), v >= 1 && v <= 9999 {
            dBinding.wrappedValue = v
        }
        isEditingDuration = false
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
                    Stepper(value: $reps, in: 0...100, step: 1) {
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
            .background(AppColors.background)
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
                    .tint(AppColors.accent)
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
