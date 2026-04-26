//
//  DataExporter.swift
//  TheLogger
//
//  CSV and JSON export/import for workout data
//

import Foundation
import SwiftData

// MARK: - Data Export

struct WorkoutDataExporter {

    /// Generate CSV content from workout history
    static func generateCSV(from workouts: [Workout]) -> String {
        // Get current unit system for proper header and conversion
        let unitSystem = UnitFormatter.currentSystem
        let weightUnit = unitSystem.weightUnit

        var csv = "Workout Date,Workout Name,Exercise,Set Number,Reps,Weight (\(weightUnit))\n"

        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .short
        dateFormatter.timeStyle = .short

        // Only export completed workouts (not templates)
        let completedWorkouts = workouts
            .filter { !$0.isTemplate && $0.endTime != nil }
            .sorted { $0.date > $1.date }

        for workout in completedWorkouts {
            let dateString = dateFormatter.string(from: workout.date)
            let workoutName = escapeCSV(workout.name)

            for exercise in (workout.exercises ?? []) {
                let exerciseName = escapeCSV(exercise.name)

                for (index, set) in exercise.setsByOrder.enumerated() {
                    let setNumber = index + 1
                    // Convert weight to display units (stored in lbs, export in user's preferred unit)
                    let displayWeight = UnitFormatter.convertToDisplay(set.weight)
                    csv += "\(dateString),\(workoutName),\(exerciseName),\(setNumber),\(set.reps),\(displayWeight)\n"
                }
            }
        }

        Analytics.send(Analytics.Signal.backupExportedCSV, parameters: ["workoutCount": "\(completedWorkouts.count)"])

        return csv
    }

    /// Generate summary statistics
    static func generateStats(from workouts: [Workout]) -> ExportStats {
        let completed = workouts.filter { !$0.isTemplate && $0.endTime != nil }

        let totalWorkouts = completed.count
        let totalExercises = completed.reduce(0) { $0 + ($1.exercises ?? []).count }
        let totalSets = completed.reduce(0) { $0 + $1.totalSets }

        let firstDate = completed.map { $0.date }.min()
        let lastDate = completed.map { $0.date }.max()

        return ExportStats(
            totalWorkouts: totalWorkouts,
            totalExercises: totalExercises,
            totalSets: totalSets,
            firstWorkoutDate: firstDate,
            lastWorkoutDate: lastDate
        )
    }

    private static func escapeCSV(_ string: String) -> String {
        if string.contains(",") || string.contains("\"") || string.contains("\n") {
            let escaped = string.replacingOccurrences(of: "\"", with: "\"\"")
            return "\"\(escaped)\""
        }
        return string
    }
}

struct ExportStats {
    let totalWorkouts: Int
    let totalExercises: Int
    let totalSets: Int
    let firstWorkoutDate: Date?
    let lastWorkoutDate: Date?

    var dateRangeString: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium

        guard let first = firstWorkoutDate, let last = lastWorkoutDate else {
            return "No workouts yet"
        }

        if Calendar.current.isDate(first, inSameDayAs: last) {
            return formatter.string(from: first)
        }

        return "\(formatter.string(from: first)) – \(formatter.string(from: last))"
    }
}

// MARK: - JSON Export/Import DTOs

struct ExportEnvelope: Codable {
    let version: Int
    let exportDate: Date
    let appVersion: String
    let workouts: [ExportWorkout]
    let exerciseMemories: [ExportExerciseMemory]
    let personalRecords: [ExportPersonalRecord]
}

struct ExportWorkout: Codable {
    let id: UUID
    let name: String
    let date: Date
    let startTime: Date?
    let endTime: Date?
    let isTemplate: Bool
    let exercises: [ExportExercise]
}

struct ExportExercise: Codable {
    let id: UUID
    let name: String
    let order: Int
    let supersetGroupId: UUID?
    let supersetOrder: Int
    let sets: [ExportSet]
}

