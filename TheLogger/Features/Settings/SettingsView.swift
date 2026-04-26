//
//  SettingsView.swift
//  TheLogger
//
//  Settings screen for app preferences
//

import SwiftUI
import SwiftData
import UserNotifications

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext

    // User preferences
    @AppStorage("unitSystem") private var unitSystem: String = "Imperial"
    @AppStorage("defaultRestSeconds") private var defaultRestSeconds: Int = 90
    @AppStorage("autoStartRestTimer") private var autoStartRestTimer: Bool = false
    @AppStorage("globalRestTimerEnabled") private var globalRestTimerEnabled: Bool = false
    @AppStorage("userName") private var userName: String = ""
    @AppStorage("weeklyWorkoutGoal") private var weeklyWorkoutGoal: Int = 4
    @AppStorage("autoPopulateSetsFromHistory") private var autoPopulateSets: Bool = true
    @AppStorage("tempoDownTarget") private var tempoDownTarget: Double = 2.0
    @AppStorage("tempoUpTarget") private var tempoUpTarget: Double = 1.0
    @AppStorage("notificationsEnabled") private var notificationsEnabled: Bool = false
    @AppStorage("handsFreeMode") private var handsFreeMode: Bool = false
    @AppStorage("notifStreakEnabled") private var notifStreakEnabled: Bool = true
    @AppStorage("notifPREnabled") private var notifPREnabled: Bool = true
    @AppStorage("notifComebackEnabled") private var notifComebackEnabled: Bool = true
    @AppStorage("notifNeglectEnabled") private var notifNeglectEnabled: Bool = true
    @AppStorage("notifChallengeEnabled") private var notifChallengeEnabled: Bool = true
    @AppStorage("notifRecapEnabled") private var notifRecapEnabled: Bool = true
    @State private var showingResetConfirmation = false
    @State private var notifDebugMessage = ""
    @State private var showingNotifDebugAlert = false
    
    // Local state for picker
    @State private var selectedUnit: UnitSystem = .imperial
    
    var body: some View {
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
                        Analytics.send(Analytics.Signal.settingsUnitChanged, parameters: ["unit": newValue.weightUnit])
                    }
                    
                    HStack {
                        Text("Display")
                        Spacer()
                        Text(selectedUnit.weightUnitFull)
                            .foregroundStyle(Color.white.opacity(0.4))
                    }
                } header: {
                    Label("Units", systemImage: "scalemass")
                        .font(.system(.caption2, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.28))
                        .textCase(nil)
                } footer: {
                    Text("All weights are stored internally and can be switched anytime without data loss.")
                        .font(.caption2)
                        .foregroundStyle(Color.white.opacity(0.18))
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
                                .foregroundStyle(Color.white.opacity(0.4))
                        }
                    }
                    .onChange(of: globalRestTimerEnabled) { _, newValue in
                        Analytics.send(Analytics.Signal.settingsRestTimerToggled, parameters: ["enabled": "\(newValue)"])
                    }

                    if globalRestTimerEnabled {
                        Stepper(value: $defaultRestSeconds, in: 30...300, step: 15) {
                            HStack {
                                Text("Default Rest")
                                Spacer()
                                Text(formatSeconds(defaultRestSeconds))
                                    .foregroundStyle(Color.white.opacity(0.4))
                                    .monospacedDigit()
                            }
                        }
                        .onChange(of: defaultRestSeconds) { _, newValue in
                            Analytics.send(Analytics.Signal.settingsRestDurationChanged, parameters: ["seconds": "\(newValue)"])
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
                        .font(.system(.caption2, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.28))
                        .textCase(nil)
                } footer: {
                    Text("Global default for rest timer. You can override for specific exercises in the exercise detail view.")
                        .font(.caption2)
                        .foregroundStyle(Color.white.opacity(0.18))
                }
                .listRowBackground(Color.white.opacity(0.06))

                // Rep Tempo Section
                Section {
                    Stepper(value: $tempoDownTarget, in: 0.5...5.0, step: 0.5) {
                        HStack {
                            Text("Eccentric (↓)")
                            Spacer()
                            Text(String(format: "%.1fs", tempoDownTarget))
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                    }
                    .onChange(of: tempoDownTarget) { _, newValue in
                        Analytics.send(Analytics.Signal.settingsTempoChanged, parameters: ["phase": "eccentric", "seconds": "\(newValue)"])
                    }
                    Stepper(value: $tempoUpTarget, in: 0.5...5.0, step: 0.5) {
                        HStack {
                            Text("Concentric (↑)")
                            Spacer()
                            Text(String(format: "%.1fs", tempoUpTarget))
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                    }
                    .onChange(of: tempoUpTarget) { _, newValue in
                        Analytics.send(Analytics.Signal.settingsTempoChanged, parameters: ["phase": "concentric", "seconds": "\(newValue)"])
                    }
                } header: {
                    Label("Rep Tempo", systemImage: "metronome")
                        .font(.system(.caption2, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.28))
                        .textCase(nil)
                } footer: {
                    Text("Target tempo for camera rep counting. Your actual tempo is color-coded against these targets — green (on pace), yellow (slightly off), red (way off).")
                        .font(.caption2)
                        .foregroundStyle(Color.white.opacity(0.18))
                }
                .listRowBackground(Color.white.opacity(0.06))

                // Camera Rep Counter Section
                Section {
                    Toggle(isOn: $handsFreeMode) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Hands-Free Mode")
                                .font(.system(.body, weight: .medium))
                            Text("Auto-logs set after 4s inactivity, sounds a chime when rest ends, re-arms quickly")
                                .font(.caption2)
                                .foregroundStyle(Color.white.opacity(0.4))
                        }
                    }
                    .accessibilityIdentifier("handsFreeSettingsToggle")
                    .onChange(of: handsFreeMode) { _, newValue in
                        Analytics.send(Analytics.Signal.settingsCameraHandsFreeToggled, parameters: ["enabled": "\(newValue)"])
                    }
                } header: {
                    Label("Camera Rep Counter", systemImage: "camera.fill")
                        .font(.system(.caption2, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.28))
                        .textCase(nil)
                } footer: {
                    Text("Prop your phone up, enable Hands-Free, and lift. The camera logs sets automatically and sounds a chime when rest is over.")
                        .font(.caption2)
                        .foregroundStyle(Color.white.opacity(0.18))
                }
                .listRowBackground(Color.white.opacity(0.06))

                // Goals Section
                Section {
                    Stepper(value: $weeklyWorkoutGoal, in: 1...7, step: 1) {
                        HStack {
                            Text("Weekly Goal")
                            Spacer()
                            Text("\(weeklyWorkoutGoal) workouts")
                                .foregroundStyle(Color.white.opacity(0.4))
                        }
                    }
                    .onChange(of: weeklyWorkoutGoal) { _, newValue in
                        Analytics.send(Analytics.Signal.settingsWeeklyGoalChanged, parameters: ["goal": "\(newValue)"])
                    }
                } header: {
                    Label("Goals", systemImage: "target")
                        .font(.system(.caption2, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.28))
                        .textCase(nil)
                } footer: {
                    Text("Set your target number of workouts per week. Shown on the home screen.")
                        .font(.caption2)
                        .foregroundStyle(Color.white.opacity(0.18))
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
                                .foregroundStyle(Color.white.opacity(0.4))
                        }
                    }
                } header: {
                    Label("Workout", systemImage: "dumbbell")
                        .font(.system(.caption2, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.28))
                        .textCase(nil)
                }
                .listRowBackground(Color.white.opacity(0.06))

                // Notifications Section
                Section {
                    Toggle(isOn: $notificationsEnabled) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Enable Notifications")
                                .font(.system(.body, weight: .medium))
                            Text("Daily nudges — max 1 per day")
                                .font(.caption2)
                                .foregroundStyle(Color.white.opacity(0.4))
                        }
                    }
                    .onChange(of: notificationsEnabled) { _, newValue in
                        if newValue {
                            NotificationScheduler.shared.requestPermission()
                        } else {
                            UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
                        }
                    }

                    if notificationsEnabled {
                        NotificationToggleRow(icon: "flame.fill", color: Color(red: 1.0, green: 0.54, blue: 0.34), label: "Streak at Risk", notificationType: "streak", isOn: $notifStreakEnabled)
                        NotificationToggleRow(icon: "trophy.fill", color: AppColors.accentGold, label: "PR Proximity", notificationType: "pr", isOn: $notifPREnabled)
                        NotificationToggleRow(icon: "arrow.counterclockwise", color: AppColors.accentBlue, label: "Comeback Reminder", notificationType: "comeback", isOn: $notifComebackEnabled)
                        NotificationToggleRow(icon: "figure.arms.open", color: AppColors.accentTeal, label: "Muscle Neglect", notificationType: "neglect", isOn: $notifNeglectEnabled)
                        NotificationToggleRow(icon: "bolt.fill", color: AppColors.accent, label: "Rest Day Challenge", notificationType: "challenge", isOn: $notifChallengeEnabled)
                        NotificationToggleRow(icon: "chart.bar.fill", color: AppColors.accentBlue, label: "Weekly Recap", notificationType: "recap", isOn: $notifRecapEnabled)
                    }
                } header: {
                    Label("Notifications", systemImage: "bell")
                        .font(.system(.caption2, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.28))
                        .textCase(nil)
                } footer: {
                    Text("All notifications are contextual and local — no account needed. Streak at risk fires at 7pm, all others at 9am (or 2pm for rest day challenge).")
                        .font(.caption2)
                        .foregroundStyle(Color.white.opacity(0.18))
                }
                .listRowBackground(Color.white.opacity(0.06))

                // Achievements Section
                Section {
                    NavigationLink {
                        AchievementsView()
                    } label: {
                        HStack(spacing: 12) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 7)
                                    .fill(AppColors.accentGold.opacity(0.85))
                                    .frame(width: 30, height: 30)
                                Image(systemName: "trophy.fill")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(.white)
                            }
                            Text("View Achievements")
                                .font(.system(.body, weight: .medium))
                        }
                    }
                } header: {
                    Label("Gamification", systemImage: "trophy")
                        .font(.system(.caption2, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.28))
                        .textCase(nil)
                }
                .listRowBackground(Color.white.opacity(0.06))

                // Personal Records Section
                Section {
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 7)
                                .fill(Color(red: 1.0, green: 0.54, blue: 0.34).opacity(0.85))
                                .frame(width: 30, height: 30)
                            Image(systemName: "medal.fill")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.white)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Epley Formula")
                                .font(.system(.body, weight: .medium))
                            Text("weight × (1 + reps ÷ 30)")
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(Color.white.opacity(0.4))
                        }
                    }
                    .padding(.vertical, 4)
                } header: {
                    Label("Personal Records", systemImage: "medal")
                        .font(.system(.caption2, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.28))
                        .textCase(nil)
                } footer: {
                    Text("PRs are ranked by estimated one-rep max (1RM) using the Epley formula. This works across all rep ranges — the same formula used by Hevy. Bodyweight exercises are ranked by reps instead.")
                        .font(.caption2)
                        .foregroundStyle(Color.white.opacity(0.18))
                }
                .listRowBackground(Color.white.opacity(0.06))

                // Profile Section
                Section {
                    HStack {
                        Text("Name")
                        Spacer()
                        TextField("Your name", text: $userName)
                            .multilineTextAlignment(.trailing)
                            .foregroundStyle(Color.white.opacity(0.4))
                    }
                } header: {
                    Label("Profile", systemImage: "person")
                        .font(.system(.caption2, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.28))
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
                        .font(.system(.caption2, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.28))
                        .textCase(nil)
                }
                .listRowBackground(Color.white.opacity(0.06))
                
                // About Section
                Section {
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
                    Label("About", systemImage: "info.circle")
                        .font(.system(.caption2, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.28))
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
                        DebugHelpers.populateSampleData(modelContext: modelContext, force: true)
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                    } label: {
                        Label("Populate Sample Data", systemImage: "cylinder.fill")
                            .foregroundStyle(AppColors.accent)
                    }

                    // Notification test buttons
                    Group {
                        Button { fireRealNotif(.streakAtRisk) } label: {
                            Label("Notif: Streak at Risk", systemImage: "bell.badge").foregroundStyle(AppColors.accent)
                        }
                        Button { fireRealNotif(.prProximity) } label: {
                            Label("Notif: PR Proximity", systemImage: "bell.badge").foregroundStyle(AppColors.accent)
                        }
                        Button { fireRealNotif(.comeback) } label: {
                            Label("Notif: Comeback", systemImage: "bell.badge").foregroundStyle(AppColors.accent)
                        }
                        Button { fireRealNotif(.muscleNeglect) } label: {
                            Label("Notif: Muscle Neglect", systemImage: "bell.badge").foregroundStyle(AppColors.accent)
                        }
                        Button { fireRealNotif(.restDayChallenge) } label: {
                            Label("Notif: Rest Day Challenge", systemImage: "bell.badge").foregroundStyle(AppColors.accent)
                        }
                        Button { fireRealNotif(.weeklyRecap) } label: {
                            Label("Notif: Weekly Recap", systemImage: "bell.badge").foregroundStyle(AppColors.accent)
                        }
                    }

                    Button(role: .destructive) {
                        showingResetConfirmation = true
                    } label: {
                        Label("Reset to New User", systemImage: "trash.fill")
                            .foregroundStyle(.red)
                    }
                } header: {
                    Label("Debug", systemImage: "hammer")
                        .font(.system(.caption2, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.28))
                        .textCase(nil)
                } footer: {
                    Text("Debug tools only available in development builds.")
                        .font(.caption2)
                        .foregroundStyle(Color.white.opacity(0.18))
                }
                .listRowBackground(Color.white.opacity(0.06))
                .alert("Reset All Data?", isPresented: $showingResetConfirmation) {
                    Button("Reset Everything", role: .destructive) {
                        resetToNewUser()
                    }
                    Button("Cancel", role: .cancel) { }
                } message: {
                    Text("This will delete ALL workouts, templates, PRs, achievements, and settings. CloudKit data will re-sync if available.")
                }
                #endif
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(AppColors.background)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                selectedUnit = UnitSystem(rawValue: unitSystem) ?? .imperial
            }
            #if DEBUG
            .alert("Notification Debug", isPresented: $showingNotifDebugAlert) {
                Button("OK") { }
            } message: {
                Text(notifDebugMessage)
            }
            #endif
    }
    
    // MARK: - Debug Helpers

    #if DEBUG
    private func fireRealNotif(_ type: NotificationScheduler.DebugNotifType) {
        NotificationScheduler.shared.debugFire(type)
        notifDebugMessage = "✅ Notification scheduled! Background the app now (Cmd+H) — fires in 5 seconds."
        showingNotifDebugAlert = true
    }

    private func fireDebugNotif(title: String, body: String) {
        scheduleDebugNotification(title: title, body: body)
        notifDebugMessage = "✅ Notification scheduled! Background the app now (Cmd+H) — fires in 5 seconds."
        showingNotifDebugAlert = true
    }

    private func fireTestNotification() {
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            DispatchQueue.main.async {
                switch settings.authorizationStatus {
                case .notDetermined:
                    // First time — request permission
                    center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
                        DispatchQueue.main.async {
                            if granted {
                                scheduleDebugNotification(title: "Test Notification 🔔", body: "Notifications are working!")
                                notifDebugMessage = "✅ Permission granted! Background the app (Cmd+H) — notification fires in 5 seconds."
                            } else {
                                notifDebugMessage = "❌ Permission denied. Go to Simulator Settings → TheLogger → Notifications → enable them."
                            }
                            showingNotifDebugAlert = true
                        }
                    }
                case .authorized, .provisional:
                    scheduleDebugNotification(title: "Test Notification 🔔", body: "Notifications are working! Background the app to see this banner.")
                    notifDebugMessage = "✅ Notification scheduled! Background the app now (press Cmd+H) — it fires in 5 seconds."
                    showingNotifDebugAlert = true
                case .denied:
                    notifDebugMessage = "❌ Notifications are blocked. Go to Simulator Settings → TheLogger → Notifications → toggle on."
                    showingNotifDebugAlert = true
                case .ephemeral:
                    scheduleDebugNotification(title: "Test Notification 🔔", body: "Notifications are working! Background the app to see this banner.")
                    notifDebugMessage = "✅ Notification scheduled! Background the app now (press Cmd+H) — it fires in 5 seconds."
                    showingNotifDebugAlert = true
                @unknown default:
                    notifDebugMessage = "Unknown authorization status."
                    showingNotifDebugAlert = true
                }
            }
        }
    }

    private func scheduleDebugNotification(
        title: String = "Test Notification 🔔",
        body: String = "Notifications are working! Background the app to see this banner."
    ) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
        let request = UNNotificationRequest(identifier: "debug-test-\(UUID())", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                DispatchQueue.main.async {
                    notifDebugMessage = "❌ Failed to schedule: \(error.localizedDescription)"
                    showingNotifDebugAlert = true
                }
            }
        }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    private func resetToNewUser() {
        // Delete all SwiftData objects
        do {
            let workouts = try modelContext.fetch(FetchDescriptor<Workout>())
            for w in workouts { modelContext.delete(w) }
            let prs = try modelContext.fetch(FetchDescriptor<PersonalRecord>())
            for pr in prs { modelContext.delete(pr) }
            let memories = try modelContext.fetch(FetchDescriptor<ExerciseMemory>())
            for m in memories { modelContext.delete(m) }
            let achievements = try modelContext.fetch(FetchDescriptor<Achievement>())
            for a in achievements { modelContext.delete(a) }
            try modelContext.save()
        } catch {
            debugLog("Reset error: \(error)")
        }

        // Clear UserDefaults
        let keys = ["hasSeededTemplates", "hasDismissedCameraTip", "dailyChallenge",
                     "hasCompletedOnboarding", "hasSeenBackupPrompt"]
        for key in keys { UserDefaults.standard.removeObject(forKey: key) }

        // Clear challenge
        DailyChallenge.clearToday()

        // Re-seed starter templates immediately
        let templates: [(name: String, exercises: [String])] = [
            ("Push Day", ["Bench Press", "Overhead Press", "Incline Dumbbell Press", "Tricep Pushdown"]),
            ("Pull Day", ["Deadlift", "Barbell Row", "Lat Pulldown", "Barbell Curl"]),
            ("Leg Day", ["Squat", "Romanian Deadlift", "Lunges", "Leg Press"]),
        ]
        for t in templates {
            let workout = Workout(name: t.name, date: Date(), isTemplate: true)
            for name in t.exercises { workout.addExercise(name: name) }
            modelContext.insert(workout)
        }
        do { try modelContext.save() } catch { debugLog("Seed error: \(error)") }
        UserDefaults.standard.set(true, forKey: "hasSeededTemplates")

        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }
    #endif

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

// MARK: - Notification Toggle Row

private struct NotificationToggleRow: View {
    let icon: String
    let color: Color
    let label: String
    let notificationType: String
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(color)
                    .frame(width: 20)
                Text(label)
                    .font(.system(.body, weight: .regular))
            }
        }
        .onChange(of: isOn) { _, newValue in
            Analytics.send(Analytics.Signal.settingsNotificationToggled, parameters: ["type": notificationType, "enabled": "\(newValue)"])
        }
    }
}

#Preview {
    SettingsView()
}

