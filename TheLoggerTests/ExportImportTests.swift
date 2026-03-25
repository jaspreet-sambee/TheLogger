//
//  ExportImportTests.swift
//  TheLoggerTests
//
//  Unit tests for JSON export/import: full backup generation,
//  import with deduplication, memory/PR merging, and round-trip.
//

import XCTest
import SwiftData
@testable import TheLogger

@MainActor
final class ExportImportTests: XCTestCase {

    var modelContext: ModelContext!
    var modelContainer: ModelContainer!

    override func setUp() async throws {
        let schema = Schema([Workout.self, Exercise.self, WorkoutSet.self, ExerciseMemory.self, PersonalRecord.self])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        modelContainer = try ModelContainer(for: schema, configurations: [configuration])
        modelContext = ModelContext(modelContainer)
    }

    // MARK: - Export

    func testJSONExportContainsAllData() throws {
        // Create workout
        let workout = makeCompletedWorkout(name: "Push Day", exerciseName: "Bench Press")
        let template = Workout(name: "My Template", date: Date(), isTemplate: true)
        let exercise = Exercise(name: "Squat", order: 0)
        exercise.addSet(reps: 5, weight: 225)
        template.exercises = [exercise]

        // Create memory
        let memory = ExerciseMemory(name: "bench press", lastReps: 8, lastWeight: 185, lastSets: 3)

        // Create PR
        let pr = PersonalRecord(exerciseName: "bench press", weight: 225, reps: 5, workoutId: workout.id)

        let data = WorkoutDataExporter.generateJSON(
            workouts: [workout, template],
            memories: [memory],
            records: [pr]
        )

        XCTAssertFalse(data.isEmpty)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let envelope = try decoder.decode(ExportEnvelope.self, from: data)

        XCTAssertEqual(envelope.version, 1)
        XCTAssertEqual(envelope.workouts.count, 2)
        XCTAssertEqual(envelope.exerciseMemories.count, 1)
        XCTAssertEqual(envelope.personalRecords.count, 1)

        // Check workout data
        let exportedWorkout = envelope.workouts.first { $0.name == "Push Day" }
        XCTAssertNotNil(exportedWorkout)
        XCTAssertFalse(exportedWorkout!.isTemplate)
        XCTAssertEqual(exportedWorkout!.exercises.count, 1)
        XCTAssertEqual(exportedWorkout!.exercises.first?.name, "Bench Press")
        XCTAssertEqual(exportedWorkout!.exercises.first?.sets.count, 1)

        // Check template
        let exportedTemplate = envelope.workouts.first { $0.name == "My Template" }
        XCTAssertNotNil(exportedTemplate)
        XCTAssertTrue(exportedTemplate!.isTemplate)

        // Check memory
        XCTAssertEqual(envelope.exerciseMemories.first?.name, "bench press")
        XCTAssertEqual(envelope.exerciseMemories.first?.lastReps, 8)
        XCTAssertEqual(envelope.exerciseMemories.first?.lastWeight, 185)

        // Check PR
        XCTAssertEqual(envelope.personalRecords.first?.exerciseName, "bench press")
        XCTAssertEqual(envelope.personalRecords.first?.weight, 225)
        XCTAssertEqual(envelope.personalRecords.first?.reps, 5)
    }

    func testJSONExportPreservesSetTypes() throws {
        let workout = Workout(name: "Test", date: Date(), isTemplate: false)
        workout.startTime = Date()
        workout.endTime = Date().addingTimeInterval(3600)
        let exercise = Exercise(name: "Bench Press", order: 0)
        exercise.addSet(reps: 10, weight: 100)
        let warmupSet = WorkoutSet(reps: 10, weight: 50, setType: .warmup, sortOrder: 0)
        let dropSet = WorkoutSet(reps: 12, weight: 80, setType: .dropSet, sortOrder: 1)
        exercise.sets = [warmupSet, dropSet]
        workout.exercises = [exercise]

        let data = WorkoutDataExporter.generateJSON(workouts: [workout], memories: [], records: [])
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let envelope = try decoder.decode(ExportEnvelope.self, from: data)

        let sets = envelope.workouts.first!.exercises.first!.sets
        XCTAssertEqual(sets.count, 2)
        XCTAssertTrue(sets.contains { $0.setType == "Warmup" })
        XCTAssertTrue(sets.contains { $0.setType == "Drop Set" })
    }

