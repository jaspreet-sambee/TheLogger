//
//  SummaryViews.swift
//  TheLogger
//
//  Workout summary and exercise progress views
//

import SwiftUI
import SwiftData
import Charts

// MARK: - Workout End Summary View

/// Summary shown after ending a workout. Requires ~5s before Done is tappable.
struct WorkoutEndSummaryView: View {
    let summary: WorkoutSummary
    let workoutName: String
    let workoutDate: Date
    let prExercises: [String]
    let prDetails: [(name: String, weight: Double, reps: Int)]
    let onDismiss: () -> Void

    init(
        summary: WorkoutSummary,
        workoutName: String = "",
        workoutDate: Date = Date(),
        prExercises: [String] = [],
        prDetails: [(name: String, weight: Double, reps: Int)] = [],
        onDismiss: @escaping () -> Void
    ) {
        self.summary = summary
        self.workoutName = workoutName
        self.workoutDate = workoutDate
        self.prExercises = prExercises
        self.prDetails = prDetails
        self.onDismiss = onDismiss
    }

    @State private var affirmation = "Nice work"
    @State private var cardVisible = false
    @State private var showHeader = false
    @State private var showAffirmation = false
    @State private var showDuration = false
    @State private var showStats = false
    @State private var showPRs = false
    @State private var showButton = false
    @State private var canDismiss = false
    @State private var showConfetti = false
    private let minDisplaySeconds: Double = 5

    private static let workoutDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                Spacer().frame(height: 20)

                cardContent
                    .padding(.horizontal, 32)
                    .padding(.vertical, 24)
                    .frame(maxWidth: .infinity)
                    .background(cardBackground)
                    .padding(.horizontal, 16)
                    .scaleEffect(cardVisible ? 1 : 0.92)
                    .opacity(cardVisible ? 1 : 0)

