//
//  SchemaMigrations.swift
//  TheLogger
//
//  SwiftData schema versioning and migration plan.
//  Prevents data loss on schema changes by migrating instead of recreating the store.
//

import SwiftData

// MARK: - Schema Version 1 (Current)

/// Current schema. Exercise.order was added for display order; SwiftData handles it via
/// lightweight migration when opening existing stores.
enum TheLoggerSchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)
    
    static var models: [any PersistentModel.Type] {
        [
            Workout.self,
            Exercise.self,
            WorkoutSet.self,
            ExerciseMemory.self,
            PersonalRecord.self
        ]
    }
}

// MARK: - Migration Plan

enum TheLoggerMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [TheLoggerSchemaV1.self]
    }

    static var stages: [MigrationStage] {
        []
    }
}
