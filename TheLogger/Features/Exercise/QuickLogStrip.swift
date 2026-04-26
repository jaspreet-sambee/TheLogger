//
//  QuickLogStrip.swift
//  TheLogger
//
//  Hero log area: reps pill + weight pill (Option A: single ± + step toggle) + LOG SET button
//

import SwiftUI
import SwiftData

// MARK: - Quick Log Strip
struct QuickLogStrip: View {
    let lastSet: WorkoutSet?
    let isTimeBased: Bool
    let setCount: Int  // Total logged sets — used for "Set N" label
    let onLog: (Int, Double, Int?, SetType) -> Void
    let onCustom: (() -> Void)?

    @AppStorage("unitSystem") private var unitSystem: String = "Imperial"

    @State private var reps: Int
    @State private var weightDisplay: Double
    @State private var duration: Int
    @State private var commitScale: CGFloat = 1.0
    @State private var weightStep: Double = 5.0
    @State private var setType: SetType = .working

    private enum StripField: Hashable { case reps, weight, duration }
    @FocusState private var focusedField: StripField?
    @State private var repsText: String = ""
    @State private var weightText: String = ""
    @State private var durationText: String = ""

    init(lastSet: WorkoutSet?, isTimeBased: Bool, setCount: Int = 0,
         onLog: @escaping (Int, Double, Int?, SetType) -> Void,
         onCustom: (() -> Void)? = nil) {
        self.lastSet = lastSet
        self.isTimeBased = isTimeBased
        self.setCount = setCount
        self.onLog = onLog
        self.onCustom = onCustom

        let initialReps = lastSet?.reps ?? 0
        let initialWeight = lastSet.map { UnitFormatter.convertToDisplay($0.weight) } ?? 0.0
        let initialDuration = lastSet?.durationSeconds ?? 0

        self._reps = State(initialValue: initialReps)
        self._weightDisplay = State(initialValue: initialWeight)
        self._duration = State(initialValue: initialDuration)

        let weightStr = initialWeight == initialWeight.rounded()
            ? "\(Int(initialWeight))"
            : String(format: "%.1f", initialWeight)
        self._repsText = State(initialValue: "\(initialReps)")
        self._weightText = State(initialValue: weightStr)
        self._durationText = State(initialValue: "\(initialDuration)")
    }

    // Step size options adapt to unit system
    private var weightStepOptions: [Double] {
        unitSystem == "Imperial" ? [2.5, 5.0, 10.0] : [1.25, 2.5, 5.0]
    }

