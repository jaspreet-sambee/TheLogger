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
    @AppStorage("userName") private var userName: String = ""
    @State private var showingNameEditor = false
    @State private var showUpgrade = false

    private var totalWorkouts: Int {
        workouts.filter { $0.isCompleted && !$0.isTemplate }.count
    }

    var body: some View {
        NavigationStack {
            List {
                // Profile header
                Section {
                    HStack(spacing: 14) {
                        LevelAvatar(
                            name: userName,
                            totalWorkouts: totalWorkouts,
                            size: 56
                        )

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

                // Pro status banner
                if proManager.isPro {
                    Section {
                        HStack(spacing: 12) {
                            Image(systemName: "crown.fill")
                                .foregroundStyle(AppColors.accentGold)
                            Text("Pro Member")
                                .font(.system(.body, weight: .semibold))
                                .foregroundStyle(.primary)
                            Spacer()
                            Button("Manage") {
                                if let url = URL(string: "itms-apps://apps.apple.com/account/subscriptions") {
                                    UIApplication.shared.open(url)
                                }
                            }
                            .font(.system(.caption, weight: .semibold))
                            .foregroundStyle(AppColors.accent)
                        }
                        .padding(.vertical, 4)
                    }
                    .listRowBackground(Color.white.opacity(0.06))
                } else {
                    Section {
                        Button { showUpgrade = true } label: {
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
                        RoundedRectangle(cornerRadius: 12)
                            .fill(AppColors.accentGold.opacity(0.08))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(AppColors.accentGold.opacity(0.2), lineWidth: 1)
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
                            Image(systemName: "gearshape.fill")
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Label("Preferences", systemImage: "slider.horizontal.3")
                        .font(.system(.caption, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .textCase(nil)
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
                                    .font(.system(.caption, weight: .regular))
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: "externaldrive.fill")
                                .foregroundStyle(AppColors.accentGold)
                        }
                    }
                } header: {
                    Label("Data", systemImage: "lock.shield")
                        .font(.system(.caption, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .textCase(nil)
                }
                .listRowBackground(Color.white.opacity(0.06))

                // About
                Section {
                    NavigationLink {
                        PrivacyPolicyView()
                    } label: {
                        Label("Privacy Policy", systemImage: "hand.raised")
                    }

                    HStack {
                        Text("Version")
                        Spacer()
                        Text(appVersion)
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Text("Build")
                        Spacer()
                        Text(buildNumber)
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Label("About", systemImage: "info.circle")
                        .font(.system(.caption, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .textCase(nil)
                } footer: {
                    VStack(spacing: 8) {
                        Text("TheLogger")
                            .font(.system(.caption, weight: .semibold))
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

#Preview {
    ProfileView()
        .modelContainer(for: [Workout.self, Exercise.self, WorkoutSet.self, ExerciseMemory.self, PersonalRecord.self, Achievement.self], inMemory: true)
}
