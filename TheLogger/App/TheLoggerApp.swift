//
//  TheLoggerApp.swift
//  TheLogger
//
//  Created by Jaspreet Singh Sambee on 2026-01-01.
//

import SwiftUI
import SwiftData
import RevenueCat

@main
struct TheLoggerApp: App {
    var sharedModelContainer: ModelContainer
    var containerCreationFailed = false

    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @Environment(\.scenePhase) private var scenePhase

    @State private var proManager = ProManager.shared

    // Deep link state for widget navigation
    @State private var deepLinkWorkoutId: UUID?
    @State private var deepLinkExerciseId: UUID?

    // Import from Files app
    @State private var showingImportResult = false
    @State private var importResultMessage = ""
    @State private var showingImportError = false
    @State private var importErrorMessage = ""

    init() {
        // Configure RevenueCat for subscription management
        Purchases.configure(withAPIKey: "appl_LGrQpHagwtGpVqzuJKVIqBFGdkD")
        Purchases.shared.delegate = ProManager.shared
        #if DEBUG
        Purchases.logLevel = .debug
        #endif

        // Initialize TelemetryDeck analytics (release builds only, skip UI tests)
        #if !DEBUG
        Analytics.initialize(appID: "2B9CE933-9D2A-4BDB-B78D-CC43735FCFDD")
        #endif

        #if DEBUG
        if CommandLine.arguments.contains("--uitesting") {
            // Reset UserDefaults for clean test state
            let defaults = UserDefaults.standard
            defaults.set(true, forKey: "hasCompletedOnboarding")
            // Disable rest timer by default so demos aren't interrupted between sets.
            // Use --enable-rest-timer alongside --uitesting to override (for rest timer demo).
            let enableRestTimer = CommandLine.arguments.contains("--enable-rest-timer")
            defaults.set(enableRestTimer, forKey: "globalRestTimerEnabled")
        }
        #endif

        #if targetEnvironment(simulator)
        // Skip onboarding in the simulator so stats/history are immediately visible.
        // Pass --show-onboarding at launch to RESET the flag and preview the onboarding flow;
        // the body still gates on hasCompletedOnboarding, so completing onboarding
        // transitions the user to MainTabView normally.
        if CommandLine.arguments.contains("--show-onboarding") {
            UserDefaults.standard.set(false, forKey: "hasCompletedOnboarding")
        } else {
            UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
        }
        #endif

        let (container, failed) = Self.makeModelContainer()
        self.sharedModelContainer = container
        self.containerCreationFailed = failed

        // Record install date once (used for new-user notification suppression)
        NotificationScheduler.shared.recordInstallDateIfNeeded()
    }

    // MARK: - Model Container Setup

    private static func makeModelContainer() -> (ModelContainer, Bool) {
        let schema = Schema([
            Workout.self,
            Exercise.self,
            WorkoutSet.self,
            ExerciseMemory.self,
            PersonalRecord.self,
            Achievement.self
        ])

        // Use CloudKit for automatic iCloud backup and sync
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .automatic
        )

