//
//  StatsDashboardView.swift
//  TheLogger
//
//  Stats tab — all gamification cards and achievements
//

import SwiftUI
import SwiftData

enum StatsPeriod: String, CaseIterable {
    case thisWeek = "This Week"
    case lastWeek = "Last Week"
    case thisMonth = "This Month"
    case allTime = "All Time"
}

struct StatsDashboardView: View {
    @Query(sort: \Workout.date, order: .reverse) private var workouts: [Workout]
    @Query private var allPRs: [PersonalRecord]
    @Query private var unlockedAchievements: [Achievement]
    @AppStorage("weeklyWorkoutGoal") private var weeklyWorkoutGoal: Int = 4

    @State private var gamificationEngine = GamificationEngine()
    @State private var selectedPeriod: StatsPeriod = .thisWeek
    @State private var showingWeeklySummary = false
    @State private var showingAchievements = false
    @State private var showingWeeklyStatsDetail = false
    @State private var showingStreakDetail = false
    @State private var showingMuscleGroupDetail = false
    @State private var showingVolumeTrendDetail = false

    private var totalWorkouts: Int {
        workouts.filter { $0.isCompleted && !$0.isTemplate }.count
    }

    private var periodWorkouts: [Workout] {
        let completed = workouts.filter { $0.isCompleted && !$0.isTemplate }
        let cal = Calendar.current
        let now = Date()
        switch selectedPeriod {
        case .thisWeek:
            guard let interval = cal.dateInterval(of: .weekOfYear, for: now) else { return completed }
            return completed.filter { interval.contains($0.date) }
        case .lastWeek:
            guard let thisWeekStart = cal.dateInterval(of: .weekOfYear, for: now)?.start,
                  let lastWeekInterval = cal.dateInterval(of: .weekOfYear, for: thisWeekStart.addingTimeInterval(-1)) else { return completed }
            return completed.filter { lastWeekInterval.contains($0.date) }
        case .thisMonth:
            guard let interval = cal.dateInterval(of: .month, for: now) else { return completed }
            return completed.filter { interval.contains($0.date) }
        case .allTime:
            return completed
        }
    }

    private var unlockedCount: Int {
        unlockedAchievements.count
    }