    func testJSONExportPreservesSupersetData() throws {
        let workout = Workout(name: "Superset Test", date: Date(), isTemplate: false)
        workout.startTime = Date()
        workout.endTime = Date().addingTimeInterval(3600)
        let groupId = UUID()
        let e1 = Exercise(name: "Bench Press", supersetGroupId: groupId, supersetOrder: 0, order: 0)
        e1.addSet(reps: 10, weight: 135)
        let e2 = Exercise(name: "Bent Over Row", supersetGroupId: groupId, supersetOrder: 1, order: 1)
        e2.addSet(reps: 10, weight: 135)
        workout.exercises = [e1, e2]

        let data = WorkoutDataExporter.generateJSON(workouts: [workout], memories: [], records: [])
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let envelope = try decoder.decode(ExportEnvelope.self, from: data)

        let exercises = envelope.workouts.first!.exercises
        XCTAssertEqual(exercises[0].supersetGroupId, exercises[1].supersetGroupId)
        XCTAssertEqual(exercises[0].supersetOrder, 0)
        XCTAssertEqual(exercises[1].supersetOrder, 1)
    }

    func testJSONExportPreservesTimeBased() throws {
        let workout = Workout(name: "Core", date: Date(), isTemplate: false)
        workout.startTime = Date()
        workout.endTime = Date().addingTimeInterval(1800)
        let exercise = Exercise(name: "Plank", order: 0)
        exercise.addSet(reps: 0, weight: 0, durationSeconds: 60)
        workout.exercises = [exercise]

        let data = WorkoutDataExporter.generateJSON(workouts: [workout], memories: [], records: [])
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let envelope = try decoder.decode(ExportEnvelope.self, from: data)

        XCTAssertEqual(envelope.workouts.first!.exercises.first!.sets.first!.durationSeconds, 60)
    }

    // MARK: - Import

    func testJSONImportCreatesWorkouts() throws {
        let workout = makeCompletedWorkout(name: "Push Day", exerciseName: "Bench Press")
        let memory = ExerciseMemory(name: "bench press", lastReps: 8, lastWeight: 185, lastSets: 3)
        let pr = PersonalRecord(exerciseName: "bench press", weight: 225, reps: 5, workoutId: workout.id)

        let data = WorkoutDataExporter.generateJSON(workouts: [workout], memories: [memory], records: [pr])

        let result = try WorkoutDataExporter.importJSON(data: data, into: modelContext)

        XCTAssertEqual(result.workoutsImported, 1)
        XCTAssertEqual(result.skipped, 0)

        let fetchedWorkouts = try modelContext.fetch(FetchDescriptor<Workout>())
        XCTAssertEqual(fetchedWorkouts.count, 1)
        XCTAssertEqual(fetchedWorkouts.first?.name, "Push Day")
        XCTAssertEqual(fetchedWorkouts.first?.exercises?.count, 1)
        XCTAssertEqual(fetchedWorkouts.first?.exercises?.first?.sets?.count, 1)
    }

    func testJSONImportDeduplication() throws {
        let workout = makeCompletedWorkout(name: "Push Day", exerciseName: "Bench Press")
        let data = WorkoutDataExporter.generateJSON(workouts: [workout], memories: [], records: [])

        // Import once
        let result1 = try WorkoutDataExporter.importJSON(data: data, into: modelContext)
        XCTAssertEqual(result1.workoutsImported, 1)

        // Import again — should skip
        let result2 = try WorkoutDataExporter.importJSON(data: data, into: modelContext)
        XCTAssertEqual(result2.workoutsImported, 0)
        XCTAssertEqual(result2.skipped, 1)

        // Only one workout in store
        let fetchedWorkouts = try modelContext.fetch(FetchDescriptor<Workout>())
        XCTAssertEqual(fetchedWorkouts.count, 1)
    }

