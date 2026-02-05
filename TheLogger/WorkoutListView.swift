//
//  WorkoutListView.swift
//
//  Root screen displaying list of workouts
//

import SwiftUI
import SwiftData
import UIKit

struct WorkoutListView: View {
    @Query(sort: \Workout.date, order: .reverse) private var workouts: [Workout]
    @Query(filter: #Predicate<Workout> { $0.isTemplate == true }, sort: \Workout.name) private var templates: [Workout]
    @Environment(\.modelContext) private var modelContext
    @State private var showingWorkoutSelector = false
    @State private var showingTemplateEditor = false
    @State private var editingTemplate: Workout?

    @State private var showingWorkoutHistory = false
    @State private var navigationPath = NavigationPath()
    @State private var hasCheckedActiveWorkout = false

    // Deep link from widget
    @Binding var deepLinkWorkoutId: UUID?
    @Binding var deepLinkExerciseId: UUID?

    init(deepLinkWorkoutId: Binding<UUID?> = .constant(nil), deepLinkExerciseId: Binding<UUID?> = .constant(nil)) {
        _deepLinkWorkoutId = deepLinkWorkoutId
        _deepLinkExerciseId = deepLinkExerciseId
    }
    @State private var userName: String = UserDefaults.standard.string(forKey: "userName") ?? ""
    @State private var showingNameEditor = false
    @State private var showingExportSheet = false
    @State private var exportCSVURL: URL? = nil
    @State private var showingSettings = false
    @State private var emptyTemplatesAppeared = false
    @State private var showConfetti = false
    @State private var lastCelebratedStreak: Int = 0
    @AppStorage("weeklyWorkoutGoal") private var weeklyWorkoutGoal: Int = 4

    // Get recent workouts for inline display (last 5)
    private var recentWorkouts: [Workout] {
        Array(workoutHistory.prefix(5))
    }

    // Days since last workout (for rest day message)
    private var daysSinceLastWorkout: Int {
        guard let lastWorkout = workoutHistory.first else { return 0 }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let lastWorkoutDay = calendar.startOfDay(for: lastWorkout.date)
        return calendar.dateComponents([.day], from: lastWorkoutDay, to: today).day ?? 0
    }

    // Check if we should celebrate a streak milestone
    private var shouldCelebrateStreak: Bool {
        let milestones = [3, 7, 14, 21, 30, 50, 100]
        return milestones.contains(workoutStreak) && workoutStreak > lastCelebratedStreak
    }

    // Get greeting based on time of day
    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        case 17..<22: return "Good evening"
        default: return "Good night"
        }
    }
    
    // Find active workout (only one can be active at a time)
    private var activeWorkout: Workout? {
        workouts.first { $0.isActive }
    }
    
    // Get completed workouts (history)
    private var workoutHistory: [Workout] {
        workouts.filter { $0.isCompleted && !$0.isTemplate }
    }
    
    // Motivational stats
    private var totalWorkouts: Int {
        workoutHistory.count
    }
    
    private var workoutStreak: Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        var streak = 0
        
        // Check if worked out today
        let hasWorkoutToday = workoutHistory.contains { workout in
            calendar.isDate(workout.date, inSameDayAs: today)
        }
        
        // Start from today if worked out today, otherwise start from yesterday
        // (gives user until end of day to maintain streak)
        var currentDate = hasWorkoutToday ? today : calendar.date(byAdding: .day, value: -1, to: today)!
        
        while true {
            let hasWorkout = workoutHistory.contains { workout in
                calendar.isDate(workout.date, inSameDayAs: currentDate)
            }
            if hasWorkout {
                streak += 1
                currentDate = calendar.date(byAdding: .day, value: -1, to: currentDate)!
            } else {
                break
            }
        }
        return streak
    }
    
    private var thisWeekWorkouts: Int {
        let calendar = Calendar.current
        // Get start of current calendar week (respects user's locale for first day of week)
        guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: Date()) else {
            return 0
        }
        let startOfWeek = weekInterval.start
        return workoutHistory.filter { $0.date >= startOfWeek }.count
    }

    // Get which days of the week had workouts (0=Sun, 6=Sat)
    private var thisWeekWorkoutDays: Set<Int> {
        let calendar = Calendar.current
        guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: Date()) else {
            return []
        }
        var days: Set<Int> = []
        for workout in workoutHistory where workout.date >= weekInterval.start {
            // weekday is 1-7 (Sun=1), convert to 0-6
            days.insert(calendar.component(.weekday, from: workout.date) - 1)
        }
        return days
    }

    // Badge for workout milestones
    private func milestoneBadge(for count: Int) -> String? {
        switch count {
        case 100...: return "Century!"
        case 50..<100: return "50+ Club"
        case 25..<50: return "25+ Strong"
        case 10..<25: return "10+ Nice"
        default: return nil
        }
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            List {
                // Welcome Header Section
                Section {
                    HStack(spacing: 12) {
                        // Level-based avatar with gradient
                        LevelAvatar(
                            name: userName,
                            totalWorkouts: totalWorkouts,
                            size: 48
                        )

                        VStack(alignment: .leading, spacing: 4) {
                            if userName.isEmpty {
                                Text("Welcome!")
                                    .font(.system(.title2, weight: .bold))
                                    .foregroundStyle(.primary)
                                Text("Tap to add your name")
                                    .font(.system(.subheadline, weight: .regular))
                                    .foregroundStyle(.secondary)
                            } else {
                                Text("\(greeting), \(userName)")
                                    .font(.system(.title2, weight: .bold))
                                    .foregroundStyle(.primary)
                                Text("Ready to work out?")
                                    .font(.system(.subheadline, weight: .regular))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        
                        Spacer()

                        HStack(spacing: 8) {
                            Button {
                                showingNameEditor = true
                            } label: {
                                Image(systemName: userName.isEmpty ? "person.crop.circle.badge.plus" : "pencil")
                                    .font(.system(.body, weight: .medium))
                                    .foregroundStyle(.blue)
                                    .padding(8)
                                    .background(
                                        Circle()
                                            .fill(Color.black.opacity(0.6))
                                    )
                            }
                            .buttonStyle(.borderless)

                            Button {
                                showingSettings = true
                            } label: {
                                Image(systemName: "gearshape.fill")
                                    .font(.system(.body, weight: .medium))
                                    .foregroundStyle(.secondary)
                                    .padding(8)
                                    .background(
                                        Circle()
                                            .fill(Color.black.opacity(0.6))
                                    )
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                    .padding(.vertical, 8)

                    // Level badge and weekly goal (gamification)
                    if totalWorkouts > 0 {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("FITNESS LEVEL")
                                    .font(.system(size: 9, weight: .semibold))
                                    .foregroundStyle(.secondary)
                                LevelBadge(totalWorkouts: totalWorkouts)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 8) {
                                Text("WEEKLY GOAL")
                                    .font(.system(size: 9, weight: .semibold))
                                    .foregroundStyle(.secondary)
                                WeeklyGoalRing(current: thisWeekWorkouts, goal: weeklyWorkoutGoal, color: .green)
                            }
                        }
                        .padding(.top, 4)
                    }
                } header: {
                    EmptyView()
                }
                .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 8, trailing: 16))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
                
                // Animated Stats Section with glass morphism
                if totalWorkouts > 0 {
                    Section {
                        VStack(spacing: 12) {
                            HStack(spacing: 12) {
                                // Streak Card with animated flame
                                AnimatedStatCard(
                                    icon: AnimatedFlame(color: .orange),
                                    value: workoutStreak,
                                    label: "Day Streak",
                                    color: .orange
                                )
                                .depthShadow(color: .orange, radius: 8)
                                .staggeredAppear(index: 0, maxStagger: 3)

                                // Total Workouts with milestone badge
                                AnimatedStatCard(
                                    icon: Image(systemName: "checkmark.circle.fill"),
                                    value: totalWorkouts,
                                    label: "Total",
                                    color: .green,
                                    badge: milestoneBadge(for: totalWorkouts)
                                )
                                .depthShadow(color: .green, radius: 8)
                                .staggeredAppear(index: 1, maxStagger: 3)

                                // This Week with day dots
                                VStack(spacing: 6) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "calendar")
                                            .font(.system(.caption, weight: .bold))
                                            .foregroundStyle(.blue)
                                        CountingNumber(value: thisWeekWorkouts)
                                            .font(.system(.title2, weight: .bold))
                                            .foregroundStyle(.blue)
                                    }
                                    Text("This Week")
                                        .font(.system(.caption2, weight: .medium))
                                        .foregroundStyle(.secondary)
                                    WeekDots(workoutDays: thisWeekWorkoutDays, accentColor: .blue)
                                }
                                .frame(maxWidth: .infinity, minHeight: 76)
                                .padding(.vertical, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.blue.opacity(0.1))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(Color.blue.opacity(0.25), lineWidth: 1)
                                        )
                                )
                                .depthShadow(color: .blue, radius: 8)
                                .staggeredAppear(index: 2, maxStagger: 3)
                            }

                            // Rest day message (when not worked out today)
                            if daysSinceLastWorkout > 0 && activeWorkout == nil {
                                RestDayMessage(daysSinceLastWorkout: daysSinceLastWorkout)
                                    .staggeredAppear(index: 3, maxStagger: 4)
                            }
                        }
                        .padding(.horizontal, 4)
                    } header: {
                        Text("Your Progress")
                            .font(.system(.subheadline, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .textCase(nil)
                    }
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                }
                
                // Active Workout Section (show when workout is active)
                if let active = activeWorkout {
                    Section {
                        ZStack {
                            NavigationLink(value: active.id.uuidString) {
                                Color.clear
                                    .contentShape(Rectangle())
                            }

                            ActiveWorkoutRowView(workout: active)
                                .depthShadow(color: .blue, radius: 12)
                        }
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                    } header: {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(Color.blue)
                                .frame(width: 8, height: 8)
                            Text("Active Workout")
                                .font(.system(.subheadline, weight: .semibold))
                        }
                        .foregroundStyle(.secondary)
                        .textCase(nil)
                    }
                }
                
                // Start Workout Button (only show when no active workout)
                if activeWorkout == nil {
                    Section {
                        Button {
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            if templates.isEmpty {
                                startWorkoutFromTemplate(template: nil)
                            } else {
                                showingWorkoutSelector = true
                            }
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "play.fill")
                                    .font(.system(size: 18, weight: .semibold))
                                Text("Start Workout")
                                    .font(.system(.body, weight: .semibold))
                            }
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(Color.blue)
                            .shimmerEffect()
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .pulsingGlow(color: .blue, radius: 10)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("startWorkoutButton")
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                    } header: {
                        EmptyView()
                    }
                }

                // Templates Section (prioritized)
                Section {
                    if !templates.isEmpty {
                        ForEach(Array(templates.enumerated()), id: \.element.id) { index, template in
                            ZStack {
                                NavigationLink(value: template.id.uuidString) {
                                    Color.clear
                                        .contentShape(Rectangle())
                                }

                                TemplateRowView(template: template)
                            }
                            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                            .staggeredAppear(index: index, maxStagger: 5)
                        }
                        .onDelete(perform: deleteTemplates)
                    } else {
                        // Empty templates state
                        VStack(spacing: 12) {
                            Image(systemName: "doc.text")
                                .font(.system(size: 40))
                                .foregroundStyle(.tertiary)
                                .symbolEffect(.bounce, value: emptyTemplatesAppeared)
                            Text("No templates yet")
                                .font(.system(.subheadline, weight: .medium))
                                .foregroundStyle(.secondary)
                            Text("Create a template to quickly start workouts")
                                .font(.system(.caption, weight: .regular))
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                        .opacity(emptyTemplatesAppeared ? 1 : 0)
                        .animation(.easeOut(duration: 0.4), value: emptyTemplatesAppeared)
                        .onAppear {
                            if templates.isEmpty { emptyTemplatesAppeared = true }
                        }
                        .onChange(of: templates.count) { _, count in
                            if count > 0 { emptyTemplatesAppeared = false }
                        }
                    }
                    
                    // New Template button
                    Button {
                        editingTemplate = nil
                        showingTemplateEditor = true
                    } label: {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(Color.blue.opacity(0.1))
                                    .frame(width: 40, height: 40)
                                
                                Image(systemName: "plus")
                                    .font(.system(.body, weight: .semibold))
                                    .foregroundStyle(.blue)
                            }
                            
                            Text("New Template")
                                .font(.system(.body, weight: .medium))
                                .foregroundStyle(.blue)
                            
                            Spacer()
                        }
                        .padding(.vertical, 12)
                        .padding(.horizontal, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.blue.opacity(0.08))
                                .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 2)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.blue.opacity(0.25), lineWidth: 1)
                                )
                        )
                    }
                } header: {
                    HStack {
                        Image(systemName: "doc.text.fill")
                            .font(.system(.caption, weight: .semibold))
                            .foregroundStyle(.blue)
                        Text("Templates")
                            .font(.system(.subheadline, weight: .semibold))
                        if !templates.isEmpty {
                            Spacer()
                            Text("\(templates.count)")
                                .font(.system(.caption, weight: .semibold))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(
                                    Capsule()
                                        .fill(Color(.systemGray5))
                                )
                        }
                    }
                    .foregroundStyle(.secondary)
                    .textCase(nil)
                }
                
                // Recent Workouts Section (inline horizontal scroll)
                if !recentWorkouts.isEmpty {
                    Section {
                        VStack(alignment: .leading, spacing: 12) {
                            // Horizontal scroll of recent workouts
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(Array(recentWorkouts.enumerated()), id: \.element.id) { index, workout in
                                        RecentWorkoutCard(workout: workout) {
                                            navigationPath.append(workout.id.uuidString)
                                        }
                                        .staggeredAppear(index: index, maxStagger: 5)
                                    }
                                }
                                .padding(.horizontal, 4)
                            }

                            // View All button
                            Button {
                                showingWorkoutHistory = true
                            } label: {
                                HStack {
                                    Text("View All History")
                                        .font(.system(.subheadline, weight: .medium))
                                    Image(systemName: "chevron.right")
                                        .font(.system(.caption, weight: .semibold))
                                }
                                .foregroundStyle(.blue)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(Color.blue.opacity(0.1))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 10)
                                                .stroke(Color.blue.opacity(0.2), lineWidth: 1)
                                        )
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    } header: {
                        HStack {
                            Image(systemName: "clock.arrow.circlepath")
                                .font(.system(.caption, weight: .semibold))
                                .foregroundStyle(.blue)
                            Text("Recent Workouts")
                                .font(.system(.subheadline, weight: .semibold))
                            Spacer()
                            Text("\(workoutHistory.count) total")
                                .font(.system(.caption, weight: .medium))
                                .foregroundStyle(.tertiary)
                        }
                        .foregroundStyle(.secondary)
                        .textCase(nil)
                    }
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                }
                
                // Data & Backup Section
                Section {
                    Button {
                        exportWorkoutData()
                    } label: {
                        HStack(spacing: 14) {
                            ZStack {
                                Circle()
                                    .fill(Color.green.opacity(0.15))
                                    .frame(width: 44, height: 44)
                                
                                Image(systemName: "square.and.arrow.up")
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundStyle(.green)
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Export Workout Data")
                                    .font(.system(.body, weight: .semibold))
                                    .foregroundStyle(.primary)
                                Text("Your data is stored safely on this device")
                                    .font(.system(.caption, weight: .regular))
                                    .foregroundStyle(.secondary)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.system(.caption, weight: .semibold))
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.vertical, 12)
                        .padding(.horizontal, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.black.opacity(0.6))
                                .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 2)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.green.opacity(0.25), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                } header: {
                    HStack(spacing: 4) {
                        Image(systemName: "lock.shield.fill")
                            .font(.system(.caption, weight: .semibold))
                            .foregroundStyle(.green)
                        Text("Data & Backup")
                            .font(.system(.subheadline, weight: .semibold))
                    }
                    .foregroundStyle(.secondary)
                    .textCase(nil)
                }
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            }
            .navigationDestination(for: String.self) { workoutId in
                // Check both workouts and templates arrays
                if let workout = workouts.first(where: { $0.id.uuidString == workoutId }) {
                    WorkoutDetailView(workout: workout, onLogAgain: { logAgainFrom(workout: $0) })
                } else if let template = templates.first(where: { $0.id.uuidString == workoutId }) {
                    WorkoutDetailView(workout: template, onLogAgain: { logAgainFrom(workout: $0) })
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background {
                ZStack {
                    Color(.systemBackground)
                    FloatingParticlesView()
                }
                .ignoresSafeArea()
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showingWorkoutHistory) {
                WorkoutHistoryView(workouts: workoutHistory, onLogAgain: { workout in
                    showingWorkoutHistory = false
                    logAgainFrom(workout: workout)
                })
            }
            .sheet(isPresented: $showingWorkoutSelector) {
                WorkoutSelectorView(templates: templates) { templateWorkout in
                    showingWorkoutSelector = false
                    startWorkoutFromTemplate(template: templateWorkout)
                }
            }
            .sheet(isPresented: $showingTemplateEditor) {
                if let template = editingTemplate {
                    TemplateEditView(template: template)
                } else {
                    TemplateEditView(template: nil)
                }
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
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
            .sheet(isPresented: $showingExportSheet) {
                if let url = exportCSVURL {
                    ExportShareSheet(url: url)
                }
            }
            .task {
                // Auto-navigate to active workout on app launch (only once)
                if !hasCheckedActiveWorkout {
                    hasCheckedActiveWorkout = true
                    if let activeWorkout = activeWorkout {
                        navigationPath.append(activeWorkout.id.uuidString)
                    }
                }
            }
            // Do NOT clear navigation when workout ends - let user see the end summary first.
            // WorkoutDetailView calls dismiss() when summary is dismissed.
            .onChange(of: workoutStreak) { _, newStreak in
                // Celebrate streak milestones
                let milestones = [3, 7, 14, 21, 30, 50, 100]
                if milestones.contains(newStreak) && newStreak > lastCelebratedStreak {
                    lastCelebratedStreak = newStreak
                    showConfetti = true
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    // Reset confetti after animation
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        showConfetti = false
                    }
                }
            }
            .overlay {
                // Confetti overlay for streak celebrations
                StreakConfettiView(isActive: showConfetti)
                    .ignoresSafeArea()
            }
            .onOpenURL { url in
                handleDeepLink(url)
            }
            .onChange(of: deepLinkWorkoutId) { _, workoutId in
                // Navigate to workout when deep link is received
                if let workoutId = workoutId {
                    navigationPath = NavigationPath()
                    navigationPath.append(workoutId.uuidString)
                    // Clear after navigation
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        deepLinkWorkoutId = nil
                        deepLinkExerciseId = nil
                    }
                }
            }
        }
    }

    private func handleDeepLink(_ url: URL) {
        guard let destination = WidgetDeepLink.parse(url) else { return }

        switch destination {
        case .workout(let workoutId):
            deepLinkWorkoutId = workoutId
            deepLinkExerciseId = nil
        case .exercise(let workoutId, let exerciseId):
            deepLinkWorkoutId = workoutId
            deepLinkExerciseId = exerciseId
        }
    }
    
    private func startWorkoutFromTemplate(template: Workout?) {
        // End any existing active workout first and save immediately
        if let existingActive = activeWorkout {
            existingActive.endTime = Date()
            try? modelContext.save()
        }

        // Double-check no active workout exists after save
        let stillActive = workouts.first { $0.isActive }
        if stillActive != nil {
            print("Warning: Active workout still exists, aborting new workout creation")
            return
        }

        // Create workout (blank or from template)
        let newWorkout: Workout
        if let template = template {
            newWorkout = duplicateWorkoutFromTemplate(template)
        } else {
            newWorkout = Workout(date: Date(), isTemplate: false)
        }

        // Mark as active and save (templates are never active)
        newWorkout.startTime = Date()
        newWorkout.endTime = nil
        newWorkout.isTemplate = false
        modelContext.insert(newWorkout)

        do {
            try modelContext.save()
            // Sync to widget
            newWorkout.syncToWidget()
            // Start Live Activity for lock screen logging
            let exerciseName = newWorkout.exercises?.first?.name ?? "Workout"
            let exerciseId = newWorkout.exercises?.first?.id ?? UUID()
            LiveActivityManager.shared.startActivity(
                workoutId: newWorkout.id,
                workoutName: newWorkout.name,
                exerciseName: exerciseName,
                exerciseId: exerciseId
            )
            // Navigate to the workout detail view
            navigationPath.append(newWorkout.id.uuidString)
        } catch {
            print("Error starting workout: \(error)")
        }
    }

    private func duplicateWorkoutFromTemplate(_ template: Workout) -> Workout {
        // Create new workout with today's date and copy the name
        let newWorkout = Workout(name: template.name, date: Date(), isTemplate: false)
        let templateExercises = template.exercisesByOrder

        // Copy all exercises (templates only have exercise names, no sets)
        for (index, exercise) in templateExercises.enumerated() {
            let newExercise = Exercise(name: exercise.name, order: index)
            if newWorkout.exercises == nil {
                newWorkout.exercises = [newExercise]
            } else {
                newWorkout.exercises?.append(newExercise)
            }
        }

        return newWorkout
    }

    /// Duplicate a completed workout as a new active workout, filling sets from ExerciseMemory.
    private func logAgainFrom(workout: Workout) {
        // End any existing active workout first
        if let existingActive = activeWorkout {
            existingActive.endTime = Date()
            try? modelContext.save()
        }

        // Create new workout with same name
        let newWorkout = Workout(name: workout.name, date: Date(), isTemplate: false)

        // Copy exercises in order, filling sets from memory (mirrors addExerciseWithMemory logic)
        let memories = (try? modelContext.fetch(FetchDescriptor<ExerciseMemory>())) ?? []
        for (index, exercise) in workout.exercisesByOrder.enumerated() {
            let newExercise = Exercise(name: exercise.name, order: index)
            let normalizedName = exercise.name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

            if let memory = memories.first(where: { $0.normalizedName == normalizedName }) {
                let isTimeBased = ExerciseLibrary.shared.find(name: exercise.name)?.isTimeBased ?? false
                for _ in 0..<memory.lastSets {
                    if isTimeBased, let d = memory.lastDuration {
                        newExercise.addSet(reps: 0, weight: 0, durationSeconds: d)
                    } else {
                        newExercise.addSet(reps: memory.lastReps, weight: memory.lastWeight)
                    }
                }
                newExercise.isAutoFilled = true
            }

            if newWorkout.exercises == nil {
                newWorkout.exercises = [newExercise]
            } else {
                newWorkout.exercises?.append(newExercise)
            }
        }

        // Mark as active and save
        newWorkout.startTime = Date()
        newWorkout.endTime = nil
        newWorkout.isTemplate = false
        modelContext.insert(newWorkout)

        do {
            try modelContext.save()
            newWorkout.syncToWidget()
            let exerciseName = newWorkout.exercises?.first?.name ?? "Workout"
            let exerciseId = newWorkout.exercises?.first?.id ?? UUID()
            LiveActivityManager.shared.startActivity(
                workoutId: newWorkout.id,
                workoutName: newWorkout.name,
                exerciseName: exerciseName,
                exerciseId: exerciseId
            )
            navigationPath.append(newWorkout.id.uuidString)
        } catch {
            print("Error starting workout: \(error)")
        }
    }

    private func deleteTemplates(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(templates[index])
        }
        // Save changes to persist deletion
        do {
            try modelContext.save()
        } catch {
            print("Error deleting template: \(error)")
        }
    }
    
    private func exportWorkoutData() {
        let csvContent = WorkoutDataExporter.generateCSV(from: Array(workouts))
        
        // Create temporary file
        let fileName = "TheLogger_Export_\(DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .none).replacingOccurrences(of: "/", with: "-")).csv"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        
        do {
            try csvContent.write(to: tempURL, atomically: true, encoding: .utf8)
            exportCSVURL = tempURL
            showingExportSheet = true
        } catch {
            print("Error creating CSV file: \(error)")
        }
    }
}


