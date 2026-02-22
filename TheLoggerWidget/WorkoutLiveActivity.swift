//
//  WorkoutLiveActivity.swift
//  TheLoggerWidget
//
//  Live Activity UI for lock screen workout logging
//

import ActivityKit
import WidgetKit
import SwiftUI

// MARK: - Activity Attributes (must match main app exactly)

struct WorkoutActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var exerciseName: String        // Current exercise name
        var exerciseId: String          // Current exercise ID
        var exerciseSets: Int           // Sets for THIS exercise only
        var lastReps: Int               // Last logged reps
        var lastWeight: Double          // Last logged weight
        var elapsedSeconds: Int         // Workout duration
    }

    var workoutId: String
    var workoutName: String
    var startTime: Date
}

// MARK: - Live Activity Widget

struct WorkoutLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: WorkoutActivityAttributes.self) { context in
            // Lock Screen UI - Read-only, tap to open app
            LockScreenView(context: context)
                .activityBackgroundTint(.black.opacity(0.85))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded - Read-only display
                DynamicIslandExpandedRegion(.leading) {
                    Label(context.state.exerciseName, systemImage: "dumbbell.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .lineLimit(1)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(context.state.formattedElapsedTime)
                        .font(.system(size: 14, weight: .medium, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack(spacing: 16) {
                        // Sets count
                        VStack(spacing: 2) {
                            Text("\(context.state.exerciseSets)")
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                            Text("sets")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }

                        Divider().frame(height: 40)

                        // Last set info
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Last Set")
                                .font(.system(size: 9))
                                .foregroundStyle(.tertiary)

                            HStack(spacing: 6) {
                                Text(context.state.formattedWeight)
                                    .font(.system(size: 14, weight: .semibold))

                                Text("×")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)

                                Text("\(context.state.lastReps)")
                                    .font(.system(size: 14, weight: .semibold))
                            }
                        }

                        Spacer()
                    }
                    .padding(.horizontal, 8)
                }
            } compactLeading: {
                Image(systemName: "dumbbell.fill")
                    .foregroundStyle(.blue)
            } compactTrailing: {
                Text("\(context.state.exerciseSets)")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
            } minimal: {
                Image(systemName: "dumbbell.fill")
                    .foregroundStyle(.blue)
            }
        }
    }
}

// MARK: - Lock Screen View

struct LockScreenView: View {
    let context: ActivityViewContext<WorkoutActivityAttributes>

    var body: some View {
        VStack(spacing: 12) {
            // Header
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "figure.strengthtraining.traditional")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.blue)
                    Text(context.state.exerciseName)
                        .font(.system(size: 16, weight: .semibold))
                        .lineLimit(1)
                }
                Spacer()
                Text(context.state.formattedElapsedTime)
                    .font(.system(size: 14, weight: .medium, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            // Stats - Clean read-only display
            HStack(spacing: 16) {
                // Sets completed
                VStack(spacing: 2) {
                    Text("\(context.state.exerciseSets)")
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                        .contentTransition(.numericText())
                    Text("sets")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                }

                Divider()
                    .frame(height: 60)

                // Last set info
                VStack(alignment: .leading, spacing: 4) {
                    Text("Last Set")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.tertiary)

                    HStack(spacing: 8) {
                        Text(context.state.formattedWeight)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(.primary)

                        Text("×")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.secondary)

                        Text("\(context.state.lastReps)")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(.primary)
                    }
                    .contentTransition(.numericText())
                }

                Spacer()
            }
        }
        .padding(16)
    }
}

// MARK: - Helpers

extension WorkoutActivityAttributes.ContentState {
    var formattedWeight: String {
        let defaults = UserDefaults(suiteName: "group.SDL-Tutorial.TheLogger")
        let useMetric = defaults?.string(forKey: "unitSystem") == "Metric"
        let weight = useMetric ? lastWeight * 0.453592 : lastWeight
        let unit = useMetric ? "kg" : "lbs"
        return String(format: "%.0f %@", weight, unit)
    }

    var formattedElapsedTime: String {
        let hours = elapsedSeconds / 3600
        let minutes = (elapsedSeconds % 3600) / 60
        return hours > 0 ? String(format: "%d:%02d", hours, minutes) : "\(minutes)m"
    }

    var lastSetSummary: String {
        "\(formattedWeight) × \(lastReps)"
    }
}
