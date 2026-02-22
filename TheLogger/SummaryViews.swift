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

/// Summary shown after ending a workout. Requires ~2s before Done is tappable.
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
    @State private var showHeader = false
    @State private var showAffirmation = false
    @State private var showDuration = false
    @State private var showStats = false
    @State private var showPRs = false
    @State private var showButton = false
    @State private var canDismiss = false
    @State private var showConfetti = false
    @State private var prRowsRevealed = 0
    @State private var durationPulse = false
    @State private var medalBounce = false
    private let minDisplaySeconds: Double = 1.0

    private static let workoutDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()

    private var hasPRs: Bool { !prExercises.isEmpty }

    var body: some View {
        ZStack {
            AppColors.background
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    headerSection
                        .opacity(showHeader ? 1 : 0)
                        .offset(y: showHeader ? 0 : 8)
                        .animation(.easeOut(duration: 0.32), value: showHeader)

                    affirmationText
                        .opacity(showAffirmation ? 1 : 0)
                        .offset(y: showAffirmation ? 0 : 6)
                        .animation(.easeOut(duration: 0.32), value: showAffirmation)

                    prSection
                        .opacity(showPRs ? 1 : 0)
                        .offset(y: showPRs ? 0 : 12)
                        .animation(.spring(response: 0.5, dampingFraction: 0.75), value: showPRs)

                    durationStat
                        .opacity(showDuration ? 1 : 0)
                        .offset(y: showDuration ? 0 : 6)
                        .animation(.easeOut(duration: 0.32), value: showDuration)

                    secondaryStats
                        .opacity(showStats ? 1 : 0)
                        .offset(y: showStats ? 0 : 6)
                        .animation(.easeOut(duration: 0.32), value: showStats)

                    dismissButton
                        .opacity(showButton ? 1 : 0)
                        .offset(y: showButton ? 0 : 6)
                        .animation(.easeOut(duration: 0.32), value: showButton)
                }
                .padding(.horizontal, 20)
                .padding(.top, 32)
                .padding(.bottom, 40)
            }
            .onAppear {
                let options = ["Nice work", "Well done", "Great session", "Solid effort", "Keep it up"]
                affirmation = options.randomElement() ?? "Nice work"

                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)

                if !prExercises.isEmpty {
                    showConfetti = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                        showConfetti = false
                    }
                }
                scheduleStagger()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    medalBounce = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    durationPulse = true
                    UIImpactFeedbackGenerator(style: .light).impactOccurred(intensity: 0.5)
                }
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
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
            showPRs = true
            for i in 0..<prDetails.count {
                DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.08) {
                    prRowsRevealed = i + 1
                }
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.32) { showDuration = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.42) { showStats = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.52) { showButton = true }
    }

    private var headerSection: some View {
        VStack(spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(AppColors.accentGold)
                Text("Workout complete")
                    .font(.system(.caption, weight: .semibold))
                    .foregroundStyle(.secondary)
            }

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
        HStack(spacing: 8) {
            Image(systemName: "star.fill")
                .font(.system(size: 22))
                .foregroundStyle(.yellow.opacity(0.9))
            Text(affirmation)
                .font(.system(.title2, weight: .semibold))
                .foregroundStyle(.primary)
        }
    }

    private var durationStat: some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: "clock.fill")
                    .font(.system(.title3, weight: .medium))
                    .foregroundStyle(AppColors.accent.opacity(0.9))
                Text(summary.formattedDuration)
                    .font(.system(size: 52, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                    .contentTransition(.numericText())
                    .scaleEffect(durationPulse ? 1 : 0.97)
                    .animation(.spring(response: 0.5, dampingFraction: 0.65), value: durationPulse)
            }
            Text("workout time")
                .font(.system(.subheadline, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(AppColors.accent.opacity(0.06))
        )
    }

    private var secondaryStats: some View {
        HStack(spacing: 20) {
            statItem(value: "\(summary.totalExercises)", label: "exercises", icon: "figure.strengthtraining.traditional")
            statItem(value: "\(summary.totalSets)", label: "sets", icon: "square.stack.3d.up")
            statItem(value: "\(summary.totalReps)", label: "reps", icon: "repeat")
            if summary.totalVolume > 0 {
                statItem(value: summary.formattedVolume, label: "volume", icon: "scalemass")
            }
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.white.opacity(0.07))
        )
    }

    private var prSection: some View {
        VStack(spacing: 16) {
            HStack(spacing: 10) {
                Image(systemName: "medal.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(hasPRs ? .yellow : .secondary.opacity(0.7))
                    .symbolEffect(.bounce, value: medalBounce)
                VStack(alignment: .leading, spacing: 2) {
                    Text(hasPRs ? "PRs achieved this workout" : "Personal Records")
                        .font(.system(.subheadline, weight: .bold))
                        .foregroundStyle(.primary)
                    if prDetails.count > 1 {
                        Text("\(prDetails.count) new records")
                            .font(.system(.caption2, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
            }

            if prDetails.isEmpty && prExercises.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "flame")
                        .font(.system(size: 14))
                        .foregroundStyle(AppColors.accent.opacity(0.8))
                    Text("No PRs this workout — keep pushing!")
                        .font(.system(.subheadline, weight: .medium))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            } else if prDetails.isEmpty {
                Text(prExercises.joined(separator: ", "))
                    .font(.system(.caption, weight: .medium))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            } else {
                VStack(spacing: 10) {
                    ForEach(Array(prDetails.enumerated()), id: \.element.name) { index, item in
                        HStack(spacing: 10) {
                            Text(item.name)
                                .font(.system(.subheadline, weight: .medium))
                                .foregroundStyle(.primary)
                            Spacer()
                            Text(formatPR(item))
                                .font(.system(.subheadline, weight: .bold))
                                .foregroundStyle(AppColors.accent)
                            Image(systemName: "sparkles")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.yellow)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.yellow.opacity(0.12))
                        )
                        .opacity(index < prRowsRevealed ? 1 : 0)
                        .offset(y: index < prRowsRevealed ? 0 : 8)
                        .animation(.spring(response: 0.4, dampingFraction: 0.75), value: prRowsRevealed)
                    }
                }
            }
        }
        .padding(.vertical, 20)
        .padding(.horizontal, 20)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(
                            hasPRs
                                ? LinearGradient(
                                    colors: [Color.yellow.opacity(0.15), AppColors.accent.opacity(0.08)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                                : LinearGradient(
                                    colors: [Color.white.opacity(0.06), Color.white.opacity(0.04)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(
                                    hasPRs ? Color.yellow.opacity(0.35) : Color.white.opacity(0.1),
                                    lineWidth: 1
                                )
                        )
        )
    }

    private func formatPR(_ item: (name: String, weight: Double, reps: Int)) -> String {
        if item.weight > 0 {
            return "\(UnitFormatter.formatWeight(item.weight, showUnit: false)) × \(item.reps)"
        }
        return "BW × \(item.reps)"
    }

    private func statItem(value: String, label: String, icon: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(.caption2, weight: .medium))
                .foregroundStyle(AppColors.accent.opacity(0.8))
            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
                .contentTransition(.numericText())
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
                    .fill(canDismiss ? AppColors.accent : Color.gray)
            )
        }
        .disabled(!canDismiss)
        .padding(.top, 8)
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
            .background(AppColors.background)
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
            statCard(title: "Max Weight", value: maxWeightEver > 0 ? String(format: "%.0f", UnitFormatter.convertToDisplay(maxWeightEver)) : "--", unit: UnitFormatter.weightUnit, icon: "arrow.up.circle.fill", color: AppColors.accent)
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
                    .fill(Color.white.opacity(0.06))
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
                .fill(Color.white.opacity(0.06))
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
                    .foregroundStyle(LinearGradient(colors: AppColors.accentGradient, startPoint: .leading, endPoint: .trailing))
                    .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round))
                AreaMark(x: .value("Date", point.date), y: .value("Weight", point.maxWeight))
                    .foregroundStyle(LinearGradient(colors: [AppColors.accent.opacity(0.2), AppColors.accent.opacity(0.02)], startPoint: .top, endPoint: .bottom))
                PointMark(x: .value("Date", point.date), y: .value("Weight", point.maxWeight))
                    .foregroundStyle(AppColors.accent)
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
                    .fill(Color.white.opacity(0.06))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppColors.accent.opacity(0.25), lineWidth: 1))
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
                .fill(Color.white.opacity(0.06))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.secondary.opacity(0.2), lineWidth: 1))
        )
        .onAppear { emptyChartAppeared = true }
    }
}