// MARK: - Active Workout Row View
// MARK: - Export Share Sheet
struct ExportShareSheet: UIViewControllerRepresentable {
    let url: URL
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let activityVC = UIActivityViewController(
            activityItems: [url],
            applicationActivities: nil
        )
        return activityVC
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

struct ActiveWorkoutRowView: View {
    let workout: Workout
    @State private var elapsedTime: TimeInterval = 0
    @State private var timer: Timer?
    
    private var formattedElapsedTime: String {
        let hours = Int(elapsedTime) / 3600
        let minutes = Int(elapsedTime) / 60 % 60
        let seconds = Int(elapsedTime) % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Left side content
            VStack(alignment: .leading, spacing: 10) {
                // Workout name with active indicator
                HStack {
                    Text(workout.name)
                        .font(.system(.title3, weight: .semibold))
                        .foregroundStyle(.primary)

                    Spacer()
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 6, height: 6)
                        Text("Active")
                            .font(.system(.caption, weight: .medium))
                            .foregroundStyle(.blue)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color.blue.opacity(0.1))
                    )
                }
                
                // Exercise count
                HStack(spacing: 16) {
                    Label {
                        Text("\(workout.exerciseCount) \(workout.exerciseCount == 1 ? "exercise" : "exercises")")
                            .font(.system(.subheadline, weight: .regular))
                    } icon: {
                        Image(systemName: "figure.strengthtraining.traditional")
                            .font(.system(.caption2, weight: .medium))
                    }
                    .foregroundStyle(.secondary)
                    
                    Spacer()
                }
            }
            
            // Right side - Elapsed time
            VStack(alignment: .trailing, spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: "clock.fill")
                        .font(.system(.caption2, weight: .medium))
                        .foregroundStyle(.blue)
                    Text(formattedElapsedTime)
                        .font(.system(.headline, weight: .semibold))
                        .foregroundStyle(.blue)
                        .monospacedDigit()
                }
                Text("elapsed")
                    .font(.system(.caption2, weight: .regular))
                    .foregroundStyle(.tertiary)
            }
            .padding(.top, 4)
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.6))
                .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 2)
        )
        .overlay(AnimatedGradientBorder())
        .onAppear {
            if let startTime = workout.startTime {
                elapsedTime = Date().timeIntervalSince(startTime)
            }
            // Start timer
            timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
                if let startTime = workout.startTime {
                    elapsedTime = Date().timeIntervalSince(startTime)
                }
            }
        }
        .onDisappear {
            timer?.invalidate()
            timer = nil
        }
    }
}

