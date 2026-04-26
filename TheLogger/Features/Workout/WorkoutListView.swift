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

    // Quick Start template selection
    @State private var selectedTemplateIndex: Int = -1
    @AppStorage("hasDismissedCameraTip") private var hasDismissedCameraTip = false

    // Rest day challenges
    @State private var restDayChallenge: DailyChallenge? = nil
    @State private var showRestDayPrompt = false
    @State private var restDayDismissed = false
    @State private var showChallengePicker = false
    @State private var showQuizSheet = false
    @State private var showQuickHitSheet = false
    @State private var showSpinWheelSheet = false

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

    private var hasActiveWorkout: Bool {
        activeWorkout != nil
    }

    private var hasWorkedOutToday: Bool {
        workoutHistory.contains { Calendar.current.isDateInToday($0.date) }
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
                    HStack(alignment: .center, spacing: 12) {
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

                        LevelAvatar(
                            name: userName,
                            totalWorkouts: totalWorkouts,
                            size: 48
                        )
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
                            thisWeekWorkouts: thisWeekWorkouts,
                            weeklyGoal: weeklyWorkoutGoal,
                            weekDays: thisWeekWorkoutDays
                        )
                        .staggeredAppear(index: 1, maxStagger: 4)
                    } header: {
                        EmptyView()
                    }
                    .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 8, trailing: 16))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                }

                // Active Workout Hero (show when workout is active)
                if let active = activeWorkout {
                    Section {
                        VStack(spacing: 16) {
                            VStack(spacing: 6) {
                                HStack(spacing: 6) {
                                    Circle()
                                        .fill(AppColors.accent)
                                        .frame(width: 8, height: 8)
                                    Text(active.name)
                                        .font(.system(.title3, weight: .bold))
                                        .foregroundStyle(.primary)
                                    Spacer()
                                }

                                // Live elapsed timer
                                TimelineView(.periodic(from: active.startTime ?? Date(), by: 1.0)) { _ in
                                    let elapsed = Date().timeIntervalSince(active.startTime ?? Date())
                                    Text(formatElapsed(elapsed))
                                        .font(.system(size: 64, weight: .bold, design: .monospaced))
                                        .foregroundStyle(LinearGradient(colors: AppColors.accentGradient, startPoint: .leading, endPoint: .trailing))
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }

                            Button {
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                Analytics.send(Analytics.Signal.workoutResumed)
                                navigationPath.append(active.id.uuidString)
                            } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: "play.fill")
                                    Text("Resume Workout")
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .gradientCTA()
                            .buttonStyle(.plain)
                        }
                        .padding(20)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.white.opacity(0.05))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(AppColors.accent.opacity(0.30), lineWidth: 1)
                                )
                        )
                    } header: { EmptyView() }
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                }

                // Rest Day Challenge (hidden if dismissed, has active workout, or already worked out today)
                if true { // TEMP: always show for testing — was: !restDayDismissed && !hasActiveWorkout
                    restDayChallengeCard
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                }

                // Quick Start Section — pill tabs + CTA (hidden when workout is in progress)
                if !hasActiveWorkout {
                Section {
                    VStack(spacing: 14) {
                        Text("QUICK START")
                            .font(.system(.caption2, weight: .semibold))
                            .foregroundStyle(Color.white.opacity(0.28))
                            .frame(maxWidth: .infinity, alignment: .leading)

                        // Horizontal template pill tabs
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(templates.indices, id: \.self) { i in
                                    let isSelected = selectedTemplateIndex == i
                                    Button {
                                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                            selectedTemplateIndex = isSelected ? -1 : i
                                        }
                                    } label: {
                                        Text(templates[i].name)
                                            .font(.system(.subheadline, weight: .semibold))
                                            .foregroundStyle(isSelected ? .white : .secondary)
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 9)
                                            .background(
                                                Capsule()
                                                    .fill(isSelected ? AppColors.accent : Color.white.opacity(0.08))
                                                    .overlay(
                                                        Capsule()
                                                            .stroke(isSelected ? Color.clear : Color.white.opacity(0.12), lineWidth: 1)
                                                    )
                                            )
                                    }
                                    .buttonStyle(.plain)
                                    .animation(.spring(response: 0.25, dampingFraction: 0.8), value: selectedTemplateIndex)
                                }

                                // "+ New" pill
                                Button {
                                    editingTemplate = nil
                                    showingTemplateEditor = true
                                    Analytics.send(Analytics.Signal.templateCreated)
                                } label: {
                                    HStack(spacing: 4) {
                                        Image(systemName: "plus")
                                            .font(.system(.caption, weight: .bold))
                                        Text("New")
                                            .font(.system(.subheadline, weight: .semibold))
                                    }
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 9)
                                    .background(
                                        Capsule()
                                            .fill(Color.white.opacity(0.06))
                                            .overlay(
                                                Capsule()
                                                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
                                            )
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                        }

                        // Full-width CTA
                        let selectedTemplate: Workout? = selectedTemplateIndex >= 0 && templates.indices.contains(selectedTemplateIndex) ? templates[selectedTemplateIndex] : nil

                        // Template exercise preview
                        if let template = selectedTemplate {
                            let exercises = template.exercisesByOrder
                            VStack(alignment: .leading, spacing: 5) {
                                ForEach(exercises) { exercise in
                                    let setCount = exercise.sets?.count ?? 0
                                    HStack(spacing: 8) {
                                        Circle()
                                            .fill(AppColors.accent.opacity(0.5))
                                            .frame(width: 5, height: 5)
                                        Text(exercise.name)
                                            .font(.system(size: 13, weight: .medium))
                                            .foregroundStyle(Color.white.opacity(0.65))
                                            .lineLimit(1)
                                        Spacer(minLength: 4)
                                        if setCount > 0 {
                                            Text("\(setCount) sets")
                                                .font(.system(size: 10, weight: .semibold))
                                                .foregroundStyle(AppColors.accent.opacity(0.65))
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(Capsule().fill(AppColors.accent.opacity(0.10)))
                                        }
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 2)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }

                        Button {
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            if let active = activeWorkout, active.isActive {
                                templateToConfirm = selectedTemplate
                                showingEndWorkoutConfirmation = true
                            } else if let t = selectedTemplate {
                                startWorkoutFromTemplate(template: t)
                            } else {
                                startWorkoutFromTemplate(template: nil)
                            }
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "play.fill")
                                Text(selectedTemplate != nil ? "Start \(selectedTemplate!.name)" : "Start Workout")
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .gradientCTA()
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("startWorkoutButton")

                        // Secondary link to start without a template
                        if selectedTemplate != nil {
                            Button {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    selectedTemplateIndex = -1
                                }
                            } label: {
                                Text("or start without template")
                                    .font(.system(.caption, weight: .medium))
                                    .foregroundStyle(Color.white.opacity(0.30))
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.plain)
                            .transition(.opacity)
                        }
                    }
                    .padding(16)
                    .background(
                        ZStack(alignment: .topTrailing) {
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color.white.opacity(0.04))
                            Circle()
                                .fill(AppColors.accent.opacity(0.10))
                                .frame(width: 100, height: 100)
                                .blur(radius: 35)
                                .offset(x: 10, y: -20)
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color.white.opacity(0.09), lineWidth: 1)
                        }
                    )
                    .shadow(color: Color.black.opacity(0.35), radius: 20, x: 0, y: 8)
                } header: {
                    EmptyView()
                }
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
                } // end if !hasActiveWorkout

                // Camera Tip Card (first 3 workouts)
                if totalWorkouts < 3 && !hasDismissedCameraTip {
                    Section {
                        HStack(spacing: 14) {
                            ZStack {
                                Circle()
                                    .fill(AppColors.accent.opacity(0.12))
                                    .frame(width: 44, height: 44)
                                Image(systemName: "camera.viewfinder")
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundStyle(AppColors.accent)
                            }
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Try Camera Rep Counter")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(.primary)
                                Text("Point your phone at yourself and the app counts your reps automatically.")
                                    .font(.system(size: 12))
                                    .foregroundStyle(Color.white.opacity(0.40))
                                    .lineLimit(2)
                            }
                            Spacer(minLength: 0)
                            Button {
                                withAnimation { hasDismissedCameraTip = true }
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(Color.white.opacity(0.25))
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(14)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(AppColors.accent.opacity(0.05))
                                .overlay(RoundedRectangle(cornerRadius: 14).stroke(AppColors.accent.opacity(0.15), lineWidth: 1))
                        )
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                    }
                }

                // PR Highlights
                if !workoutHistory.isEmpty {
                    Section {
                        PRHomeWidgetView()
                    } header: {
                        EmptyView()
                    }
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 4, trailing: 16))
                    .listRowSeparator(.hidden)
                    .listSectionSeparator(.hidden)
                    .listRowBackground(Color.clear)
                } else {
                    Section {
                        HStack(spacing: 10) {
                            Text("🏆")
                                .font(.system(size: 18))
                            VStack(alignment: .leading, spacing: 2) {
                                Text("PR Highlights")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(Color.white.opacity(0.40))
                                Text("Set personal records to see them here")
                                    .font(.system(size: 11))
                                    .foregroundStyle(Color.white.opacity(0.20))
                            }
                        }
                        .padding(.vertical, 8)
                        .listRowBackground(Color.white.opacity(0.03))
                        .listRowSeparator(.hidden)
                    }
                }

                // Recent Workouts Section
                if !recentWorkouts.isEmpty {
                    Section {
                        VStack(spacing: 0) {
                            ForEach(Array(recentWorkouts.enumerated()), id: \.element.id) { index, workout in
                                RecentWorkoutRow(
                                    workout: workout,
                                    prCount: allPRs.filter { $0.workoutId == workout.id }.count,
                                    onTap: { navigationPath.append(workout.id.uuidString) }
                                )
                                if index < recentWorkouts.count - 1 {
                                    Rectangle()
                                        .fill(Color.white.opacity(0.05))
                                        .frame(height: 1)
                                        .padding(.leading, 28)
                                }
                            }
                        }
                    } header: {
                        HStack {
                            Text("RECENT")
                                .font(.system(.caption2, weight: .semibold))
                                .foregroundStyle(Color.white.opacity(0.28))
                            Spacer()
                            Button("View all →") { showingWorkoutHistory = true }
                                .font(.system(.caption, weight: .semibold))
                                .foregroundStyle(AppColors.accent)
                        }
                        .textCase(nil)
                        .padding(.bottom, 4)
                    }
                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 8, trailing: 16))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                } else {
                    Section {
                        HStack(spacing: 10) {
                            Text("📋")
                                .font(.system(size: 18))
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Recent Workouts")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(Color.white.opacity(0.40))
                                Text("Your workout history will appear here")
                                    .font(.system(size: 11))
                                    .foregroundStyle(Color.white.opacity(0.20))
                            }
                        }
                        .padding(.vertical, 8)
                        .listRowBackground(Color.white.opacity(0.03))
                        .listRowSeparator(.hidden)
                    }
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
            .sheet(isPresented: $showQuizSheet) {
                if var challenge = restDayChallenge {
                    QuizChallengeView(challenge: Binding(
                        get: { challenge },
                        set: { challenge = $0; restDayChallenge = $0 }
                    ))
                    .presentationBackground(AppColors.background)
                }
            }
            .sheet(isPresented: $showQuickHitSheet) {
                if var challenge = restDayChallenge {
                    QuickHitChallengeView(challenge: Binding(
                        get: { challenge },
                        set: { challenge = $0; restDayChallenge = $0 }
                    ))
                    .presentationBackground(AppColors.background)
                }
            }
            .sheet(isPresented: $showSpinWheelSheet) {
                let canQuiz = ChallengeGenerator.canGenerateQuiz(workouts: workouts, prs: allPRs)
                SpinWheelView(
                    canQuiz: canQuiz,
                    workouts: workouts,
                    prs: allPRs,
                    onResult: { challenge in
                        restDayChallenge = challenge
                        challenge.save()
                        showSpinWheelSheet = false
                        // Open the appropriate sheet after a brief delay
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            if challenge.category == .quiz {
                                showQuizSheet = true
                            } else {
                                showQuickHitSheet = true
                            }
                        }
                    }
                )
                .presentationBackground(AppColors.background)
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
                        Analytics.send(Analytics.Signal.templateDeleted)
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
            .onReceive(NotificationCenter.default.publisher(for: .workoutEnded)) { _ in
                selectedTemplateIndex = -1
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

                // TEMP: Clear saved challenge for testing — remove before launch
                DailyChallenge.clearToday()

                // Load any saved rest day challenge
                if let saved = DailyChallenge.loadToday() {
                    restDayChallenge = saved
                    showChallengePicker = true
                }
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

    private func formatElapsed(_ elapsed: TimeInterval) -> String {
        let total = Int(max(0, elapsed))
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        } else {
            return String(format: "%02d:%02d", m, s)
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

    // MARK: - Rest Day Challenge Card

    @ViewBuilder
    private var restDayChallengeCard: some View {
        let streak = gamificationEngine.streakData.current

        if showChallengePicker {
            // Show completed state
            if let challenge = restDayChallenge, challenge.isCompleted {
                let doneColor = Color(red: 0.20, green: 0.70, blue: 0.40)  // muted green
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("✓ COMPLETED")
                            .font(.system(size: 9, weight: .bold))
                            .kerning(0.8)
                            .foregroundStyle(doneColor)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(doneColor.opacity(0.12)))
                        Spacer()
                        Text("🔥 \(streak + 1) day streak!")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Color.white.opacity(0.35))
                    }
                    HStack(spacing: 10) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(doneColor.opacity(0.7))
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Streak saved!")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(Color.white.opacity(0.80))
                            Text("+30 XP earned")
                                .font(.system(size: 12))
                                .foregroundStyle(AppColors.accentGold.opacity(0.7))
                        }
                    }
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 18)
                        .fill(doneColor.opacity(0.04))
                        .overlay(RoundedRectangle(cornerRadius: 18).stroke(doneColor.opacity(0.15), lineWidth: 1))
                )
            } else {
                // Show challenge options
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("REST DAY")
                            .font(.system(size: 9, weight: .bold))
                            .kerning(0.8)
                            .foregroundStyle(AppColors.accentGold)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(AppColors.accentGold.opacity(0.15)))
                        Spacer()
                        Text("🔥 \(streak) day streak")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Color.white.opacity(0.35))
                    }
                    Text("Keep Your Streak Alive")
                        .font(.system(size: 16, weight: .heavy))
                    Text("Pick a quick challenge — takes less than 3 minutes.")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.white.opacity(0.35))

                    let canQuiz = ChallengeGenerator.canGenerateQuiz(workouts: workouts, prs: allPRs)
                    ChallengePicker(
                        canQuiz: canQuiz,
                        workoutCount: workoutHistory.count,
                        onPickQuiz: {
                            if let quiz = ChallengeGenerator.generateQuiz(workouts: workouts, prs: allPRs) {
                                restDayChallenge = quiz
                                quiz.save()
                                Analytics.send(Analytics.Signal.restDayChallengeStarted, parameters: ["type": "quiz"])
                                showQuizSheet = true
                            }
                        },
                        onPickQuickHit: {
                            let hit = ChallengeGenerator.generateQuickHit()
                            restDayChallenge = hit
                            hit.save()
                            Analytics.send(Analytics.Signal.restDayChallengeStarted, parameters: ["type": "quickHit"])
                            showQuickHitSheet = true
                        },
                        onPickSpin: {
                            Analytics.send(Analytics.Signal.restDayChallengeStarted, parameters: ["type": "spin"])
                            showSpinWheelSheet = true
                        }
                    )

                    HStack(spacing: 6) {
                        Text("🔥")
                            .font(.system(size: 11))
                        Text("Keeps streak")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Color.white.opacity(0.28))
                        Text("+30 XP")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(AppColors.accentGold)
                    }
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 18)
                        .fill(AppColors.accentGold.opacity(0.05))
                        .overlay(RoundedRectangle(cornerRadius: 18).stroke(AppColors.accentGold.opacity(0.22), lineWidth: 1))
                )
            }
        } else {
            // Rest day prompt: "Taking a rest day?"
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("🔥 \(streak) day streak")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.35))
                    Spacer()
                }
                Text("Taking a rest day?")
                    .font(.system(size: 18, weight: .heavy))
                Text("Do a quick challenge to keep your streak alive.")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.white.opacity(0.35))

                HStack(spacing: 10) {
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            showChallengePicker = true
                        }
                    } label: {
                        Text("🏠 Yes, rest day")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(AppColors.accentGold)
                            .frame(maxWidth: .infinity)
                            .frame(height: 40)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(AppColors.accentGold.opacity(0.12))
                                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(AppColors.accentGold.opacity(0.25), lineWidth: 1))
                            )
                    }
                    .buttonStyle(.plain)

                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            restDayDismissed = true
                        }
                    } label: {
                        Text("💪 No, gym today")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color.white.opacity(0.40))
                            .frame(maxWidth: .infinity)
                            .frame(height: 40)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color.white.opacity(0.06))
                                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.10), lineWidth: 1))
                            )
                    }
                    .buttonStyle(.plain)
                }

                HStack(spacing: 4) {
                    Image(systemName: "flame")
                        .font(.system(size: 9))
                        .foregroundStyle(Color.white.opacity(0.18))
                    Text("Miss today and your streak resets")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.white.opacity(0.18))
                }
                .frame(maxWidth: .infinity)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color.white.opacity(0.03))
                    .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.white.opacity(0.10), lineWidth: 1))
            )
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

