//
//  StatsDashboardView.swift
//  TheLogger
//
//  Stats tab — all gamification cards and achievements
//

import SwiftUI
import SwiftData

struct StatsDashboardView: View {
    @Query(sort: \Workout.date, order: .reverse) private var workouts: [Workout]
    @Query private var allPRs: [PersonalRecord]
    @Query private var unlockedAchievements: [Achievement]
    @AppStorage("weeklyWorkoutGoal") private var weeklyWorkoutGoal: Int = 4

    @State private var gamificationEngine = GamificationEngine()
    @State private var showingWeeklySummary = false
    @State private var showingAchievements = false
    @State private var showingWeeklyStatsDetail = false
    @State private var showingStreakDetail = false
    @State private var showingMuscleGroupDetail = false
    @State private var showingVolumeTrendDetail = false

    private var totalWorkouts: Int {
        workouts.filter { $0.isCompleted && !$0.isTemplate }.count
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
                        // Weekly Stats
                        WeeklyStatsCard(stats: gamificationEngine.weeklyStats, onTap: { showingWeeklyStatsDetail = true })
                            .staggeredAppear(index: 0, maxStagger: 6)

                        // Streak Calendar
                        StreakCalendarCard(streakData: gamificationEngine.streakData, onTap: { showingStreakDetail = true })
                            .staggeredAppear(index: 1, maxStagger: 6)

                        // Muscle Group Breakdown
                        MuscleGroupBreakdownCard(breakdown: gamificationEngine.weeklyStats.muscleBreakdown, onTap: { showingMuscleGroupDetail = true })
                            .staggeredAppear(index: 2, maxStagger: 6)

                        // Volume Trend
                        VolumeTrendCard(trend: gamificationEngine.volumeTrend, onTap: { showingVolumeTrendDetail = true })
                            .staggeredAppear(index: 3, maxStagger: 6)

                        // Weekly Recap
                        WeeklyRecapCard(
                            stats: gamificationEngine.weeklyStats,
                            prCount: gamificationEngine.thisWeekPRCount
                        ) {
                            showingWeeklySummary = true
                        }
                        .staggeredAppear(index: 4, maxStagger: 6)

                        // Achievements summary row
                        achievementsSummary
                            .staggeredAppear(index: 5, maxStagger: 6)
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
            .onChange(of: workouts.count) { _, _ in
                refreshGamification()
            }
        }
    }

    // MARK: - Achievements Summary

    private var achievementsSummary: some View {
        Button {
            showingAchievements = true
        } label: {
            HStack(spacing: 14) {
                // Unlocked count ring
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

                Text("View All")
                    .font(.system(.subheadline, weight: .medium))
                    .foregroundStyle(AppColors.accent)
                Image(systemName: "chevron.right")
                    .font(.system(.caption, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(16)
            .cardStyle(borderColor: AppColors.accentGold)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("achievementsSummaryButton")
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 20) {
            Spacer()
                .frame(height: 60)

            Image(systemName: "chart.bar")
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)

            Text("No stats yet")
                .font(.system(.title3, weight: .semibold))
                .foregroundStyle(.secondary)

            Text("Complete your first workout to see your stats, streaks, and achievements here.")
                .font(.system(.subheadline, weight: .regular))
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Helpers

    private func refreshGamification() {
        gamificationEngine.refresh(
            workouts: workouts,
            prs: allPRs,
            weeklyGoal: weeklyWorkoutGoal
        )
    }
}

#Preview {
    StatsDashboardView()
        .modelContainer(for: [Workout.self, Exercise.self, WorkoutSet.self, ExerciseMemory.self, PersonalRecord.self, Achievement.self], inMemory: true)
}