                Spacer()
            }
            .onAppear {
                let options = ["Nice work", "Well done", "Great session", "Solid effort", "Keep it up"]
                affirmation = options.randomElement() ?? "Nice work"
                withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) {
                    cardVisible = true
                }
                if !prExercises.isEmpty {
                    showConfetti = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                        showConfetti = false
                    }
                }
                scheduleStagger()
                DispatchQueue.main.asyncAfter(deadline: .now() + minDisplaySeconds) {
                    withAnimation(.easeOut(duration: 0.3)) {
                        canDismiss = true
                    }
                }
            }

            if showConfetti {
                ConfettiView()
                    .allowsHitTesting(false)
            }
        }
    }

    private func scheduleStagger() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) { showHeader = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.14) { showAffirmation = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) { showDuration = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.32) { showStats = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.42) { showPRs = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.52) { showButton = true }
    }

    private var cardContent: some View {
        ScrollView {
            VStack(spacing: 28) {
                headerSection
                        .opacity(showHeader ? 1 : 0)
                        .offset(y: showHeader ? 0 : 6)
                        .animation(.easeOut(duration: 0.32), value: showHeader)
                affirmationText
                    .opacity(showAffirmation ? 1 : 0)
                    .offset(y: showAffirmation ? 0 : 6)
                    .animation(.easeOut(duration: 0.32), value: showAffirmation)
                durationStat
                    .opacity(showDuration ? 1 : 0)
                    .offset(y: showDuration ? 0 : 6)
                    .animation(.easeOut(duration: 0.32), value: showDuration)
                secondaryStats
                    .opacity(showStats ? 1 : 0)
                    .offset(y: showStats ? 0 : 6)
                    .animation(.easeOut(duration: 0.32), value: showStats)
                if !prExercises.isEmpty {
                    prSection
                        .opacity(showPRs ? 1 : 0)
                        .offset(y: showPRs ? 0 : 6)
                        .animation(.easeOut(duration: 0.32), value: showPRs)
                }
                dismissButton
                    .opacity(showButton ? 1 : 0)
                    .offset(y: showButton ? 0 : 6)
                    .animation(.easeOut(duration: 0.32), value: showButton)
            }
        }
    }

    private var headerSection: some View {
        VStack(spacing: 6) {
            if !workoutName.isEmpty {
                Text(workoutName)
                    .font(.system(.headline, weight: .semibold))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
            }
            Text(Self.workoutDateFormatter.string(from: workoutDate))
                .font(.system(.caption, weight: .medium))
                .foregroundStyle(.secondary)
        }
    }

    private var affirmationText: some View {
        Text(affirmation)
            .font(.system(.title2, weight: .semibold))
            .foregroundStyle(.primary)
    }

    private var durationStat: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "clock.fill")
                    .font(.system(.title3, weight: .medium))
                    .foregroundStyle(.blue.opacity(0.9))
                Text(summary.formattedDuration)
                    .font(.system(size: 52, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
            }
            Text("workout time")
                .font(.system(.subheadline, weight: .medium))
                .foregroundStyle(.secondary)
        }
    }

    private var secondaryStats: some View {
        HStack(spacing: 24) {
            statItem(value: "\(summary.totalExercises)", label: "exercises", icon: "figure.strengthtraining.traditional")
            Rectangle()
                .fill(Color.secondary.opacity(0.25))
                .frame(width: 1, height: 44)
            statItem(value: "\(summary.totalSets)", label: "sets", icon: "square.stack.3d.up")
            Rectangle()
                .fill(Color.secondary.opacity(0.25))
                .frame(width: 1, height: 44)
            statItem(value: "\(summary.totalReps)", label: "reps", icon: "repeat")
            if summary.totalVolume > 0 {
                Rectangle()
                    .fill(Color.secondary.opacity(0.25))
                    .frame(width: 1, height: 44)
                statItem(value: summary.formattedVolume, label: "volume", icon: "scalemass")
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
    }

    private var prSection: some View {
        VStack(spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "trophy.fill")
                    .font(.system(.body, weight: .semibold))
                    .foregroundStyle(.yellow)
                Text("Personal Records")
                    .font(.system(.subheadline, weight: .semibold))
                    .foregroundStyle(.primary)
            }

            if prDetails.isEmpty {
                Text(prExercises.joined(separator: ", "))
                    .font(.system(.caption, weight: .medium))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            } else {
                VStack(spacing: 8) {
                    ForEach(prDetails, id: \.name) { item in
                        HStack {
                            Text(item.name)
                                .font(.system(.subheadline, weight: .medium))
                                .foregroundStyle(.primary)
                            Spacer()
                            Text(formatPR(item))
                                .font(.system(.subheadline, weight: .semibold))
                                .foregroundStyle(.yellow)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.yellow.opacity(0.08))
                        )
                    }
                }
            }
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 20)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.yellow.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.yellow.opacity(0.35), lineWidth: 1)
                )
        )
    }

    private func formatPR(_ item: (name: String, weight: Double, reps: Int)) -> String {
        if item.weight > 0 {
            return "\(UnitFormatter.formatWeightCompact(item.weight)) × \(item.reps)"
        }
        return "\(item.reps) reps"
    }

    private func statItem(value: String, label: String, icon: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(.caption2, weight: .medium))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
            Text(label)
                .font(.system(.caption2, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .frame(minWidth: 56)
    }

    private var dismissButton: some View {
        Button(action: onDismiss) {
            HStack(spacing: 8) {
                if canDismiss {
                    Text("Done")
                        .font(.system(.body, weight: .semibold))
                } else {
                    ProgressView()
                        .tint(.white)
                    Text("Viewing summary...")
                        .font(.system(.subheadline, weight: .medium))
                }
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(canDismiss ? Color.blue : Color.gray)
            )
        }
        .disabled(!canDismiss)
        .padding(.top, 8)
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 24)
            .fill(Color(.systemBackground))
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(Color.blue.opacity(0.15), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.06), radius: 12, x: 0, y: 4)
    }
}

// MARK: - Exercise Progress View

struct ExerciseProgressView: View {
    let exerciseName: String
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var emptyChartAppeared = false

    struct WeightDataPoint: Identifiable {
        let id = UUID()
        let date: Date
        let maxWeight: Double
    }