// MARK: - Template Row View
struct TemplateRowView: View {
    let template: Workout

    // Get first few exercise names for preview (in saved order)
    private var exercisePreview: [String] {
        Array(template.exercisesByOrder.prefix(3).map { $0.name })
    }

    private var remainingCount: Int {
        max(0, template.exercisesByOrder.count - 3)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header row
            HStack {
                Text(template.name)
                    .font(.system(.headline, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(.caption, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }

            // Exercise chips
            if !exercisePreview.isEmpty {
                HStack(spacing: 6) {
                    ForEach(exercisePreview, id: \.self) { exercise in
                        Text(exercise)
                            .font(.system(.caption, weight: .medium))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(
                                Capsule()
                                    .fill(Color(.systemGray5))
                            )
                            .lineLimit(1)
                    }

                    if remainingCount > 0 {
                        Text("+\(remainingCount)")
                            .font(.system(.caption, weight: .semibold))
                            .foregroundStyle(.tertiary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(
                                Capsule()
                                    .strokeBorder(Color(.systemGray4), lineWidth: 1)
                            )
                    }
                }
            } else {
                Text("No exercises yet")
                    .font(.system(.caption, weight: .medium))
                    .foregroundStyle(.tertiary)
                    .italic()
            }
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.6))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(.separator), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.06), radius: 6, x: 0, y: 2)
    }
}