    var body: some View {
        VStack(spacing: 10) {
            // "Same as last" header
            if !isTimeBased, lastSet != nil {
                HStack {
                    Text("Set \(setCount + 1)")
                        .font(.system(size: 11, weight: .heavy))
                        .foregroundStyle(AppColors.accent.opacity(0.55))
                        .kerning(1.0)
                        .textCase(.uppercase)
                    Spacer()
                    Button {
                        resetToLastSet()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.system(size: 10, weight: .semibold))
                            Text("Same as last")
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .foregroundStyle(Color.white.opacity(0.55))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(Color.white.opacity(0.08))
                                .overlay(Capsule().stroke(Color.white.opacity(0.13), lineWidth: 1))
                        )
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 4)
            }

            if isTimeBased {
                durationGroup.frame(maxWidth: .infinity)
            } else {
                HStack(spacing: 10) {
                    repsGroup.frame(maxWidth: .infinity)
                    weightGroup.frame(maxWidth: .infinity)
                        .layoutPriority(1) // weight pill gets more space (flex: 1.4 in mockup)
                }
            }

            // Set type picker
            setTypePicker

            logButton
        }
        .padding(.top, 14)
        .padding(.bottom, 12)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(AppColors.accent.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 22)
                        .stroke(AppColors.accent.opacity(0.15), lineWidth: 1)
                )
        )
        .onChange(of: focusedField) { oldField, newField in
            switch oldField {
            case .reps:     commitRepsText()
            case .weight:   commitWeightText()
            case .duration: commitDurationText()
            case nil:       break
            }
            if newField != nil {
                DispatchQueue.main.async {
                    UIApplication.shared.sendAction(#selector(UIResponder.selectAll(_:)), to: nil, from: nil, for: nil)
                }
            }
        }
        .onChange(of: reps) { _, v in if focusedField != .reps { repsText = "\(v)" } }
        .onChange(of: weightDisplay) { _, v in if focusedField != .weight { weightText = formatWeight(v) } }
        .onChange(of: duration) { _, v in if focusedField != .duration { durationText = "\(v)" } }
        .onChange(of: lastSet?.reps) { _, newReps in
            if let newReps, focusedField != .reps { reps = newReps; repsText = "\(newReps)" }
        }
        .onChange(of: lastSet?.weight) { _, newWeight in
            if let newWeight, focusedField != .weight {
                let w = UnitFormatter.convertToDisplay(newWeight)
                weightDisplay = w; weightText = formatWeight(w)
            }
        }
        .onChange(of: lastSet?.durationSeconds) { _, newDuration in
            if focusedField != .duration {
                let d = newDuration ?? 30; duration = d; durationText = "\(d)"
            }
        }
        // Sync step options when unit system changes
        .onChange(of: unitSystem) { _, _ in
            weightStep = unitSystem == "Imperial" ? 5.0 : 2.5
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
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
                .fontWeight(.semibold)
            }
        }
    }

    // MARK: - LOG SET Button

    private var logButton: some View {
        Button {
            withAnimation(.spring(response: 0.15, dampingFraction: 0.6)) { commitScale = 0.96 }
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                commit()
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { commitScale = 1.0 }
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "checkmark")
                    .font(.system(size: 14, weight: .heavy))
                Text("LOG SET")
                    .font(.system(size: 14, weight: .heavy))
                    .kerning(0.8)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(
                LinearGradient(
                    colors: [AppColors.accent, Color(red: 0.75, green: 0.14, blue: 0.23)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .shadow(color: AppColors.accent.opacity(0.4), radius: 8, x: 0, y: 4)
            .scaleEffect(commitScale)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("quickLogCommitButton")
    }

    // MARK: - Reps Group

    private var repsGroup: some View {
        VStack(spacing: 6) {
            Text("Reps")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.28))
                .kerning(0.6)
                .textCase(.uppercase)

            HStack(spacing: 4) {
                largePillButton("−") { reps = max(0, reps - 1) }
                TextField("0", text: $repsText)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.center)
                    .font(.system(size: 28, weight: .heavy))
                    .monospacedDigit()
                    .foregroundStyle(.primary)
                    .frame(minWidth: 44)
                    .focused($focusedField, equals: .reps)
                    .onSubmit { commitRepsText(); focusedField = .weight }
                largePillButton("+") { reps += 1 }
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.05))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.09), lineWidth: 1))
        )
    }

    // MARK: - Weight Group (Option A: single ± + step toggle)

    private var weightGroup: some View {
        VStack(spacing: 8) {
            weightMainRow
            weightStepToggle
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.05))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.09), lineWidth: 1))
        )
    }

    private var weightMainRow: some View {
        HStack(spacing: 6) {
            weightPmButton("−") { weightDisplay = max(0, weightDisplay - weightStep) }
            TextField("0", text: $weightText)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.center)
                .font(.system(size: 24, weight: .heavy))
                .monospacedDigit()
                .minimumScaleFactor(0.6)
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity)
                .focused($focusedField, equals: .weight)
                .onSubmit { commitWeightText(); focusedField = nil }
            weightPmButton("+") { weightDisplay += weightStep }
        }
    }

    private var weightStepToggle: some View {
        HStack(spacing: 0) {
            ForEach(weightStepOptions, id: \.self) { step in
                Button {
                    weightStep = step
                    UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: 0.5)
                } label: {
                    Text(formatStep(step))
                        .font(.system(size: 11, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(weightStep == step ? AppColors.accent : Color.white.opacity(0.28))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 5)
                        .background(weightStep == step ? AppColors.accent.opacity(0.15) : Color.clear)
                }
                .buttonStyle(.plain)
            }
        }
        .clipShape(Capsule())
        .background(
            Capsule()
                .fill(Color.white.opacity(0.06))
                .overlay(Capsule().stroke(Color.white.opacity(0.09), lineWidth: 1))
        )
    }

    // MARK: - Set Type Picker

    private var setTypePicker: some View {
        HStack(spacing: 6) {
            ForEach([SetType.warmup, .working, .dropSet, .failure], id: \.self) { type in
                Button {
                    setType = type
                    UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: 0.5)
                } label: {
                    Text(type == .dropSet ? "Drop" : type.rawValue)
                        .font(.system(size: 11, weight: .bold))
                        .kerning(0.2)
                        .foregroundStyle(setType == type ? type.color : Color.white.opacity(0.35))
                        .frame(maxWidth: .infinity)
                        .frame(height: 30)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(setType == type ? type.color.opacity(0.12) : Color.white.opacity(0.04))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(setType == type ? type.color.opacity(0.35) : Color.white.opacity(0.08), lineWidth: 1)
                                )
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Duration Group

    private var durationGroup: some View {
        VStack(spacing: 6) {
            Text("DURATION (sec)")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.30))
                .kerning(0.5)

            HStack(spacing: 0) {
                largePillButton("−") { duration = max(5, duration - 5) }
                TextField("0", text: $durationText)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.center)
                    .font(.system(size: 24, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(.primary)
                    .frame(width: 62)
                    .focused($focusedField, equals: .duration)
                    .onSubmit { commitDurationText(); focusedField = nil }
                largePillButton("+") { duration += 5 }
            }
        }
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.white.opacity(0.06))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.09), lineWidth: 1))
        )
    }

    // MARK: - Helpers

    private func largePillButton(_ label: String, action: @escaping () -> Void) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred(intensity: 0.6)
            action()
        } label: {
            Text(label)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(AppColors.accent)
                .frame(width: 34, height: 34)
                .background(
                    Circle()
                        .fill(AppColors.accent.opacity(0.10))
                        .overlay(Circle().stroke(AppColors.accent.opacity(0.20), lineWidth: 1))
                )
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
    }

    private func weightPmButton(_ label: String, action: @escaping () -> Void) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred(intensity: 0.7)
            action()
        } label: {
            Text(label)
                .font(.system(size: 22, weight: .light))
                .foregroundStyle(Color.white.opacity(0.60))
                .frame(width: 40, height: 40)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.07))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.12), lineWidth: 1))
                )
        }
        .buttonStyle(.plain)
    }

    private func formatStep(_ step: Double) -> String {
        step == step.rounded() ? "\(Int(step))" : String(format: "%.1f", step)
    }

    private func formatWeight(_ value: Double) -> String {
        value == value.rounded() ? "\(Int(value))" : String(format: "%.1f", value)
    }

    private func resetToLastSet() {
        guard let lastSet else { return }
        // Dismiss keyboard first
        focusedField = nil
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        // Reset values
        reps = lastSet.reps
        let w = UnitFormatter.convertToDisplay(lastSet.weight)
        weightDisplay = w
        repsText = "\(lastSet.reps)"
        weightText = formatWeight(w)
        if let d = lastSet.durationSeconds {
            duration = d
            durationText = "\(d)"
        }
        UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: 0.6)
    }

    // MARK: - Text commit

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

    private func commit() {
        switch focusedField {
        case .reps:     commitRepsText()
        case .weight:   commitWeightText()
        case .duration: commitDurationText()
        case nil:       break
        }
        focusedField = nil
        if isTimeBased {
            onLog(0, 0, duration, setType)
        } else {
            onLog(reps, UnitFormatter.convertToStorage(weightDisplay), nil, setType)
        }
    }
}
