//
//  DashboardCards.swift
//  TheLogger
//
//  Dashboard card views for the home screen
//

import SwiftUI
import Charts

// MARK: - Weekly Stats Card

struct WeeklyStatsCard: View {
    let stats: WeeklyStats
    var onTap: (() -> Void)? = nil

    var body: some View {
        Group {
            if let onTap {
                Button(action: onTap) { cardContent }
                    .buttonStyle(.plain)
            } else {
                cardContent
            }
        }
    }

    private var cardContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("THIS WEEK")
                    .font(.system(.caption2, weight: .bold))
                    .foregroundStyle(.secondary)
                Spacer()
                if onTap != nil {
                    Image(systemName: "chevron.right")
                        .font(.system(.caption2, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
            }

            HStack(spacing: 0) {
                statColumn(
                    value: formatVolume(stats.totalVolume),
                    label: "Volume",
                    delta: stats.volumeDelta.map { String(format: "%+.0f%%", $0) },
                    color: AppColors.accent
                )

                Divider()
                    .frame(height: 40)
                    .padding(.horizontal, 8)

                statColumn(
                    value: "\(stats.totalSets)",
                    label: "Sets",
                    delta: stats.setsDelta.map { $0 >= 0 ? "+\($0)" : "\($0)" },
                    color: AppColors.accentGold
                )

                Divider()
                    .frame(height: 40)
                    .padding(.horizontal, 8)

                statColumn(
                    value: "\(stats.totalReps)",
                    label: "Reps",
                    delta: stats.repsDelta.map { $0 >= 0 ? "+\($0)" : "\($0)" },
                    color: AppColors.accentBlue
                )

                Divider()
                    .frame(height: 40)
                    .padding(.horizontal, 8)

                statColumn(
                    value: "\(stats.workoutCount)",
                    label: "Workouts",
                    delta: stats.workoutCountDelta.map { $0 >= 0 ? "+\($0)" : "\($0)" },
                    color: AppColors.accentTeal
                )
            }
        }
        .padding(16)
        .cardStyle(borderColor: AppColors.accent)
    }

    private func statColumn(value: String, label: String, delta: String?, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(color)
                .minimumScaleFactor(0.7)
                .lineLimit(1)

            Text(label)
                .font(.system(.caption2, weight: .medium))
                .foregroundStyle(.secondary)

            if let delta = delta {
                Text(delta)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(delta.hasPrefix("+") ? AppColors.accentGold : (delta.hasPrefix("-") ? .red : .secondary))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(
                        Capsule()
                            .fill(delta.hasPrefix("+") ? AppColors.accentGold.opacity(0.12) : (delta.hasPrefix("-") ? Color.red.opacity(0.12) : Color.clear))
                    )
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func formatVolume(_ volume: Double) -> String {
        let display = UnitFormatter.convertToDisplay(volume)
        if display >= 1000 {
            return String(format: "%.1fk", display / 1000)
        }
        return String(format: "%.0f", display)
    }
}

// MARK: - Muscle Group Breakdown Card

struct MuscleGroupBreakdownCard: View {
    let breakdown: [MuscleGroup: Int]
    var onTap: (() -> Void)? = nil

    private var sortedGroups: [(group: MuscleGroup, count: Int)] {
        breakdown.map { (group: $0.key, count: $0.value) }
            .sorted { $0.count > $1.count }
    }

    private var maxCount: Int {
        sortedGroups.first?.count ?? 1
    }

    var body: some View {
        Group {
            if let onTap {
                Button(action: onTap) { cardContent }
                    .buttonStyle(.plain)
            } else {
                cardContent
            }
        }
    }

    private var cardContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("MUSCLE GROUPS")
                    .font(.system(.caption2, weight: .bold))
                    .foregroundStyle(.secondary)
                Spacer()
                if onTap != nil {
                    Image(systemName: "chevron.right")
                        .font(.system(.caption2, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
            }

            if sortedGroups.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "figure.arms.open")
                        .foregroundStyle(.tertiary)
                    Text("Complete workouts to see your muscle breakdown")
                        .font(.system(.caption, weight: .medium))
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 8)
            } else {
                ForEach(Array(sortedGroups.enumerated()), id: \.element.group) { _, item in
                    HStack(spacing: 10) {
                        Image(systemName: item.group.icon)
                            .font(.system(.caption, weight: .medium))
                            .foregroundStyle(AppColors.accent)
                            .frame(width: 20)

                        Text(item.group.rawValue)
                            .font(.system(.caption, weight: .medium))
                            .foregroundStyle(.primary)
                            .frame(width: 72, alignment: .leading)

                        GeometryReader { geo in
                            Capsule()
                                .fill(AppColors.accent.opacity(0.2))
                                .frame(height: 8)
                                .overlay(alignment: .leading) {
                                    Capsule()
                                        .fill(AppColors.accent)
                                        .frame(width: max(8, geo.size.width * CGFloat(item.count) / CGFloat(maxCount)), height: 8)
                                }
                        }
                        .frame(height: 8)

                        Text("\(item.count)")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(.secondary)
                            .frame(width: 24, alignment: .trailing)
                    }
                }
            }
        }
        .padding(16)
        .cardStyle(borderColor: AppColors.accent)
    }
}