/// MARK: - Home Summary Card

private struct HomeSummaryCard: View {
    let streak: Int
    let thisWeekWorkouts: Int
    let weeklyGoal: Int
    let weekDays: Set<Int>

    // Days Mon–Sun (weekday 2–1 in Calendar; Mon=2, Sun=1)
    private let orderedWeekdays: [Int] = [2, 3, 4, 5, 6, 7, 1] // Mon→Sun

    var body: some View {
        HStack(spacing: 8) {
            // Streak pill
            if streak > 0 {
                HStack(spacing: 4) {
                    Text("🔥")
                        .font(.system(.caption))
                    Text("\(streak)")
                        .font(.system(.caption, weight: .bold))
                        .foregroundStyle(Color.white.opacity(0.88))
                    Text("streak")
                        .font(.system(.caption, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.55))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    Capsule()
                        .fill(AppColors.accentGold.opacity(0.13))
                )

                Circle()
                    .fill(Color.white.opacity(0.20))
                    .frame(width: 3, height: 3)
            }

            // Week dots + count
            HStack(spacing: 5) {
                HStack(spacing: 4) {
                    ForEach(orderedWeekdays, id: \.self) { day in
                        Circle()
                            .fill(weekDays.contains(day) ? AppColors.accent.opacity(0.85) : Color.white.opacity(0.15))
                            .frame(width: 7, height: 7)
                    }
                }

                Text("\(thisWeekWorkouts)")
                    .font(.system(.caption, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.88))
                Text("/\(weeklyGoal) this week")
                    .font(.system(.caption, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.55))
            }

            Spacer()
        }
        .accessibilityIdentifier("homeSummaryCard")
    }
}

