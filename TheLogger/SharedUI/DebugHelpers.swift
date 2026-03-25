//
//  DebugHelpers.swift
//  TheLogger
//
//  Debug utilities for development and testing
//

import SwiftUI
import SwiftData

#if DEBUG
struct DebugHelpers {

    // MARK: - Entry Point

    /// Version key — bump to force a re-seed on next launch (clears old workouts).
    private static let seedVersion = 2

    /// Populate the database with realistic sample data.
    /// Re-seeds automatically when `seedVersion` is bumped; safe to call on every launch.
    static func populateSampleData(modelContext: ModelContext) {
        let seededVersion = UserDefaults.standard.integer(forKey: "debugSeedVersion")
        guard seededVersion < seedVersion else {
            print("[DEBUG] Seed data is current (v\(seedVersion)), skipping")
            return
        }

        // Clear any existing non-template workouts before re-seeding.
        let descriptor = FetchDescriptor<Workout>(predicate: #Predicate { !$0.isTemplate })
        if let existing = try? modelContext.fetch(descriptor) {
            existing.forEach { modelContext.delete($0) }
            try? modelContext.save()
        }

        createTemplates(modelContext: modelContext)
        createWorkoutHistory(modelContext: modelContext)
        createExerciseMemories(modelContext: modelContext)

        try? modelContext.save()
        UserDefaults.standard.set(seedVersion, forKey: "debugSeedVersion")
        print("[DEBUG] ✅ Sample data seeded (v\(seedVersion)): workouts, 3 templates, 15 exercise memories")
    }

    // MARK: - Templates

    private static func createTemplates(modelContext: ModelContext) {
        let today = Date()

        let pushTemplate = Workout(name: "Push Day", date: today, isTemplate: true)
        for name in ["Bench Press", "Incline Dumbbell Press", "Overhead Press", "Lateral Raise", "Tricep Pushdown"] {
            pushTemplate.addExercise(name: name)
        }
        modelContext.insert(pushTemplate)

        let pullTemplate = Workout(name: "Pull Day", date: today, isTemplate: true)
        for name in ["Deadlift", "Barbell Row", "Lat Pulldown", "Dumbbell Curl", "Face Pull"] {
            pullTemplate.addExercise(name: name)
        }
        modelContext.insert(pullTemplate)

        let legsTemplate = Workout(name: "Leg Day", date: today, isTemplate: true)
        for name in ["Squat", "Leg Press", "Romanian Deadlift", "Leg Curl", "Calf Raise"] {
            legsTemplate.addExercise(name: name)
        }
        modelContext.insert(legsTemplate)
    }

    // MARK: - Workout History

    private static func createWorkoutHistory(modelContext: ModelContext) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // Find this week's Monday so current-week workouts always land in the right bucket.
        var components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today)
        components.weekday = 2  // Monday
        let thisMonday = calendar.date(from: components) ?? today

        // Build sessions: week=8 is current week, week=1 is 7 weeks ago.
        // Push=Mon, Pull=Tue, Legs=Wed. Skip sessions whose date is in the future.
        struct Session { let date: Date; let type: String; let week: Int }
        var sessions: [Session] = []

        for weekOffset in 0..<8 {
            let weekNumber = 8 - weekOffset  // 8 = current, 1 = oldest
            guard let mon = calendar.date(byAdding: .weekOfYear, value: -weekOffset, to: thisMonday) else { continue }
            let tue = calendar.date(byAdding: .day, value: 1, to: mon)!
            let wed = calendar.date(byAdding: .day, value: 2, to: mon)!

            let daySlots: [(type: String, base: Date, hour: Int)] = [
                ("push", mon, 9),
                ("pull", tue, 7),
                ("legs", wed, 9),
            ]
            for slot in daySlots {
                guard slot.base <= today else { continue }
                let startDate = calendar.date(bySettingHour: slot.hour, minute: 0, second: 0, of: slot.base) ?? slot.base
                sessions.append(Session(date: startDate, type: slot.type, week: weekNumber))
            }
        }

