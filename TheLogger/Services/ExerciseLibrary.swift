//
//  ExerciseLibrary.swift
//  TheLogger
//
//  Built-in exercise database with muscle groups
//

import Foundation

// MARK: - Exercise Library

enum MuscleGroup: String, CaseIterable, Identifiable {
    case chest = "Chest"
    case back = "Back"
    case shoulders = "Shoulders"
    case arms = "Arms"
    case legs = "Legs"
    case core = "Core"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .chest: return "figure.arms.open"
        case .back: return "figure.walk"
        case .shoulders: return "figure.boxing"
        case .arms: return "figure.strengthtraining.traditional"
        case .legs: return "figure.run"
        case .core: return "figure.core.training"
        }
    }
}

struct LibraryExercise: Identifiable, Hashable {
    let id: String
    let name: String
    let muscleGroup: MuscleGroup
    let isCompound: Bool
    /// When true, sets are logged by duration (seconds) instead of reps/weight
    let isTimeBased: Bool

    init(id: String, name: String, muscleGroup: MuscleGroup, isCompound: Bool, isTimeBased: Bool = false) {
        self.id = id
        self.name = name
        self.muscleGroup = muscleGroup
        self.isCompound = isCompound
        self.isTimeBased = isTimeBased
    }

    var normalizedName: String {
        name.lowercased().trimmingCharacters(in: .whitespaces)
    }
}

struct ExerciseLibrary {
    static let shared = ExerciseLibrary()

    let exercises: [LibraryExercise]

    private init() {
        exercises = Self.buildLibrary()
    }

    /// Get exercises grouped by muscle group
    var groupedByMuscle: [MuscleGroup: [LibraryExercise]] {
        Dictionary(grouping: exercises, by: { $0.muscleGroup })
    }

    /// Search exercises by name
    func search(_ query: String) -> [LibraryExercise] {
        guard !query.isEmpty else { return exercises }
        let q = query.lowercased()
        return exercises.filter { $0.normalizedName.contains(q) }
    }

    /// Find exercise by name
    func find(name: String) -> LibraryExercise? {
        let normalized = name.lowercased().trimmingCharacters(in: .whitespaces)
        return exercises.first { $0.normalizedName == normalized }
    }

    /// Get suggested rest duration
    func restDuration(for exerciseName: String) -> Int {
        if let exercise = find(name: exerciseName) {
            return exercise.isCompound ? 120 : 60
        }
        // Fallback heuristics
        let name = exerciseName.lowercased()
        let compoundKeywords = ["squat", "deadlift", "bench", "press", "row", "pull-up", "pullup", "chin-up", "chinup", "dip", "clean", "snatch", "thrust", "lunge"]
        for keyword in compoundKeywords {
            if name.contains(keyword) { return 120 }
        }
        return 60
    }

