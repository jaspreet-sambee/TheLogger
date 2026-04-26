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

    private var isDone: Bool {
        let sets = exercise.sets ?? []
        return !sets.isEmpty && sets.allSatisfy { $0.reps > 0 }
    }

    private var accentBarGradient: LinearGradient {
        if isActive {
            return LinearGradient(
                colors: [AppColors.accent, AppColors.accent.opacity(0.2)],
                startPoint: .top, endPoint: .bottom
            )
        } else if isDone {
            return LinearGradient(
                colors: [AppColors.accentGold, AppColors.accentGold.opacity(0.2)],
                startPoint: .top, endPoint: .bottom
            )
        } else {
            return LinearGradient(
                colors: [Color.white.opacity(0.25), Color.white.opacity(0.06)],
                startPoint: .top, endPoint: .bottom
            )
        }
    }

    private var metaLine: String {
        let libraryEntry = ExerciseLibrary.shared.find(name: exercise.name)
        let muscle = libraryEntry?.muscleGroup.rawValue ?? ""
        let sets = exercise.sets ?? []
        let prefix = muscle.isEmpty ? "" : "\(muscle) · "

        if sets.isEmpty {
            return "\(prefix)Not started"
        }
        if isDone && !isActive {
            return "\(prefix)Done"
        }
        return "\(prefix)\(sets.count) \(sets.count == 1 ? "set" : "sets")"
    }

    var body: some View {
        HStack(spacing: 0) {
            // Left accent bar (gradient)
            Rectangle()
                .fill(accentBarGradient)
                .frame(width: 3)
                .padding(.vertical, 8)

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Text(exercise.name)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.primary)
                        .matchedGeometryEffect(id: "title-\(exercise.id)", in: namespace)
                    Spacer(minLength: 0)
                }

                // Meta line: muscle group + status
                Text(metaLine)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(Color.white.opacity(0.38))

                // Set badges row
                setsBadgesRow
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 14)

            // Right: sets count column
            VStack(alignment: .trailing, spacing: 2) {
                let setsList = exercise.sets ?? []
                if setsList.isEmpty {
                    Text("—")
                        .font(.system(size: 22, weight: .heavy))
                        .foregroundStyle(Color.white.opacity(0.25))
                } else {
                    Text("\(setsList.count)")
                        .font(.system(size: 22, weight: .heavy))
                        .foregroundStyle(isDone ? AppColors.accentGold : Color.white.opacity(0.7))
                        .contentTransition(.numericText(value: Double(setsList.count)))
                        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: setsList.count)
                }
                Text("sets")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.30))
            }
            .padding(.trailing, 14)
            .padding(.vertical, 14)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.white.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .fill(isDone
                              ? AppColors.accentGold.opacity(0.03)
                              : (isActive ? AppColors.accent.opacity(0.05) : Color.clear))
                )
                .overlay {
                    if isDone {
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(AppColors.accentGold.opacity(0.25), lineWidth: 1)
                    } else if isActive {
                        AnimatedGradientBorder(
                            cornerRadius: 18,
                            colors: AppColors.accentGradient + [AppColors.accentGradient[0]],
                            lineWidth: 1
                        )
                    } else {
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(Color.white.opacity(0.09), lineWidth: 1)
                    }
                }
                .matchedGeometryEffect(id: "card-\(exercise.id)", in: namespace)
        )
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: isDone)
    }

    // MARK: - Set Badges

    @ViewBuilder
    private var setsBadgesRow: some View {
        let sets = exercise.setsByOrder
        if sets.isEmpty {
            Text("Not started")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.35))
                .padding(.horizontal, 9)
                .padding(.vertical, 3)
                .background(Capsule().fill(Color.white.opacity(0.06)))
        } else {
            // Find the best set index by estimated 1RM (highest score among PR-eligible sets)
            let bestIndex: Int? = {
                var bestScore = 0.0
                var bestIdx: Int? = nil
                for (i, s) in sets.enumerated() {
                    guard s.type.countsForPR, s.reps > 0 else { continue }
                    let score = s.weight > 0 ? s.weight * (1.0 + Double(s.reps) / 30.0) : Double(s.reps)
                    if score > bestScore { bestScore = score; bestIdx = i }
                }
                return bestIdx
            }()
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(sets.indices, id: \.self) { i in
                        setBadge(for: sets[i], isBest: i == bestIndex)
                    }
                }
            }
        }
    }

    private func setBadge(for set: WorkoutSet, isBest: Bool = false) -> some View {
        let (label, fg, bg, border) = badgeStyle(for: set, isBest: isBest)
        return Text(label)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(fg)
            .padding(.horizontal, 9)
            .padding(.vertical, 3)
            .background(
                Capsule()
                    .fill(bg)
                    .overlay(Capsule().stroke(border, lineWidth: 1))
            )
    }

    private func badgeStyle(for set: WorkoutSet, isBest: Bool) -> (String, Color, Color, Color) {
        let isBodyweight = set.weight == 0
        let weightStr = isBodyweight ? "BW" : UnitFormatter.formatWeightCompact(set.weight, showUnit: false)
        let valueStr = isBodyweight ? "BW × \(set.reps)" : "\(weightStr) × \(set.reps)"

        if isBest {
            return ("🏆 \(valueStr)", AppColors.accentGold, AppColors.accentGold.opacity(0.12), AppColors.accentGold.opacity(0.3))
        }

        switch set.type {
        case .warmup:
            let yellow = Color(red: 1.0, green: 0.82, blue: 0.3)
            return ("W \(valueStr)", yellow, yellow.opacity(0.12), yellow.opacity(0.2))
        case .dropSet:
            let orange = Color(red: 1.0, green: 0.35, blue: 0.19)
            return (valueStr, orange, orange.opacity(0.12), orange.opacity(0.2))
        case .failure:
            return ("F \(valueStr)", AppColors.accent, AppColors.accent.opacity(0.12), AppColors.accent.opacity(0.2))
        case .pause:
            return ("P \(valueStr)", Color.teal, Color.teal.opacity(0.12), Color.teal.opacity(0.2))
        default: // .working
            return (valueStr, AppColors.accent, AppColors.accent.opacity(0.12), AppColors.accent.opacity(0.2))
        }
    }

    // MARK: - Superset Menu

    @ViewBuilder
    private var supersetMenuButton: some View {
        let otherExercises = (workout.exercises ?? []).filter { $0.id != exercise.id && !$0.isInSuperset }

        Menu {
            if exercise.isInSuperset {
                Button(role: .destructive) {
                    workout.removeFromSuperset(exerciseId: exercise.id)
                    onSaveWorkout?()
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                } label: {
                    Label("Remove from Superset", systemImage: "link.badge.minus")
                }
            } else if !otherExercises.isEmpty {
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
