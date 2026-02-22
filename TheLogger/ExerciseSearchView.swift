//
//  ExerciseSearchView.swift
//  TheLogger
//
//  Exercise search and selection view
//

import SwiftUI
import SwiftData

// MARK: - Exercise Search View
struct ExerciseSearchView: View {
    let onSelect: (String) -> Void
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var searchText = ""
    @FocusState private var isSearchFocused: Bool

    // User's exercise history
    @Query(sort: \ExerciseMemory.lastUpdated, order: .reverse) private var exerciseMemories: [ExerciseMemory]

    // Built-in library
    private let library = ExerciseLibrary.shared

    // Search state
    private var isSearching: Bool {
        !searchText.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var searchQuery: String {
        searchText.lowercased().trimmingCharacters(in: .whitespaces)
    }

    // Filtered user exercises
    private var filteredUserExercises: [ExerciseMemory] {
        guard isSearching else { return exerciseMemories }
        return exerciseMemories.filter { $0.name.lowercased().contains(searchQuery) }
    }

    // Filtered library exercises (show all; recent exercises also appear in Recent section)
    private var filteredLibraryExercises: [LibraryExercise] {
        isSearching ? library.search(searchText) : library.exercises
    }

    // Check if exact match exists in library or user exercises
    private var exactMatchExists: Bool {
        exerciseMemories.contains { $0.normalizedName == searchQuery } ||
        library.exercises.contains { $0.normalizedName == searchQuery }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                searchField
                resultsList
            }
            .background(AppColors.background)
            .navigationTitle("Add Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .presentationBackground(AppColors.background)
        .onAppear { isSearchFocused = true }
    }

    private var searchField: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            TextField("Search exercises", text: $searchText)
                .textFieldStyle(.plain)
                .focused($isSearchFocused)
                .submitLabel(.done)
                .accessibilityIdentifier("exerciseSearchField")
                .onSubmit {
                    if isSearching {
                        selectExercise(searchText.trimmingCharacters(in: .whitespaces))
                    }
                }

            if !searchText.isEmpty {
                Button { searchText = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.white.opacity(0.06))
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppColors.accent.opacity(0.25), lineWidth: 1))
        .padding(.horizontal, 16)
        .padding(.top, 16)
    }

    private var resultsList: some View {
        List {
            // Add custom option (if no exact match)
            if isSearching && !exactMatchExists {
                addCustomRow
            }

            // User's recent exercises
            if !filteredUserExercises.isEmpty {
                userExercisesSection
            }

            // Library exercises (grouped by muscle when not searching)
            if isSearching {
                librarySearchResultsSection
            } else {
                libraryGroupedSection
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    private var addCustomRow: some View {
        Button {
            selectExercise(searchText.trimmingCharacters(in: .whitespaces))
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "plus.circle.fill")
                    .foregroundStyle(AppColors.accent)
                Text("Add \"\(searchText.trimmingCharacters(in: .whitespaces))\"")
                    .foregroundStyle(.primary)
                Spacer()
                Text("Custom")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .listRowBackground(Color.white.opacity(0.06))
    }

    private var userExercisesSection: some View {
        Section {
            ForEach(filteredUserExercises, id: \.name) { memory in
                Button { selectExercise(memory.name) } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(memory.name)
                                .foregroundStyle(.primary)
                            Text("\(memory.lastSets) sets · \(memory.lastReps) reps · \(UnitFormatter.formatWeightCompact(memory.lastWeight))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
                .accessibilityIdentifier("exerciseResult_\(memory.name)")
                .listRowBackground(Color.white.opacity(0.06))
            }
        } header: {
            Text("Recent")
                .font(.caption)
                .foregroundStyle(.secondary)
                .textCase(nil)
        }
    }

    private var librarySearchResultsSection: some View {
        Section {
            ForEach(filteredLibraryExercises) { exercise in
                libraryExerciseRow(exercise)
            }
        } header: {
            if !filteredLibraryExercises.isEmpty {
                Text("Library")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textCase(nil)
            }
        }
    }

    private var libraryGroupedSection: some View {
        ForEach(MuscleGroup.allCases) { group in
            let exercises = filteredLibraryExercises.filter { $0.muscleGroup == group }
            if !exercises.isEmpty {
                Section {
                    ForEach(exercises) { exercise in
                        libraryExerciseRow(exercise)
                    }
                } header: {
                    HStack(spacing: 6) {
                        Image(systemName: group.icon)
                            .font(.caption2)
                        Text(group.rawValue)
                            .font(.caption)
                    }
                    .foregroundStyle(.secondary)
                    .textCase(nil)
                }
            }
        }
    }

    private func libraryExerciseRow(_ exercise: LibraryExercise) -> some View {
        Button { selectExercise(exercise.name) } label: {
            HStack {
                Text(exercise.name)
                    .foregroundStyle(.primary)
                Spacer()
            }
        }
        .accessibilityIdentifier("exerciseResult_\(exercise.name)")
        .listRowBackground(Color.white.opacity(0.06))
    }

    private func selectExercise(_ name: String) {
        onSelect(name)
        dismiss()
    }
}
