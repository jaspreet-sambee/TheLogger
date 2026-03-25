//
//  QuickLogStrip.swift
//  TheLogger
//
//  Quick log strip for rapid set entry
//

import SwiftUI
import SwiftData

// MARK: - Quick Log Strip
/// Stepper row below the set list: shows the last set's values with live
/// reps / weight (or duration) adjustment. Tap checkmark to log.
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
                    // Dismiss keyboard for any other focused field (e.g. exercise name)
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
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
            stepButton("\u{2212}") { reps = max(0, reps - 1) }
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
            stepButton("\u{2212}") { duration = max(5, duration - 5) }
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