// MARK: - Workout Row View
struct WorkoutRowView: View {
    let workout: Workout
    let useBorder: Bool
    let isActive: Bool
    let isCompact: Bool
    
    init(workout: Workout, useBorder: Bool = false, isActive: Bool = false, isCompact: Bool = false) {
        self.workout = workout
        self.useBorder = useBorder
        self.isActive = isActive
        self.isCompact = isCompact
    }
    
    // Single subtle color overlay
    private var accentColor: Color {
        Color(UIColor.systemGray6)
    }
    
    // Relative date formatter for compact mode
    private var compactDateString: String {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let workoutDay = calendar.startOfDay(for: workout.date)
        
        if calendar.isDateInToday(workout.date) {
            return "Today"
        } else if calendar.isDateInYesterday(workout.date) {
            return "Yesterday"
        } else if let days = calendar.dateComponents([.day], from: workoutDay, to: today).day, days < 7 {
            return "\(days) days ago"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d"
            return formatter.string(from: workout.date)
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: isCompact ? 6 : 10) {
            // Workout name with active indicator
            HStack {
                Text(workout.name)
                    .font(.system(.title3, weight: .semibold))
                    .foregroundStyle(.primary)

                if isActive {
                    Spacer()
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 6, height: 6)
                        Text("Active")
                            .font(.system(.caption, weight: .medium))
                            .foregroundStyle(.blue)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color.blue.opacity(0.1))
                    )
                }
            }
            
            if isCompact {
                // Compact mode: single line with date and exercise count
                Text("\(compactDateString) • \(workout.exerciseCount) \(workout.exerciseCount == 1 ? "exercise" : "exercises")")
                    .font(.system(.caption, weight: .regular))
                    .foregroundStyle(.secondary)
            } else {
                // Full mode: icons and separate lines
                HStack(spacing: 16) {
                    // Workout date
                    Label {
                        Text(workout.formattedDate)
                            .font(.system(.subheadline, weight: .regular))
                    } icon: {
                        Image(systemName: "calendar")
                            .font(.system(.caption2, weight: .medium))
                    }
                    .foregroundStyle(.secondary)
                    
                    // Number of exercises
                    Label {
                        Text("\(workout.exerciseCount) \(workout.exerciseCount == 1 ? "exercise" : "exercises")")
                            .font(.system(.subheadline, weight: .regular))
                    } icon: {
                        Image(systemName: "figure.strengthtraining.traditional")
                            .font(.system(.caption2, weight: .medium))
                    }
                    .foregroundStyle(.secondary)
                    
                    Spacer()
                }
            }
        }
        .padding(.vertical, isCompact ? 12 : 16)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.black.opacity(0.6))
                Group {
                    if useBorder {
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color(.separator).opacity(0.5), lineWidth: 1.0)
                    } else {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(accentColor)
                    }
                }
                // Active workout border highlight
                if isActive {
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.blue.opacity(0.25), lineWidth: 1)
                }
            }
        )
    }
}

