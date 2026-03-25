//
//  WorkoutRowView.swift
//
//  Row view for displaying a workout in a list
//

import SwiftUI
import SwiftData

struct WorkoutRowView: View {
    let workout: Workout
    let useBorder: Bool
    let isActive: Bool
    let isCompact: Bool

    init(workout: Workout, useBorder: Bool = false, isActive: Bool = false, isCompact: Bool = false) {
        self.workout = workout
        self.useBorder = useBorder
        self.isActive = isActive
        self.isCompact = isCompact
    }

    // Single subtle color overlay
    private var accentColor: Color {
        Color(UIColor.systemGray6)
    }

    // Relative date formatter for compact mode
    private var compactDateString: String {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let workoutDay = calendar.startOfDay(for: workout.date)

        if calendar.isDateInToday(workout.date) {
            return "Today"
        } else if calendar.isDateInYesterday(workout.date) {
            return "Yesterday"
        } else if let days = calendar.dateComponents([.day], from: workoutDay, to: today).day, days < 7 {
            return "\(days) days ago"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d"
            return formatter.string(from: workout.date)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: isCompact ? 6 : 10) {
            // Workout name with active indicator
            HStack {
                Text(workout.name)
                    .font(.system(.title3, weight: .semibold))
                    .foregroundStyle(.primary)

                if isActive {
                    Spacer()
                    HStack(spacing: 4) {
                        Circle()
                            .fill(AppColors.accent)
                            .frame(width: 6, height: 6)
                        Text("Active")
                            .font(.system(.caption, weight: .medium))
                            .foregroundStyle(AppColors.accent)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(AppColors.accent.opacity(0.1))
                    )
                }
            }

            if isCompact {
                // Compact mode: single line with date and exercise count
                Text("\(compactDateString) • \(workout.exerciseCount) \(workout.exerciseCount == 1 ? "exercise" : "exercises")")
                    .font(.system(.caption, weight: .regular))
                    .foregroundStyle(.secondary)
            } else {
                // Full mode: icons and separate lines
                HStack(spacing: 16) {
                    // Workout date
                    Label {
                        Text(workout.formattedDate)
                            .font(.system(.subheadline, weight: .regular))
                    } icon: {
                        Image(systemName: "calendar")
                            .font(.system(.caption2, weight: .medium))
                    }
                    .foregroundStyle(.secondary)

                    // Number of exercises
                    Label {
                        Text("\(workout.exerciseCount) \(workout.exerciseCount == 1 ? "exercise" : "exercises")")
                            .font(.system(.subheadline, weight: .regular))
                    } icon: {
                        Image(systemName: "figure.strengthtraining.traditional")
                            .font(.system(.caption2, weight: .medium))
                    }
                    .foregroundStyle(.secondary)

                    Spacer()
                }
            }
        }
        .padding(.vertical, isCompact ? 12 : 16)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.06))
                if useBorder {
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1.0)
                }
                if isActive {
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(AppColors.accent.opacity(0.25), lineWidth: 1)
                }
            }
        )
    }
}
