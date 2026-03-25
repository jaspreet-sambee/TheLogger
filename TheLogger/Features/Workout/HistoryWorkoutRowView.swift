//
//  HistoryWorkoutRowView.swift
//
//  Row view for displaying a workout in the history list
//

import SwiftUI
import SwiftData

struct HistoryWorkoutRowView: View {
    let workout: Workout

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: workout.date)
    }

    // Get first 2-3 exercise names for preview (in saved order)
    private var exercisePreview: String? {
        let exercises = workout.exercisesByOrder
        guard !exercises.isEmpty else { return nil }
        let names = exercises.prefix(3).map { $0.name }
        let joined = names.joined(separator: ", ")
        if exercises.count > 3 {
            return joined + ", ..."
        }
        return joined
    }

    var body: some View {
        HStack(spacing: 14) {
            // Date indicator with subtle accent
            VStack(spacing: 4) {
                Text(formattedDate)
                    .font(.system(.caption, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 50)
            }

            // Main content
            VStack(alignment: .leading, spacing: 6) {
                Text(workout.name)
                    .font(.system(.headline, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                // Exercise names preview
                if let preview = exercisePreview {
                    Text(preview)
                        .font(.system(.caption, weight: .regular))
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }

                HStack(spacing: 16) {
                    HStack(spacing: 4) {
                        Image(systemName: "figure.strengthtraining.traditional")
                            .font(.system(.caption2, weight: .medium))
                            .foregroundStyle(AppColors.accent.opacity(0.7))
                        Text("\(workout.exerciseCount)")
                            .font(.system(.subheadline, weight: .semibold))
                    }
                    .foregroundStyle(.secondary)

                    if workout.totalSets > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "list.bullet")
                                .font(.system(.caption2, weight: .medium))
                            Text("\(workout.totalSets)")
                                .font(.system(.subheadline, weight: .semibold))
                        }
                        .foregroundStyle(.secondary)
                    }

                    if let endTime = workout.endTime, let startTime = workout.startTime {
                        let duration = endTime.timeIntervalSince(startTime)
                        let hours = Int(duration) / 3600
                        let minutes = Int(duration) / 60 % 60
                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                                .font(.system(.caption2, weight: .medium))
                            if hours > 0 {
                                Text("\(hours)h \(minutes)m")
                                    .font(.system(.subheadline, weight: .semibold))
                            } else {
                                Text("\(minutes)m")
                                    .font(.system(.subheadline, weight: .semibold))
                            }
                        }
                        .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(.caption, weight: .semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(AppColors.accent.opacity(0.2), lineWidth: 1)
                )
        )
    }
}
