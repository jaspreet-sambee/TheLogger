//
//  ExerciseDetailView.swift
//  TheLogger
//
//  Exercise progress tracking with charts and PR history
//

import SwiftUI
import SwiftData
import Charts

struct ExerciseDetailView: View {
    let exerciseName: String

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Workout.date, order: .reverse) private var workouts: [Workout]
    @State private var selectedTimeRange: TimeRange = .allTime
    @State private var chartData: [ChartDataPoint] = []
    @State private var prBreakthroughs: [PRBreakthrough] = []
    @State private var showingAllWorkouts = false
    @State private var selectedDataPoint: ChartDataPoint?

    // Computed properties for stats
    private var currentPR: ChartDataPoint? {
        chartData.max(by: { $0.prScore < $1.prScore })
    }

    private var allTimeBest: ChartDataPoint? {
        chartData.max(by: { $0.prScore < $1.prScore })
    }

    private var totalWorkouts: Int {
        Set(chartData.map { $0.workoutId }).count
    }

    private var averageGain: Double? {
        guard chartData.count >= 2 else { return nil }
        let sorted = chartData.sorted(by: { $0.date < $1.date })
        let first = sorted.first!.prScore
        let last = sorted.last!.prScore
        guard first > 0 else { return nil }
        return ((last - first) / first) * 100
    }

    private var filteredChartData: [ChartDataPoint] {
        selectedTimeRange.filter(chartData)
    }

    var body: some View {
        ZStack {
            AppColors.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    // Time Range Selector
                    timeRangeSelector
                        .staggeredAppear(index: 0)

                    // Chart Hero Section
                    if !filteredChartData.isEmpty {
                        chartSection
                            .staggeredAppear(index: 1)
                    } else {
                        emptyChartState
                            .staggeredAppear(index: 1)
                    }

                    // Stats Cards Grid
                    if !chartData.isEmpty {
                        statsCardsGrid
                            .staggeredAppear(index: 2)
                    }

                    // PR History Timeline
                    if !prBreakthroughs.isEmpty {
                        prHistorySection
                            .staggeredAppear(index: 3)
                    }

                    // Full Workout History (Collapsible)
                    if !chartData.isEmpty {
                        fullHistorySection
                            .staggeredAppear(index: 4)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 32)
            }
        }
        .navigationTitle(exerciseName)
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            loadData()
        }
    }

    // MARK: - Time Range Selector

    private var timeRangeSelector: some View {
        Menu {
            ForEach(TimeRange.allCases) { range in
                Button {
                    withAnimation(.smooth) {
                        selectedTimeRange = range
                    }
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                } label: {
                    HStack {
                        Text(range.rawValue)
                        if selectedTimeRange == range {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "calendar")
                    .font(.system(.caption, weight: .semibold))
                Text(selectedTimeRange.rawValue)
                    .font(.system(.subheadline, weight: .medium))
                Image(systemName: "chevron.down")
                    .font(.caption2)
            }
            .foregroundStyle(AppColors.accent)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(AppColors.accent.opacity(0.15))
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Chart Section

    private var chartSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            let isBodyweightExercise = filteredChartData.allSatisfy { $0.isBodyweight }
            Text(isBodyweightExercise ? "Max Reps Progress" : "Estimated 1RM Progress")
                .font(.system(.headline, weight: .semibold))
                .foregroundStyle(.primary)

            Chart(filteredChartData) { point in
                // Area gradient
                AreaMark(
                    x: .value("Date", point.date),
                    y: .value(isBodyweightExercise ? "Reps" : "1RM", point.prScore)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [AppColors.accent.opacity(0.3), AppColors.accent.opacity(0.05)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .interpolationMethod(.catmullRom)

                // Line
                LineMark(
                    x: .value("Date", point.date),
                    y: .value(isBodyweightExercise ? "Reps" : "1RM", point.prScore)
                )
                .foregroundStyle(AppColors.accent)
                .lineStyle(StrokeStyle(lineWidth: 3))
                .interpolationMethod(.catmullRom)

                // Points
                PointMark(
                    x: .value("Date", point.date),
                    y: .value(isBodyweightExercise ? "Reps" : "1RM", point.prScore)
                )
                .foregroundStyle(AppColors.accent)
                .symbolSize(80)
            }
            .frame(height: 280)
            .chartXAxis {
                AxisMarks(values: .automatic) { _ in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                        .foregroundStyle(.secondary.opacity(0.3))
                    AxisValueLabel()
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                        .foregroundStyle(.secondary.opacity(0.3))
                    AxisValueLabel {
                        if let doubleValue = value.as(Double.self) {
                            if isBodyweightExercise {
                                Text("\(Int(doubleValue))")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            } else {
                                Text(UnitFormatter.formatWeightCompact(doubleValue, showUnit: false))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .chartYAxisLabel(isBodyweightExercise ? "reps" : UnitFormatter.currentSystem.weightUnit, alignment: .leading)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.06))
            )
        }
    }

    private var emptyChartState: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 64))
                .foregroundStyle(.secondary.opacity(0.5))

            Text("No Data for This Range")
                .font(.system(.headline, weight: .semibold))
                .foregroundStyle(.primary)

            Text("Try selecting a different time range")
                .font(.system(.subheadline))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 280)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.06))
        )
    }

    // MARK: - Stats Cards Grid

    private var statsCardsGrid: some View {
        LazyVGrid(columns: [
            GridItem(.flexible(), spacing: 12),
            GridItem(.flexible(), spacing: 12)
        ], spacing: 12) {
            // Current PR
            if let pr = currentPR {
                StatCard(
                    icon: "medal.fill",
                    iconColor: .yellow,
                    title: "Current PR",
                    value: pr.displayString,
                    subtitle: pr.isBodyweight ? "Max reps" : "1RM: \(UnitFormatter.formatWeightCompact(pr.estimated1RM, showUnit: true))"
                )
            }

            // Total Workouts
            StatCard(
                icon: "checkmark.circle.fill",
                iconColor: .green,
                title: "Total Workouts",
                value: "\(totalWorkouts)",
                subtitle: totalWorkouts == 1 ? "workout" : "workouts"
            )

            // All-Time Best
            if let best = allTimeBest {
                StatCard(
                    icon: "star.fill",
                    iconColor: AppColors.accent,
                    title: "All-Time Best",
                    value: best.isBodyweight
                        ? "\(best.reps) reps"
                        : UnitFormatter.formatWeightCompact(best.estimated1RM, showUnit: true),
                    subtitle: best.displayString
                )
            }

            // Average Gain
            if let gain = averageGain {
                StatCard(
                    icon: "chart.line.uptrend.xyaxis",
                    iconColor: AppColors.accent,
                    title: "Total Gain",
                    value: String(format: "%+.1f%%", gain),
                    subtitle: "Since start"
                )
            }
        }
    }

    // MARK: - PR History Section

    private var prHistorySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("PR Breakthroughs")
                .font(.system(.headline, weight: .semibold))
                .foregroundStyle(.primary)

            VStack(spacing: 8) {
                ForEach(prBreakthroughs) { breakthrough in
                    NavigationLink {
                        if let workout = workouts.first(where: { $0.id == breakthrough.workoutId }) {
                            WorkoutDetailView(workout: workout, onLogAgain: { _ in })
                        } else {
                            Text("Workout not found")
                        }
                    } label: {
                        PRBreakthroughCard(breakthrough: breakthrough)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Full History Section

    private var fullHistorySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    showingAllWorkouts.toggle()
                }
                UIImpactFeedbackGenerator(style: .light).impactOccurred(intensity: 0.5)
            } label: {
                HStack {
                    Text("All Workouts")
                        .font(.system(.headline, weight: .semibold))
                        .foregroundStyle(.primary)

                    Spacer()

                    Image(systemName: showingAllWorkouts ? "chevron.up" : "chevron.down")
                        .font(.system(.subheadline, weight: .semibold))
                        .foregroundStyle(AppColors.accent)
                }
            }
            .buttonStyle(.plain)

            if showingAllWorkouts {
                VStack(spacing: 8) {
                    ForEach(chartData.sorted(by: { $0.date > $1.date })) { point in
                        NavigationLink {
                            if let workout = workouts.first(where: { $0.id == point.workoutId }) {
                                WorkoutDetailView(workout: workout, onLogAgain: { _ in })
                            } else {
                                Text("Workout not found")
                            }
                        } label: {
                            WorkoutHistoryCard(dataPoint: point)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    // MARK: - Data Loading

    private func loadData() {
        // Load chart data
        chartData = PRManager.shared.getExerciseHistory(
            exerciseName: exerciseName,
            modelContext: modelContext
        )

        // Load PR breakthroughs
        prBreakthroughs = PRManager.shared.getPRBreakthroughs(
            exerciseName: exerciseName,
            modelContext: modelContext
        )
    }
}

// MARK: - Supporting Views

struct StatCard: View {
    let icon: String
    let iconColor: Color
    let title: String
    let value: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(.caption, weight: .semibold))
                    .foregroundStyle(iconColor)

                Text(title)
                    .font(.system(.caption2, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            Text(value)
                .font(.system(.title3, weight: .bold))
                .foregroundStyle(.primary)

            Text(subtitle)
                .font(.system(.caption2))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.06))
        )
    }
}

struct PRBreakthroughCard: View {
    let breakthrough: PRBreakthrough

    var body: some View {
        HStack(spacing: 12) {
                // Trophy icon
                Image(systemName: "medal.fill")
                    .font(.system(.body))
                    .foregroundStyle(.yellow)
                    .frame(width: 24)

                // Content
                VStack(alignment: .leading, spacing: 4) {
                    Text(breakthrough.date, style: .date)
                        .font(.system(.subheadline, weight: .medium))
                        .foregroundStyle(.primary)

                    HStack(spacing: 6) {
                        let btLabel = breakthrough.weight == 0
                            ? "BW × \(breakthrough.reps)"
                            : "\(UnitFormatter.formatWeightCompact(breakthrough.weight, showUnit: true)) × \(breakthrough.reps)"
                        Text(btLabel)
                            .font(.system(.caption, weight: .medium))
                            .foregroundStyle(.secondary)

                        if breakthrough.weight > 0 {
                            Text("•")
                                .font(.system(.caption))
                                .foregroundStyle(.tertiary)

                            Text("1RM: \(UnitFormatter.formatWeightCompact(breakthrough.estimated1RM, showUnit: true))")
                                .font(.system(.caption))
                                .foregroundStyle(.tertiary)
                        }
                    }
                }

                Spacer()

                // Improvement badge
                if let improvement = breakthrough.improvementPercent {
                    Text(String(format: "+%.1f%%", improvement))
                        .font(.system(.caption, weight: .semibold))
                        .foregroundStyle(AppColors.accentGold)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(AppColors.accentGold.opacity(0.15))
                        )
                }

                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.white.opacity(0.07))
            )
    }
}

struct WorkoutHistoryCard: View {
    let dataPoint: ChartDataPoint

    var body: some View {
        HStack(spacing: 12) {
            // Date
            VStack(alignment: .leading, spacing: 2) {
                Text(dataPoint.date, style: .date)
                    .font(.system(.subheadline, weight: .medium))
                    .foregroundStyle(.primary)

                Text(dataPoint.date, style: .relative)
                    .font(.system(.caption2))
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            // Performance
            VStack(alignment: .trailing, spacing: 2) {
                Text(dataPoint.displayString)
                    .font(.system(.subheadline, weight: .medium))
                    .foregroundStyle(.secondary)

                if !dataPoint.isBodyweight {
                    Text("1RM: \(UnitFormatter.formatWeightCompact(dataPoint.estimated1RM, showUnit: true))")
                        .font(.system(.caption2))
                        .foregroundStyle(.tertiary)
                }
            }

            Image(systemName: "chevron.right")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.05))
        )
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        ExerciseDetailView(exerciseName: "Bench Press")
    }
}