// MARK: - Volume Trend Card

struct VolumeTrendCard: View {
    let trend: [VolumeTrendPoint]
    var onTap: (() -> Void)? = nil

    var body: some View {
        Group {
            if let onTap {
                Button(action: onTap) { cardContent }
                    .buttonStyle(.plain)
            } else {
                cardContent
            }
        }
    }

    private var cardContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("VOLUME TREND")
                    .font(.system(.caption2, weight: .bold))
                    .foregroundStyle(.secondary)
                Spacer()
                if onTap != nil {
                    Image(systemName: "chevron.right")
                        .font(.system(.caption2, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
            }

            if trend.allSatisfy({ $0.volume == 0 }) {
                HStack(spacing: 8) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .foregroundStyle(.tertiary)
                    Text("Complete workouts to see your volume trend")
                        .font(.system(.caption, weight: .medium))
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 12)
            } else {
                Chart(trend) { point in
                    LineMark(
                        x: .value("Week", point.weekStart),
                        y: .value("Volume", point.volume)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: AppColors.accentGradient,
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round))

                    AreaMark(
                        x: .value("Week", point.weekStart),
                        y: .value("Volume", point.volume)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [AppColors.accent.opacity(0.2), AppColors.accent.opacity(0.02)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                }
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                        AxisValueLabel()
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
                .frame(height: 100)
            }
        }
        .padding(16)
        .cardStyle(borderColor: AppColors.accent)
    }
}

// MARK: - Streak Calendar Card

struct StreakCalendarCard: View {
    let streakData: StreakData
    var onTap: (() -> Void)? = nil

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)
    private let dayLabels = ["S", "M", "T", "W", "T", "F", "S"]

    private var last28Days: [Date] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        // Calculate the start day so the grid aligns with weekdays
        let todayWeekday = calendar.component(.weekday, from: today) - 1  // 0=Sun
        let daysToShow = 28
        let startOffset = -(daysToShow - 1 - (6 - todayWeekday))

        return (0..<daysToShow).compactMap { i in
            calendar.date(byAdding: .day, value: startOffset + i, to: today)
        }
    }

    var body: some View {
        Group {
            if let onTap {
                Button(action: onTap) { cardContent }
                    .buttonStyle(.plain)
            } else {
                cardContent
            }
        }
    }

    private var cardContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("STREAK")
                        .font(.system(.caption2, weight: .bold))
                        .foregroundStyle(.secondary)
                    HStack(spacing: 6) {
                        Image(systemName: "flame.fill")
                            .foregroundStyle(streakData.current > 0 ? AppColors.accent : .secondary)
                        Text("\(streakData.current) day\(streakData.current == 1 ? "" : "s")")
                            .font(.system(.title3, weight: .bold))
                            .foregroundStyle(.primary)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("BEST")
                        .font(.system(.caption2, weight: .bold))
                        .foregroundStyle(.secondary)
                    Text("\(streakData.bestEver) day\(streakData.bestEver == 1 ? "" : "s")")
                        .font(.system(.subheadline, weight: .semibold))
                        .foregroundStyle(AppColors.accentGold)
                }

                if onTap != nil {
                    Image(systemName: "chevron.right")
                        .font(.system(.caption2, weight: .semibold))
                        .foregroundStyle(.tertiary)
                        .padding(.leading, 8)
                }
            }

            // Day labels
            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(0..<7, id: \.self) { i in
                    Text(dayLabels[i])
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity)
                }
            }

            // Heatmap dots
            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(last28Days, id: \.self) { date in
                    let count = streakData.workoutDays[date] ?? 0
                    let calendar = Calendar.current
                    let isToday = calendar.isDateInToday(date)
                    let isFuture = date > Date()

                    Circle()
                        .fill(dotColor(count: count, isFuture: isFuture))
                        .frame(width: 14, height: 14)
                        .overlay {
                            if isToday {
                                Circle()
                                    .stroke(AppColors.accent, lineWidth: 1.5)
                                    .frame(width: 16, height: 16)
                            }
                        }
                }
            }
        }
        .padding(16)
        .cardStyle(borderColor: AppColors.accent)
    }

    fileprivate func dotColor(count: Int, isFuture: Bool) -> Color {
        if isFuture { return Color.clear }
        switch count {
        case 0: return Color.white.opacity(0.08)
        case 1: return AppColors.accent.opacity(0.5)
        default: return AppColors.accent
        }
    }
}