struct ExportSet: Codable {
    let id: UUID
    let reps: Int
    let weight: Double
    let durationSeconds: Int?
    let setType: String
    let sortOrder: Int
}

struct ExportExerciseMemory: Codable {
    let name: String
    let lastReps: Int
    let lastWeight: Double
    let lastSets: Int
    let lastDuration: Int?
    let lastUpdated: Date
    let note: String?
    let restTimerEnabled: Bool?
}

struct ExportPersonalRecord: Codable {
    let exerciseName: String
    let weight: Double
    let reps: Int
    let date: Date
    let workoutId: UUID
}

struct ImportResult {
    let workoutsImported: Int
    let skipped: Int
    let memoriesUpdated: Int
    let prsUpdated: Int
}

// MARK: - Model ↔ DTO Conversions

extension Workout {
    func toExportModel() -> ExportWorkout {
        let exportExercises = exercisesByOrder.map { exercise in
            let exportSets = exercise.setsByOrder.map { set in
                ExportSet(
                    id: set.id,
                    reps: set.reps,
                    weight: set.weight,
                    durationSeconds: set.durationSeconds,
                    setType: set.setType,
                    sortOrder: set.sortOrder
                )
            }
            return ExportExercise(
                id: exercise.id,
                name: exercise.name,
                order: exercise.order,
                supersetGroupId: exercise.supersetGroupId,
                supersetOrder: exercise.supersetOrder,
                sets: exportSets
            )
        }
        return ExportWorkout(
            id: id,
            name: name,
            date: date,
            startTime: startTime,
            endTime: endTime,
            isTemplate: isTemplate,
            exercises: exportExercises
        )
    }

    static func fromExportModel(_ export: ExportWorkout) -> Workout {
        let workout = Workout(id: export.id, name: export.name, date: export.date, isTemplate: export.isTemplate)
        workout.startTime = export.startTime
        workout.endTime = export.endTime
        let exercises = export.exercises.map { exportEx in
            let exercise = Exercise(
                id: exportEx.id,
                name: exportEx.name,
                supersetGroupId: exportEx.supersetGroupId,
                supersetOrder: exportEx.supersetOrder,
                order: exportEx.order
            )
            exercise.sets = exportEx.sets.map { exportSet in
                let setType = SetType(rawValue: exportSet.setType) ?? .working
                return WorkoutSet(
                    id: exportSet.id,
                    reps: exportSet.reps,
                    weight: exportSet.weight,
                    durationSeconds: exportSet.durationSeconds,
                    setType: setType,
                    sortOrder: exportSet.sortOrder
                )
            }
            return exercise
        }
        workout.exercises = exercises
        return workout
    }
}

extension ExerciseMemory {
    func toExportModel() -> ExportExerciseMemory {
        ExportExerciseMemory(
            name: name,
            lastReps: lastReps,
            lastWeight: lastWeight,
            lastSets: lastSets,
            lastDuration: lastDuration,
            lastUpdated: lastUpdated,
            note: note,
            restTimerEnabled: restTimerEnabled
        )
    }

    static func fromExportModel(_ export: ExportExerciseMemory) -> ExerciseMemory {
        ExerciseMemory(
            name: export.name,
            lastReps: export.lastReps,
            lastWeight: export.lastWeight,
            lastSets: export.lastSets,
            lastDuration: export.lastDuration,
            lastUpdated: export.lastUpdated,
            note: export.note,
            restTimerEnabled: export.restTimerEnabled
        )
    }
}

extension PersonalRecord {
    func toExportModel() -> ExportPersonalRecord {
        ExportPersonalRecord(
            exerciseName: exerciseName,
            weight: weight,
            reps: reps,
            date: date,
            workoutId: workoutId
        )
    }

    static func fromExportModel(_ export: ExportPersonalRecord) -> PersonalRecord {
        PersonalRecord(
            exerciseName: export.exerciseName,
            weight: export.weight,
            reps: export.reps,
            date: export.date,
            workoutId: export.workoutId
        )
    }
}

// MARK: - JSON Export/Import