    private var totalDefinitions: Int {
        AchievementManager.definitions.count
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                if totalWorkouts == 0 {
                    emptyState
                } else {
                    VStack(spacing: 16) {
                        // Period selector
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(StatsPeriod.allCases, id: \.self) { period in
                                    let isActive = selectedPeriod == period
                                    Button {
                                        withAnimation(.easeOut(duration: 0.2)) {
                                            selectedPeriod = period
                                        }
                                        refreshGamification()
                                        Analytics.send(Analytics.Signal.statsPeriodChanged, parameters: ["period": period.rawValue])
                                    } label: {
                                        Text(period.rawValue)
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundStyle(isActive ? .white : Color.white.opacity(0.50))
                                            .padding(.horizontal, 14)
                                            .padding(.vertical, 8)
                                            .background(
                                                Capsule()
                                                    .fill(isActive ? AppColors.accent : Color.white.opacity(0.07))
                                                    .overlay(
                                                        Capsule()
                                                            .stroke(isActive ? Color.clear : Color.white.opacity(0.10), lineWidth: 1)
                                                    )
                                            )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, 4)
                        }
                        .staggeredAppear(index: 0, maxStagger: 7)

                        // Weekly Stats
                        WeeklyStatsCard(stats: gamificationEngine.weeklyStats, onTap: { showingWeeklyStatsDetail = true })
                            .staggeredAppear(index: 1, maxStagger: 7)

                        // Achievements (featured, right after weekly stats)
                        achievementsSummary
                            .staggeredAppear(index: 2, maxStagger: 7)

                        // Streak Calendar
                        StreakCalendarCard(streakData: gamificationEngine.streakData, onTap: { showingStreakDetail = true })
                            .staggeredAppear(index: 3, maxStagger: 7)

                        // Muscle Group Breakdown
                        MuscleGroupBreakdownCard(breakdown: gamificationEngine.weeklyStats.muscleBreakdown, onTap: { showingMuscleGroupDetail = true })
                            .staggeredAppear(index: 4, maxStagger: 7)

                        // Volume Trend
                        VolumeTrendCard(trend: gamificationEngine.volumeTrend, onTap: { showingVolumeTrendDetail = true })
                            .staggeredAppear(index: 5, maxStagger: 7)

                        // Weekly Recap
                        WeeklyRecapCard(
                            stats: gamificationEngine.weeklyStats,
                            prCount: gamificationEngine.thisWeekPRCount
                        ) {
                            showingWeeklySummary = true
                        }
                        .staggeredAppear(index: 6, maxStagger: 7)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 32)
                }
            }
            .scrollContentBackground(.hidden)
            .background {
                ZStack {
                    AppColors.background
                    FloatingParticlesView()
                }
                .ignoresSafeArea()
            }
            .navigationTitle("Stats")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showingWeeklySummary) {
                WeeklySummaryView(
                    stats: gamificationEngine.weeklyStats,
                    streakData: gamificationEngine.streakData,
                    volumeTrend: gamificationEngine.volumeTrend,
                    prCount: gamificationEngine.thisWeekPRCount,
                    weeklyGoal: weeklyWorkoutGoal
                )
            }
            .sheet(isPresented: $showingAchievements) {
                AchievementsView()
            }
            .sheet(isPresented: $showingWeeklyStatsDetail) {
                WeeklyStatsDetailSheet(stats: gamificationEngine.weeklyStats)
            }
            .sheet(isPresented: $showingStreakDetail) {
                StreakDetailSheet(streakData: gamificationEngine.streakData)
            }
            .sheet(isPresented: $showingMuscleGroupDetail) {
                MuscleGroupDetailSheet(breakdown: gamificationEngine.weeklyStats.muscleBreakdown)
            }
            .sheet(isPresented: $showingVolumeTrendDetail) {
                VolumeTrendDetailSheet(trend: gamificationEngine.volumeTrend)
            }
            .task {
                refreshGamification()
            }
            .onAppear {
                refreshGamification()
                Analytics.send(Analytics.Signal.statsDashboardViewed)
            }
            .onChange(of: workouts.count) { _, _ in
                refreshGamification()
            }
            .onChange(of: selectedPeriod) { _, _ in
                refreshGamification()
            }
        }
    }

    // MARK: - Achievements Summary

    private var achievementsSummary: some View {
        let unlockedIds = Set(unlockedAchievements.map(\.id))
        let defs = AchievementManager.definitions

        return Button {
            showingAchievements = true
        } label: {
            VStack(alignment: .leading, spacing: 14) {
                // Header row: ring + title + chevron
                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .stroke(AppColors.accentGold.opacity(0.2), lineWidth: 4)
                        Circle()
                            .trim(from: 0, to: totalDefinitions > 0 ? Double(unlockedCount) / Double(totalDefinitions) : 0)
                            .stroke(AppColors.accentGold, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                        Image(systemName: "trophy.fill")
                            .font(.system(.caption, weight: .semibold))
                            .foregroundStyle(AppColors.accentGold)
                    }
                    .frame(width: 40, height: 40)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Achievements")
                            .font(.system(.body, weight: .semibold))
                            .foregroundStyle(.primary)
                        Text("\(unlockedCount) of \(totalDefinitions) unlocked")
                            .font(.system(.caption, weight: .medium))
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(.caption, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }

                // Badge tiles — pick one from each category for variety
                let tileDefs = pickRepresentativeTiles(from: defs, unlocked: unlockedIds)
                HStack(spacing: 8) {
                    ForEach(tileDefs) { def in
                        let isUnlocked = unlockedIds.contains(def.id)
                        VStack(spacing: 4) {
                            Image(systemName: def.icon)
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(isUnlocked ? categoryColor(def.category) : Color.white.opacity(0.25))
                            Text(def.name)
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(isUnlocked ? Color.white.opacity(0.8) : Color.white.opacity(0.25))
                                .lineLimit(1)
                            Text(isUnlocked ? "Unlocked" : "Locked")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(isUnlocked ? Color.green : Color.white.opacity(0.18))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 1)
                                .background(
                                    Capsule().fill(isUnlocked ? Color.green.opacity(0.15) : Color.white.opacity(0.06))
                                )
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(isUnlocked ? AppColors.accentGold.opacity(0.10) : Color.white.opacity(0.05))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(isUnlocked ? AppColors.accentGold.opacity(0.30) : Color.white.opacity(0.10), lineWidth: 1)
                                )
                        )
                    }
                }
            }
            .padding(16)
            .tintedCardStyle(tint: AppColors.accentGold, secondaryTint: Color(red: 1.0, green: 0.6, blue: 0.2))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("achievementsSummaryButton")
    }

    /// Pick one achievement per category (prefer unlocked, then closest to unlock)
    private func pickRepresentativeTiles(from defs: [AchievementDefinition], unlocked: Set<String>) -> [AchievementDefinition] {
        var result: [AchievementDefinition] = []
        for cat in AchievementCategory.allCases {
            let catDefs = defs.filter { $0.category == cat }
            // Prefer first unlocked; fallback to first in category
            if let first = catDefs.first(where: { unlocked.contains($0.id) }) ?? catDefs.first {
                result.append(first)
            }
            if result.count >= 4 { break }
        }
        return result
    }

    private func categoryColor(_ cat: AchievementCategory) -> Color {
        switch cat {
        case .consistency: return AppColors.accent
        case .strength: return AppColors.accentGold
        case .volume: return AppColors.accentBlue
        case .variety: return AppColors.accentTeal
        case .dedication: return Color.purple
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            // Header
            VStack(spacing: 8) {
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(AppColors.accent.opacity(0.4))
                Text("Your Stats Dashboard")
                    .font(.system(size: 20, weight: .bold))
                Text("Complete your first workout to unlock these insights:")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.white.opacity(0.35))
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 24)

            // Preview cards (greyed out)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                statsPreviewCard(icon: "⚖️", title: "Weekly Stats", desc: "Volume, sets, reps")
                statsPreviewCard(icon: "🔥", title: "Streak Calendar", desc: "Training consistency")
                statsPreviewCard(icon: "💪", title: "Muscle Groups", desc: "Balance breakdown")
                statsPreviewCard(icon: "📈", title: "Volume Trend", desc: "Progress over time")
            }
            .padding(.horizontal, 16)

            // CTA
            Button {
                // Switch to Home tab
                NotificationCenter.default.post(name: Notification.Name("switchToHomeTab"), object: nil)
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 12))
                    Text("Start Your First Workout")
                        .font(.system(size: 15, weight: .bold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(AppColors.accent)
                )
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 16)
            .padding(.top, 8)

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private func statsPreviewCard(icon: String, title: String, desc: String) -> some View {
        VStack(spacing: 8) {
            Text(icon)
                .font(.system(size: 22))
                .opacity(0.4)
            Text(title)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Color.white.opacity(0.30))
            Text(desc)
                .font(.system(size: 10))
                .foregroundStyle(Color.white.opacity(0.15))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.white.opacity(0.03))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.06), lineWidth: 1))
        )
    }

    // MARK: - Helpers

    private var allCompletedWorkouts: [Workout] {
        workouts.filter { $0.isCompleted && !$0.isTemplate }
    }

    private func refreshGamification() {
        // Streak, volume trend, and heatmap need ALL workouts — not period-filtered.
        // Weekly stats are computed internally by GamificationEngine using calendar intervals.
        gamificationEngine.refresh(
            workouts: allCompletedWorkouts,
            prs: allPRs,
            weeklyGoal: weeklyWorkoutGoal
        )
    }
}

#Preview {
    StatsDashboardView()
        .modelContainer(for: [Workout.self, Exercise.self, WorkoutSet.self, ExerciseMemory.self, PersonalRecord.self, Achievement.self], inMemory: true)
}