// MARK: - Weekly Recap Card

struct WeeklyRecapCard: View {
    let stats: WeeklyStats
    let prCount: Int
    let onViewRecap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("WEEKLY RECAP")
                        .font(.system(.caption2, weight: .bold))
                        .foregroundStyle(.secondary)

                    Text(weekRangeString())
                        .font(.system(.caption, weight: .medium))
                        .foregroundStyle(.tertiary)
                }

                Spacer()

                if prCount > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "medal.fill")
                            .font(.system(.caption2))
                            .foregroundStyle(AppColors.accentGold)
                        Text("\(prCount) PR\(prCount == 1 ? "" : "s")")
                            .font(.system(.caption2, weight: .semibold))
                            .foregroundStyle(AppColors.accentGold)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(AppColors.accentGold.opacity(0.15)))
                }
            }

            // Mini stats row
            HStack(spacing: 16) {
                miniStat(value: "\(stats.workoutCount)", label: "workouts", icon: "figure.strengthtraining.traditional")
                miniStat(value: "\(stats.totalSets)", label: "sets", icon: "square.stack.3d.up")
                miniStat(value: formatVolume(stats.totalVolume), label: UnitFormatter.weightUnit, icon: "scalemass")
            }

            Button(action: onViewRecap) {
                HStack {
                    Text("View Full Recap")
                        .font(.system(.subheadline, weight: .medium))
                    Image(systemName: "chevron.right")
                        .font(.system(.caption, weight: .semibold))
                }
                .foregroundStyle(AppColors.accent)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(AppColors.accent.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(AppColors.accent.opacity(0.2), lineWidth: 1)
                        )
                )
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .cardStyle(borderColor: AppColors.accent)
    }

    private func miniStat(value: String, label: String, icon: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(AppColors.accent.opacity(0.7))
            VStack(alignment: .leading, spacing: 1) {
                Text(value)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                Text(label)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.secondary)
            }
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

// MARK: - Weekly Stats Detail Sheet

