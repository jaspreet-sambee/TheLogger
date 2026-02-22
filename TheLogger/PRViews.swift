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
            HStack {
                Image(systemName: "medal.fill")
                    .font(.system(.subheadline, weight: .semibold))
                    .foregroundStyle(.yellow)

                Text("Recent PRs")
                    .font(.system(.title3, weight: .bold))
                    .foregroundStyle(.primary)

                Spacer()

                NavigationLink {
                    PRTimelineView()
                } label: {
                    HStack(spacing: 4) {
                        Text("All")
                            .font(.system(.subheadline, weight: .medium))
                            .foregroundStyle(AppColors.accent)
                    }
                }
                .fixedSize(horizontal: true, vertical: false)
            }
            .padding(.horizontal, 16)

            if recentPRs.isEmpty {
                // Empty state
                VStack(spacing: 12) {
                    Image(systemName: "medal")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary.opacity(0.5))

                    Text("No PRs Yet")
                        .font(.system(.headline, weight: .medium))
                        .foregroundStyle(.secondary)

                    Text("Complete your first workout to start tracking PRs!")
                        .font(.system(.subheadline))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
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
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.06))
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
        HStack(spacing: 12) {
            // Trophy icon
            Image(systemName: "medal.fill")
                .font(.system(.body))
                .foregroundStyle(.yellow)
                .frame(width: 24)

            // Exercise info
            VStack(alignment: .leading, spacing: 2) {
                Text(pr.displayName)
                    .font(.system(.subheadline, weight: .medium))
                    .foregroundStyle(.primary)

                HStack(spacing: 6) {
                    if pr.isBodyweight {
                        Text("BW × \(pr.reps)")
                            .font(.system(.caption, weight: .medium))
                            .foregroundStyle(.secondary)
                    } else {
                        Text(UnitFormatter.formatWeightCompact(pr.weight, showUnit: true))
                            .font(.system(.caption, weight: .medium))
                            .foregroundStyle(.secondary)

                        Text("×")
                            .font(.system(.caption))
                            .foregroundStyle(.tertiary)

                        Text("\(pr.reps)")
                            .font(.system(.caption, weight: .medium))
                            .foregroundStyle(.secondary)
                    }

                    Text("•")
                        .font(.system(.caption))
                        .foregroundStyle(.tertiary)

                    Text(pr.relativeTimeString)
                        .font(.system(.caption))
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()

            if pr.isStale {
                Image(systemName: "clock")
                    .font(.caption)
                    .foregroundStyle(AppColors.accent)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.systemGray6).opacity(0.3))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(.systemGray4).opacity(0.35), lineWidth: 1)
                )
        )
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
                    .fill(Color.yellow.opacity(0.2))
                    .frame(width: 48, height: 48)

                Image(systemName: "medal.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(.yellow)
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
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.06))
                .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(AppColors.accent.opacity(0.25), lineWidth: 1)
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
