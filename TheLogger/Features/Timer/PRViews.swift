//
//  PRViews.swift
//  TheLogger
//
//  PR Timeline and related views
//

import SwiftUI
import SwiftData

// MARK: - PR Home Widget

struct PRHomeWidgetView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var recentPRs: [PREntry] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 5) {
                        Text("🏆")
                            .font(.system(size: 14))
                        Text("Personal Records")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(AppColors.accentGold.opacity(0.9))
                    }
                    if !recentPRs.isEmpty {
                        Text("\(recentPRs.count) PR\(recentPRs.count == 1 ? "" : "s") tracked")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Color.white.opacity(0.30))
                    }
                }

                Spacer()

                NavigationLink {
                    PRTimelineView()
                } label: {
                    Text("All →")
                        .font(.system(.caption, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.28))
                }
                .fixedSize(horizontal: true, vertical: false)
                .padding(.top, 2)
            }
            .padding(.horizontal, 16)

            if recentPRs.isEmpty {
                // Empty state
                HStack(spacing: 10) {
                    Image(systemName: "trophy")
                        .font(.system(.body))
                        .foregroundStyle(AppColors.accentGold.opacity(0.4))
                    Text("Complete a workout to start tracking PRs")
                        .font(.system(.caption, weight: .regular))
                        .foregroundStyle(Color.white.opacity(0.30))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.bottom, 4)
            } else {
                VStack(spacing: 8) {
                    ForEach(recentPRs.prefix(3)) { pr in
                        PRCompactCard(pr: pr)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
        .padding(.vertical, 16)
        .background(
            ZStack(alignment: .topTrailing) {
                RoundedRectangle(cornerRadius: 18)
                    .fill(AppColors.accentGold.opacity(0.05))
                Circle()
                    .fill(AppColors.accentGold.opacity(0.12))
                    .frame(width: 120, height: 120)
                    .blur(radius: 30)
                    .offset(x: 10, y: -30)
                RoundedRectangle(cornerRadius: 18)
                    .stroke(AppColors.accentGold.opacity(0.14), lineWidth: 1)
            }
        )
        .onAppear {
            loadRecentPRs()
        }
        .onReceive(NotificationCenter.default.publisher(for: .workoutEnded)) { _ in
            loadRecentPRs()
        }
    }

    private func loadRecentPRs() {
        recentPRs = PRManager.shared.getPRTimeline(modelContext: modelContext)
    }
}

// MARK: - PR Compact Card (for home widget)

struct PRCompactCard: View {
    let pr: PREntry

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            // Left: exercise name + date
            VStack(alignment: .leading, spacing: 3) {
                Text(pr.displayName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.85))
                    .lineLimit(1)

                Text(pr.relativeTimeString)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.28))
            }

            Spacer()

            // Right: weight in gold + reps below
            VStack(alignment: .trailing, spacing: 3) {
                if pr.isBodyweight {
                    Text("BW")
                        .font(.system(size: 15, weight: .heavy))
                        .foregroundStyle(AppColors.accentGold.opacity(0.9))
                } else {
                    Text(UnitFormatter.formatWeightCompact(pr.weight, showUnit: true))
                        .font(.system(size: 15, weight: .heavy))
                        .foregroundStyle(AppColors.accentGold.opacity(0.9))
                }

                Text("× \(pr.reps)")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(AppColors.accentGold.opacity(0.55))
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - PR Timeline View

struct PRTimelineView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var allPRs: [PREntry] = []
    @State private var selectedFilter: PRFilter = .all
    @State private var selectedSort: PRSort = .recent
    @State private var showingFilterMenu = false
    @State private var showingSortMenu = false

    private var filteredAndSortedPRs: [PREntry] {
        let filtered = selectedFilter.filter(allPRs)
        return selectedSort.sort(filtered)
    }

    var body: some View {
        ZStack {
            AppColors.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 16) {
                    // Filter and sort controls
                    HStack(spacing: 12) {
                        // Filter menu
                        Menu {
                            ForEach(PRFilter.allCases) { filter in
                                Button {
                                    selectedFilter = filter
                                } label: {
                                    HStack {
                                        Text(filter.rawValue)
                                        if selectedFilter == filter {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Text("Filter: \(selectedFilter.rawValue)")
                                    .font(.system(.subheadline, weight: .medium))
                                Image(systemName: "chevron.down")
                                    .font(.caption2)
                            }
                            .foregroundStyle(AppColors.accent)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(AppColors.accent.opacity(0.15))
                            )
                        }

                        // Sort menu
                        Menu {
                            ForEach(PRSort.allCases) { sort in
                                Button {
                                    selectedSort = sort
                                } label: {
                                    HStack {
                                        Text(sort.rawValue)
                                        if selectedSort == sort {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Text("Sort: \(selectedSort.rawValue)")
                                    .font(.system(.subheadline, weight: .medium))
                                Image(systemName: "chevron.down")
                                    .font(.caption2)
                            }
                            .foregroundStyle(AppColors.accent)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(AppColors.accent.opacity(0.15))
                            )
                        }

                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                    // PR list
                    if filteredAndSortedPRs.isEmpty {
                        emptyState
                    } else {
                        LazyVStack(spacing: 12) {
                            ForEach(Array(filteredAndSortedPRs.enumerated()), id: \.element.id) { index, pr in
                                NavigationLink {
                                    ExerciseDetailView(exerciseName: pr.displayName)
                                } label: {
                                    PRCard(pr: pr)
                                }
                                .buttonStyle(.plain)
                                .staggeredAppear(index: index, maxStagger: 6)
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                }
                .padding(.bottom, 16)
            }
        }
        .navigationTitle("Personal Records")
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            loadPRs()
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "medal")
                .font(.system(size: 64))
                .foregroundStyle(.secondary.opacity(0.5))

            Text("No PRs Found")
                .font(.system(.title2, weight: .semibold))
                .foregroundStyle(.primary)

            Text("Try changing your filter or complete more workouts")
                .font(.system(.subheadline))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxHeight: .infinity)
        .padding(.top, 80)
    }

    private func loadPRs() {
        allPRs = PRManager.shared.getPRTimeline(modelContext: modelContext)
    }
}

// MARK: - PR Card (for timeline)

struct PRCard: View {
    let pr: PREntry

    var body: some View {
        HStack(spacing: 16) {
            // Trophy icon
            ZStack {
                Circle()
                    .fill(AppColors.accentGold.opacity(0.15))
                    .frame(width: 48, height: 48)

                Image(systemName: "medal.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(AppColors.accentGold)
            }

            // Content
            VStack(alignment: .leading, spacing: 6) {
                Text(pr.displayName)
                    .font(.system(.headline, weight: .semibold))
                    .foregroundStyle(.primary)

                HStack(spacing: 8) {
                    // Weight × Reps (or BW × Reps for bodyweight)
                    if pr.isBodyweight {
                        Text("BW × \(pr.reps)")
                            .font(.system(.subheadline, weight: .medium))
                            .foregroundStyle(.secondary)
                    } else {
                        HStack(spacing: 4) {
                            Text(UnitFormatter.formatWeightCompact(pr.weight, showUnit: true))
                                .font(.system(.subheadline, weight: .medium))
                            Text("×")
                                .font(.system(.subheadline))
                                .foregroundStyle(.tertiary)
                            Text("\(pr.reps)")
                                .font(.system(.subheadline, weight: .medium))
                        }
                        .foregroundStyle(.secondary)

                        Divider()
                            .frame(height: 12)

                        Text("1RM: \(UnitFormatter.formatWeightCompact(pr.estimated1RM, showUnit: true))")
                            .font(.system(.caption, weight: .medium))
                            .foregroundStyle(.tertiary)
                    }
                }

                // Date
                HStack(spacing: 6) {
                    Text(pr.date, style: .date)
                        .font(.system(.caption))
                        .foregroundStyle(.tertiary)

                    Text("•")
                        .font(.system(.caption))
                        .foregroundStyle(.tertiary)

                    Text(pr.relativeTimeString)
                        .font(.system(.caption))
                        .foregroundStyle(pr.isStale ? AppColors.accent : .secondary)

                    if pr.isStale {
                        Image(systemName: "clock")
                            .font(.caption2)
                            .foregroundStyle(AppColors.accent)
                    }
                }
            }

            Spacer()

            // Chevron
            Image(systemName: "chevron.right")
                .font(.system(.subheadline, weight: .semibold))
                .foregroundStyle(.secondary.opacity(0.5))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(AppColors.accentGold.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(AppColors.accentGold.opacity(0.18), lineWidth: 1)
        )
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        WorkoutListViewPreview()
    }
}

private struct WorkoutListViewPreview: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                PRHomeWidgetView()
                    .padding(.horizontal, 16)
            }
        }
        .background(AppColors.background)
    }
}
