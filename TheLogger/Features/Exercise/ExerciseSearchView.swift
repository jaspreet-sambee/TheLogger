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

    // Filtered user exercises — deduplicated by normalized name (keep most recent)
    private var filteredUserExercises: [ExerciseMemory] {
        var seen = Set<String>()
        let deduped = exerciseMemories.filter { m in
            let key = m.normalizedName
            guard !seen.contains(key) else { return false }
            seen.insert(key)
            return true
        }
        guard isSearching else { return deduped }
        return deduped.filter { $0.name.lowercased().contains(searchQuery) }
    }

    // Filtered library exercises — exclude names already in the Recent section to avoid duplicates
    private var filteredLibraryExercises: [LibraryExercise] {
        let recentNames = Set(filteredUserExercises.map { $0.normalizedName })
        let results = isSearching ? library.search(searchText) : library.exercises
        return results.filter { !recentNames.contains($0.normalizedName) }
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
                    .font(.system(.body, weight: .medium))
                    .foregroundStyle(AppColors.accent)
                Text("Add \"\(searchText.trimmingCharacters(in: .whitespaces))\"")
                    .font(.system(.body, weight: .medium))
                    .foregroundStyle(.primary)
                Spacer()
                Text("Custom")
                    .font(.system(.caption2, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.25))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Color.white.opacity(0.06)))
            }
        }
        .listRowBackground(AppColors.accent.opacity(0.06))
    }

    private var userExercisesSection: some View {
        Section {
            ForEach(filteredUserExercises, id: \.name) { memory in
                Button { selectExercise(memory.name) } label: {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(memory.name)
                                .font(.system(.body, weight: .medium))
                                .foregroundStyle(.primary)
                            Text("\(memory.lastSets) sets · \(memory.lastReps) reps · \(UnitFormatter.formatWeightCompact(memory.lastWeight))")
                                .font(.system(.caption2, weight: .medium))
                                .foregroundStyle(Color.white.opacity(0.35))
                        }
                        Spacer()
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(.caption2, weight: .medium))
                            .foregroundStyle(Color.white.opacity(0.2))
                    }
                }
                .accessibilityIdentifier("exerciseResult_\(memory.name)")
                .listRowBackground(Color.white.opacity(0.06))
            }
        } header: {
            Text("Recent")
                .font(.system(.caption2, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.28))
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
                    .font(.system(.caption2, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.28))
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
                            .font(.system(.caption2, weight: .medium))
                        Text(group.rawValue)
                            .font(.system(.caption2, weight: .semibold))
                    }
                    .foregroundStyle(Color.white.opacity(0.28))
                    .textCase(nil)
                }
            }
        }
    }

    private func libraryExerciseRow(_ exercise: LibraryExercise) -> some View {
        Button { selectExercise(exercise.name) } label: {
            HStack {
                Text(exercise.name)
                    .font(.system(.body, weight: .medium))
                    .foregroundStyle(.primary)
                Spacer()
                Text(exercise.muscleGroup.rawValue)
                    .font(.system(.caption2, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.2))
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