    func testJSONImportMergesMemories() throws {
        // Insert existing memory
        let existingMemory = ExerciseMemory(name: "bench press", lastReps: 5, lastWeight: 135, lastSets: 3, lastUpdated: Date().addingTimeInterval(-86400))
        modelContext.insert(existingMemory)
        try modelContext.save()

        // Export a newer memory
        let newerMemory = ExerciseMemory(name: "bench press", lastReps: 8, lastWeight: 185, lastSets: 4, lastUpdated: Date())
        let data = WorkoutDataExporter.generateJSON(workouts: [], memories: [newerMemory], records: [])

        let result = try WorkoutDataExporter.importJSON(data: data, into: modelContext)
        XCTAssertEqual(result.memoriesUpdated, 1)

        // Verify updated
        let fetchedMemories = try modelContext.fetch(FetchDescriptor<ExerciseMemory>())
        XCTAssertEqual(fetchedMemories.count, 1)
        XCTAssertEqual(fetchedMemories.first?.lastReps, 8)
        XCTAssertEqual(fetchedMemories.first?.lastWeight, 185)
    }

    func testJSONImportMergesMemories_olderIgnored() throws {
        // Insert existing memory (newer)
        let existingMemory = ExerciseMemory(name: "bench press", lastReps: 8, lastWeight: 185, lastSets: 3, lastUpdated: Date())
        modelContext.insert(existingMemory)
        try modelContext.save()

        // Export an older memory
        let olderMemory = ExerciseMemory(name: "bench press", lastReps: 5, lastWeight: 135, lastSets: 2, lastUpdated: Date().addingTimeInterval(-86400))
        let data = WorkoutDataExporter.generateJSON(workouts: [], memories: [olderMemory], records: [])

        let result = try WorkoutDataExporter.importJSON(data: data, into: modelContext)
        XCTAssertEqual(result.memoriesUpdated, 0)

        // Verify not changed
        let fetchedMemories = try modelContext.fetch(FetchDescriptor<ExerciseMemory>())
        XCTAssertEqual(fetchedMemories.first?.lastReps, 8)
    }

    func testJSONImportInsertsNewMemory() throws {
        let memory = ExerciseMemory(name: "squat", lastReps: 5, lastWeight: 225, lastSets: 5)
        let data = WorkoutDataExporter.generateJSON(workouts: [], memories: [memory], records: [])

        let result = try WorkoutDataExporter.importJSON(data: data, into: modelContext)
        XCTAssertEqual(result.memoriesUpdated, 1)

        let fetchedMemories = try modelContext.fetch(FetchDescriptor<ExerciseMemory>())
        XCTAssertEqual(fetchedMemories.count, 1)
        XCTAssertEqual(fetchedMemories.first?.name, "squat")
    }

    func testJSONImportMergesPRs_betterPRKept() throws {
        // Insert existing PR
        let existingPR = PersonalRecord(exerciseName: "bench press", weight: 185, reps: 5, workoutId: UUID())
        modelContext.insert(existingPR)
        try modelContext.save()

        // Export a better PR
        let betterPR = PersonalRecord(exerciseName: "bench press", weight: 225, reps: 5, workoutId: UUID())
        let data = WorkoutDataExporter.generateJSON(workouts: [], memories: [], records: [betterPR])

        let result = try WorkoutDataExporter.importJSON(data: data, into: modelContext)
        XCTAssertEqual(result.prsUpdated, 1)

        let fetchedPRs = try modelContext.fetch(FetchDescriptor<PersonalRecord>())
        XCTAssertEqual(fetchedPRs.count, 1)
        XCTAssertEqual(fetchedPRs.first?.weight, 225)
    }

