//
//  AchievementsView.swift
//  TheLogger
//
//  Full achievements grid with category filter tabs
//

import SwiftUI
import SwiftData

struct AchievementsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(ProManager.self) private var proManager
    @Query private var unlockedAchievements: [Achievement]

    @State private var selectedCategory: AchievementCategory?
    @State private var achievementContext: AchievementContext?
    @State private var showUpgrade = false

    private var unlockedIds: Set<String> {
        Set(unlockedAchievements.map(\.id))
    }

    private var filteredDefinitions: [AchievementDefinition] {
        let defs = AchievementManager.definitions
        if let category = selectedCategory {
            return defs.filter { $0.category == category }
        }
        return defs
    }

    private var unlockedCount: Int {
        unlockedAchievements.count
    }

    private var totalCount: Int {
        AchievementManager.definitions.count
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Progress header
                    progressHeader

                    // Pro upgrade banner (free users)
                    if !proManager.isPro {
                        upgradeAchievementsBanner
                    }

                    // Category tabs
                    categoryTabs

                    // Achievement grid
                    if proManager.isPro {
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            ForEach(filteredDefinitions) { definition in
                                AchievementCard(
                                    definition: definition,
                                    isUnlocked: unlockedIds.contains(definition.id),
                                    progress: achievementContext.map { AchievementManager.progress(for: definition.id, context: $0) } ?? 0
                                )
                            }
                        }
                    } else {
                        // Free: show first 3 blurred, rest hidden
                        let teaser = Array(filteredDefinitions.prefix(3))
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            ForEach(teaser) { definition in
                                AchievementCard(
                                    definition: definition,
                                    isUnlocked: false,
                                    progress: 0
                                )
                                .blur(radius: 4)
                                .overlay(
                                    Image(systemName: "lock.fill")
                                        .font(.system(size: 22, weight: .semibold))
                                        .foregroundStyle(.white.opacity(0.8))
                                )
                                .allowsHitTesting(false)
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 40)
            }
            .background(AppColors.background)
            .navigationTitle("Achievements")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .task {
                loadContext()
            }
            .sheet(isPresented: $showUpgrade) {
                UpgradeView()
                    .environment(proManager)
            }
        }
        .presentationBackground(AppColors.background)
        .onAppear {
            Analytics.send(Analytics.Signal.achievementsViewed)
        }
    }

    // MARK: - Subviews

    private var upgradeAchievementsBanner: some View {
        Button {
            showUpgrade = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "crown.fill")
                    .foregroundStyle(AppColors.accentGold)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Unlock All Achievements")
                        .font(.system(.subheadline, weight: .semibold))
                        .foregroundStyle(.primary)
                    Text("Upgrade to Pro to track all \(totalCount) achievements")
                        .font(.system(.caption, weight: .regular))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(.caption, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(AppColors.accentGold.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(AppColors.accentGold.opacity(0.25), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("upgradeAchievementsBanner")
    }

    private var progressHeader: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .stroke(AppColors.accent.opacity(0.2), lineWidth: 8)
                Circle()
                    .trim(from: 0, to: totalCount > 0 ? Double(unlockedCount) / Double(totalCount) : 0)
                    .stroke(AppColors.accent, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 2) {
                    Text("\(unlockedCount)")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(AppColors.accent)
                    Text("of \(totalCount)")
                        .font(.system(.caption2, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 80, height: 80)

            Text("Achievements Unlocked")
                .font(.system(.subheadline, weight: .semibold))
                .foregroundStyle(.primary)
        }
        .padding(.vertical, 12)
    }

    private var categoryTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                categoryTab(label: "All", category: nil)
                ForEach(AchievementCategory.allCases) { category in
                    categoryTab(label: category.rawValue, category: category)
                }
            }
            .padding(.horizontal, 4)
        }
    }

    private func categoryTab(label: String, category: AchievementCategory?) -> some View {
        let isSelected = selectedCategory == category
        return Button {
            withAnimation(.easeOut(duration: 0.2)) {
                selectedCategory = category
            }
        } label: {
            Text(label)
                .font(.system(.caption, weight: .semibold))
                .foregroundStyle(isSelected ? .white : .secondary)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(isSelected ? AppColors.accent : Color.white.opacity(0.08))
                )
        }
        .buttonStyle(.plain)
    }

    private func loadContext() {
        let workoutDescriptor = FetchDescriptor<Workout>()
        let prDescriptor = FetchDescriptor<PersonalRecord>()

        guard let workouts = try? modelContext.fetch(workoutDescriptor),
              let prs = try? modelContext.fetch(prDescriptor) else { return }

        let engine = GamificationEngine()
        let weeklyGoal = UserDefaults.standard.integer(forKey: "weeklyWorkoutGoal")
        engine.refresh(workouts: workouts, prs: prs, weeklyGoal: max(weeklyGoal, 1))

        achievementContext = AchievementManager.buildContext(
            workouts: workouts, prs: prs, streakData: engine.streakData
        )
    }
}

// MARK: - Achievement Card

struct AchievementCard: View {
    let definition: AchievementDefinition
    let isUnlocked: Bool
    let progress: Double

    var body: some View {
        VStack(spacing: 10) {
            // Icon
            ZStack {
                Circle()
                    .fill(isUnlocked ? tierColor.opacity(0.2) : Color.white.opacity(0.05))
                    .frame(width: 48, height: 48)

                Image(systemName: definition.icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(isUnlocked ? tierColor : .secondary.opacity(0.4))
            }

            // Name
            Text(definition.name)
                .font(.system(.caption, weight: .bold))
                .foregroundStyle(isUnlocked ? .primary : .secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)

            // Description
            Text(definition.description)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .lineLimit(2)

            // Progress bar (only for locked)
            if !isUnlocked {
                ProgressView(value: progress)
                    .tint(tierColor.opacity(0.6))
                    .frame(width: 60)
            }

            // Tier badge
            Text(definition.tier.rawValue)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(isUnlocked ? tierColor : .secondary.opacity(0.5))
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(
                    Capsule()
                        .fill(isUnlocked ? tierColor.opacity(0.15) : Color.white.opacity(0.05))
                )
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isUnlocked ? tierColor.opacity(0.06) : Color.white.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isUnlocked ? tierColor.opacity(0.3) : Color.white.opacity(0.1), lineWidth: 1)
                )
        )
    }

    private var tierColor: Color {
        switch definition.tier {
        case .bronze: return Color(red: 0.8, green: 0.5, blue: 0.2)
        case .silver: return Color(red: 0.75, green: 0.75, blue: 0.8)
        case .gold: return AppColors.accentGold
        case .platinum: return Color(red: 0.9, green: 0.85, blue: 1.0)
        }
    }
}