struct WeeklyStatsDetailSheet: View {
    let stats: WeeklyStats

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    detailRow(
                        icon: "scalemass.fill",
                        iconColor: AppColors.accent,
                        label: "Volume",
                        value: formattedVolume(stats.totalVolume),
                        unit: UnitFormatter.weightUnit,
                        delta: stats.volumeDelta.map { String(format: "%+.0f%%", $0) },
                        explanation: "Total weight moved this week (sets × reps × weight). Delta is vs. last week."
                    )
                    Divider().opacity(0.3)
                    detailRow(
                        icon: "square.stack.3d.up.fill",
                        iconColor: AppColors.accentGold,
                        label: "Sets",
                        value: "\(stats.totalSets)",
                        unit: nil,
                        delta: stats.setsDelta.map { $0 >= 0 ? "+\($0)" : "\($0)" },
                        explanation: "Total working sets completed."
                    )
                    Divider().opacity(0.3)
                    detailRow(
                        icon: "arrow.triangle.2.circlepath",
                        iconColor: AppColors.accentBlue,
                        label: "Reps",
                        value: "\(stats.totalReps)",
                        unit: nil,
                        delta: stats.repsDelta.map { $0 >= 0 ? "+\($0)" : "\($0)" },
                        explanation: "Total repetitions performed."
                    )
                    Divider().opacity(0.3)
                    detailRow(
                        icon: "figure.strengthtraining.traditional",
                        iconColor: AppColors.accentTeal,
                        label: "Workouts",
                        value: "\(stats.workoutCount)",
                        unit: nil,
                        delta: stats.workoutCountDelta.map { $0 >= 0 ? "+\($0)" : "\($0)" },
                        explanation: "Completed workout sessions."
                    )
                    Divider().opacity(0.3)
                    detailRow(
                        icon: "clock.fill",
                        iconColor: AppColors.accentTeal,
                        label: "Duration",
                        value: "\(stats.totalDurationMinutes)",
                        unit: "min",
                        delta: nil,
                        explanation: "Total time spent training this week."
                    )
                }
                .padding(20)
            }
            .scrollContentBackground(.hidden)
            .background(AppColors.background.ignoresSafeArea())
            .navigationTitle("This Week")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium, .large])
    }

    private func detailRow(icon: String, iconColor: Color, label: String, value: String, unit: String?, delta: String?, explanation: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.system(.body, weight: .semibold))
                .foregroundStyle(iconColor)
                .frame(width: 32, height: 32)
                .background(iconColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 4) {
                Text(label)
                    .font(.system(.subheadline, weight: .semibold))
                    .foregroundStyle(.primary)
                Text(explanation)
                    .font(.system(.caption, weight: .regular))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text(value)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(iconColor)
                    if let unit {
                        Text(unit)
                            .font(.system(.caption, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                }
                if let delta {
                    Text(delta)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(delta.hasPrefix("+") ? AppColors.accentGold : (delta.hasPrefix("-") ? .red : .secondary))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(delta.hasPrefix("+") ? AppColors.accentGold.opacity(0.12) : (delta.hasPrefix("-") ? Color.red.opacity(0.12) : Color.clear))
                        )
                }
            }
        }
    }

    private func formattedVolume(_ volume: Double) -> String {
        let display = UnitFormatter.convertToDisplay(volume)
        if display >= 1000 {
            return String(format: "%.1fk", display / 1000)
        }
        return String(format: "%.0f", display)
    }
}

// MARK: - Streak Detail Sheet

