//
//  TemplateEditView.swift
//  TheLogger
//
//  Template creation and editing view
//

import SwiftUI
import SwiftData

// MARK: - Template Edit View
struct TemplateEditView: View {
    let template: Workout?
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var templateWorkout: Workout
    @State private var showingAddExercise = false
    @State private var exerciseName: String = ""
    @State private var showingEditName = false
    @State private var editedName: String = ""
    private var isNewTemplate: Bool

    init(template: Workout?) {
        self.template = template
        // Create a workout for editing
        if let existingTemplate = template {
            _templateWorkout = State(initialValue: existingTemplate)
            self.isNewTemplate = false
        } else {
            // For new templates, create a workout (will be inserted into context in onAppear)
            let newWorkout = Workout(name: "", date: Date(), isTemplate: true)
            _templateWorkout = State(initialValue: newWorkout)
            self.isNewTemplate = true
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 12) {
                        Text(templateWorkout.name.isEmpty ? "Template Name" : templateWorkout.name)
                            .font(.system(.title2, weight: .semibold))
                            .foregroundStyle(templateWorkout.name.isEmpty ? .secondary : .primary)
                        Spacer()
                        Button {
                            editedName = templateWorkout.name
                            showingEditName = true
                        } label: {
                            Image(systemName: "pencil")
                                .font(.system(.body, weight: .medium))
                        }
                        .tint(.blue)
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("Template Name")
                        .font(.system(.caption, weight: .medium))
                        .foregroundStyle(.secondary)
                        .textCase(nil)
                }

                Section {
                    let exercisesList = templateWorkout.exercisesByOrder
                    if exercisesList.isEmpty {
                        Text("Add your first exercise to start logging")
                            .font(.system(.subheadline, weight: .regular))
                            .foregroundStyle(.secondary)
                            .padding(.vertical, 8)
                    } else {
                        ForEach(exercisesList) { exercise in
                            NavigationLink {
                                ExerciseEditView(exercise: exercise, workout: templateWorkout)
                            } label: {
                                ExerciseRowView(
                                    exercise: exercise,
                                    currentWorkout: templateWorkout,
                                    modelContext: modelContext
                                )
                            }
                        }
                        .onDelete { indexSet in
                            for index in indexSet {
                                templateWorkout.removeExercise(id: exercisesList[index].id)
                            }
                            autoSaveTemplate()
                        }
                    }

                    Button {
                        showingAddExercise = true
                    } label: {
                        Label("Add Exercise", systemImage: "plus.circle")
                            .font(.system(.body, weight: .medium))
                    }
                    .tint(.blue)
                } header: {
                    Text("Exercises")
                        .font(.system(.caption, weight: .medium))
                        .foregroundStyle(.secondary)
                        .textCase(nil)
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Color(.systemBackground))
            .navigationTitle(template == nil ? "New Template" : "Edit Template")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        // If it's a new template and user cancels, remove it from context
                        if isNewTemplate {
                            modelContext.delete(templateWorkout)
                        }
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveTemplate()
                    }
                    .disabled(templateWorkout.name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .alert("Add Exercise", isPresented: $showingAddExercise) {
                TextField("Exercise Name", text: $exerciseName)
                Button("Add") {
                    if !exerciseName.trimmingCharacters(in: .whitespaces).isEmpty {
                        templateWorkout.addExercise(name: exerciseName.trimmingCharacters(in: .whitespaces))
                        exerciseName = ""
                        autoSaveTemplate()
                    }
                }
                Button("Cancel", role: .cancel) {
                    exerciseName = ""
                }
            } message: {
                Text("Enter the name of the exercise")
            }
            .alert("Edit Template Name", isPresented: $showingEditName) {
                TextField("Template Name", text: $editedName)
                Button("Save") {
                    if !editedName.trimmingCharacters(in: .whitespaces).isEmpty {
                        templateWorkout.name = editedName.trimmingCharacters(in: .whitespaces)
                        autoSaveTemplate()
                    }
                }
                Button("Cancel", role: .cancel) {
                    editedName = ""
                }
            } message: {
                Text("Enter a name for this template")
            }
            .onAppear {
                // For new templates, insert into context so relationships work
                if isNewTemplate {
                    // Check if it's already in the context
                    let descriptor = FetchDescriptor<Workout>()
                    if let workouts = try? modelContext.fetch(descriptor),
                       workouts.contains(where: { $0.id == templateWorkout.id }) == false {
                        modelContext.insert(templateWorkout)
                    }
                }
            }
        }
    }

    private func autoSaveTemplate() {
        // Ensure it's marked as a template
        templateWorkout.isTemplate = true
        templateWorkout.startTime = nil
        templateWorkout.endTime = nil

        // For new templates, make sure it's in the context
        if isNewTemplate {
            let descriptor = FetchDescriptor<Workout>()
            if let workouts = try? modelContext.fetch(descriptor),
               workouts.contains(where: { $0.id == templateWorkout.id }) == false {
                modelContext.insert(templateWorkout)
            }
        }

        do {
            try modelContext.save()
        } catch {
            print("Error auto-saving template: \(error)")
        }
    }

    private func saveTemplate() {
        // Ensure it's marked as a template
        templateWorkout.isTemplate = true
        templateWorkout.startTime = nil
        templateWorkout.endTime = nil

        // For new templates, make sure it's in the context
        if isNewTemplate {
            let descriptor = FetchDescriptor<Workout>()
            if let workouts = try? modelContext.fetch(descriptor),
               workouts.contains(where: { $0.id == templateWorkout.id }) == false {
                modelContext.insert(templateWorkout)
            }
        }

        do {
            try modelContext.save()
            dismiss()
        } catch {
            print("Error saving template: \(error)")
            // If save failed and it's a new template, remove it from context
            if isNewTemplate {
                modelContext.delete(templateWorkout)
            }
        }
    }
}
