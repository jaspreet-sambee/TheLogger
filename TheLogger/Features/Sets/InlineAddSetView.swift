//
//  InlineAddSetView.swift
//  TheLogger
//
//  Inline view for adding a new set to an exercise
//

import SwiftUI
import SwiftData
import UIKit

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
        let impact = UIImpactFeedbackGenerator(style: .soft)
        impact.impactOccurred()
    }
}