    private var progressData: [WeightDataPoint] {
        let normalizedName = exerciseName.lowercased().trimmingCharacters(in: CharacterSet.whitespaces)
        let descriptor = FetchDescriptor<Workout>(sortBy: [SortDescriptor(\Workout.date, order: .forward)])
        guard let workouts = try? modelContext.fetch(descriptor) else { return [] }
        var dataPoints: [WeightDataPoint] = []
        for workout in workouts where workout.endTime != nil && !workout.isTemplate {
            if let exercise = workout.exercises?.first(where: { $0.name.lowercased().trimmingCharacters(in: CharacterSet.whitespaces) == normalizedName }) {
                let maxWeight = (exercise.sets ?? []).map { $0.weight }.max() ?? 0
                if maxWeight > 0 {
                    dataPoints.append(WeightDataPoint(date: workout.date, maxWeight: maxWeight))
                }
            }
        }
        return dataPoints
    }

    private var maxWeightEver: Double { progressData.map { $0.maxWeight }.max() ?? 0 }
    private var lastPerformed: Date? { progressData.last?.date }
    private var formattedLastPerformed: String {
        guard let date = lastPerformed else { return "Never" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    statsSection
                    if progressData.count >= 2 { chartSection } else { emptyChartState }
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
            }
            .background(Color.black)
            .navigationTitle(exerciseName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var statsSection: some View {
        HStack(spacing: 16) {
            statCard(title: "Max Weight", value: maxWeightEver > 0 ? String(format: "%.0f", UnitFormatter.convertToDisplay(maxWeightEver)) : "--", unit: UnitFormatter.weightUnit, icon: "arrow.up.circle.fill", color: .blue)
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "calendar")
                        .font(.system(.caption, weight: .medium))
                        .foregroundStyle(.secondary)
                    Text("Last Performed")
                        .font(.system(.caption, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                Text(formattedLastPerformed)
                    .font(.system(.subheadline, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.black.opacity(0.6))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.secondary.opacity(0.2), lineWidth: 1))
            )
        }
    }

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
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                Text(unit)
                    .font(.system(.caption, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.6))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(color.opacity(0.25), lineWidth: 1))
        )
    }

    private var chartSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Weight Over Time")
                .font(.system(.caption, weight: .medium))
                .foregroundStyle(.secondary)
            Chart(progressData) { point in
                LineMark(x: .value("Date", point.date), y: .value("Weight", point.maxWeight))
                    .foregroundStyle(LinearGradient(colors: [.blue, .teal], startPoint: .leading, endPoint: .trailing))
                    .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round))
                AreaMark(x: .value("Date", point.date), y: .value("Weight", point.maxWeight))
                    .foregroundStyle(LinearGradient(colors: [.blue.opacity(0.2), .blue.opacity(0.02)], startPoint: .top, endPoint: .bottom))
                PointMark(x: .value("Date", point.date), y: .value("Weight", point.maxWeight))
                    .foregroundStyle(.blue)
                    .symbolSize(30)
            }
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5)).foregroundStyle(Color.secondary.opacity(0.2))
                    AxisValueLabel().foregroundStyle(.secondary).font(.caption2)
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { _ in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5)).foregroundStyle(Color.secondary.opacity(0.2))
                    AxisValueLabel().foregroundStyle(.secondary).font(.caption2)
                }
            }
            .frame(height: 200)
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.black.opacity(0.6))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.blue.opacity(0.25), lineWidth: 1))
            )
        }
    }

    private var emptyChartState: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 32))
                .foregroundStyle(.tertiary)
                .symbolEffect(.bounce, value: emptyChartAppeared)
            Text("Not enough data yet")
                .font(.system(.subheadline, weight: .medium))
                .foregroundStyle(.secondary)
            Text("Complete at least 2 workouts with this exercise to see your progress chart.")
                .font(.system(.caption))
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .padding(.horizontal, 20)
        .opacity(emptyChartAppeared ? 1 : 0)
        .animation(.easeOut(duration: 0.4), value: emptyChartAppeared)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.6))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.secondary.opacity(0.2), lineWidth: 1))
        )
        .onAppear { emptyChartAppeared = true }
    }
}