    private static func buildLibrary() -> [LibraryExercise] {
        var list: [LibraryExercise] = []

        // CHEST
        list.append(contentsOf: [
            LibraryExercise(id: "bench-press", name: "Bench Press", muscleGroup: .chest, isCompound: true),
            LibraryExercise(id: "incline-bench-press", name: "Incline Bench Press", muscleGroup: .chest, isCompound: true),
            LibraryExercise(id: "decline-bench-press", name: "Decline Bench Press", muscleGroup: .chest, isCompound: true),
            LibraryExercise(id: "dumbbell-bench-press", name: "Dumbbell Bench Press", muscleGroup: .chest, isCompound: true),
            LibraryExercise(id: "incline-dumbbell-press", name: "Incline Dumbbell Press", muscleGroup: .chest, isCompound: true),
            LibraryExercise(id: "chest-fly", name: "Chest Fly", muscleGroup: .chest, isCompound: false),
            LibraryExercise(id: "cable-fly", name: "Cable Fly", muscleGroup: .chest, isCompound: false),
            LibraryExercise(id: "pec-deck", name: "Pec Deck", muscleGroup: .chest, isCompound: false),
            LibraryExercise(id: "push-up", name: "Push-Up", muscleGroup: .chest, isCompound: true),
            LibraryExercise(id: "dips-chest", name: "Dips (Chest)", muscleGroup: .chest, isCompound: true),
            LibraryExercise(id: "dumbbell-fly", name: "Dumbbell Fly", muscleGroup: .chest, isCompound: false),
            LibraryExercise(id: "decline-dumbbell-press", name: "Decline Dumbbell Press", muscleGroup: .chest, isCompound: true),
            LibraryExercise(id: "chest-press-machine", name: "Chest Press Machine", muscleGroup: .chest, isCompound: true),
            LibraryExercise(id: "floor-press", name: "Floor Press", muscleGroup: .chest, isCompound: true),
            LibraryExercise(id: "landmine-press", name: "Landmine Press", muscleGroup: .chest, isCompound: true),
            LibraryExercise(id: "svend-press", name: "Svend Press", muscleGroup: .chest, isCompound: false),
            LibraryExercise(id: "pec-fly-machine", name: "Pec Fly Machine", muscleGroup: .chest, isCompound: false),
            LibraryExercise(id: "incline-cable-fly", name: "Incline Cable Fly", muscleGroup: .chest, isCompound: false),
        ])

        // BACK
        list.append(contentsOf: [
            LibraryExercise(id: "deadlift", name: "Deadlift", muscleGroup: .back, isCompound: true),
            LibraryExercise(id: "barbell-row", name: "Barbell Row", muscleGroup: .back, isCompound: true),
            LibraryExercise(id: "dumbbell-row", name: "Dumbbell Row", muscleGroup: .back, isCompound: true),
            LibraryExercise(id: "pull-up", name: "Pull-Up", muscleGroup: .back, isCompound: true),
            LibraryExercise(id: "chin-up", name: "Chin-Up", muscleGroup: .back, isCompound: true),
            LibraryExercise(id: "lat-pulldown", name: "Lat Pulldown", muscleGroup: .back, isCompound: true),
            LibraryExercise(id: "seated-cable-row", name: "Seated Cable Row", muscleGroup: .back, isCompound: true),
            LibraryExercise(id: "t-bar-row", name: "T-Bar Row", muscleGroup: .back, isCompound: true),
            LibraryExercise(id: "face-pull", name: "Face Pull", muscleGroup: .back, isCompound: false),
            LibraryExercise(id: "straight-arm-pulldown", name: "Straight Arm Pulldown", muscleGroup: .back, isCompound: false),
            LibraryExercise(id: "rack-pull", name: "Rack Pull", muscleGroup: .back, isCompound: true),
            LibraryExercise(id: "romanian-deadlift", name: "Romanian Deadlift", muscleGroup: .back, isCompound: true),
            LibraryExercise(id: "single-arm-dumbbell-row", name: "Single-Arm Dumbbell Row", muscleGroup: .back, isCompound: false),
            LibraryExercise(id: "pendlay-row", name: "Pendlay Row", muscleGroup: .back, isCompound: true),
            LibraryExercise(id: "wide-grip-lat-pulldown", name: "Wide Grip Lat Pulldown", muscleGroup: .back, isCompound: true),
            LibraryExercise(id: "close-grip-lat-pulldown", name: "Close Grip Lat Pulldown", muscleGroup: .back, isCompound: true),
            LibraryExercise(id: "reverse-grip-pulldown", name: "Reverse Grip Pulldown", muscleGroup: .back, isCompound: true),
            LibraryExercise(id: "inverted-row", name: "Inverted Row", muscleGroup: .back, isCompound: true),
            LibraryExercise(id: "machine-row", name: "Machine Row", muscleGroup: .back, isCompound: true),
            LibraryExercise(id: "back-extension", name: "Back Extension", muscleGroup: .back, isCompound: false),
            LibraryExercise(id: "good-morning", name: "Good Morning", muscleGroup: .back, isCompound: true),
            LibraryExercise(id: "hyperextension", name: "Hyperextension", muscleGroup: .back, isCompound: false),
            LibraryExercise(id: "v-bar-row", name: "V-Bar Row", muscleGroup: .back, isCompound: true),
        ])

        // SHOULDERS
        list.append(contentsOf: [
            LibraryExercise(id: "overhead-press", name: "Overhead Press", muscleGroup: .shoulders, isCompound: true),
            LibraryExercise(id: "seated-dumbbell-press", name: "Seated Dumbbell Press", muscleGroup: .shoulders, isCompound: true),
            LibraryExercise(id: "arnold-press", name: "Arnold Press", muscleGroup: .shoulders, isCompound: true),
            LibraryExercise(id: "lateral-raise", name: "Lateral Raise", muscleGroup: .shoulders, isCompound: false),
            LibraryExercise(id: "front-raise", name: "Front Raise", muscleGroup: .shoulders, isCompound: false),
            LibraryExercise(id: "rear-delt-fly", name: "Rear Delt Fly", muscleGroup: .shoulders, isCompound: false),
            LibraryExercise(id: "upright-row", name: "Upright Row", muscleGroup: .shoulders, isCompound: true),
            LibraryExercise(id: "shrugs", name: "Shrugs", muscleGroup: .shoulders, isCompound: false),
            LibraryExercise(id: "cable-lateral-raise", name: "Cable Lateral Raise", muscleGroup: .shoulders, isCompound: false),
            LibraryExercise(id: "face-pull-shoulders", name: "Face Pull", muscleGroup: .shoulders, isCompound: false),
            LibraryExercise(id: "push-press", name: "Push Press", muscleGroup: .shoulders, isCompound: true),
            LibraryExercise(id: "machine-shoulder-press", name: "Machine Shoulder Press", muscleGroup: .shoulders, isCompound: true),
            LibraryExercise(id: "reverse-pec-deck", name: "Reverse Pec Deck", muscleGroup: .shoulders, isCompound: false),
            LibraryExercise(id: "bent-over-lateral-raise", name: "Bent Over Lateral Raise", muscleGroup: .shoulders, isCompound: false),
            LibraryExercise(id: "cable-front-raise", name: "Cable Front Raise", muscleGroup: .shoulders, isCompound: false),
            LibraryExercise(id: "scaption-raise", name: "Scaption Raise", muscleGroup: .shoulders, isCompound: false),
            LibraryExercise(id: "landmine-shoulder-press", name: "Landmine Shoulder Press", muscleGroup: .shoulders, isCompound: true),
        ])

        // ARMS
        list.append(contentsOf: [
            LibraryExercise(id: "barbell-curl", name: "Barbell Curl", muscleGroup: .arms, isCompound: false),
            LibraryExercise(id: "dumbbell-curl", name: "Dumbbell Curl", muscleGroup: .arms, isCompound: false),
            LibraryExercise(id: "hammer-curl", name: "Hammer Curl", muscleGroup: .arms, isCompound: false),
            LibraryExercise(id: "preacher-curl", name: "Preacher Curl", muscleGroup: .arms, isCompound: false),
            LibraryExercise(id: "concentration-curl", name: "Concentration Curl", muscleGroup: .arms, isCompound: false),
            LibraryExercise(id: "cable-curl", name: "Cable Curl", muscleGroup: .arms, isCompound: false),
            LibraryExercise(id: "tricep-pushdown", name: "Tricep Pushdown", muscleGroup: .arms, isCompound: false),
            LibraryExercise(id: "tricep-dips", name: "Tricep Dips", muscleGroup: .arms, isCompound: true),
            LibraryExercise(id: "skull-crushers", name: "Skull Crushers", muscleGroup: .arms, isCompound: false),
            LibraryExercise(id: "overhead-tricep-extension", name: "Overhead Tricep Extension", muscleGroup: .arms, isCompound: false),
            LibraryExercise(id: "close-grip-bench-press", name: "Close Grip Bench Press", muscleGroup: .arms, isCompound: true),
            LibraryExercise(id: "wrist-curl", name: "Wrist Curl", muscleGroup: .arms, isCompound: false),
            LibraryExercise(id: "ez-bar-curl", name: "EZ-Bar Curl", muscleGroup: .arms, isCompound: false),
            LibraryExercise(id: "incline-dumbbell-curl", name: "Incline Dumbbell Curl", muscleGroup: .arms, isCompound: false),
            LibraryExercise(id: "reverse-curl", name: "Reverse Curl", muscleGroup: .arms, isCompound: false),
            LibraryExercise(id: "spider-curl", name: "Spider Curl", muscleGroup: .arms, isCompound: false),
            LibraryExercise(id: "tricep-kickback", name: "Tricep Kickback", muscleGroup: .arms, isCompound: false),
            LibraryExercise(id: "jm-press", name: "JM Press", muscleGroup: .arms, isCompound: false),
            LibraryExercise(id: "diamond-push-up", name: "Diamond Push-Up", muscleGroup: .arms, isCompound: true),
            LibraryExercise(id: "reverse-grip-tricep-pushdown", name: "Reverse Grip Tricep Pushdown", muscleGroup: .arms, isCompound: false),
            LibraryExercise(id: "zottman-curl", name: "Zottman Curl", muscleGroup: .arms, isCompound: false),
            LibraryExercise(id: "drag-curl", name: "Drag Curl", muscleGroup: .arms, isCompound: false),
            LibraryExercise(id: "reverse-wrist-curl", name: "Reverse Wrist Curl", muscleGroup: .arms, isCompound: false),
            LibraryExercise(id: "forearm-curl", name: "Forearm Curl", muscleGroup: .arms, isCompound: false),
        ])

        // LEGS
        list.append(contentsOf: [
            LibraryExercise(id: "squat", name: "Squat", muscleGroup: .legs, isCompound: true),
            LibraryExercise(id: "front-squat", name: "Front Squat", muscleGroup: .legs, isCompound: true),
            LibraryExercise(id: "leg-press", name: "Leg Press", muscleGroup: .legs, isCompound: true),
            LibraryExercise(id: "hack-squat", name: "Hack Squat", muscleGroup: .legs, isCompound: true),
            LibraryExercise(id: "goblet-squat", name: "Goblet Squat", muscleGroup: .legs, isCompound: true),
            LibraryExercise(id: "lunges", name: "Lunges", muscleGroup: .legs, isCompound: true),
            LibraryExercise(id: "bulgarian-split-squat", name: "Bulgarian Split Squat", muscleGroup: .legs, isCompound: true),
            LibraryExercise(id: "leg-extension", name: "Leg Extension", muscleGroup: .legs, isCompound: false),
            LibraryExercise(id: "leg-curl", name: "Leg Curl", muscleGroup: .legs, isCompound: false),
            LibraryExercise(id: "hip-thrust", name: "Hip Thrust", muscleGroup: .legs, isCompound: true),
            LibraryExercise(id: "glute-bridge", name: "Glute Bridge", muscleGroup: .legs, isCompound: false),
            LibraryExercise(id: "calf-raise", name: "Calf Raise", muscleGroup: .legs, isCompound: false),
            LibraryExercise(id: "seated-calf-raise", name: "Seated Calf Raise", muscleGroup: .legs, isCompound: false),
            LibraryExercise(id: "sumo-deadlift", name: "Sumo Deadlift", muscleGroup: .legs, isCompound: true),
            LibraryExercise(id: "step-ups", name: "Step-Ups", muscleGroup: .legs, isCompound: true),
            LibraryExercise(id: "romanian-deadlift-legs", name: "Romanian Deadlift", muscleGroup: .legs, isCompound: true),
            LibraryExercise(id: "walking-lunges", name: "Walking Lunges", muscleGroup: .legs, isCompound: true),
            LibraryExercise(id: "stiff-leg-deadlift", name: "Stiff Leg Deadlift", muscleGroup: .legs, isCompound: true),
            LibraryExercise(id: "trap-bar-deadlift", name: "Trap Bar Deadlift", muscleGroup: .legs, isCompound: true),
            LibraryExercise(id: "leg-press-calf-raise", name: "Leg Press Calf Raise", muscleGroup: .legs, isCompound: false),
            LibraryExercise(id: "calf-press", name: "Calf Press on Leg Press", muscleGroup: .legs, isCompound: false),
            LibraryExercise(id: "glute-kickback", name: "Glute Kickback", muscleGroup: .legs, isCompound: false),
            LibraryExercise(id: "hip-abduction", name: "Hip Abduction", muscleGroup: .legs, isCompound: false),
            LibraryExercise(id: "hip-adduction", name: "Hip Adduction", muscleGroup: .legs, isCompound: false),
            LibraryExercise(id: "single-leg-rdl", name: "Single-Leg RDL", muscleGroup: .legs, isCompound: false),
            LibraryExercise(id: "cossack-squat", name: "Cossack Squat", muscleGroup: .legs, isCompound: false),
            LibraryExercise(id: "sissy-squat", name: "Sissy Squat", muscleGroup: .legs, isCompound: false),
            LibraryExercise(id: "glute-ham-raise", name: "Glute Ham Raise", muscleGroup: .legs, isCompound: false),
            LibraryExercise(id: "box-step-up", name: "Box Step-Up", muscleGroup: .legs, isCompound: true),
        ])

        // CORE
        list.append(contentsOf: [
            LibraryExercise(id: "plank", name: "Plank", muscleGroup: .core, isCompound: false, isTimeBased: true),
            LibraryExercise(id: "crunches", name: "Crunches", muscleGroup: .core, isCompound: false),
            LibraryExercise(id: "leg-raise", name: "Leg Raise", muscleGroup: .core, isCompound: false),
            LibraryExercise(id: "hanging-leg-raise", name: "Hanging Leg Raise", muscleGroup: .core, isCompound: false),
            LibraryExercise(id: "russian-twist", name: "Russian Twist", muscleGroup: .core, isCompound: false),
            LibraryExercise(id: "cable-crunch", name: "Cable Crunch", muscleGroup: .core, isCompound: false),
            LibraryExercise(id: "ab-wheel-rollout", name: "Ab Wheel Rollout", muscleGroup: .core, isCompound: false),
            LibraryExercise(id: "dead-bug", name: "Dead Bug", muscleGroup: .core, isCompound: false, isTimeBased: true),
            LibraryExercise(id: "mountain-climbers", name: "Mountain Climbers", muscleGroup: .core, isCompound: false),
            LibraryExercise(id: "woodchop", name: "Woodchop", muscleGroup: .core, isCompound: false),
            LibraryExercise(id: "bicycle-crunch", name: "Bicycle Crunch", muscleGroup: .core, isCompound: false),
            LibraryExercise(id: "v-up", name: "V-Up", muscleGroup: .core, isCompound: false),
            LibraryExercise(id: "reverse-crunch", name: "Reverse Crunch", muscleGroup: .core, isCompound: false),
            LibraryExercise(id: "side-plank", name: "Side Plank", muscleGroup: .core, isCompound: false, isTimeBased: true),
            LibraryExercise(id: "oblique-crunch", name: "Oblique Crunch", muscleGroup: .core, isCompound: false),
            LibraryExercise(id: "decline-crunch", name: "Decline Crunch", muscleGroup: .core, isCompound: false),
            LibraryExercise(id: "pallof-press", name: "Pallof Press", muscleGroup: .core, isCompound: false),
            LibraryExercise(id: "bird-dog", name: "Bird Dog", muscleGroup: .core, isCompound: false, isTimeBased: true),
            LibraryExercise(id: "hollow-hold", name: "Hollow Hold", muscleGroup: .core, isCompound: false, isTimeBased: true),
            LibraryExercise(id: "windshield-wipers", name: "Windshield Wipers", muscleGroup: .core, isCompound: false),
            LibraryExercise(id: "knee-raise", name: "Knee Raise", muscleGroup: .core, isCompound: false),
            LibraryExercise(id: "flutter-kicks", name: "Flutter Kicks", muscleGroup: .core, isCompound: false),
            LibraryExercise(id: "heel-touch", name: "Heel Touch", muscleGroup: .core, isCompound: false),
            LibraryExercise(id: "sit-up", name: "Sit-Up", muscleGroup: .core, isCompound: false),
            LibraryExercise(id: "toe-touch", name: "Toe Touch", muscleGroup: .core, isCompound: false),
            LibraryExercise(id: "l-sit", name: "L-Sit", muscleGroup: .core, isCompound: false, isTimeBased: true),
            LibraryExercise(id: "plank-up-down", name: "Plank Up-Down", muscleGroup: .core, isCompound: false),
            LibraryExercise(id: "landmine-rotation", name: "Landmine Rotation", muscleGroup: .core, isCompound: false),
        ])

        return list.sorted { $0.name < $1.name }
    }
}
