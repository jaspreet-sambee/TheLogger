//
//  WorkoutListView.swift
//
//  Root screen displaying list of workouts
//

import SwiftUI
import SwiftData

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
    @State private var userName: String = UserDefaults.standard.string(forKey: "userName") ?? ""
    @State private var showingNameEditor = false

    
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
        var currentDate = today
        
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
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: Date())!
        return workoutHistory.filter { $0.date >= weekAgo }.count
    }

    
    var body: some View {
        NavigationStack(path: $navigationPath) {
            List {
                // Welcome Header Section
                Section {
                    HStack(spacing: 12) {
                        // Greeting text in circular background
                        ZStack {
                            Circle()
                                .fill(Color(.systemGray5))
                                .frame(width: 48, height: 48)
                            
                            if userName.isEmpty {
                                Image(systemName: "person.circle.fill")
                                    .font(.system(size: 32, weight: .medium))
                                    .foregroundStyle(.secondary)
                            } else {
                                Text(String(userName.prefix(1).uppercased()))
                                    .font(.system(size: 24, weight: .bold))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        
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
                        
                        Button {
                            showingNameEditor = true
                        } label: {
                            Image(systemName: userName.isEmpty ? "person.crop.circle.badge.plus" : "pencil")
                                .font(.system(.body, weight: .medium))
                                .foregroundStyle(.blue)
                                .padding(8)
                                .background(
                                    Circle()
                                        .fill(Color(.systemGray6))
                                )
                        }
                    }
                    .padding(.vertical, 8)
                } header: {
                    EmptyView()
                }
                .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 8, trailing: 16))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
                
                // Active Workout Section
                // Motivational Stats Section
                // Motivational Stats Section
                if totalWorkouts > 0 {
                    Section {
                        HStack(spacing: 16) {
                            // Streak Card
                            VStack(spacing: 8) {
                                HStack(spacing: 6) {
                                    Image(systemName: "flame.fill")
                                        .font(.system(.caption, weight: .bold))
                                        .foregroundStyle(.orange)
                                    Text("\(workoutStreak)")
                                        .font(.system(.title2, weight: .bold))
                                        .foregroundStyle(.orange)
                                }
                                Text("Day Streak")
                                    .font(.system(.caption2, weight: .medium))
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.orange.opacity(0.1))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color.orange.opacity(0.25), lineWidth: 1)
                                    )
                            )
                            
                            // Total Workouts Card
                            VStack(spacing: 8) {
                                HStack(spacing: 6) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(.caption, weight: .bold))
                                        .foregroundStyle(.green)
                                    Text("\(totalWorkouts)")
                                        .font(.system(.title2, weight: .bold))
                                        .foregroundStyle(.green)
                                }
                                Text("Total")
                                    .font(.system(.caption2, weight: .medium))
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.green.opacity(0.1))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color.green.opacity(0.25), lineWidth: 1)
                                    )
                            )
                            
                            // This Week Card
                            VStack(spacing: 8) {
                                HStack(spacing: 6) {
                                    Image(systemName: "calendar")
                                        .font(.system(.caption, weight: .bold))
                                        .foregroundStyle(.purple)
                                    Text("\(thisWeekWorkouts)")
                                        .font(.system(.title2, weight: .bold))
                                        .foregroundStyle(.purple)
                                }
                                Text("This Week")
                                    .font(.system(.caption2, weight: .medium))
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.purple.opacity(0.1))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color.purple.opacity(0.25), lineWidth: 1)
                                    )
                            )
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
                        }
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                    } header: {
                        Text("Active Workout")
                            .font(.system(.subheadline, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .textCase(nil)
                    }
                }
                
                // Start Workout Section (only show when no active workout)
                if activeWorkout == nil {
                    Section {
                        Button {
                            if templates.isEmpty { startWorkoutFromTemplate(template: nil) } else { showingWorkoutSelector = true }
                        } label: {
                            HStack(spacing: 14) {
                                ZStack {
                                    Circle()
                                        .fill(Color.blue.opacity(0.1))
                                        .frame(width: 48, height: 48)
                                    
                                    Image(systemName: "play.circle.fill")
                                        .font(.system(size: 26, weight: .semibold))
                                        .foregroundStyle(.blue)
                                }
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Start Workout")
                                        .font(.system(.headline, weight: .semibold))
                                        .foregroundStyle(.primary)
                                    Text("Begin a new training session")
                                        .font(.system(.subheadline, weight: .regular))
                                        .foregroundStyle(.secondary)
                                }
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .font(.system(.subheadline, weight: .semibold))
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(.vertical, 16)
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
                        .buttonStyle(.plain)
                        .padding(.vertical, 4)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    } header: {
                        Text("Quick Start")
                            .font(.system(.subheadline, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .textCase(nil)
                    }
                }

                // Templates Section (prioritized)
                Section {
                    if !templates.isEmpty {
                        ForEach(templates) { template in
                            ZStack {
                                NavigationLink(value: template.id.uuidString) {
                                    Color.clear
                                        .contentShape(Rectangle())
                                }
                                
                                TemplateRowView(template: template)
                            }
                            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                        }
                        .onDelete(perform: deleteTemplates)
                    } else {
                        // Empty templates state
                        VStack(spacing: 12) {
                            Image(systemName: "doc.text")
                                .font(.system(size: 40))
                                .foregroundStyle(.tertiary)
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
                                .fill(Color.black.opacity(0.6))
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
                
                // Workout History Section (collapsed behind action)
                if !workoutHistory.isEmpty {
                    Section {
                        Button {
                            showingWorkoutHistory = true
                        } label: {
                            HStack(spacing: 14) {
                                ZStack {
                                    Circle()
                                        .fill(Color.black)
                                        .frame(width: 44, height: 44)
                                    
                                    Image(systemName: "clock.fill")
                                        .font(.system(size: 20, weight: .medium))
                                        .foregroundStyle(.secondary)
                                }
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Workout History")
                                        .font(.system(.body, weight: .semibold))
                                        .foregroundStyle(.primary)
                                    Text("\(workoutHistory.count) completed \(workoutHistory.count == 1 ? "workout" : "workouts")")
                                        .font(.system(.caption, weight: .regular))
                                        .foregroundStyle(.secondary)
                                }
                                
                                Spacer()
                                
                                HStack(spacing: 6) {
                                    Text("\(workoutHistory.count)")
                                        .font(.system(.subheadline, weight: .semibold))
                                        .foregroundStyle(.secondary)
                                    Image(systemName: "chevron.right")
                                        .font(.system(.caption, weight: .semibold))
                                        .foregroundStyle(.tertiary)
                                }
                            }
                            .padding(.vertical, 12)
                            .padding(.horizontal, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.black.opacity(0.6))
                                    .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 2)
                            )
                        }
                        .buttonStyle(.plain)
                    } header: {
                        HStack {
                            Image(systemName: "clock.fill")
                                .font(.system(.caption, weight: .semibold))
                            Text("History")
                                .font(.system(.subheadline, weight: .semibold))
                        }
                        .foregroundStyle(.secondary)
                        .textCase(nil)
                    }
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                }
                
                // Empty state
                if templates.isEmpty && workoutHistory.isEmpty && activeWorkout == nil {
                    ContentUnavailableView(
                        "No Templates",
                        systemImage: "figure.strengthtraining.traditional",
                        description: Text("Start a workout to create your first template")
                    )
                }
            }
            .navigationDestination(for: String.self) { workoutId in
                if let workout = workouts.first(where: { $0.id.uuidString == workoutId }) {
                    WorkoutDetailView(workout: workout)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background {
                Color(.systemBackground)
                    .ignoresSafeArea()
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showingWorkoutHistory) {
                WorkoutHistoryView(workouts: workoutHistory)
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
            .task {
                // Auto-navigate to active workout on app launch (only once)
                if !hasCheckedActiveWorkout {
                    hasCheckedActiveWorkout = true
                    if let activeWorkout = activeWorkout {
                        navigationPath.append(activeWorkout.id.uuidString)
                    }
                }
            }
        }
    }
    
    private func startWorkoutFromTemplate(template: Workout?) {
        // Ensure no other workout is active (safety check)
        if let existingActive = activeWorkout {
            existingActive.endTime = Date()
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
            // Navigate to the workout detail view
            navigationPath.append(newWorkout.id.uuidString)
        } catch {
            print("Error starting workout: \(error)")
        }
    }
    
    private func duplicateWorkoutFromTemplate(_ template: Workout) -> Workout {
        // Create new workout with today's date and copy the name
        let newWorkout = Workout(name: template.name, date: Date(), isTemplate: false)
        
        // Copy all exercises (templates only have exercise names, no sets)
        for exercise in template.exercises {
            let newExercise = Exercise(name: exercise.name)
            // Templates don't have sets, so we don't copy them
            newWorkout.exercises.append(newExercise)
        }
        
        return newWorkout
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
}


// MARK: - Active Workout Row View
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
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.blue.opacity(0.25), lineWidth: 1)
                )
        )
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
    
    var body: some View {
        HStack(spacing: 14) {
            // Icon indicator
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.blue.opacity(0.1))
                    .frame(width: 48, height: 48)
                
                Image(systemName: "doc.text.fill")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(.blue)
            }
            
            // Content
            VStack(alignment: .leading, spacing: 6) {
                Text(template.name)
                    .font(.system(.headline, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                
                HStack(spacing: 16) {
                    HStack(spacing: 4) {
                        Image(systemName: "figure.strengthtraining.traditional")
                            .font(.system(.caption2, weight: .medium))
                        Text("\(template.exerciseCount)")
                            .font(.system(.subheadline, weight: .semibold))
                    }
                    .foregroundStyle(.secondary)
                    
                    if template.totalSets > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "list.bullet")
                                .font(.system(.caption2, weight: .medium))
                            Text("\(template.totalSets)")
                                .font(.system(.subheadline, weight: .semibold))
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
                    WorkoutDetailView(workout: workout)
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
    
    var body: some View {
        HStack(spacing: 14) {
            // Date indicator with subtle accent
            VStack(spacing: 4) {
                Text(formattedDate)
                    .font(.system(.caption, weight: .semibold))
                    .foregroundStyle(.purple)
                    .frame(width: 50)
            }
            
            // Main content
            VStack(alignment: .leading, spacing: 6) {
                Text(workout.name)
                    .font(.system(.headline, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                
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
