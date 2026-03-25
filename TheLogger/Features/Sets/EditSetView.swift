//
//  EditSetView.swift
//  TheLogger
//
//  Sheet-based view for editing an existing set
//

import SwiftUI
import SwiftData

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
