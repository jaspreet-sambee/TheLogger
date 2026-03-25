//
//  AddSetView.swift
//  TheLogger
//
//  Sheet-based view for adding a set with stepper controls
//

import SwiftUI
import SwiftData

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
