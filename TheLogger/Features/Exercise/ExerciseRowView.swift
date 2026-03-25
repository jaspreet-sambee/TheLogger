//
//  ExerciseRowView.swift
//  TheLogger
//
//  Exercise row view for workout lists
//

import SwiftUI
import SwiftData

// MARK: - Exercise Row View
struct ExerciseRowView: View {
    let exercise: Exercise
    let currentWorkout: Workout
    let modelContext: ModelContext
    var isActive: Bool = false

    @State private var cachedNote: String?
    @State private var cachedProgressMessage: String?
    @State private var hasFetchedData = false

    // Normalize exercise name for comparison (lowercase, trimmed)
    private var normalizedName: String {
        exercise.name.lowercased().trimmingCharacters(in: .whitespaces)
    }

    private func fetchRowData() {
        guard !hasFetchedData else { return }
        hasFetchedData = true

        // Fetch note from ExerciseMemory
        let memDescriptor = FetchDescriptor<ExerciseMemory>()
        if let memories = try? modelContext.fetch(memDescriptor),
           let memory = memories.first(where: { $0.normalizedName == normalizedName }),
           let note = memory.note, !note.isEmpty {
            cachedNote = note
        }

        // Find previous exercise for progress comparison
        guard !(exercise.sets ?? []).isEmpty else { return }
        let descriptor = FetchDescriptor<Workout>(
            sortBy: [SortDescriptor(\.endTime, order: .reverse)]
        )
        guard let allWorkouts = try? modelContext.fetch(descriptor) else { return }

        var previousExercise: Exercise?
        for workout in allWorkouts where workout.id != currentWorkout.id && !workout.isTemplate && workout.endTime != nil {
            if let previous = (workout.exercises ?? []).first(where: {
                $0.name.lowercased().trimmingCharacters(in: .whitespaces) == normalizedName
            }), !(previous.sets ?? []).isEmpty {
                previousExercise = previous
                break
            }
        }

        guard let previous = previousExercise else { return }

        // Compute progress message
        let currentWorkingSets = (exercise.sets ?? []).filter { $0.type.countsForPR }
        let previousWorkingSets = (previous.sets ?? []).filter { $0.type.countsForPR }
        guard !currentWorkingSets.isEmpty, !previousWorkingSets.isEmpty else { return }

        let currentMaxWeight = currentWorkingSets.map { $0.weight }.max() ?? 0
        let previousMaxWeight = previousWorkingSets.map { $0.weight }.max() ?? 0

        if currentMaxWeight > previousMaxWeight {
            let increase = currentMaxWeight - previousMaxWeight
            cachedProgressMessage = "+\(UnitFormatter.formatWeight(increase))"
            return
        }

        let currentTotalSets = currentWorkingSets.count
        let previousTotalSets = previousWorkingSets.count
        if currentTotalSets > previousTotalSets {
            let increase = currentTotalSets - previousTotalSets
            cachedProgressMessage = "+\(increase) \(increase == 1 ? "set" : "sets")"
            return
        }

        let currentTotalReps = currentWorkingSets.reduce(0) { $0 + $1.reps }
        let previousTotalReps = previousWorkingSets.reduce(0) { $0 + $1.reps }
        if currentTotalReps > previousTotalReps {
            let increase = currentTotalReps - previousTotalReps
            cachedProgressMessage = "+\(increase) reps"
            return
        }

        cachedProgressMessage = "Matched last time"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    // Active indicator
                    if isActive {
                        Circle()
                            .fill(AppColors.accent)
                            .frame(width: 6, height: 6)
                    }

                    Text(exercise.name)
                        .font(.system(.headline, weight: .semibold))
                        .foregroundStyle(isActive ? .primary : .secondary)

                    // Subtle indicator for auto-filled data
                    if exercise.isAutoFilled {
                        Text("· from last workout")
                            .font(.system(.caption2, weight: .regular))
                            .foregroundStyle(.secondary.opacity(0.7))
                    }

                    // Set type badges (show non-working types)
                    ForEach(SetType.allCases.filter { $0 != .working }, id: \.self) { type in
                        let count = (exercise.sets ?? []).filter { $0.type == type }.count
                        if count > 0 {
                            HStack(spacing: 2) {
                                Image(systemName: type.icon)
                                    .font(.system(.caption2, weight: .medium))
                                Text("\(count)")
                                    .font(.system(.caption2, weight: .semibold))
                            }
                            .foregroundStyle(type.color.opacity(0.9))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill(type.color.opacity(0.12))
                            )
                        }
                    }
                }

                // Note snippet (from ExerciseMemory)
                if let note = cachedNote {
                    HStack(spacing: 4) {
                        Image(systemName: "note.text")
                            .font(.system(.caption2, weight: .medium))
                        Text(note)
                            .lineLimit(1)
                    }
                    .font(.system(.caption2, weight: .regular))
                    .foregroundStyle(.tertiary)
                }

                // Progress comparison (inline under exercise name)
                if let message = cachedProgressMessage {
                    Text(message)
                        .font(.system(.caption, weight: .medium))
                        .foregroundStyle(isActive ? .secondary : .tertiary)
                }
            }

            if (exercise.sets ?? []).isEmpty {
                Text("No sets added")
                    .font(.system(.subheadline, weight: .regular))
                    .foregroundStyle(isActive ? .secondary : .tertiary)
                    .padding(.top, 2)
            } else {
                let isTimeBased = ExerciseLibrary.shared.find(name: exercise.name)?.isTimeBased ?? false
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(exercise.setsByOrder) { set in
                        HStack {
                            if isTimeBased, let d = set.durationSeconds {
                                Text(UnitFormatter.formatDuration(d))
                                    .font(.system(.subheadline, weight: .regular))
                                    .foregroundStyle(isActive ? .primary : .secondary)
                            } else {
                                Text("\(set.reps) reps")
                                    .font(.system(.subheadline, weight: .regular))
                                    .foregroundStyle(isActive ? .primary : .secondary)
                            }
                            Spacer()
                            if !isTimeBased {
                                Text(UnitFormatter.formatWeight(set.weight))
                                    .font(.system(.subheadline, weight: .regular))
                                    .foregroundStyle(isActive ? .secondary : .tertiary)
                            }
                        }
                    }
                }
                .padding(.top, 4)
            }

            HStack {
                let isTimeBased = ExerciseLibrary.shared.find(name: exercise.name)?.isTimeBased ?? false
                Group {
                    if isTimeBased {
                        Text("Total: \(UnitFormatter.formatDuration(exercise.totalDurationSeconds))")
                    } else {
                        Text("Total: \(exercise.totalReps) reps")
                    }
                }
                .font(.system(.caption, weight: .medium))
                .foregroundStyle(isActive ? .secondary : .tertiary)
                Spacer()
            }
            .padding(.top, 4)
        }
        .padding(.vertical, 8)
        .opacity(isActive ? 1.0 : 0.7)
        .onAppear { fetchRowData() }
    }
}