    func testJSONImportMergesPRs_worsePRSkipped() throws {
        // Insert existing PR (better)
        let existingPR = PersonalRecord(exerciseName: "bench press", weight: 225, reps: 5, workoutId: UUID())
        modelContext.insert(existingPR)
        try modelContext.save()

        // Export a worse PR
        let worsePR = PersonalRecord(exerciseName: "bench press", weight: 185, reps: 5, workoutId: UUID())
        let data = WorkoutDataExporter.generateJSON(workouts: [], memories: [], records: [worsePR])

        let result = try WorkoutDataExporter.importJSON(data: data, into: modelContext)
        XCTAssertEqual(result.prsUpdated, 0)

        let fetchedPRs = try modelContext.fetch(FetchDescriptor<PersonalRecord>())
        XCTAssertEqual(fetchedPRs.first?.weight, 225)
    }

    func testJSONImportInsertsNewPR() throws {
        let pr = PersonalRecord(exerciseName: "squat", weight: 315, reps: 3, workoutId: UUID())
        let data = WorkoutDataExporter.generateJSON(workouts: [], memories: [], records: [pr])

        let result = try WorkoutDataExporter.importJSON(data: data, into: modelContext)
        XCTAssertEqual(result.prsUpdated, 1)

        let fetchedPRs = try modelContext.fetch(FetchDescriptor<PersonalRecord>())
        XCTAssertEqual(fetchedPRs.count, 1)
        XCTAssertEqual(fetchedPRs.first?.exerciseName, "squat")
    }

    // MARK: - Round Trip

    func testJSONRoundTrip() throws {
        // Create rich data
        let workout = makeCompletedWorkout(name: "Full Body", exerciseName: "Squat", setCount: 3, weight: 225, reps: 5)
        let template = Workout(name: "PPL Template", date: Date(), isTemplate: true)
        let templateEx = Exercise(name: "Deadlift", order: 0)
        templateEx.addSet(reps: 5, weight: 315)
        template.exercises = [templateEx]

        let memory = ExerciseMemory(name: "squat", lastReps: 5, lastWeight: 225, lastSets: 5)
        let pr = PersonalRecord(exerciseName: "squat", weight: 315, reps: 3, workoutId: workout.id)

        // Export
        let data = WorkoutDataExporter.generateJSON(
            workouts: [workout, template],
            memories: [memory],
            records: [pr]
        )

        // Import into fresh context
        let result = try WorkoutDataExporter.importJSON(data: data, into: modelContext)
        XCTAssertEqual(result.workoutsImported, 2)

        // Export again from imported data
        let importedWorkouts = try modelContext.fetch(FetchDescriptor<Workout>())
        let importedMemories = try modelContext.fetch(FetchDescriptor<ExerciseMemory>())
        let importedPRs = try modelContext.fetch(FetchDescriptor<PersonalRecord>())

        let data2 = WorkoutDataExporter.generateJSON(
            workouts: importedWorkouts,
            memories: importedMemories,
            records: importedPRs
        )

        // Decode both and compare structure
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let envelope1 = try decoder.decode(ExportEnvelope.self, from: data)
        let envelope2 = try decoder.decode(ExportEnvelope.self, from: data2)

        XCTAssertEqual(envelope1.workouts.count, envelope2.workouts.count)
        XCTAssertEqual(envelope1.exerciseMemories.count, envelope2.exerciseMemories.count)
        XCTAssertEqual(envelope1.personalRecords.count, envelope2.personalRecords.count)

        // Verify workout IDs match (same UUIDs preserved through round-trip)
        let ids1 = Set(envelope1.workouts.map(\.id))
        let ids2 = Set(envelope2.workouts.map(\.id))
        XCTAssertEqual(ids1, ids2)
    }

    func testCSVExportStillWorks() {
        let workout = makeCompletedWorkout(name: "Test Workout", exerciseName: "Bench Press")
        let csv = WorkoutDataExporter.generateCSV(from: [workout])
        XCTAssertTrue(csv.contains("Workout Date,Workout Name,Exercise,Set Number,Reps,Weight"))
        XCTAssertTrue(csv.contains("Test Workout"))
        XCTAssertTrue(csv.contains("Bench Press"))
    }

