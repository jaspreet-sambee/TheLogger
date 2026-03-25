//
//  ActiveWorkoutRowView.swift
//
//  Row view for displaying an active workout in progress
//

import SwiftUI
import SwiftData

struct ActiveWorkoutRowView: View {
    let workout: Workout
    @State private var elapsedTime: TimeInterval = 0
    @State private var timer: Timer?

    private var formattedElapsedTime: String {
        let hours = Int(elapsedTime) / 3600
        let minutes = Int(elapsedTime) / 60 % 60
        let seconds = Int(elapsedTime) % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Left side content
            VStack(alignment: .leading, spacing: 10) {
                // Workout name with active indicator
                HStack {
                    Text(workout.name)
                        .font(.system(.title3, weight: .semibold))
                        .foregroundStyle(.primary)

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

                // Exercise count
                HStack(spacing: 16) {
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

            // Right side - Elapsed time
            VStack(alignment: .trailing, spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: "clock.fill")
                        .font(.system(.caption2, weight: .medium))
                        .foregroundStyle(AppColors.accent)
                    Text(formattedElapsedTime)
                        .font(.system(.headline, weight: .semibold))
                        .foregroundStyle(AppColors.accent)
                        .monospacedDigit()
                }
                Text("elapsed")
                    .font(.system(.caption2, weight: .regular))
                    .foregroundStyle(.tertiary)
            }
            .padding(.top, 4)
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.06))
        )
        .overlay(AnimatedGradientBorder())
        .onAppear {
            if let startTime = workout.startTime {
                elapsedTime = Date().timeIntervalSince(startTime)
            }
            // Start timer
            timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
                if let startTime = workout.startTime {
                    elapsedTime = Date().timeIntervalSince(startTime)
                }
            }
        }
        .onDisappear {
            timer?.invalidate()
            timer = nil
        }
    }
}