// MARK: - Recent Workout Row

private struct RecentWorkoutRow: View {
    let workout: Workout
    let prCount: Int
    let onTap: () -> Void

    private var exerciseCount: Int {
        workout.exercises?.count ?? 0
    }

    private var totalVolume: Double {
        guard let exercises = workout.exercises else { return 0 }
        return exercises.reduce(0.0) { total, exercise in
            total + (exercise.sets ?? []).reduce(0.0) { $0 + $1.weight * Double($1.reps) }
        }
    }

    private var durationString: String? {
        guard let start = workout.startTime, let end = workout.endTime else { return nil }
        let secs = Int(end.timeIntervalSince(start))
        let h = secs / 3600
        let m = (secs % 3600) / 60
        if h > 0 { return "\(h)h \(m)m" }
        return m > 0 ? "\(m)m" : nil
    }

    private var relativeDateString: String {
        let cal = Calendar.current
        let now = Date()
        if cal.isDateInToday(workout.date) { return "Today" }
        if cal.isDateInYesterday(workout.date) { return "Yesterday" }
        let days = cal.dateComponents([.day], from: workout.date, to: now).day ?? 0
        if days < 7 {
            let fmt = DateFormatter()
            fmt.dateFormat = "EEE"
            return fmt.string(from: workout.date)
        }
        let fmt = DateFormatter()
        fmt.dateFormat = "MMM d"
        return fmt.string(from: workout.date)
    }