struct StreakDetailSheet: View {
    let streakData: StreakData

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)
    private let dayLabels = ["S", "M", "T", "W", "T", "F", "S"]

    private var last91Days: [Date] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let todayWeekday = calendar.component(.weekday, from: today) - 1  // 0=Sun
        let daysToShow = 91  // 13 full weeks
        let startOffset = -(daysToShow - 1 - (6 - todayWeekday))
        return (0..<daysToShow).compactMap { i in
            calendar.date(byAdding: .day, value: startOffset + i, to: today)
        }
    }

    private var totalWorkoutDaysLast90: Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        guard let cutoff = calendar.date(byAdding: .day, value: -89, to: today) else { return 0 }
        return streakData.workoutDays.filter { $0.key >= cutoff && $0.value > 0 }.count
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Streak stats prominently at top
                    HStack(spacing: 0) {
                        VStack(spacing: 6) {
                            HStack(spacing: 6) {
                                Image(systemName: "flame.fill")
                                    .font(.system(.title2, weight: .bold))
                                    .foregroundStyle(streakData.current > 0 ? AppColors.accent : .secondary)
                                Text("\(streakData.current)")
                                    .font(.system(size: 44, weight: .bold, design: .rounded))
                                    .foregroundStyle(.primary)
                            }
                            Text("Current streak")
                                .font(.system(.caption, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)

                        Divider()
                            .frame(height: 60)

                        VStack(spacing: 6) {
                            Text("\(streakData.bestEver)")
                                .font(.system(size: 44, weight: .bold, design: .rounded))
                                .foregroundStyle(AppColors.accentGold)
                            Text("Best ever")
                                .font(.system(.caption, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .padding(20)
                    .cardStyle(borderColor: AppColors.accent)

                    // 90-day heatmap
                    VStack(alignment: .leading, spacing: 10) {
                        Text("LAST 13 WEEKS")
                            .font(.system(.caption2, weight: .bold))
                            .foregroundStyle(.secondary)

                        LazyVGrid(columns: columns, spacing: 4) {
                            ForEach(0..<7, id: \.self) { i in
                                Text(dayLabels[i])
                                    .font(.system(size: 9, weight: .medium))
                                    .foregroundStyle(.tertiary)
                                    .frame(maxWidth: .infinity)
                            }
                        }

                        LazyVGrid(columns: columns, spacing: 4) {
                            ForEach(last91Days, id: \.self) { date in
                                let count = streakData.workoutDays[date] ?? 0
                                let calendar = Calendar.current
                                let isToday = calendar.isDateInToday(date)
                                let isFuture = date > Date()

                                Circle()
                                    .fill(dotColor(count: count, isFuture: isFuture))
                                    .frame(maxWidth: .infinity)
                                    .aspectRatio(1, contentMode: .fit)
                                    .overlay {
                                        if isToday {
                                            Circle()
                                                .stroke(AppColors.accent, lineWidth: 1.5)
                                        }
                                    }
                            }
                        }
                    }
                    .padding(16)
                    .cardStyle(borderColor: AppColors.accent)

                    // Summary stats
                    HStack(spacing: 0) {
                        summaryStatColumn(
                            value: "\(totalWorkoutDaysLast90)",
                            label: "Training days",
                            sublabel: "last 90 days",
                            color: AppColors.accent
                        )
                        Divider().frame(height: 40)
                        summaryStatColumn(
                            value: "\(streakData.weeklyGoalStreak)",
                            label: "Goal weeks",
                            sublabel: "consecutive",
                            color: AppColors.accentTeal
                        )
                    }
                    .padding(16)
                    .cardStyle(borderColor: AppColors.accent)
                }
                .padding(20)
            }
            .scrollContentBackground(.hidden)
            .background(AppColors.background.ignoresSafeArea())
            .navigationTitle("Streak History")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium, .large])
    }

    private func summaryStatColumn(value: String, label: String, sublabel: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(color)
            Text(label)
                .font(.system(.caption, weight: .semibold))
                .foregroundStyle(.primary)
            Text(sublabel)
                .font(.system(.caption2, weight: .regular))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func dotColor(count: Int, isFuture: Bool) -> Color {
        if isFuture { return Color.clear }
        switch count {
        case 0: return Color.white.opacity(0.08)
        case 1: return AppColors.accent.opacity(0.5)
        default: return AppColors.accent
        }
    }
}

// MARK: - Muscle Group Detail Sheet

struct MuscleGroupDetailSheet: View {
    let breakdown: [MuscleGroup: Int]

    private var sortedGroups: [(group: MuscleGroup, count: Int)] {
        breakdown.map { (group: $0.key, count: $0.value) }
            .sorted { $0.count > $1.count }
    }

    private var maxCount: Int {
        sortedGroups.first?.count ?? 1
    }

    private var topGroup: MuscleGroup? { sortedGroups.first?.group }
    private var hasCore: Bool { breakdown[.core, default: 0] > 0 }
    private var hasLegs: Bool { breakdown[.legs, default: 0] > 0 }

    var body: some View {
        NavigationStack {
            ScrollView {
                muscleGroupContent
                    .padding(20)
            }
            .scrollContentBackground(.hidden)
            .background(AppColors.background.ignoresSafeArea())
            .navigationTitle("Muscle Groups")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium, .large])
    }

    @ViewBuilder
    private var muscleGroupContent: some View {
        if sortedGroups.isEmpty {
            HStack(spacing: 8) {
                Image(systemName: "figure.arms.open")
                    .foregroundStyle(.tertiary)
                Text("Complete workouts to see your muscle breakdown")
                    .font(.system(.subheadline, weight: .medium))
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 40)
        } else {
            VStack(alignment: .leading, spacing: 16) {
                muscleBarRows
                if let top = topGroup {
                    tipCard(topGroup: top)
                }
            }
        }
    }

    private var muscleBarRows: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(sortedGroups, id: \.group) { item in
                muscleBarRow(item: item)
            }
        }
        .padding(16)
        .cardStyle(borderColor: AppColors.accent)
    }

    private func muscleBarRow(item: (group: MuscleGroup, count: Int)) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: item.group.icon)
                    .font(.system(.subheadline, weight: .medium))
                    .foregroundStyle(AppColors.accent)
                    .frame(width: 24)
                Text(item.group.rawValue)
                    .font(.system(.subheadline, weight: .semibold))
                    .foregroundStyle(.primary)
                Spacer()
                Text("\(item.count) set\(item.count == 1 ? "" : "s")")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(AppColors.accent)
            }
            GeometryReader { geo in
                Capsule()
                    .fill(AppColors.accent.opacity(0.15))
                    .frame(height: 12)
                    .overlay(alignment: .leading) {
                        Capsule()
                            .fill(LinearGradient(colors: AppColors.accentGradient, startPoint: .leading, endPoint: .trailing))
                            .frame(width: max(12, geo.size.width * CGFloat(item.count) / CGFloat(maxCount)), height: 12)
                    }
            }
            .frame(height: 12)
            Text("sets targeted this week")
                .font(.system(.caption2, weight: .regular))
                .foregroundStyle(.tertiary)
        }
    }

    private func tipCard(topGroup: MuscleGroup) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "lightbulb.fill")
                    .font(.system(.caption, weight: .semibold))
                    .foregroundStyle(AppColors.accentGold)
                Text("Tip")
                    .font(.system(.caption, weight: .bold))
                    .foregroundStyle(AppColors.accentGold)
            }
            Text("Your most trained group this week is **\(topGroup.rawValue)**.")
                .font(.system(.caption, weight: .regular))
                .foregroundStyle(.secondary)
            if !hasCore || !hasLegs {
                let missing = [!hasCore ? "core" : nil, !hasLegs ? "legs" : nil].compactMap { $0 }.joined(separator: " and ")
                Text("Consider adding some \(missing) work for a balanced training week.")
                    .font(.system(.caption, weight: .regular))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .cardStyle(borderColor: AppColors.accentGold)
    }
}

