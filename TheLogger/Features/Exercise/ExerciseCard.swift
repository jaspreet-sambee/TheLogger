//
//  ExerciseCard.swift
//  TheLogger
//
//  Exercise card view (Apple Health style, matched geometry)
//

import SwiftUI
import SwiftData

// MARK: - Exercise Card (Apple Health style, matched geometry)
struct ExerciseCard: View {
    let exercise: Exercise
    let workout: Workout
    let namespace: Namespace.ID
    var isActive: Bool = false
    var onSaveWorkout: (() -> Void)?

    private var setsSummary: String {
        let sets = exercise.sets ?? []
        if sets.isEmpty { return "No sets" }
        let count = sets.count
        let isTimeBased = ExerciseLibrary.shared.find(name: exercise.name)?.isTimeBased ?? false
        if isTimeBased {
            return "\(count) \(count == 1 ? "set" : "sets") · \(UnitFormatter.formatDuration(exercise.totalDurationSeconds))"
        }
        return "\(count) \(count == 1 ? "set" : "sets") · \(exercise.totalReps) reps"
    }

    // Determine accent color based on exercise type
    private var accentColor: Color {
        let name = exercise.name.lowercased()
        // Compound exercises (warm tones)
        let compounds = ["squat", "deadlift", "bench", "press", "row", "pull-up", "pullup", "chin-up", "dip"]
        if compounds.contains(where: { name.contains($0) }) {
            return AppColors.accent.opacity(0.7)
        }
        // Default (neutral)
        return Color.white.opacity(0.6)
    }

    var body: some View {
        HStack(spacing: 0) {
            // Left accent bar
            RoundedRectangle(cornerRadius: 2)
                .fill(isActive ? AppColors.accent : accentColor)
                .frame(width: 4)
                .padding(.vertical, 8)

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Text(exercise.name)
                        .font(.system(.headline, weight: .semibold))
                        .foregroundStyle(.primary)
                        .matchedGeometryEffect(id: "title-\(exercise.id)", in: namespace)
                    Spacer(minLength: 0)

                    if isActive {
                        Text("Current")
                            .font(.system(.caption2, weight: .medium))
                            .foregroundStyle(AppColors.accent)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(
                                Capsule()
                                    .fill(AppColors.accent.opacity(0.12))
                            )
                    }

                    // Superset menu button
                    if workout.isActive {
                        supersetMenuButton
                    }

                    // Sets count badge
                    let setsList = exercise.sets ?? []
                    if !setsList.isEmpty {
                        Text("\(setsList.count)")
                            .font(.system(.caption, weight: .bold))
                            .foregroundStyle(.secondary)
                            .frame(width: 24, height: 24)
                            .background(
                                Circle()
                                    .fill(Color.white.opacity(0.06))
                            )
                    }
                }

                Text(setsSummary)
                    .font(.system(.subheadline, weight: .regular))
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 14)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(isFullyLogged ? AppColors.accentGold.opacity(0.05) : (isActive ? AppColors.accent.opacity(0.06) : Color.white.opacity(0.02)))
                )
                .overlay {
                    if isFullyLogged {
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(AppColors.accentGold.opacity(0.4), lineWidth: 1.5)
                    } else if isActive {
                        AnimatedGradientBorder(cornerRadius: 12,
                            colors: AppColors.accentGradient + [AppColors.accentGradient[0]], lineWidth: 1)
                    } else {
                        RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.06), lineWidth: 1)
                    }
                }
                .matchedGeometryEffect(id: "card-\(exercise.id)", in: namespace)
        )
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: isFullyLogged)
    }

    private var isFullyLogged: Bool {
        let sets = exercise.sets ?? []
        return !sets.isEmpty && sets.allSatisfy { $0.reps > 0 }
    }

    @ViewBuilder
    private var supersetMenuButton: some View {
        let otherExercises = (workout.exercises ?? []).filter { $0.id != exercise.id && !$0.isInSuperset }

        Menu {
            if exercise.isInSuperset {
                // Show remove option if already in superset
                Button(role: .destructive) {
                    workout.removeFromSuperset(exerciseId: exercise.id)
                    onSaveWorkout?()
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                } label: {
                    Label("Remove from Superset", systemImage: "link.badge.minus")
                }
            } else if !otherExercises.isEmpty {
                // Show create superset options
                ForEach(otherExercises) { other in
                    Button {
                        workout.createSuperset(from: [exercise.id, other.id])
                        onSaveWorkout?()
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    } label: {
                        Label(other.name, systemImage: "link")
                    }
                }
            } else {
                // No other exercises available
                Text("No other exercises to superset")
                    .foregroundStyle(.secondary)
            }
        } label: {
            Image(systemName: exercise.isInSuperset ? "link.circle.fill" : "link.circle")
                .font(.system(.caption, weight: .medium))
                .foregroundStyle(exercise.isInSuperset ? .purple : .secondary)
                .frame(width: 24, height: 24)
                .contentShape(Rectangle())
        }
    }
}