        do {
            let container = try ModelContainer(
                for: Workout.self, Exercise.self, WorkoutSet.self, ExerciseMemory.self, PersonalRecord.self, Achievement.self,
                migrationPlan: TheLoggerMigrationPlan.self,
                configurations: modelConfiguration
            )

            // Migrate existing workouts that don't have a name
            // This runs synchronously to ensure migration completes before returning
            let context = container.mainContext
            let descriptor = FetchDescriptor<Workout>()
            if let workouts = try? context.fetch(descriptor) {
                var needsSave = false
                for workout in workouts {
                    // Check if name is empty or just whitespace
                    if workout.name.trimmingCharacters(in: .whitespaces).isEmpty {
                        let formatter = DateFormatter()
                        formatter.dateStyle = .medium
                        formatter.timeStyle = .short
                        workout.name = formatter.string(from: workout.date)
                        needsSave = true
                    }
                    // Migrate sets: assign sortOrder = index so display order is stable.
                    for exercise in workout.exercises ?? [] {
                        let ordered = (exercise.sets ?? []).sorted { $0.id.uuidString < $1.id.uuidString }
                        for (index, set) in ordered.enumerated() {
                            if set.sortOrder != index {
                                set.sortOrder = index
                                needsSave = true
                            }
                        }
                    }
                    // Migrate exercises: assign order = index (SwiftData V2 added Exercise.order).
                    // Use stable sort by id so we don't renumber differently each launch.
                    let orderedExs = (workout.exercises ?? []).sorted { $0.id.uuidString < $1.id.uuidString }
                    for (index, exercise) in orderedExs.enumerated() {
                        if exercise.order != index {
                            exercise.order = index
                            needsSave = true
                        }
                    }
                }
                if needsSave {
                    try? context.save()
                }
            }

            #if DEBUG
            if CommandLine.arguments.contains("--seed-data") {
                DebugHelpers.populateSampleData(modelContext: context)
            }
            #endif

            #if targetEnvironment(simulator)
            // Auto-seed realistic workout history in the simulator so Stats/Home cards are populated.
            DebugHelpers.populateSampleData(modelContext: context)
            #endif

            return (container, false)
        } catch {
            // ModelContainer creation failed. Preserve existing store by moving to recovery
            // (never delete), then create a fresh store. CloudKit may restore data on sync.
            debugLog("[TheLogger] Error creating ModelContainer: \(error)")
            debugLog("[TheLogger] Moving store to recovery folder (data preserved for potential recovery)")

            let fileManager = FileManager.default
            let appSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            let storeBase = appSupportURL.appendingPathComponent("default.store")

            // Move store files to recovery directory instead of deleting
            let timestamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
            let recoveryDir = appSupportURL.appendingPathComponent("default.store.recovery.\(timestamp)")

            let storeFiles: [URL] = [
                storeBase,
                storeBase.appendingPathExtension("wal"),
                storeBase.appendingPathExtension("shm")
            ]

            do {
                try fileManager.createDirectory(at: recoveryDir, withIntermediateDirectories: true)
                for url in storeFiles {
                    if fileManager.fileExists(atPath: url.path) {
                        let dest = recoveryDir.appendingPathComponent(url.lastPathComponent)
                        try? fileManager.removeItem(at: dest)
                        try fileManager.moveItem(at: url, to: dest)
                        debugLog("[TheLogger] Moved to recovery: \(url.lastPathComponent)")
                    }
                }
            } catch let moveError {
                debugLog("[TheLogger] Could not move to recovery: \(moveError)")
            }

            // Create fresh container; CloudKit will sync down if data exists in iCloud
            do {
                let freshContainer = try ModelContainer(
                    for: Workout.self, Exercise.self, WorkoutSet.self, ExerciseMemory.self, PersonalRecord.self, Achievement.self,
                    migrationPlan: TheLoggerMigrationPlan.self,
                    configurations: modelConfiguration
                )
                debugLog("[TheLogger] Created fresh database; CloudKit may restore data")
                return (freshContainer, false)
            } catch {
                debugLog("[TheLogger] Failed to create fresh database: \(error)")
                // Last resort: in-memory storage — signal UI to show an error alert
                debugLog("[TheLogger] Using in-memory storage as fallback")
                let fallbackConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
                if let fallback = try? ModelContainer(for: schema, configurations: [fallbackConfig]) {
                    return (fallback, true)
                }
                // Absolute last resort — empty schema in-memory container
                let emptyConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
                return ((try? ModelContainer(for: schema, configurations: [emptyConfig]))!, true)
            }
        }
    }

    // MARK: - Body

    var body: some Scene {
        WindowGroup {
            Group {
                if hasCompletedOnboarding {
                    MainTabView(
                        deepLinkWorkoutId: $deepLinkWorkoutId,
                        deepLinkExerciseId: $deepLinkExerciseId
                    )
                    .onAppear {
                        syncPendingSetsFromWidget()
                    }
                } else {
                    OnboardingView()
                }
            }
            .alert("Storage Error", isPresented: .constant(containerCreationFailed)) {
                Button("OK") { }
            } message: {
                Text("TheLogger could not access its database and is running in temporary mode. Your data will not be saved this session. Please restart the app — if the problem persists, try reinstalling.")
            }
            .environment(proManager)
            .task {
                await proManager.checkSubscriptionStatus()
                seedStarterTemplatesIfNeeded()
                // Request notification permission on first launch
                NotificationScheduler.shared.requestPermission()
            }
            .onOpenURL { url in
                handleBackupFileOpen(url)
            }
            .alert("Import Complete", isPresented: $showingImportResult) {
                Button("OK") { }
            } message: {
                Text(importResultMessage)
            }
            .alert("Import Failed", isPresented: $showingImportError) {
                Button("OK") { }
            } message: {
                Text(importErrorMessage)
            }
        }
        .modelContainer(sharedModelContainer)
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                // Sync any sets logged from the widget
                syncPendingSetsFromWidget()
                // Schedule today's notification (runs once per day)
                NotificationScheduler.shared.scheduleIfNeeded(modelContext: sharedModelContainer.mainContext)
            }
        }
        .handlesExternalEvents(matching: ["thelogger"])
    }

    // MARK: - Backup File Import

    private func handleBackupFileOpen(_ url: URL) {
        guard url.pathExtension == "thelogger" else { return }
        let didAccess = url.startAccessingSecurityScopedResource()
        defer { if didAccess { url.stopAccessingSecurityScopedResource() } }
        do {
            let data = try Data(contentsOf: url)
            let context = sharedModelContainer.mainContext
            let result = try WorkoutDataExporter.importJSON(data: data, into: context)
            importResultMessage = "Imported \(result.workoutsImported) workout\(result.workoutsImported == 1 ? "" : "s"). \(result.skipped) skipped (duplicates). \(result.memoriesUpdated) exercise settings updated. \(result.prsUpdated) personal records updated."
            showingImportResult = true
        } catch {
            importErrorMessage = error.localizedDescription
            showingImportError = true
        }
    }

    // MARK: - Widget Sync

    /// Sync sets that were logged from the Live Activity widget
    // MARK: - Starter Templates

    @AppStorage("hasSeededTemplates") private var hasSeededTemplates = false

    private func seedStarterTemplatesIfNeeded() {
        guard !hasSeededTemplates else { return }

        let context = sharedModelContainer.mainContext
        // Only seed if user has no templates at all
        let descriptor = FetchDescriptor<Workout>(predicate: #Predicate { $0.isTemplate == true })
        guard let existing = try? context.fetch(descriptor), existing.isEmpty else {
            hasSeededTemplates = true
            return
        }

        let templates: [(name: String, exercises: [String])] = [
            ("Push Day", ["Bench Press", "Overhead Press", "Incline Dumbbell Press", "Tricep Pushdown"]),
            ("Pull Day", ["Deadlift", "Barbell Row", "Lat Pulldown", "Barbell Curl"]),
            ("Leg Day", ["Squat", "Romanian Deadlift", "Lunges", "Leg Press"]),
        ]

        for t in templates {
            let workout = Workout(name: t.name, date: Date(), isTemplate: true)
            for name in t.exercises {
                workout.addExercise(name: name)
            }
            context.insert(workout)
        }

        do {
            try context.save()
            hasSeededTemplates = true
        } catch {
            debugLog("Error seeding templates: \(error)")
        }
    }

    private func syncPendingSetsFromWidget() {
        // Debug: Print full intent debug log
        if let debugDefaults = UserDefaults(suiteName: "group.com.thelogger.app"),
           let intentLog = debugDefaults.string(forKey: "debugIntentLog") {
            debugLog("[App] ====== WIDGET INTENT DEBUG LOG ======")
            debugLog(intentLog)
            debugLog("[App] ====================================")
        } else {
            debugLog("[App] DEBUG - No widget intent log found")
        }

        let pendingSets = PendingSetManager.getPendingSets()
        guard !pendingSets.isEmpty else { return }

        let context = sharedModelContainer.mainContext

        for pendingSet in pendingSets {
            // Find the workout and exercise
            guard let workoutId = UUID(uuidString: pendingSet.workoutId),
                  let exerciseId = UUID(uuidString: pendingSet.exerciseId) else {
                continue
            }

            let descriptor = FetchDescriptor<Workout>(
                predicate: #Predicate { $0.id == workoutId }
            )

            guard let workout = try? context.fetch(descriptor).first,
                  let exercise = workout.exercises?.first(where: { $0.id == exerciseId }) else {
                continue
            }

            // Add the set to the exercise
            exercise.addSet(reps: pendingSet.reps, weight: pendingSet.weight)
            debugLog("[App] Synced pending set: \(pendingSet.reps) reps @ \(pendingSet.weight) for \(exercise.name)")
        }

        // Save and clear pending sets
        try? context.save()
        PendingSetManager.clearPendingSets()

        // Update widget with latest data
        if let activeWorkout = try? context.fetch(FetchDescriptor<Workout>()).first(where: { $0.isActive }) {
            activeWorkout.syncToWidget()
        }
    }
}