extension WorkoutDataExporter {

    /// Generate a full JSON backup of all workout data
    static func generateJSON(workouts: [Workout], memories: [ExerciseMemory], records: [PersonalRecord]) -> Data {
        let envelope = ExportEnvelope(
            version: 1,
            exportDate: Date(),
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0",
            workouts: workouts.map { $0.toExportModel() },
            exerciseMemories: memories.map { $0.toExportModel() },
            personalRecords: records.map { $0.toExportModel() }
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return (try? encoder.encode(envelope)) ?? Data()
    }

    /// Import workout data from a JSON backup, with deduplication
    static func importJSON(data: Data, into context: ModelContext) throws -> ImportResult {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let envelope = try decoder.decode(ExportEnvelope.self, from: data)

        guard envelope.version <= 1 else {
            throw ImportError.unsupportedVersion(envelope.version)
        }

        // Fetch existing workout IDs for deduplication
        let existingWorkouts = (try? context.fetch(FetchDescriptor<Workout>())) ?? []
        let existingIds = Set(existingWorkouts.map(\.id))

        var imported = 0
        var skipped = 0

        for exportWorkout in envelope.workouts {
            if existingIds.contains(exportWorkout.id) {
                skipped += 1
                continue
            }
            let workout = Workout.fromExportModel(exportWorkout)
            context.insert(workout)
            imported += 1
        }

        // Merge exercise memories
        let existingMemories = (try? context.fetch(FetchDescriptor<ExerciseMemory>())) ?? []
        let memoryByName = Dictionary(uniqueKeysWithValues: existingMemories.map {
            ($0.normalizedName, $0)
        })

        var memoriesUpdated = 0
        for exportMemory in envelope.exerciseMemories {
            let normalized = exportMemory.name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            if let existing = memoryByName[normalized] {
                // Update if the imported one is more recent
                if exportMemory.lastUpdated > existing.lastUpdated {
                    existing.update(
                        reps: exportMemory.lastReps,
                        weight: exportMemory.lastWeight,
                        sets: exportMemory.lastSets,
                        durationSeconds: exportMemory.lastDuration,
                        note: exportMemory.note
                    )
                    existing.restTimerEnabled = exportMemory.restTimerEnabled
                    memoriesUpdated += 1
                }
            } else {
                let memory = ExerciseMemory.fromExportModel(exportMemory)
                context.insert(memory)
                memoriesUpdated += 1
            }
        }

        // Merge personal records — keep the better PR per exercise
        let existingPRs = (try? context.fetch(FetchDescriptor<PersonalRecord>())) ?? []
        let prByName = Dictionary(uniqueKeysWithValues: existingPRs.map {
            ($0.exerciseName, $0)
        })

        var prsUpdated = 0
        for exportPR in envelope.personalRecords {
            let normalized = exportPR.exerciseName.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            if let existing = prByName[normalized] {
                // Compare using prScore (estimated 1RM for weighted, reps for bodyweight)
                let importedScore: Double = exportPR.weight > 0
                    ? exportPR.weight * (1.0 + Double(exportPR.reps) / 30.0)
                    : Double(exportPR.reps)
                if importedScore > existing.prScore {
                    existing.weight = exportPR.weight
                    existing.reps = exportPR.reps
                    existing.date = exportPR.date
                    existing.workoutId = exportPR.workoutId
                    prsUpdated += 1
                }
            } else {
                let pr = PersonalRecord.fromExportModel(exportPR)
                context.insert(pr)
                prsUpdated += 1
            }
        }

        try context.save()
        return ImportResult(
            workoutsImported: imported,
            skipped: skipped,
            memoriesUpdated: memoriesUpdated,
            prsUpdated: prsUpdated
        )
    }
}

enum ImportError: LocalizedError {
    case unsupportedVersion(Int)

    var errorDescription: String? {
        switch self {
        case .unsupportedVersion(let v):
            return "This backup was created with a newer version of TheLogger (format version \(v)). Please update the app to import it."
        }
    }
}
