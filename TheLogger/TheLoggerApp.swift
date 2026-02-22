//
//  TheLoggerApp.swift
//  TheLogger
//
//  Created by Jaspreet Singh Sambee on 2026-01-01.
//

import SwiftUI
import SwiftData

@main
struct TheLoggerApp: App {
    // Configure SwiftData model container with iCloud sync and migration plan
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Workout.self,
            Exercise.self,
            WorkoutSet.self,
            ExerciseMemory.self,
            PersonalRecord.self
        ])

        // Use CloudKit for automatic iCloud backup and sync
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .automatic
        )
        
        do {
            let container = try ModelContainer(
                for: Workout.self, Exercise.self, WorkoutSet.self, ExerciseMemory.self, PersonalRecord.self,
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

            return container
        } catch {
            // ModelContainer creation failed. Preserve existing store by moving to recovery
            // (never delete), then create a fresh store. CloudKit may restore data on sync.
            print("[TheLogger] Error creating ModelContainer: \(error)")
            print("[TheLogger] Moving store to recovery folder (data preserved for potential recovery)")
            
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
                        print("[TheLogger] Moved to recovery: \(url.lastPathComponent)")
                    }
                }
            } catch let moveError {
                print("[TheLogger] Could not move to recovery: \(moveError)")
            }
            
            // Create fresh container; CloudKit will sync down if data exists in iCloud
            do {
                let freshContainer = try ModelContainer(
                    for: Workout.self, Exercise.self, WorkoutSet.self, ExerciseMemory.self, PersonalRecord.self,
                    migrationPlan: TheLoggerMigrationPlan.self,
                    configurations: modelConfiguration
                )
                print("[TheLogger] Created fresh database; CloudKit may restore data")
                return freshContainer
            } catch {
                print("[TheLogger] Failed to create fresh database: \(error)")
                // Last resort: in-memory storage
                print("[TheLogger] Using in-memory storage as fallback")
                let fallbackConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
                do {
                    return try ModelContainer(for: schema, configurations: [fallbackConfig])
                } catch {
                    fatalError("Could not create ModelContainer: \(error)")
                }
            }
        }
    }()
    
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @Environment(\.scenePhase) private var scenePhase

    // Deep link state for widget navigation
    @State private var deepLinkWorkoutId: UUID?
    @State private var deepLinkExerciseId: UUID?

    init() {
        #if DEBUG
        if CommandLine.arguments.contains("--uitesting") {
            // Reset UserDefaults for clean test state
            let defaults = UserDefaults.standard
            defaults.set(true, forKey: "hasCompletedOnboarding")
            // Disable rest timer by default so demos aren't interrupted between sets.
            // Use --enable-rest-timer alongside --uitesting to override (for rest timer demo).
            let enableRestTimer = CommandLine.arguments.contains("--enable-rest-timer")
            defaults.set(enableRestTimer, forKey: "globalRestTimerEnabled")
            defaults.synchronize()
        }
        #endif
    }

    var body: some Scene {
        WindowGroup {
            if hasCompletedOnboarding {
                WorkoutListView(
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
        .modelContainer(sharedModelContainer)
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                // Sync any sets logged from the widget
                syncPendingSetsFromWidget()
            }
        }
        .handlesExternalEvents(matching: ["thelogger"])
    }

    /// Sync sets that were logged from the Live Activity widget
    private func syncPendingSetsFromWidget() {
        // Debug: Print full intent debug log
        if let debugDefaults = UserDefaults(suiteName: "group.SDL-Tutorial.TheLogger"),
           let debugLog = debugDefaults.string(forKey: "debugIntentLog") {
            print("[App] ====== WIDGET INTENT DEBUG LOG ======")
            print(debugLog)
            print("[App] ====================================")
        } else {
            print("[App] DEBUG - No widget intent log found")
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
            print("[App] Synced pending set: \(pendingSet.reps) reps @ \(pendingSet.weight) for \(exercise.name)")
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