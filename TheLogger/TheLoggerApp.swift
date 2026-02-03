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
    // Configure SwiftData model container with iCloud sync
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
            let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
            
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
                    // Use stable order (id) so we don't renumber differently each launch.
                    for exercise in workout.exercises ?? [] {
                        let ordered = (exercise.sets ?? []).sorted { $0.id.uuidString < $1.id.uuidString }
                        for (index, set) in ordered.enumerated() {
                            if set.sortOrder != index {
                                set.sortOrder = index
                                needsSave = true
                            }
                        }
                    }
                }
                if needsSave {
                    try? context.save()
                }
            }
            
            return container
        } catch {
            // If migration fails, this is likely due to a schema change
            // Try to delete the old database and create a new one
            print("Error creating ModelContainer: \(error)")
            print("Attempting to reset database due to schema change...")
            
            // Get the Application Support directory where SwiftData stores files
            let appSupportURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            let storeURL = appSupportURL.appendingPathComponent("default.store")
            
            // Try to delete all database files
            let fileManager = FileManager.default
            let filesToDelete = [
                storeURL,
                storeURL.appendingPathExtension("wal"),
                storeURL.appendingPathExtension("shm")
            ]
            
            for url in filesToDelete {
                if fileManager.fileExists(atPath: url.path) {
                    do {
                        try fileManager.removeItem(at: url)
                        print("Deleted: \(url.lastPathComponent)")
                    } catch {
                        print("Failed to delete \(url.lastPathComponent): \(error)")
                    }
                }
            }
            
            // Also try to delete the entire store directory if it exists
            let storeDirectory = appSupportURL.appendingPathComponent("default.store")
            if fileManager.fileExists(atPath: storeDirectory.path) {
                try? fileManager.removeItem(at: storeDirectory)
            }
            
            // Try creating again with fresh database
            do {
                let newContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])
                print("Successfully created new database after reset")
                return newContainer
            } catch {
                print("Failed to create new database after reset: \(error)")
                // Last resort: use in-memory storage (data won't persist)
                print("Using in-memory storage as fallback")
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
