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
    // Configure SwiftData model container for local persistence
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Workout.self,
            Exercise.self,
            WorkoutSet.self,
            ExerciseMemory.self,
            PersonalRecord.self
        ])
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false
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
                    for exercise in workout.exercises {
                        let ordered = exercise.sets.sorted { $0.id.uuidString < $1.id.uuidString }
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
    
    var body: some Scene {
        WindowGroup {
            if hasCompletedOnboarding {
                WorkoutListView()
            } else {
                OnboardingView()
            }
        }
        .modelContainer(sharedModelContainer)
    }
}
