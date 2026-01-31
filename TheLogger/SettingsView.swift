//
//  SettingsView.swift
//  TheLogger
//
//  Settings screen for app preferences
//

import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    
    // User preferences
    @AppStorage("unitSystem") private var unitSystem: String = "Imperial"
    @AppStorage("defaultRestSeconds") private var defaultRestSeconds: Int = 90
    @AppStorage("autoStartRestTimer") private var autoStartRestTimer: Bool = false
    @AppStorage("userName") private var userName: String = ""
    @AppStorage("weeklyWorkoutGoal") private var weeklyWorkoutGoal: Int = 4
    
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
                .listRowBackground(Color.black.opacity(0.6))
                
                // Rest Timer Section
                Section {
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
                        Text("Auto-start after logging set")
                    }
                } header: {
                    Label("Rest Timer", systemImage: "timer")
                        .font(.system(.caption, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .textCase(nil)
                } footer: {
                    Text("Default rest time between sets. Compound exercises automatically use longer rest periods.")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .listRowBackground(Color.black.opacity(0.6))

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
                .listRowBackground(Color.black.opacity(0.6))

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
                .listRowBackground(Color.black.opacity(0.6))
                
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
                .listRowBackground(Color.black.opacity(0.6))
                
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
                .listRowBackground(Color.black.opacity(0.6))
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Color.black)
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
        .presentationBackground(Color.black)
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