        for session in sessions {
            let endDate = calendar.date(byAdding: .minute, value: 65, to: session.date) ?? session.date
            let workoutName = session.type == "push" ? "Push Day" :
                              session.type == "pull" ? "Pull Day" : "Leg Day"

            let workout = Workout(name: workoutName, date: session.date, isTemplate: false)
            workout.startTime = session.date
            workout.endTime = endDate

            switch session.type {
            case "push": addPushDay(to: workout, week: session.week)
            case "pull": addPullDay(to: workout, week: session.week)
            case "legs": addLegDay(to: workout, week: session.week)
            default: break
            }

            modelContext.insert(workout)
        }
    }

    // MARK: - Push Day

    private static func addPushDay(to workout: Workout, week: Int) {
        // Bench Press: 185 → 225 lbs
        workout.addExercise(name: "Bench Press")
        if let ex = workout.exercisesByOrder.last {
            let bp = w(185, 225, week)
            addSet(to: ex, reps: 5, weight: 135, type: .warmup)
            addSet(to: ex, reps: 8, weight: bp)
            addSet(to: ex, reps: 8, weight: bp)
            addSet(to: ex, reps: 6, weight: bp + 10)
        }

        // Incline Dumbbell Press: 55 → 75 lbs
        workout.addExercise(name: "Incline Dumbbell Press")
        if let ex = workout.exercisesByOrder.last {
            let idp = w(55, 75, week)
            addSet(to: ex, reps: 10, weight: idp)
            addSet(to: ex, reps: 10, weight: idp)
            addSet(to: ex, reps: 8,  weight: idp)
        }

        // Overhead Press: 95 → 125 lbs
        workout.addExercise(name: "Overhead Press")
        if let ex = workout.exercisesByOrder.last {
            let ohp = w(95, 125, week)
            addSet(to: ex, reps: 5, weight: 65, type: .warmup)
            addSet(to: ex, reps: 8, weight: ohp)
            addSet(to: ex, reps: 8, weight: ohp)
            addSet(to: ex, reps: 6, weight: ohp)
        }

        // Lateral Raise: 20 → 30 lbs
        workout.addExercise(name: "Lateral Raise")
        if let ex = workout.exercisesByOrder.last {
            let lr = w(20, 30, week)
            addSet(to: ex, reps: 15, weight: lr)
            addSet(to: ex, reps: 15, weight: lr)
            addSet(to: ex, reps: 12, weight: lr)
        }

        // Tricep Pushdown: 50 → 80 lbs
        workout.addExercise(name: "Tricep Pushdown")
        if let ex = workout.exercisesByOrder.last {
            let tp = w(50, 80, week)
            addSet(to: ex, reps: 12, weight: tp)
            addSet(to: ex, reps: 12, weight: tp)
            addSet(to: ex, reps: 10, weight: tp)
        }
    }

    // MARK: - Pull Day

    private static func addPullDay(to workout: Workout, week: Int) {
        // Deadlift: 275 → 355 lbs
        workout.addExercise(name: "Deadlift")
        if let ex = workout.exercisesByOrder.last {
            let dl = w(275, 355, week)
            addSet(to: ex, reps: 5, weight: 135, type: .warmup)
            addSet(to: ex, reps: 3, weight: 225, type: .warmup)
            addSet(to: ex, reps: 5, weight: dl)
            addSet(to: ex, reps: 5, weight: dl)
        }

        // Barbell Row: 135 → 185 lbs
        workout.addExercise(name: "Barbell Row")
        if let ex = workout.exercisesByOrder.last {
            let br = w(135, 185, week)
            addSet(to: ex, reps: 5, weight: 95, type: .warmup)
            addSet(to: ex, reps: 8, weight: br)
            addSet(to: ex, reps: 8, weight: br)
            addSet(to: ex, reps: 8, weight: br)
        }

        // Lat Pulldown: 100 → 140 lbs
        workout.addExercise(name: "Lat Pulldown")
        if let ex = workout.exercisesByOrder.last {
            let lp = w(100, 140, week)
            addSet(to: ex, reps: 10, weight: lp)
            addSet(to: ex, reps: 10, weight: lp)
            addSet(to: ex, reps: 8,  weight: lp)
        }

        // Dumbbell Curl: 30 → 45 lbs
        workout.addExercise(name: "Dumbbell Curl")
        if let ex = workout.exercisesByOrder.last {
            let dc = w(30, 45, week)
            addSet(to: ex, reps: 12, weight: dc)
            addSet(to: ex, reps: 12, weight: dc)
            addSet(to: ex, reps: 10, weight: dc)
        }

        // Face Pull: 40 → 70 lbs
        workout.addExercise(name: "Face Pull")
        if let ex = workout.exercisesByOrder.last {
            let fp = w(40, 70, week)
            addSet(to: ex, reps: 15, weight: fp)
            addSet(to: ex, reps: 15, weight: fp)
            addSet(to: ex, reps: 15, weight: fp)
        }
    }

    // MARK: - Leg Day

    private static func addLegDay(to workout: Workout, week: Int) {
        // Squat: 225 → 295 lbs
        workout.addExercise(name: "Squat")
        if let ex = workout.exercisesByOrder.last {
            let sq = w(225, 295, week)
            addSet(to: ex, reps: 5, weight: 135, type: .warmup)
            addSet(to: ex, reps: 3, weight: 185, type: .warmup)
            addSet(to: ex, reps: 5, weight: sq)
            addSet(to: ex, reps: 5, weight: sq)
            addSet(to: ex, reps: 5, weight: sq)
        }

        // Leg Press: 270 → 450 lbs
        workout.addExercise(name: "Leg Press")
        if let ex = workout.exercisesByOrder.last {
            let lp = w(270, 450, week)
            addSet(to: ex, reps: 12, weight: lp)
            addSet(to: ex, reps: 10, weight: lp)
            addSet(to: ex, reps: 10, weight: lp)
        }

        // Romanian Deadlift: 135 → 205 lbs
        workout.addExercise(name: "Romanian Deadlift")
        if let ex = workout.exercisesByOrder.last {
            let rdl = w(135, 205, week)
            addSet(to: ex, reps: 10, weight: rdl)
            addSet(to: ex, reps: 10, weight: rdl)
            addSet(to: ex, reps: 8,  weight: rdl)
        }

        // Leg Curl: 80 → 120 lbs
        workout.addExercise(name: "Leg Curl")
        if let ex = workout.exercisesByOrder.last {
            let lc = w(80, 120, week)
            addSet(to: ex, reps: 12, weight: lc)
            addSet(to: ex, reps: 12, weight: lc)
            addSet(to: ex, reps: 10, weight: lc)
        }

        // Calf Raise: 100 → 180 lbs
        workout.addExercise(name: "Calf Raise")
        if let ex = workout.exercisesByOrder.last {
            let cr = w(100, 180, week)
            addSet(to: ex, reps: 15, weight: cr)
            addSet(to: ex, reps: 15, weight: cr)
            addSet(to: ex, reps: 15, weight: cr)
        }
    }

    // MARK: - Exercise Memories

    private static func createExerciseMemories(modelContext: ModelContext) {
        // Reflect the most recent session (week 8) weights
        let memories: [(name: String, weight: Double, reps: Int, sets: Int)] = [
            ("Bench Press",            w(185, 225, 8) + 10, 6,  4),
            ("Incline Dumbbell Press", w(55, 75, 8),        8,  3),
            ("Overhead Press",         w(95, 125, 8),       6,  3),
            ("Lateral Raise",          w(20, 30, 8),        12, 3),
            ("Tricep Pushdown",        w(50, 80, 8),        10, 3),
            ("Deadlift",               w(275, 355, 8),      5,  2),
            ("Barbell Row",            w(135, 185, 8),      8,  3),
            ("Lat Pulldown",           w(100, 140, 8),      8,  3),
            ("Dumbbell Curl",          w(30, 45, 8),        10, 3),
            ("Face Pull",              w(40, 70, 8),        15, 3),
            ("Squat",                  w(225, 295, 8),      5,  3),
            ("Leg Press",              w(270, 450, 8),      10, 3),
            ("Romanian Deadlift",      w(135, 205, 8),      8,  3),
            ("Leg Curl",               w(80, 120, 8),       10, 3),
            ("Calf Raise",             w(100, 180, 8),      15, 3),
        ]

        for m in memories {
            modelContext.insert(ExerciseMemory(
                name: m.name,
                lastReps: m.reps,
                lastWeight: m.weight,
                lastSets: m.sets
            ))
        }
    }

    // MARK: - Helpers

    /// Interpolate weight from `start` (week 1) to `end` (week 8), rounded to nearest 5 lbs.
    private static func w(_ start: Double, _ end: Double, _ week: Int) -> Double {
        let t = Double(week - 1) / 7.0
        return ((start + (end - start) * t) / 5).rounded() * 5
    }

    /// Append a set to an exercise, respecting sortOrder and supporting set type.
    private static func addSet(to exercise: Exercise, reps: Int, weight: Double, type: SetType = .working) {
        let nextOrder = (exercise.sets ?? []).map(\.sortOrder).max().map { $0 + 1 } ?? 0
        let newSet = WorkoutSet(reps: reps, weight: weight, setType: type, sortOrder: nextOrder)
        if exercise.sets == nil {
            exercise.sets = [newSet]
        } else {
            exercise.sets?.append(newSet)
        }
    }
}
#endif