    private var volumeString: String {
        let display = UnitFormatter.convertToDisplay(totalVolume)
        if display >= 1000 {
            return String(format: "%.1fk %@", display / 1000, UnitFormatter.weightUnit)
        }
        return String(format: "%.0f %@", display, UnitFormatter.weightUnit)
    }

    var body: some View {
        Button {
            onTap()
        } label: {
            HStack(spacing: 12) {
                // Left accent bar
                RoundedRectangle(cornerRadius: 2)
                    .fill(
                        LinearGradient(
                            colors: [AppColors.accent, AppColors.accent.opacity(0.2)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 3, height: 36)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(workout.name)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.white.opacity(0.88))
                            .lineLimit(1)

                        if prCount > 0 {
                            HStack(spacing: 3) {
                                Text("🏆")
                                    .font(.system(size: 10))
                                Text("\(prCount) PR\(prCount == 1 ? "" : "s")")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(AppColors.accentGold)
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill(AppColors.accentGold.opacity(0.12))
                                    .overlay(Capsule().stroke(AppColors.accentGold.opacity(0.22), lineWidth: 1))
                            )
                        }

                        Spacer()
                    }

                    HStack(spacing: 4) {
                        Text("\(exerciseCount) exercise\(exerciseCount == 1 ? "" : "s")")
                        if totalVolume > 0 {
                            Text("·")
                            Text(volumeString)
                        }
                    }
                    .font(.system(size: 12))
                    .foregroundStyle(Color.white.opacity(0.35))
                }

                VStack(alignment: .trailing, spacing: 3) {
                    Text(relativeDateString)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.40))

                    if let dur = durationString {
                        Text(dur)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Color.white.opacity(0.22))
                    }
                }
            }
            .padding(.vertical, 11)
        }
        .buttonStyle(.plain)
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

                // Exercise list with set counts
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(exercises) { exercise in
                        let setCount = exercise.sets?.count ?? 0
                        let muscle = ExerciseLibrary.shared.find(name: exercise.name)?.muscleGroup
                        HStack(spacing: 8) {
                            // Accent dot
                            Circle()
                                .fill(AppColors.accent.opacity(0.5))
                                .frame(width: 5, height: 5)

                            // Exercise name
                            Text(exercise.name)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(Color.white.opacity(0.70))
                                .lineLimit(1)

                            Spacer(minLength: 4)

                            // Set count pill
                            if setCount > 0 {
                                Text("\(setCount) sets")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(AppColors.accent.opacity(0.7))
                                    .padding(.horizontal, 7)
                                    .padding(.vertical, 2)
                                    .background(
                                        Capsule()
                                            .fill(AppColors.accent.opacity(0.10))
                                    )
                            }

                            // Muscle tag
                            if let muscle {
                                Text(muscle.rawValue)
                                    .font(.system(size: 9, weight: .semibold))
                                    .foregroundStyle(Color.white.opacity(0.30))
                            }
                        }
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
