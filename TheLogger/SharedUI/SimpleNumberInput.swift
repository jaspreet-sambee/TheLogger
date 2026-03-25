//
//  SimpleNumberInput.swift
//  TheLogger
//
//  Shared enum for set field focus and simple number input sheet
//

import SwiftUI
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
