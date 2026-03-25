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
    @Environment(ProManager.self) private var proManager
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
    @AppStorage("userName") private var userName: String = ""
    @State private var showingDeleteTemplateConfirmation = false
    @State private var pendingDeleteTemplate: Workout?
    @State private var templateToConfirm: Workout? = nil
    @State private var showingEndWorkoutConfirmation = false

    // Migration backup prompt
    @AppStorage("hasSeenBackupPrompt") private var hasSeenBackupPrompt = false
    @State private var showingBackupPrompt = false
    @State private var showConfetti = false
    @State private var lastCelebratedStreak: Int = 0
    @AppStorage("weeklyWorkoutGoal") private var weeklyWorkoutGoal: Int = 4
    @AppStorage("startWorkoutOnLaunch") private var startWorkoutOnLaunch = false

    // Gamification
    @State private var gamificationEngine = GamificationEngine()
    @Query private var allPRs: [PersonalRecord]
    @Query private var unlockedAchievements: [Achievement]
    @State private var pendingCelebration: AchievementDefinition?

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

        // Build a set of workout days for O(1) lookup instead of O(n) per day
        let workoutDays = Set(workoutHistory.map { calendar.startOfDay(for: $0.date) })

        let hasWorkoutToday = workoutDays.contains(today)
        var currentDate = hasWorkoutToday ? today : calendar.date(byAdding: .day, value: -1, to: today)!

        while workoutDays.contains(currentDate) {
            streak += 1
            currentDate = calendar.date(byAdding: .day, value: -1, to: currentDate)!
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
                    HStack(alignment: .top, spacing: 12) {
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
                            } else {
                                Text("\(greeting), \(userName)!")
                                    .font(.system(.title2, weight: .bold))
                                    .foregroundStyle(.primary)
                            }

                            if daysSinceLastWorkout > 0 && activeWorkout == nil && totalWorkouts > 0 {
                                RestDayMessage(daysSinceLastWorkout: daysSinceLastWorkout)
                            } else {
                                Text("Ready to work out?")
                                    .font(.system(.subheadline, weight: .regular))
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Spacer()

                        if totalWorkouts > 0 {
                            WeeklyGoalRing(current: thisWeekWorkouts, goal: weeklyWorkoutGoal, color: AppColors.accentGold)
                        }
                    }
                    .padding(.vertical, 8)
                    .staggeredAppear(index: 0, maxStagger: 4)
                } header: {
                    EmptyView()
                }
                .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 8, trailing: 16))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)

                // Quick Glance Summary (only for returning users)
                if totalWorkouts > 0 {
                    Section {
                        HomeSummaryCard(
                            streak: workoutStreak,
                            stats: gamificationEngine.weeklyStats,
                            thisWeekWorkouts: thisWeekWorkouts,
                            weeklyGoal: weeklyWorkoutGoal
                        )
                        .staggeredAppear(index: 1, maxStagger: 4)
                    } header: {
                        EmptyView()
                    }
                    .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 8, trailing: 16))
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
                                .shimmerEffect()
                                .depthShadow(color: AppColors.accent, radius: 12)
                        }
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                    } header: {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(AppColors.accent)
                                .frame(width: 8, height: 8)
                            Text("Active Workout")
                                .font(.system(.subheadline, weight: .bold))
                        }
                        .foregroundStyle(.primary)
                        .textCase(nil)
                    }
                }

                // Template Carousel
                Section {
                        ScrollView(.horizontal, showsIndicators: false) {
                            LazyHStack(spacing: 16) {
                                ForEach(templates) { template in
                                    TemplateHeroCard(template: template) {
                                        if activeWorkout != nil {
                                            templateToConfirm = template
                                            showingEndWorkoutConfirmation = true
                                        } else {
                                            startWorkoutFromTemplate(template: template)
                                        }
                                    } onEdit: {
                                        navigationPath.append(template.id.uuidString)
                                    }
                                    .containerRelativeFrame(.horizontal) { size, _ in
                                        size - 48
                                    }
                                    .visualEffect { content, proxy in
                                        let frame = proxy.frame(in: .scrollView(axis: .horizontal))
                                        let scrollWidth = proxy.bounds(of: .scrollView(axis: .horizontal))?.width ?? 1
                                        let midX = frame.midX
                                        let distance = midX - scrollWidth / 2
                                        let normalized = distance / (scrollWidth / 2)
                                        let clamped = max(-1, min(1, normalized))

                                        return content
                                            .scaleEffect(1.0 - abs(clamped) * 0.08)
                                            .rotation3DEffect(
                                                .degrees(clamped * 18),
                                                axis: (x: 0, y: 1, z: 0),
                                                perspective: 0.4
                                            )
                                            .offset(y: abs(clamped) * 14)
                                    }
                                }

                                // "Create Template" as the last card in the carousel
                                NewTemplateCard {
                                    editingTemplate = nil
                                    showingTemplateEditor = true
                                    Analytics.send(Analytics.Signal.templateCreated)
                                }
                                .containerRelativeFrame(.horizontal) { size, _ in
                                    templates.isEmpty ? size : size - 48
                                }
                                .visualEffect { content, proxy in
                                    let frame = proxy.frame(in: .scrollView(axis: .horizontal))
                                    let scrollWidth = proxy.bounds(of: .scrollView(axis: .horizontal))?.width ?? 1
                                    let midX = frame.midX
                                    let distance = midX - scrollWidth / 2
                                    let normalized = distance / (scrollWidth / 2)
                                    let clamped = max(-1, min(1, normalized))

                                    return content
                                        .scaleEffect(1.0 - abs(clamped) * 0.08)
                                        .rotation3DEffect(
                                            .degrees(clamped * 18),
                                            axis: (x: 0, y: 1, z: 0),
                                            perspective: 0.4
                                        )
                                        .offset(y: abs(clamped) * 14)
                                }
                            }
                            .scrollTargetLayout()
                            .padding(.vertical, 4)
                        }
                        .scrollTargetBehavior(.viewAligned)
                        .contentMargins(.horizontal, 20)
                        .frame(height: 220)
                    } header: {
                        HStack {
                            Image(systemName: "rectangle.stack.fill")
                                .font(.system(.caption, weight: .bold))
                                .foregroundStyle(AppColors.accent)
                            Text("Templates")
                                .font(.system(.subheadline, weight: .bold))
                            Spacer()
                        }
                        .foregroundStyle(.primary)
                        .textCase(nil)
                    }
                    .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)

                    // CTA button
                    Section {
                        Button {
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            if activeWorkout != nil {
                                templateToConfirm = nil
                                showingEndWorkoutConfirmation = true
                            } else {
                                startWorkoutFromTemplate(template: nil)
                            }
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "figure.run")
                                Text("Start New Workout")
                            }
                            .font(.system(.body, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(
                                LinearGradient(
                                    colors: AppColors.accentGradient,
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .shimmerEffect()
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                        .shadow(color: AppColors.accent.opacity(0.3), radius: 12, y: 6)
                        .accessibilityIdentifier("startWorkoutButton")
                    } header: { EmptyView() }
                    .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 8, trailing: 16))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)

                // Recent Workouts Section (inline horizontal scroll)
                if !recentWorkouts.isEmpty {
                    Section {
                        VStack(alignment: .leading, spacing: 12) {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(Array(recentWorkouts.enumerated()), id: \.element.id) { index, workout in
                                        RecentWorkoutCard(workout: workout) {
                                            navigationPath.append(workout.id.uuidString)
                                        }
                                        .visualEffect { content, proxy in
                                            let frame = proxy.frame(in: .scrollView(axis: .horizontal))
                                            let scrollWidth = proxy.bounds(of: .scrollView(axis: .horizontal))?.width ?? 1
                                            let midX = frame.midX
                                            let distance = midX - scrollWidth / 2
                                            let normalized = distance / (scrollWidth / 2)
                                            let clamped = max(-1, min(1, normalized))

                                            return content
                                                .scaleEffect(1.0 - abs(clamped) * 0.06)
                                                .offset(y: abs(clamped) * 6)
                                        }
                                    }
                                }
                                .padding(.horizontal, 4)
                            }

                            Button {
                                showingWorkoutHistory = true
                            } label: {
                                HStack {
                                    Text("View All History")
                                        .font(.system(.subheadline, weight: .medium))
                                    Image(systemName: "chevron.right")
                                        .font(.system(.caption, weight: .semibold))
                                }
                                .foregroundStyle(AppColors.accent)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(AppColors.accent.opacity(0.1))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 10)
                                                .stroke(AppColors.accent.opacity(0.2), lineWidth: 1)
                                        )
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    } header: {
                        HStack {
                            Image(systemName: "clock.arrow.circlepath")
                                .font(.system(.caption, weight: .bold))
                                .foregroundStyle(AppColors.accent)
                            Text("Recent Workouts")
                                .font(.system(.subheadline, weight: .bold))
                            Spacer()
                            Text("\(workoutHistory.count) total")
                                .font(.system(.caption2, weight: .medium))
                                .foregroundStyle(.tertiary)
                        }
                        .foregroundStyle(.primary)
                        .textCase(nil)
                    }
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                }

                // PR Timeline Widget
                if !workoutHistory.isEmpty {
                    Section {
                        PRHomeWidgetView()
                    } header: {
                        EmptyView()
                    }
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    .listRowSeparator(.hidden)
                    .listSectionSeparator(.hidden)
                    .listRowBackground(Color.clear)
                }

            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background {
                ZStack {
                    AppColors.background
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
            .sheet(isPresented: $showingTemplateEditor) {
                if let template = editingTemplate {
                    TemplateEditView(template: template)
                } else {
                    TemplateEditView(template: nil)
                }
            }
            .overlay {
                if let definition = pendingCelebration {
                    AchievementCelebrationView(definition: definition) {
                        pendingCelebration = nil
                    }
                    .transition(.opacity)
                    .zIndex(100)
                }
            }
            .alert("Delete Template", isPresented: $showingDeleteTemplateConfirmation) {
                Button("Cancel", role: .cancel) {
                    pendingDeleteTemplate = nil
                }
                Button("Delete", role: .destructive) {
                    if let template = pendingDeleteTemplate {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                            modelContext.delete(template)
                        }
                        try? modelContext.save()
                        pendingDeleteTemplate = nil
                    }
                }
            } message: {
                Text("Are you sure you want to delete the template \"\(pendingDeleteTemplate?.name ?? "")\"? This cannot be undone.")
            }
            .alert("End Current Workout?", isPresented: $showingEndWorkoutConfirmation) {
                Button("End & Start New", role: .destructive) {
                    startWorkoutFromTemplate(template: templateToConfirm)
                }
                Button("Cancel", role: .cancel) {
                    templateToConfirm = nil
                }
            } message: {
                if let t = templateToConfirm {
                    Text("This will end your active workout and start \"\(t.name)\".")
                } else {
                    Text("This will end your active workout and start a new one.")
                }
            }
            .alert("Back Up Your Data", isPresented: $showingBackupPrompt) {
                Button("OK") {
                    hasSeenBackupPrompt = true
                }
                Button("Remind Me Later", role: .cancel) { }
                Button("Don't Show Again") {
                    hasSeenBackupPrompt = true
                }
            } message: {
                Text("We recommend exporting a backup of your workout data. Go to Profile > Data & Backup to export.")
            }
            .task {
                #if DEBUG
                // Clear all data for UI testing mode (clean state for each test)
                if CommandLine.arguments.contains("--uitesting") && !hasCheckedActiveWorkout {
                    do {
                        // Delete all workouts (including templates)
                        let workoutDescriptor = FetchDescriptor<Workout>()
                        let allWorkouts = try modelContext.fetch(workoutDescriptor)
                        for workout in allWorkouts {
                            modelContext.delete(workout)
                        }

                        // Delete all exercise memories
                        let memoryDescriptor = FetchDescriptor<ExerciseMemory>()
                        let memories = try modelContext.fetch(memoryDescriptor)
                        for memory in memories {
                            modelContext.delete(memory)
                        }

                        // Delete all personal records
                        let prDescriptor = FetchDescriptor<PersonalRecord>()
                        let prs = try modelContext.fetch(prDescriptor)
                        for pr in prs {
                            modelContext.delete(pr)
                        }

                        // Delete all achievements
                        let achievementDescriptor = FetchDescriptor<Achievement>()
                        let achievements = try modelContext.fetch(achievementDescriptor)
                        for achievement in achievements {
                            modelContext.delete(achievement)
                        }

                        try modelContext.save()
                        debugLog("[TheLogger] UI Testing: Cleared all data for clean test state")
                    } catch {
                        debugLog("[TheLogger] UI Testing: Failed to clear data - \(error)")
                    }
                }
                #endif

                // Auto-navigate to active workout on app launch (only once)
                if !hasCheckedActiveWorkout {
                    hasCheckedActiveWorkout = true

                    // Handle "Start First Workout" from onboarding
                    if startWorkoutOnLaunch {
                        startWorkoutOnLaunch = false
                        startWorkoutFromTemplate(template: nil)
                    } else if let activeWorkout = activeWorkout {
                        navigationPath.append(activeWorkout.id.uuidString)
                    }

                    // Show migration backup prompt for existing users
                    if !hasSeenBackupPrompt {
                        let hasCompletedWorkouts = workouts.contains { !$0.isTemplate && $0.endTime != nil }
                        if hasCompletedWorkouts {
                            showingBackupPrompt = true
                        }
                    }
                }

                // Refresh gamification stats
                refreshGamification()
            }
            .onChange(of: workouts.count) { _, _ in
                refreshGamification()
                checkAchievements()
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
            .navigationDestination(for: String.self) { workoutId in
                // Check both workouts and templates arrays
                if let workout = workouts.first(where: { $0.id.uuidString == workoutId }) {
                    let _ = debugLog("✅ Found workout: \(workout.name)")
                    WorkoutDetailView(workout: workout, onLogAgain: { logAgainFrom(workout: $0) })
                } else if let template = templates.first(where: { $0.id.uuidString == workoutId }) {
                    let _ = debugLog("✅ Found template: \(template.name)")
                    WorkoutDetailView(workout: template, onLogAgain: { logAgainFrom(workout: $0) })
                } else {
                    let _ = debugLog("❌ No workout found for ID: \(workoutId)")
                    Text("Workout not found")
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
            debugLog("Warning: Active workout still exists, aborting new workout creation")
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
        Analytics.send(Analytics.Signal.workoutStarted, parameters: ["source": template != nil ? "template" : "blank"])

        do {
            try modelContext.save()
            // Sync to widget
            newWorkout.syncToWidget()
            // Start Live Activity for lock screen logging with actual data
            if let firstExercise = newWorkout.exercises?.first {
                let sets = firstExercise.setsByOrder
                let lastSet = sets.last
                LiveActivityManager.shared.startActivity(
                    workoutId: newWorkout.id,
                    workoutName: newWorkout.name,
                    exerciseName: firstExercise.name,
                    exerciseId: firstExercise.id,
                    exerciseSets: sets.count,
                    lastReps: lastSet?.reps ?? 0,
                    lastWeight: lastSet?.weight ?? 0
                )
            } else {
                LiveActivityManager.shared.startActivity(
                    workoutId: newWorkout.id,
                    workoutName: newWorkout.name,
                    exerciseName: "Workout",
                    exerciseId: UUID()
                )
            }
            // Navigate to the workout detail view
            navigationPath.append(newWorkout.id.uuidString)
        } catch {
            debugLog("Error starting workout: \(error)")
        }
    }

    private func duplicateWorkoutFromTemplate(_ template: Workout) -> Workout {
        // Create new workout with today's date and copy the name
        let newWorkout = Workout(name: template.name, date: Date(), isTemplate: false)
        let templateExercises = template.exercisesByOrder

        // Copy all exercises with their sets from template
        for (index, exercise) in templateExercises.enumerated() {
            let newExercise = Exercise(name: exercise.name, order: index)

            // Copy sets from template if they exist
            if let templateSets = exercise.sets, !templateSets.isEmpty {
                var copiedSets: [WorkoutSet] = []
                for (setIndex, templateSet) in exercise.setsByOrder.enumerated() {
                    let copiedSet = WorkoutSet(
                        reps: templateSet.reps,
                        weight: templateSet.weight,
                        durationSeconds: templateSet.durationSeconds,
                        setType: templateSet.type,
                        sortOrder: setIndex
                    )
                    copiedSets.append(copiedSet)
                }
                newExercise.sets = copiedSets
            }

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

            let isTimeBased = ExerciseLibrary.shared.find(name: exercise.name)?.isTimeBased ?? false
            if let previousExercise = Exercise.findPreviousExercise(
                name: exercise.name,
                excludingWorkoutId: newWorkout.id,
                modelContext: modelContext
            ) {
                for previousSet in previousExercise.setsByOrder {
                    if isTimeBased {
                        newExercise.addSet(reps: 0, weight: 0, durationSeconds: previousSet.durationSeconds)
                    } else {
                        newExercise.addSet(reps: previousSet.reps, weight: previousSet.weight)
                    }
                }
                newExercise.isAutoFilled = true
            } else if let memory = memories.first(where: { $0.normalizedName == normalizedName }) {
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
        Analytics.send(Analytics.Signal.workoutStarted, parameters: ["source": "logAgain"])

        do {
            try modelContext.save()
            newWorkout.syncToWidget()
            // Start Live Activity with actual exercise data
            if let firstExercise = newWorkout.exercises?.first {
                let sets = firstExercise.setsByOrder
                let lastSet = sets.last
                LiveActivityManager.shared.startActivity(
                    workoutId: newWorkout.id,
                    workoutName: newWorkout.name,
                    exerciseName: firstExercise.name,
                    exerciseId: firstExercise.id,
                    exerciseSets: sets.count,
                    lastReps: lastSet?.reps ?? 0,
                    lastWeight: lastSet?.weight ?? 0
                )
            } else {
                LiveActivityManager.shared.startActivity(
                    workoutId: newWorkout.id,
                    workoutName: newWorkout.name,
                    exerciseName: "Workout",
                    exerciseId: UUID()
                )
            }
            navigationPath.append(newWorkout.id.uuidString)
        } catch {
            debugLog("Error starting workout: \(error)")
        }
    }

    // MARK: - Gamification

    private func refreshGamification() {
        gamificationEngine.refresh(
            workouts: workouts,
            prs: allPRs,
            weeklyGoal: weeklyWorkoutGoal
        )
    }

    private func checkAchievements() {
        let unlockedIds = Set(unlockedAchievements.map(\.id))
        let context = AchievementManager.buildContext(
            workouts: workouts,
            prs: allPRs,
            streakData: gamificationEngine.streakData
        )

        let newlyUnlocked = AchievementManager.checkAll(context: context, alreadyUnlocked: unlockedIds)
        for definition in newlyUnlocked {
            // Only persist achievement unlocks for Pro users
            if proManager.isPro {
                let achievement = Achievement(id: definition.id)
                modelContext.insert(achievement)
            }
            Analytics.send(Analytics.Signal.achievementUnlocked, parameters: ["id": definition.id, "name": definition.name])
        }

        if !newlyUnlocked.isEmpty {
            try? modelContext.save()
            // Show celebration for the first newly unlocked achievement
            pendingCelebration = newlyUnlocked.first
        }
    }
}

// MARK: - Home Summary Card

private struct HomeSummaryCard: View {
    let streak: Int
    let stats: WeeklyStats
    let thisWeekWorkouts: Int
    let weeklyGoal: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Row 1: Streak badge + key numbers
            HStack(spacing: 0) {
                if streak > 0 {
                    HStack(spacing: 4) {
                        Text("\u{1F525}")
                            .font(.system(.caption))
                        Text("\(streak)-day streak")
                            .font(.system(.caption, weight: .semibold))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        Capsule()
                            .fill(AppColors.accentGold.opacity(0.15))
                    )
                    .foregroundStyle(AppColors.accentGold)

                    Spacer()
                }

                Text("\(stats.workoutCount) workout\(stats.workoutCount == 1 ? "" : "s")")
                    .foregroundStyle(.secondary)
                Text("  ·  ")
                    .foregroundStyle(.tertiary)
                Text("\(stats.totalSets) sets")
                    .foregroundStyle(.secondary)
                Text("  ·  ")
                    .foregroundStyle(.tertiary)
                if let delta = stats.volumeDelta {
                    Text("\(delta >= 0 ? "\u{2191}" : "\u{2193}")\(String(format: "%.0f", abs(delta)))% vol")
                        .foregroundStyle(delta >= 0 ? AppColors.accentGold : .red)
                } else {
                    Text("\(formatVolume(stats.totalVolume)) \(UnitFormatter.weightUnit)")
                        .foregroundStyle(.secondary)
                }

                if streak == 0 {
                    Spacer()
                }
            }
            .font(.system(.subheadline, weight: .medium))

            // Row 2: Weekly goal progress bar
            VStack(spacing: 4) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(AppColors.accent.opacity(0.12))
                            .frame(height: 6)
                        Capsule()
                            .fill(AppColors.accent)
                            .frame(width: geo.size.width * min(1.0, CGFloat(thisWeekWorkouts) / max(1, CGFloat(weeklyGoal))), height: 6)
                    }
                }
                .frame(height: 6)

                HStack {
                    Text("Weekly goal")
                        .font(.system(.caption2))
                        .foregroundStyle(.tertiary)
                    Spacer()
                    Text("\(thisWeekWorkouts)/\(weeklyGoal)")
                        .font(.system(.caption2, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    LinearGradient(
                        colors: [AppColors.accent.opacity(0.3), AppColors.accentGold.opacity(0.15), .clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        }
        .accessibilityIdentifier("homeSummaryCard")
    }

    private func formatVolume(_ volume: Double) -> String {
        let display = UnitFormatter.convertToDisplay(volume)
        if display >= 1000 {
            return String(format: "%.1fk", display / 1000)
        }
        return String(format: "%.0f", display)
    }
}

// MARK: - Template Carousel Cards

private struct TemplateHeroCard: View {
    let template: Workout
    let onStart: () -> Void
    let onEdit: () -> Void

    private var exercises: [Exercise] {
        template.exercisesByOrder
    }

    var body: some View {
        Button {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            onStart()
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                // Header row
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(template.name.isEmpty ? "Unnamed Template" : template.name)
                            .font(.system(.title3, weight: .bold))
                            .foregroundStyle(.primary)
                            .lineLimit(1)

                        if !exercises.isEmpty {
                            Text("\(exercises.count) exercise\(exercises.count == 1 ? "" : "s")")
                                .font(.system(.caption2, weight: .medium))
                                .foregroundStyle(.tertiary)
                        }
                    }

                    Spacer()

                    Button(action: onEdit) {
                        Image(systemName: "pencil")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.secondary)
                            .frame(width: 32, height: 32)
                            .background(Circle().fill(Color.white.opacity(0.08)))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)

                Spacer(minLength: 8)

                // Exercise list
                VStack(alignment: .leading, spacing: 5) {
                    let displayCount = min(exercises.count, 4)
                    let overflow = exercises.count - displayCount
                    ForEach(exercises.prefix(displayCount)) { exercise in
                        HStack(spacing: 8) {
                            Circle()
                                .fill(AppColors.accent.opacity(0.6))
                                .frame(width: 5, height: 5)
                            Text(exercise.name)
                                .font(.system(.subheadline))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                    if overflow > 0 {
                        Text("+\(overflow) more")
                            .font(.system(.caption))
                            .foregroundStyle(.tertiary)
                            .padding(.leading, 13)
                    }
                }
                .padding(.horizontal, 16)

                Spacer(minLength: 8)

                // Tap-to-start hint
                HStack {
                    Spacer()
                    HStack(spacing: 6) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 10))
                        Text("Tap to start")
                            .font(.system(.caption2, weight: .medium))
                    }
                    .foregroundStyle(AppColors.accent.opacity(0.6))
                    .padding(.trailing, 16)
                    .padding(.bottom, 12)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 190)
            .background {
                RoundedRectangle(cornerRadius: 12)
                    .fill(AppColors.accent.opacity(0.06))
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(AppColors.accent.opacity(0.2), lineWidth: 1)
            }
            .shadow(color: AppColors.accent.opacity(0.12), radius: 16, y: 8)
        }
        .buttonStyle(.plain)
    }
}

private struct NewTemplateCard: View {
    let onCreate: () -> Void

    var body: some View {
        Button(action: onCreate) {
            VStack(spacing: 10) {
                Spacer()
                Image(systemName: "plus")
                    .font(.system(size: 28, weight: .medium))
                    .foregroundStyle(AppColors.accent.opacity(0.7))
                Text("Create Template")
                    .font(.system(.subheadline, weight: .semibold))
                    .foregroundStyle(AppColors.accent)
                Text("Save a routine to start fast")
                    .font(.system(.caption2))
                    .foregroundStyle(.tertiary)
                Spacer()
            }
            .frame(maxWidth: .infinity)
            .frame(height: 190)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(AppColors.accent.opacity(0.3), style: StrokeStyle(lineWidth: 1.5, dash: [8, 6]))
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(AppColors.accent.opacity(0.04))
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    WorkoutListView()
        .modelContainer(for: [Workout.self, Exercise.self, WorkoutSet.self, ExerciseMemory.self, PersonalRecord.self, Achievement.self], inMemory: true)
}