// MARK: - Volume Trend Detail Sheet

struct VolumeTrendDetailSheet: View {
    let trend: [VolumeTrendPoint]

    private var nonEmptyTrend: [VolumeTrendPoint] {
        trend.filter { $0.volume > 0 }
    }

    private var trendSummary: String {
        guard nonEmptyTrend.count >= 2 else { return "Not enough data yet." }
        let first = nonEmptyTrend.first!.volume
        let last = nonEmptyTrend.last!.volume
        guard first > 0 else { return "Not enough data yet." }
        let pct = ((last - first) / first) * 100
        let weeks = nonEmptyTrend.count
        if abs(pct) < 5 { return "Stable over \(weeks) week\(weeks == 1 ? "" : "s")." }
        let direction = pct > 0 ? "Trending up" : "Trending down"
        return "\(direction) \(String(format: "%.0f", abs(pct)))% over \(weeks) week\(weeks == 1 ? "" : "s")."
    }

    private let weekFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f
    }()

    var body: some View {
        NavigationStack {
            ScrollView {
                volumeTrendContent
                    .padding(20)
            }
            .scrollContentBackground(.hidden)
            .background(AppColors.background.ignoresSafeArea())
            .navigationTitle("Volume Trend")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium, .large])
    }

    private var volumeTrendContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            trendSummaryCard
            if !trend.allSatisfy({ $0.volume == 0 }) {
                volumeChartCard
            }
            weeklyBreakdownList
        }
    }

    private var trendSummaryCard: some View {
        HStack(spacing: 10) {
            Image(systemName: trendIcon)
                .font(.system(.body, weight: .semibold))
                .foregroundStyle(trendColor)
                .frame(width: 32, height: 32)
                .background(trendColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
            Text(trendSummary)
                .font(.system(.subheadline, weight: .medium))
                .foregroundStyle(.primary)
        }
        .padding(14)
        .cardStyle(borderColor: trendColor)
    }

    private var volumeChartCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("VOLUME OVER TIME")
                .font(.system(.caption2, weight: .bold))
                .foregroundStyle(.secondary)
            Chart(trend) { point in
                LineMark(x: .value("Week", point.weekStart), y: .value("Volume", point.volume))
                    .foregroundStyle(LinearGradient(colors: AppColors.accentGradient, startPoint: .leading, endPoint: .trailing))
                    .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
                AreaMark(x: .value("Week", point.weekStart), y: .value("Volume", point.volume))
                    .foregroundStyle(LinearGradient(colors: [AppColors.accent.opacity(0.25), AppColors.accent.opacity(0.02)], startPoint: .top, endPoint: .bottom))
            }
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                    AxisValueLabel().foregroundStyle(.secondary).font(.caption2)
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { _ in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5)).foregroundStyle(Color.secondary.opacity(0.2))
                    AxisValueLabel().foregroundStyle(.secondary).font(.caption2)
                }
            }
            .frame(height: 220)
        }
        .padding(16)
        .cardStyle(borderColor: AppColors.accent)
    }

    private var weeklyBreakdownList: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("WEEKLY BREAKDOWN")
                .font(.system(.caption2, weight: .bold))
                .foregroundStyle(.secondary)
                .padding(.bottom, 10)
            ForEach(Array(trend.enumerated()), id: \.element.id) { index, point in
                weekRow(index: index, point: point)
            }
        }
        .padding(16)
        .cardStyle(borderColor: AppColors.accent)
    }

    private func weekRow(index: Int, point: VolumeTrendPoint) -> some View {
        let prev: Double? = index > 0 ? trend[index - 1].volume : nil
        return VStack(spacing: 0) {
            HStack {
                Text(weekFormatter.string(from: point.weekStart))
                    .font(.system(.subheadline, weight: .medium))
                    .foregroundStyle(.primary)
                Spacer()
                if point.volume == 0 {
                    Text("—")
                        .font(.system(.subheadline, weight: .medium))
                        .foregroundStyle(.tertiary)
                } else {
                    weekRowValue(volume: point.volume, prev: prev)
                }
            }
            .padding(.vertical, 10)
            if index < trend.count - 1 {
                Divider().opacity(0.3)
            }
        }
    }

    private func weekRowValue(volume: Double, prev: Double?) -> some View {
        HStack(spacing: 6) {
            Text(formattedVolume(volume))
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(AppColors.accent)
            Text(UnitFormatter.weightUnit)
                .font(.system(.caption2, weight: .medium))
                .foregroundStyle(.secondary)
            if let prev, prev > 0 {
                Image(systemName: volume >= prev ? "arrow.up" : "arrow.down")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(volume >= prev ? AppColors.accentGold : Color.red)
            }
        }
    }

    private var trendIcon: String {
        guard nonEmptyTrend.count >= 2 else { return "chart.line.uptrend.xyaxis" }
        let first = nonEmptyTrend.first!.volume
        let last = nonEmptyTrend.last!.volume
        guard first > 0 else { return "chart.line.uptrend.xyaxis" }
        let pct = ((last - first) / first) * 100
        if abs(pct) < 5 { return "minus" }
        return pct > 0 ? "chart.line.uptrend.xyaxis" : "chart.line.downtrend.xyaxis"
    }

    private var trendColor: Color {
        guard nonEmptyTrend.count >= 2 else { return .secondary }
        let first = nonEmptyTrend.first!.volume
        let last = nonEmptyTrend.last!.volume
        guard first > 0 else { return .secondary }
        let pct = ((last - first) / first) * 100
        if abs(pct) < 5 { return .secondary }
        return pct > 0 ? AppColors.accentGold : .red
    }

    private func formattedVolume(_ volume: Double) -> String {
        let display = UnitFormatter.convertToDisplay(volume)
        if display >= 1000 {
            return String(format: "%.1fk", display / 1000)
        }
        return String(format: "%.0f", display)
    }
}
