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

    /// Populate the database with realistic sample data.
    /// No-ops if workout history already exists (safe to call on every launch).
    static func populateSampleData(modelContext: ModelContext) {
        let descriptor = FetchDescriptor<Workout>(predicate: #Predicate { !$0.isTemplate })
        let existingCount = (try? modelContext.fetchCount(descriptor)) ?? 0
        guard existingCount == 0 else {
            print("[DEBUG] Sample data already exists (\(existingCount) workouts), skipping seed")
            return
        }

        createTemplates(modelContext: modelContext)
        createWorkoutHistory(modelContext: modelContext)
        createExerciseMemories(modelContext: modelContext)

        try? modelContext.save()
        print("[DEBUG] ✅ Sample data seeded: 24 workouts, 3 templates, 15 exercise memories")
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
        let today = Date()

        func makeDate(daysAgo: Int, hour: Int) -> Date {
            let d = calendar.date(byAdding: .day, value: -daysAgo, to: today) ?? today
            return calendar.date(bySettingHour: hour, minute: 0, second: 0, of: d) ?? d
        }

        // PPL schedule over 8 weeks: (daysAgo, type, week 1–8, startHour)
        // week 1 = oldest, week 8 = most recent — used for progressive overload
        let schedule: [(daysAgo: Int, type: String, week: Int, hour: Int)] = [
            // Week 1 (8 weeks ago)
            (56, "push", 1, 7),
            (54, "pull", 1, 9),
            (52, "legs", 1, 7),
            // Week 2
            (49, "push", 2, 9),
            (47, "pull", 2, 7),
            (45, "legs", 2, 9),
            // Week 3
            (42, "push", 3, 7),
            (40, "pull", 3, 9),
            (38, "legs", 3, 7),
            // Week 4
            (35, "push", 4, 9),
            (33, "pull", 4, 7),
            (30, "legs", 4, 9),
            // Week 5
            (28, "push", 5, 7),
            (26, "pull", 5, 9),
            (23, "legs", 5, 7),
            // Week 6
            (21, "push", 6, 9),
            (19, "pull", 6, 7),
            (16, "legs", 6, 9),
            // Week 7
            (14, "push", 7, 7),
            (12, "pull", 7, 9),
            (9,  "legs", 7, 7),
            // Week 8 (most recent completed)
            (7,  "push", 8, 9),
            (5,  "pull", 8, 7),
            (3,  "legs", 8, 9),
        ]

        for session in schedule {
            let startDate = makeDate(daysAgo: session.daysAgo, hour: session.hour)
            let endDate = calendar.date(byAdding: .minute, value: 65, to: startDate) ?? startDate
            let workoutName = session.type == "push" ? "Push Day" :
                              session.type == "pull" ? "Pull Day" : "Leg Day"

            let workout = Workout(name: workoutName, date: startDate, isTemplate: false)
            workout.startTime = startDate
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