    func testImportUnsupportedVersionThrows() {
        let json = """
        {
            "version": 99,
            "exportDate": "2026-03-13T10:00:00Z",
            "appVersion": "1.0",
            "workouts": [],
            "exerciseMemories": [],
            "personalRecords": []
        }
        """
        let data = json.data(using: .utf8)!
        XCTAssertThrowsError(try WorkoutDataExporter.importJSON(data: data, into: modelContext)) { error in
            XCTAssertTrue(error.localizedDescription.contains("newer version"))
        }
    }

    func testImportInvalidJSONThrows() {
        let data = "not valid json".data(using: .utf8)!
        XCTAssertThrowsError(try WorkoutDataExporter.importJSON(data: data, into: modelContext))
    }

    func testExportEmptyDatabase() throws {
        let data = WorkoutDataExporter.generateJSON(workouts: [], memories: [], records: [])
        XCTAssertFalse(data.isEmpty)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let envelope = try decoder.decode(ExportEnvelope.self, from: data)
        XCTAssertEqual(envelope.workouts.count, 0)
        XCTAssertEqual(envelope.exerciseMemories.count, 0)
        XCTAssertEqual(envelope.personalRecords.count, 0)
    }

    // MARK: - DTO Conversion

    func testWorkoutToExportModelPreservesAllFields() {
        let workout = Workout(id: UUID(), name: "Test", date: Date(), isTemplate: false)
        workout.startTime = Date()
        workout.endTime = Date().addingTimeInterval(3600)
        let exercise = Exercise(name: "Squat", order: 0)
        exercise.addSet(reps: 5, weight: 225)
        workout.exercises = [exercise]

        let export = workout.toExportModel()
        XCTAssertEqual(export.id, workout.id)
        XCTAssertEqual(export.name, workout.name)
        XCTAssertEqual(export.startTime, workout.startTime)
        XCTAssertEqual(export.endTime, workout.endTime)
        XCTAssertEqual(export.isTemplate, workout.isTemplate)
        XCTAssertEqual(export.exercises.count, 1)
        XCTAssertEqual(export.exercises.first?.sets.count, 1)
    }

    func testWorkoutFromExportModelCreatesCorrectObjects() {
        let exportSet = ExportSet(id: UUID(), reps: 8, weight: 185, durationSeconds: nil, setType: "Working", sortOrder: 0)
        let exportExercise = ExportExercise(id: UUID(), name: "Bench Press", order: 0, supersetGroupId: nil, supersetOrder: 0, sets: [exportSet])
        let exportWorkout = ExportWorkout(id: UUID(), name: "Push Day", date: Date(), startTime: Date(), endTime: Date().addingTimeInterval(3600), isTemplate: false, exercises: [exportExercise])

        let workout = Workout.fromExportModel(exportWorkout)
        XCTAssertEqual(workout.id, exportWorkout.id)
        XCTAssertEqual(workout.name, "Push Day")
        XCTAssertEqual(workout.exercises?.count, 1)
        XCTAssertEqual(workout.exercises?.first?.name, "Bench Press")
        XCTAssertEqual(workout.exercises?.first?.sets?.first?.reps, 8)
        XCTAssertEqual(workout.exercises?.first?.sets?.first?.weight, 185)
    }

    // MARK: - Helpers

    private func makeCompletedWorkout(
        name: String,
        exerciseName: String,
        setCount: Int = 1,
        weight: Double = 135,
        reps: Int = 10
    ) -> Workout {
        let workout = Workout(name: name, date: Date(), isTemplate: false)
        workout.startTime = Date()
        workout.endTime = Date().addingTimeInterval(3600)

        let exercise = Exercise(name: exerciseName, order: 0)
        for _ in 0..<setCount {
            exercise.addSet(reps: reps, weight: weight)
        }
        workout.exercises = [exercise]
        return workout
    }
}
