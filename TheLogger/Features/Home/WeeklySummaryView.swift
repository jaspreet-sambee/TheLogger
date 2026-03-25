//
//  WeeklySummaryView.swift
//  TheLogger
//
//  Full weekly recap sheet with Charts and week-over-week comparison
//

import SwiftUI
import Charts

struct WeeklySummaryView: View {
    let stats: WeeklyStats
    let streakData: StreakData
    let volumeTrend: [VolumeTrendPoint]
    let prCount: Int
    let weeklyGoal: Int

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Goal ring
                    goalSection

                    // Streak heatmap
                    StreakCalendarCard(streakData: streakData)

                    // Stats grid
                    statsGrid

                    // PRs this week
                    if prCount > 0 {
                        prBadge
                    }

                    // Muscle groups
                    if !stats.muscleBreakdown.isEmpty {
                        MuscleGroupBreakdownCard(breakdown: stats.muscleBreakdown)
                    }

                    // Volume trend
                    if !volumeTrend.isEmpty {
                        volumeTrendSection
                    }

                    // Vs last week
                    comparisonSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 40)
            }
            .background(AppColors.background)
            .navigationTitle("Weekly Recap")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationBackground(AppColors.background)
        .onAppear {
            Analytics.send(Analytics.Signal.weeklyRecapViewed)
        }
    }

    // MARK: - Sections

    private var goalSection: some View {
        VStack(spacing: 12) {
            WeeklyGoalRing(
                current: stats.workoutCount,
                goal: weeklyGoal,
                color: stats.workoutCount >= weeklyGoal ? AppColors.accentGold : AppColors.accent
            )
            .frame(width: 80, height: 80)

            if stats.workoutCount >= weeklyGoal {
                Text("Goal reached!")
                    .font(.system(.subheadline, weight: .semibold))
                    .foregroundStyle(AppColors.accentGold)
            } else {
                Text("\(weeklyGoal - stats.workoutCount) more to hit your goal")
                    .font(.system(.subheadline, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            Text(weekRangeString())
                .font(.system(.caption, weight: .medium))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
    }

    private var statsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            statCard(title: "Volume", value: formatVolume(stats.totalVolume), unit: UnitFormatter.weightUnit, icon: "scalemass", color: AppColors.accent)
            statCard(title: "Sets", value: "\(stats.totalSets)", unit: "total", icon: "square.stack.3d.up", color: AppColors.accentGold)
            statCard(title: "Reps", value: "\(stats.totalReps)", unit: "total", icon: "repeat", color: AppColors.accentBlue)
            statCard(title: "Duration", value: "\(stats.totalDurationMinutes)", unit: "min", icon: "clock", color: AppColors.accentTeal)
        }
    }

    private var prBadge: some View {
        HStack(spacing: 10) {
            Image(systemName: "medal.fill")
                .font(.system(.title3))
                .foregroundStyle(AppColors.accentGold)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(prCount) Personal Record\(prCount == 1 ? "" : "s") This Week")
                    .font(.system(.subheadline, weight: .semibold))
                    .foregroundStyle(.primary)
                Text("Keep pushing your limits!")
                    .font(.system(.caption, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(AppColors.accentGold.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(AppColors.accentGold.opacity(0.3), lineWidth: 1)
                )
        )
    }

    private var volumeTrendSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("4-WEEK VOLUME TREND")
                .font(.system(.caption2, weight: .bold))
                .foregroundStyle(.secondary)

            Chart(volumeTrend) { point in
                BarMark(
                    x: .value("Week", point.weekStart, unit: .weekOfYear),
                    y: .value("Volume", point.volume)
                )
                .foregroundStyle(
                    LinearGradient(colors: AppColors.accentGradient, startPoint: .bottom, endPoint: .top)
                )
                .cornerRadius(4)
            }
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                    AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                        .foregroundStyle(.secondary)
                        .font(.caption2)
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { _ in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                        .foregroundStyle(Color.secondary.opacity(0.2))
                    AxisValueLabel()
                        .foregroundStyle(.secondary)
                        .font(.caption2)
                }
            }
            .frame(height: 160)
        }
        .padding(16)
        .cardStyle(borderColor: AppColors.accent)
    }

    private var comparisonSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("VS LAST WEEK")
                .font(.system(.caption2, weight: .bold))
                .foregroundStyle(.secondary)

            if let volumeDelta = stats.volumeDelta {
                comparisonRow(label: "Volume", delta: String(format: "%+.0f%%", volumeDelta), isPositive: volumeDelta >= 0)
            }
            if let setsDelta = stats.setsDelta {
                comparisonRow(label: "Sets", delta: setsDelta >= 0 ? "+\(setsDelta)" : "\(setsDelta)", isPositive: setsDelta >= 0)
            }
            if let repsDelta = stats.repsDelta {
                comparisonRow(label: "Reps", delta: repsDelta >= 0 ? "+\(repsDelta)" : "\(repsDelta)", isPositive: repsDelta >= 0)
            }
            if let workoutDelta = stats.workoutCountDelta {
                comparisonRow(label: "Workouts", delta: workoutDelta >= 0 ? "+\(workoutDelta)" : "\(workoutDelta)", isPositive: workoutDelta >= 0)
            }

            if stats.volumeDelta == nil && stats.setsDelta == nil {
                Text("No data from last week to compare")
                    .font(.system(.caption, weight: .medium))
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 8)
            }
        }
        .padding(16)
        .cardStyle(borderColor: .secondary)
    }

    // MARK: - Helpers

    private func statCard(title: String, value: String, unit: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(.caption, weight: .medium))
                    .foregroundStyle(color)
                Text(title)
                    .font(.system(.caption, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            HStack(alignment: .lastTextBaseline, spacing: 4) {
                Text(value)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                Text(unit)
                    .font(.system(.caption, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .cardStyle(borderColor: color)
    }

    private func comparisonRow(label: String, delta: String, isPositive: Bool) -> some View {
        HStack {
            Text(label)
                .font(.system(.subheadline, weight: .medium))
                .foregroundStyle(.primary)
            Spacer()
            HStack(spacing: 4) {
                Image(systemName: isPositive ? "arrow.up.right" : "arrow.down.right")
                    .font(.system(size: 10, weight: .bold))
                Text(delta)
                    .font(.system(.subheadline, weight: .semibold))
            }
            .foregroundStyle(isPositive ? AppColors.accentGold : .red)
        }
    }

    private func formatVolume(_ volume: Double) -> String {
        let display = UnitFormatter.convertToDisplay(volume)
        if display >= 1000 {
            return String(format: "%.1fk", display / 1000)
        }
        return String(format: "%.0f", display)
    }

    private func weekRangeString() -> String {
        let calendar = Calendar.current
        guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: Date()) else { return "" }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        let end = calendar.date(byAdding: .day, value: -1, to: weekInterval.end) ?? weekInterval.end
        return "\(formatter.string(from: weekInterval.start)) - \(formatter.string(from: end))"
    }
}
