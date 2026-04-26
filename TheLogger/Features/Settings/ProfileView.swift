//
//  ProfileView.swift
//  TheLogger
//
//  Profile tab — user info, settings, data & backup, about
//

import SwiftUI
import SwiftData

struct ProfileView: View {
    @Environment(ProManager.self) private var proManager
    @Query(sort: \Workout.date, order: .reverse) private var workouts: [Workout]
    @Query private var allPRs: [PersonalRecord]
    @AppStorage("userName") private var userName: String = ""
    @AppStorage("weeklyWorkoutGoal") private var weeklyWorkoutGoal: Int = 4
    @State private var showingNameEditor = false
    @State private var showUpgrade = false
    @State private var gamification = GamificationEngine()

    private var completedWorkouts: [Workout] {
        workouts.filter { $0.isCompleted && !$0.isTemplate }
    }

    private var totalWorkouts: Int { completedWorkouts.count }

    private var totalPRs: Int { allPRs.count }

    private var memberSince: String? {
        guard let earliest = completedWorkouts.last else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM yyyy"
        return formatter.string(from: earliest.date)
    }

    var body: some View {
        NavigationStack {
            List {
                // Profile header
                Section {
                    HStack(spacing: 14) {
                        ZStack {
                            Circle()
                                .strokeBorder(
                                    LinearGradient(
                                        colors: AppColors.accentGradient,
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 3
                                )
                                .frame(width: 72, height: 72)
                            LevelAvatar(
                                name: userName,
                                totalWorkouts: totalWorkouts,
                                size: 64
                            )
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            if userName.isEmpty {
                                Text("Welcome!")
                                    .font(.system(.title3, weight: .bold))
                                    .foregroundStyle(.primary)
                            } else {
                                Text(userName)
                                    .font(.system(.title3, weight: .bold))
                                    .foregroundStyle(.primary)
                            }

                            LevelBadge(totalWorkouts: totalWorkouts)
                        }

                        Spacer()

                        Button {
                            showingNameEditor = true
                        } label: {
                            Image(systemName: userName.isEmpty ? "person.crop.circle.badge.plus" : "pencil")
                                .font(.system(.body, weight: .medium))
                                .foregroundStyle(AppColors.accent)
                                .padding(8)
                                .background(
                                    Circle()
                                        .fill(Color.white.opacity(0.08))
                                )
                        }
                        .buttonStyle(.borderless)
                    }
                    .padding(.vertical, 8)
                }
                .listRowBackground(Color.white.opacity(0.06))

                // Quick stats strip
                Section {
                    HStack(spacing: 0) {
                        ProfileStatItem(
                            value: "\(totalWorkouts)",
                            label: "Workouts",
                            icon: "figure.strengthtraining.traditional",
                            color: AppColors.accent
                        )
                        Divider()
                            .frame(height: 32)
                            .overlay(Color.white.opacity(0.06))
                        ProfileStatItem(
                            value: "\(gamification.streakData.current)",
                            label: "Streak",
                            icon: "flame.fill",
                            color: Color(red: 1.0, green: 0.45, blue: 0.25)
                        )
                        Divider()
                            .frame(height: 32)
                            .overlay(Color.white.opacity(0.06))
                        ProfileStatItem(
                            value: "\(totalPRs)",
                            label: "PRs",
                            icon: "trophy.fill",
                            color: AppColors.accentGold
                        )
                    }
                    .padding(.vertical, 6)
                }
                .listRowBackground(
                    RoundedRectangle(cornerRadius: 18)
                        .fill(
                            LinearGradient(
                                colors: [AppColors.accent.opacity(0.06), Color.white.opacity(0.04)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 18)
                                .stroke(AppColors.accent.opacity(0.12), lineWidth: 1)
                        )
                )

                // Pro status banner
                if proManager.isPro {
                    Section {
                        HStack(spacing: 12) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 7)
                                    .fill(AppColors.accentGold.opacity(0.85))
                                    .frame(width: 30, height: 30)
                                Image(systemName: "crown.fill")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(.white)
                            }
                            Text("Pro Member")
                                .font(.system(.body, weight: .semibold))
                                .foregroundStyle(.primary)
                            Spacer()
                            Button("Manage") {
                                // Try App Store subscriptions, fall back to Settings
                                if let url = URL(string: "itms-apps://apps.apple.com/account/subscriptions"),
                                   UIApplication.shared.canOpenURL(url) {
                                    UIApplication.shared.open(url)
                                } else if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                                    UIApplication.shared.open(settingsURL)
                                }
                            }
                            .font(.system(.caption, weight: .semibold))
                            .foregroundStyle(AppColors.accent)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(AppColors.accent.opacity(0.12), in: Capsule())
                        }
                        .padding(.vertical, 4)
                    }
                    .listRowBackground(
                        RoundedRectangle(cornerRadius: 18)
                            .fill(AppColors.accentGold.opacity(0.06))
                            .overlay(
                                RoundedRectangle(cornerRadius: 18)
                                    .stroke(AppColors.accentGold.opacity(0.18), lineWidth: 1)
                            )
                    )
                } else {
                    Section {
                        Button {
                            showUpgrade = true
                            Analytics.send(Analytics.Signal.upgradePromptTapped)
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "crown.fill")
                                    .foregroundStyle(AppColors.accentGold)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Upgrade to Pro")
                                        .font(.system(.body, weight: .semibold))
                                        .foregroundStyle(.primary)
                                    Text("Unlimited camera, share cards, achievements & export")
                                        .font(.system(.caption, weight: .regular))
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(.caption, weight: .semibold))
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(.vertical, 4)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("upgradeProBanner")
                    }
                    .listRowBackground(
                        RoundedRectangle(cornerRadius: 18)
                            .fill(
                                LinearGradient(
                                    colors: [AppColors.accentGold.opacity(0.12), AppColors.accentGold.opacity(0.06)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 18)
                                    .stroke(AppColors.accentGold.opacity(0.25), lineWidth: 1)
                            )
                    )
                }

                // Settings
                Section {
                    NavigationLink {
                        SettingsView()
                    } label: {
                        Label {
                            Text("Settings")
                                .font(.system(.body, weight: .medium))
                        } icon: {
                            ZStack {
                                RoundedRectangle(cornerRadius: 7)
                                    .fill(AppColors.accent.opacity(0.85))
                                    .frame(width: 30, height: 30)
                                Image(systemName: "gearshape.fill")
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundStyle(.white)
                            }
                        }
                    }
                } header: {
                    Text("Preferences")
                        .font(.system(.caption2, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.28))
                        .textCase(.uppercase)
                }
                .listRowBackground(Color.white.opacity(0.06))

                // Data & Backup
                Section {
                    NavigationLink {
                        DataBackupView()
                    } label: {
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Data & Backup")
                                    .font(.system(.body, weight: .medium))
                                Text("Export, import, and manage your data")
                                    .font(.system(.caption2, weight: .regular))
                                    .foregroundStyle(Color.white.opacity(0.4))
                            }
                        } icon: {
                            ZStack {
                                RoundedRectangle(cornerRadius: 7)
                                    .fill(AppColors.accentGold.opacity(0.85))
                                    .frame(width: 30, height: 30)
                                Image(systemName: "externaldrive.fill")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(.white)
                            }
                        }
                    }
                } header: {
                    Text("Data")
                        .font(.system(.caption2, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.28))
                        .textCase(.uppercase)
                }
                .listRowBackground(Color.white.opacity(0.06))

                // About
                Section {
                    NavigationLink {
                        PrivacyPolicyView()
                    } label: {
                        Label {
                            Text("Privacy Policy")
                                .font(.system(.body, weight: .medium))
                        } icon: {
                            ZStack {
                                RoundedRectangle(cornerRadius: 7)
                                    .fill(AppColors.accentBlue.opacity(0.85))
                                    .frame(width: 30, height: 30)
                                Image(systemName: "hand.raised.fill")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(.white)
                            }
                        }
                    }

                    HStack {
                        Text("Version")
                            .font(.system(.body, weight: .medium))
                        Spacer()
                        Text(appVersion)
                            .foregroundStyle(Color.white.opacity(0.4))
                    }

                    HStack {
                        Text("Build")
                            .font(.system(.body, weight: .medium))
                        Spacer()
                        Text(buildNumber)
                            .foregroundStyle(Color.white.opacity(0.4))
                    }
                } header: {
                    Text("About")
                        .font(.system(.caption2, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.28))
                        .textCase(.uppercase)
                } footer: {
                    VStack(spacing: 8) {
                        Text("TheLogger")
                            .font(.system(.caption, weight: .semibold))
                        if let since = memberSince {
                            Text("Member since \(since)")
                                .font(.caption2)
                        }
                        Text("Built with love for lifters who value simplicity and privacy.")
                            .font(.caption2)
                            .multilineTextAlignment(.center)
                    }
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 16)
                }
                .listRowBackground(Color.white.opacity(0.06))

                #if DEBUG
                Section {
                    NavigationLink {
                        DebugSettingsView()
                    } label: {
                        Label("Debug Tools", systemImage: "hammer")
                    }
                } header: {
                    Label("Debug", systemImage: "hammer")
                        .font(.system(.caption, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .textCase(nil)
                }
                .listRowBackground(Color.white.opacity(0.06))
                #endif
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(AppColors.background)
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                gamification.refresh(workouts: workouts, prs: allPRs, weeklyGoal: weeklyWorkoutGoal)
                Analytics.send(Analytics.Signal.profileViewed)
            }
            .sheet(isPresented: $showUpgrade) {
                UpgradeView()
                    .environment(proManager)
            }
            .alert("Your Name", isPresented: $showingNameEditor) {
                TextField("Enter your name", text: $userName)
                Button("Save") {
                    UserDefaults.standard.set(userName, forKey: "userName")
                }
                Button("Cancel", role: .cancel) {
                    userName = UserDefaults.standard.string(forKey: "userName") ?? ""
                }
            } message: {
                Text("We'll use this to personalize your experience")
            }
        }
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }
}

// MARK: - Debug Settings (DEBUG only)

#if DEBUG
private struct DebugSettingsView: View {
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        List {
            Section {
                Button {
                    DebugHelpers.populateSampleData(modelContext: modelContext)
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                } label: {
                    Label("Populate Sample Data", systemImage: "cylinder.fill")
                        .foregroundStyle(AppColors.accent)
                }
            } footer: {
                Text("Populate sample data will add 8 workouts and 6 exercise memories.")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .listRowBackground(Color.white.opacity(0.06))
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(AppColors.background)
        .navigationTitle("Debug Tools")
        .navigationBarTitleDisplayMode(.inline)
    }
}
#endif

// MARK: - Profile Stat Item

private struct ProfileStatItem: View {
    let value: String
    let label: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(color)
            Text(value)
                .font(.system(.title3, weight: .bold))
                .foregroundStyle(.primary)
                .monospacedDigit()
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    ProfileView()
        .modelContainer(for: [Workout.self, Exercise.self, WorkoutSet.self, ExerciseMemory.self, PersonalRecord.self, Achievement.self], inMemory: true)
}
