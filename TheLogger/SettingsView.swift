//
//  SettingsView.swift
//  TheLogger
//
//  Settings screen for app preferences
//

import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    // User preferences
    @AppStorage("unitSystem") private var unitSystem: String = "Imperial"
    @AppStorage("defaultRestSeconds") private var defaultRestSeconds: Int = 90
    @AppStorage("autoStartRestTimer") private var autoStartRestTimer: Bool = false
    @AppStorage("globalRestTimerEnabled") private var globalRestTimerEnabled: Bool = false
    @AppStorage("userName") private var userName: String = ""
    @AppStorage("weeklyWorkoutGoal") private var weeklyWorkoutGoal: Int = 4
    @AppStorage("autoPopulateSetsFromHistory") private var autoPopulateSets: Bool = true
    
    // Local state for picker
    @State private var selectedUnit: UnitSystem = .imperial
    
    var body: some View {
        NavigationStack {
            List {
                // Units Section
                Section {
                    Picker("Weight Unit", selection: $selectedUnit) {
                        ForEach(UnitSystem.allCases) { unit in
                            Text(unit.rawValue).tag(unit)
                        }
                    }
                    .onChange(of: selectedUnit) { _, newValue in
                        unitSystem = newValue.rawValue
                    }
                    
                    HStack {
                        Text("Display")
                        Spacer()
                        Text(selectedUnit.weightUnitFull)
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Label("Units", systemImage: "scalemass")
                        .font(.system(.caption, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .textCase(nil)
                } footer: {
                    Text("All weights are stored internally and can be switched anytime without data loss.")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .listRowBackground(Color.white.opacity(0.06))
                
                // Rest Timer Section
                Section {
                    Toggle(isOn: $globalRestTimerEnabled) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Enable Rest Timer")
                                .font(.system(.body, weight: .medium))
                            Text("Shows rest timer after logging sets")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if globalRestTimerEnabled {
                        Stepper(value: $defaultRestSeconds, in: 30...300, step: 15) {
                            HStack {
                                Text("Default Rest")
                                Spacer()
                                Text(formatSeconds(defaultRestSeconds))
                                    .foregroundStyle(.secondary)
                                    .monospacedDigit()
                            }
                        }

                        Toggle(isOn: $autoStartRestTimer) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Auto-start Timer")
                                    .font(.system(.body, weight: .medium))
                                Text("Starts immediately after logging set")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                } header: {
                    Label("Rest Timer", systemImage: "timer")
                        .font(.system(.caption, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .textCase(nil)
                } footer: {
                    Text("Global default for rest timer. You can override for specific exercises in the exercise detail view.")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .listRowBackground(Color.white.opacity(0.06))

                // Goals Section
                Section {
                    Stepper(value: $weeklyWorkoutGoal, in: 1...7, step: 1) {
                        HStack {
                            Text("Weekly Goal")
                            Spacer()
                            Text("\(weeklyWorkoutGoal) workouts")
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Label("Goals", systemImage: "target")
                        .font(.system(.caption, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .textCase(nil)
                } footer: {
                    Text("Set your target number of workouts per week. Shown on the home screen.")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .listRowBackground(Color.white.opacity(0.06))

                // Workout Section
                Section {
                    Toggle(isOn: $autoPopulateSets) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Auto-populate Sets")
                                .font(.system(.body, weight: .medium))
                            Text("Pre-fills sets and values from your last workout for this exercise")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Label("Workout", systemImage: "dumbbell")
                        .font(.system(.caption, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .textCase(nil)
                }
                .listRowBackground(Color.white.opacity(0.06))

                // Personal Records Section
                Section {
                    HStack(spacing: 12) {
                        Image(systemName: "medal.fill")
                            .font(.system(.body, weight: .medium))
                            .foregroundStyle(AppColors.accentGold)
                            .frame(width: 24)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Epley Formula")
                                .font(.system(.body, weight: .medium))
                            Text("weight × (1 + reps ÷ 30)")
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                } header: {
                    Label("Personal Records", systemImage: "medal")
                        .font(.system(.caption, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .textCase(nil)
                } footer: {
                    Text("PRs are ranked by estimated one-rep max (1RM) using the Epley formula. This works across all rep ranges — the same formula used by Hevy. Bodyweight exercises are ranked by reps instead.")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .listRowBackground(Color.white.opacity(0.06))

                // Profile Section
                Section {
                    HStack {
                        Text("Name")
                        Spacer()
                        TextField("Your name", text: $userName)
                            .multilineTextAlignment(.trailing)
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Label("Profile", systemImage: "person")
                        .font(.system(.caption, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .textCase(nil)
                }
                .listRowBackground(Color.white.opacity(0.06))
                
                // Data Section
                Section {
                    NavigationLink {
                        PrivacyPolicyView()
                    } label: {
                        Label("Privacy Policy", systemImage: "hand.raised")
                    }
                } header: {
                    Label("Data & Privacy", systemImage: "lock.shield")
                        .font(.system(.caption, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .textCase(nil)
                }
                .listRowBackground(Color.white.opacity(0.06))
                
                // About Section
                Section {
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
                        Text("Built with ❤️ for lifters who value simplicity and privacy.")
                            .font(.caption2)
                            .multilineTextAlignment(.center)
                    }
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 16)
                }
                .listRowBackground(Color.white.opacity(0.06))

                #if DEBUG
                // Debug Section
                Section {
                    Button {
                        DebugHelpers.populateSampleData(modelContext: modelContext)
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                    } label: {
                        Label("Populate Sample Data", systemImage: "cylinder.fill")
                            .foregroundStyle(AppColors.accent)
                    }
                } header: {
                    Label("Debug", systemImage: "hammer")
                        .font(.system(.caption, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .textCase(nil)
                } footer: {
                    Text("Debug tools only available in development builds. Populate sample data will add 8 workouts and 6 exercise memories.")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .listRowBackground(Color.white.opacity(0.06))
                #endif
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(AppColors.background)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                selectedUnit = UnitSystem(rawValue: unitSystem) ?? .imperial
            }
        }
        .presentationBackground(AppColors.background)
    }
    
    // MARK: - Helpers
    
    private func formatSeconds(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let secs = seconds % 60
        if secs == 0 {
            return "\(minutes)m"
        }
        return "\(minutes):\(String(format: "%02d", secs))"
    }
    
    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }
    
    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }
}

#Preview {
    SettingsView()
}