// MARK: - Workout Selector View
struct WorkoutSelectorView: View {
    let templates: [Workout]
    let onSelect: (Workout?) -> Void  // nil = start new, Workout = use template
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Full screen black background
                Color.black
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Start New Workout option - Prominent card
                        Button {
                            onSelect(nil)
                        } label: {
                            VStack(spacing: 12) {
                                ZStack {
                                    Circle()
                                        .fill(Color.blue.opacity(0.15))
                                        .frame(width: 48, height: 48)
                                    
                                    Image(systemName: "plus.circle.fill")
                                        .font(.system(size: 24, weight: .medium))
                                        .foregroundStyle(.blue)
                                }
                                
                                VStack(spacing: 4) {
                                    Text("Start New Workout")
                                        .font(.system(.title2, weight: .semibold))
                                        .foregroundStyle(.primary)
                                    Text("Create a workout from scratch")
                                        .font(.system(.subheadline, weight: .regular))
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .padding(.horizontal, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.black.opacity(0.6))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        
                        // Templates Section
                        if !templates.isEmpty {
                            VStack(alignment: .leading, spacing: 16) {
                                HStack {
                                    Image(systemName: "doc.text.fill")
                                        .font(.system(.subheadline, weight: .semibold))
                                        .foregroundStyle(.blue)
                                    Text("Templates")
                                        .font(.system(.title3, weight: .bold))
                                        .foregroundStyle(.primary)
                                    Spacer()
                                    Text("\(templates.count)")
                                        .font(.system(.subheadline, weight: .medium))
                                        .foregroundStyle(.secondary)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(
                                            Capsule()
                                                .fill(Color(.tertiarySystemBackground))
                                        )
                                }
                                .padding(.horizontal, 16)
                                
                                ForEach(templates) { template in
                                    Button {
                                        onSelect(template)
                                    } label: {
                                        TemplateCardView(template: template)
                                    }
                                    .buttonStyle(.plain)
                                    .padding(.horizontal, 16)
                                }
                            }
                            .padding(.bottom, 8)
                        } else {
                            VStack(spacing: 12) {
                                Image(systemName: "doc.text")
                                    .font(.system(size: 48))
                                    .foregroundStyle(.secondary.opacity(0.5))
                                Text("No Templates")
                                    .font(.system(.headline, weight: .medium))
                                    .foregroundStyle(.secondary)
                                Text("Create templates to quickly start workouts")
                                    .font(.system(.subheadline, weight: .regular))
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 40)
                            .padding(.horizontal, 16)
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
            .navigationTitle("Start Workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .presentationBackground(Color.black)
    }
}

// MARK: - Template Card View
struct TemplateCardView: View {
    let template: Workout
    
    var body: some View {
        HStack(spacing: 16) {
            // Icon/Visual Indicator
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.blue.opacity(0.1))
                    .frame(width: 48, height: 48)
                
                Image(systemName: "doc.text.fill")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(.blue)
            }
            
            // Content
            VStack(alignment: .leading, spacing: 8) {
                Text(template.name)
                    .font(.system(.headline, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                
                HStack(spacing: 16) {
                    // Exercise count
                    HStack(spacing: 6) {
                        Image(systemName: "figure.strengthtraining.traditional")
                            .font(.system(.caption, weight: .medium))
                            .foregroundStyle(.secondary)
                        Text("\(template.exerciseCount)")
                            .font(.system(.subheadline, weight: .medium))
                            .foregroundStyle(.secondary)
                        Text(template.exerciseCount == 1 ? "exercise" : "exercises")
                            .font(.system(.caption, weight: .regular))
                            .foregroundStyle(.secondary)
                    }
                    
                    // Set count (if template has sets)
                    if template.totalSets > 0 {
                        HStack(spacing: 6) {
                            Image(systemName: "list.bullet")
                                .font(.system(.caption, weight: .medium))
                                .foregroundStyle(.secondary)
                            Text("\(template.totalSets)")
                                .font(.system(.subheadline, weight: .medium))
                                .foregroundStyle(.secondary)
                            Text(template.totalSets == 1 ? "set" : "sets")
                                .font(.system(.caption, weight: .regular))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            
            Spacer()
            
            // Chevron
            Image(systemName: "chevron.right")
                .font(.system(.subheadline, weight: .semibold))
                .foregroundStyle(.secondary.opacity(0.5))
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.6))
                .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.blue.opacity(0.25), lineWidth: 1)
        )
    }
}

// MARK: - Workout History View
struct WorkoutHistoryView: View {
    let workouts: [Workout]
    var onLogAgain: ((Workout) -> Void)? = nil
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var navigationPath = NavigationPath()
    
    // Group workouts by date
    private var groupedWorkouts: [(Date, [Workout])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: workouts) { workout in
            calendar.startOfDay(for: workout.date)
        }
        return grouped.sorted { $0.key > $1.key }
    }
    
    private func sectionHeader(for date: Date) -> String {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let workoutDay = calendar.startOfDay(for: date)
        
        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else if let days = calendar.dateComponents([.day], from: workoutDay, to: today).day, days < 7 {
            return "\(days) days ago"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMMM d, yyyy"
            return formatter.string(from: date)
        }
    }
    
    var body: some View {
        NavigationStack(path: $navigationPath) {
            List {
                if workouts.isEmpty {
                    ContentUnavailableView(
                        "No History",
                        systemImage: "clock",
                        description: Text("Completed workouts will appear here")
                    )
                } else {
                    ForEach(groupedWorkouts, id: \.0) { date, workoutsForDate in
                        Section {
                            ForEach(workoutsForDate) { workout in
                                ZStack {
                                    NavigationLink(value: workout.id.uuidString) {
                                        Color.clear
                                            .contentShape(Rectangle())
                                    }
                                    
                                    HistoryWorkoutRowView(workout: workout)
                                }
                                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                                .listRowSeparator(.hidden)
                                .listRowBackground(Color.clear)
                            }
                            .onDelete { indexSet in
                                deleteWorkouts(at: indexSet, from: workoutsForDate)
                            }
                        } header: {
                            HStack {
                                Text(sectionHeader(for: date))
                                    .font(.system(.subheadline, weight: .semibold))
                                Spacer()
                                Text("\(workoutsForDate.count)")
                                    .font(.system(.caption, weight: .semibold))
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 2)
                                    .background(
                                        Capsule()
                                            .fill(Color(.systemGray5))
                                    )
                            }
                            .foregroundStyle(.secondary)
                            .textCase(nil)
                        }
                    }
                }
            }
            .navigationDestination(for: String.self) { workoutId in
                if let workout = workouts.first(where: { $0.id.uuidString == workoutId }) {
                    WorkoutDetailView(workout: workout, onLogAgain: onLogAgain)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Color.black)
            .navigationTitle("Workout History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .presentationBackground(Color.black)
    }
    
    private func deleteWorkouts(at offsets: IndexSet, from workoutsForDate: [Workout]) {
        for index in offsets {
            let workout = workoutsForDate[index]
            modelContext.delete(workout)
        }
        do {
            try modelContext.save()
        } catch {
            print("Error deleting workout: \(error)")
        }
    }
}

// MARK: - History Workout Row View
struct HistoryWorkoutRowView: View {
    let workout: Workout

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: workout.date)
    }

    // Get first 2-3 exercise names for preview (in saved order)
    private var exercisePreview: String? {
        let exercises = workout.exercisesByOrder
        guard !exercises.isEmpty else { return nil }
        let names = exercises.prefix(3).map { $0.name }
        let joined = names.joined(separator: ", ")
        if exercises.count > 3 {
            return joined + ", ..."
        }
        return joined
    }

    var body: some View {
        HStack(spacing: 14) {
            // Date indicator with subtle accent
            VStack(spacing: 4) {
                Text(formattedDate)
                    .font(.system(.caption, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 50)
            }

            // Main content
            VStack(alignment: .leading, spacing: 6) {
                Text(workout.name)
                    .font(.system(.headline, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                // Exercise names preview
                if let preview = exercisePreview {
                    Text(preview)
                        .font(.system(.caption, weight: .regular))
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }

                HStack(spacing: 16) {
                    HStack(spacing: 4) {
                        Image(systemName: "figure.strengthtraining.traditional")
                            .font(.system(.caption2, weight: .medium))
                            .foregroundStyle(.green)
                        Text("\(workout.exerciseCount)")
                            .font(.system(.subheadline, weight: .semibold))
                    }
                    .foregroundStyle(.secondary)
                    
                    if workout.totalSets > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "list.bullet")
                                .font(.system(.caption2, weight: .medium))
                            Text("\(workout.totalSets)")
                                .font(.system(.subheadline, weight: .semibold))
                        }
                        .foregroundStyle(.secondary)
                    }
                    
                    if let endTime = workout.endTime, let startTime = workout.startTime {
                        let duration = endTime.timeIntervalSince(startTime)
                        let hours = Int(duration) / 3600
                        let minutes = Int(duration) / 60 % 60
                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                                .font(.system(.caption2, weight: .medium))
                            if hours > 0 {
                                Text("\(hours)h \(minutes)m")
                                    .font(.system(.subheadline, weight: .semibold))
                            } else {
                                Text("\(minutes)m")
                                    .font(.system(.subheadline, weight: .semibold))
                            }
                        }
                        .foregroundStyle(.secondary)
                    }
                }
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.system(.caption, weight: .semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.6))
                .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 2)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.blue.opacity(0.25), lineWidth: 1)
                )
        )
    }
}

#Preview {
    WorkoutListView()
        .modelContainer(for: [Workout.self, Exercise.self, WorkoutSet.self, ExerciseMemory.self], inMemory: true)
}
