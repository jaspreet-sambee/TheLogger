//
//  ExerciseType.swift
//  TheLogger
//
//  Exercise definitions for camera-based rep counting
//

import Vision

/// Supported exercise types for camera rep counting
enum ExerciseType: String, CaseIterable {
    case squat = "Squat"
    case bicepCurl = "Bicep Curl"
    case shoulderPress = "Shoulder Press"
    case lateralRaise = "Lateral Raise"
    case frontRaise = "Front Raise"

    /// The joints used to calculate the primary angle for this exercise
    var jointConfiguration: JointConfiguration {
        switch self {
        case .squat:
            return JointConfiguration(
                joint1: .rightAnkle,      // bottom reference (feet)
                joint2: .rightShoulder,   // top reference (shoulders)
                joint3: .rightHip,        // tracked joint (hip drops when squatting)
                downThreshold: 95,        // hip height ratio when squatting (mapped to pseudo-angle)
                upThreshold: 105,         // hip height ratio when standing
                description: "Track hip height",
                startsAtBottom: false,
                measurement: .verticalProgress
            )
        case .bicepCurl:
            return JointConfiguration(
                joint1: .rightHip,       // bottom reference
                joint2: .rightShoulder,  // top reference
                joint3: .rightWrist,     // tracked point
                downThreshold: 25,       // wrist at hip level (~0°, allow some slack)
                upThreshold: 100,        // wrist well above midpoint
                description: "Track wrist height",
                startsAtBottom: true,
                measurement: .verticalProgress
            )
        case .shoulderPress:
            return JointConfiguration(
                joint1: .rightShoulder,
                joint2: .rightElbow,
                joint3: .rightWrist,
                downThreshold: 95,    // Elbow angle at bottom
                upThreshold: 160,     // Elbow angle at top (arms extended)
                description: "Track arm extension"
            )
        case .lateralRaise:
            return JointConfiguration(
                joint1: .rightHip,
                joint2: .rightShoulder,
                joint3: .rightWrist,
                downThreshold: 30,    // Arm at side
                upThreshold: 75,      // Arm raised to ~shoulder height
                description: "Track arm raise",
                startsAtBottom: true
            )
        case .frontRaise:
            return JointConfiguration(
                joint1: .rightHip,
                joint2: .rightShoulder,
                joint3: .rightWrist,
                downThreshold: 25,    // Arm hanging at side
                upThreshold: 80,      // Arm raised to shoulder height
                description: "Track arm raise",
                startsAtBottom: true
            )
        }
    }

    /// Body framing instruction shown in the calibration overlay
    var framingTip: String {
        switch self {
        case .bicepCurl, .shoulderPress, .lateralRaise, .frontRaise:
            return "Step back so the camera can see you from the waist up"
        case .squat:
            return "Stand back so the camera can see your full body"
        }
    }

    /// Short note shown in the calibration overlay describing which limb(s) are tracked
    var trackingNote: String {
        switch self {
        case .bicepCurl, .shoulderPress, .lateralRaise, .frontRaise:
            return "Either arm counts"
        case .squat:
            return "Both legs tracked"
        }
    }

    /// Phone placement tip shown in the calibration overlay
    var setupTip: String {
        switch self {
        case .squat:         return "Phone propped at waist height, ~6 ft away, portrait"
        case .bicepCurl:     return "Phone against wall in front of you, portrait"
        case .shoulderPress: return "Phone propped at chest height, facing you"
        case .lateralRaise:  return "Phone propped in front, chest height, portrait"
        case .frontRaise:    return "Phone propped in front, chest height, portrait"
        }
    }

    /// Short description of how to perform one rep, shown on the setup screen
    var repDescription: String {
        switch self {
        case .squat:        return "Stand → squat down → stand back up. Keep knees visible."
        case .bicepCurl:    return "Extend arms → curl up past 90° → extend back. Keep elbows visible to camera."
        case .shoulderPress: return "Weights at shoulders → press overhead → lower back. Face the camera."
        case .lateralRaise: return "Arms at sides → raise to shoulder height → lower back down."
        case .frontRaise:   return "Arms hanging → raise in front to shoulder height → lower back down."
        }
    }

    /// System image for UI display
    var systemImage: String {
        switch self {
        case .squat:         return "figure.strengthtraining.traditional"
        case .bicepCurl:     return "dumbbell.fill"
        case .shoulderPress: return "figure.highintensity.intervaltraining"
        case .lateralRaise:  return "figure.arms.open"
        case .frontRaise:    return "figure.cross.training"
        }
    }

    /// Category for grouping in the picker
    var category: ExerciseCategory {
        switch self {
        case .shoulderPress, .lateralRaise, .frontRaise:
            return .push
        case .bicepCurl:
            return .pull
        case .squat:
            return .legs
        }
    }

    /// Attempt to match exercise name to a supported type
    static func from(exerciseName: String) -> ExerciseType? {
        let name = exerciseName.lowercased()

        // Squat variants
        if name.contains("squat") || name.contains("goblet squat") || name.contains("front squat") ||
           name.contains("back squat") || name.contains("sumo squat") { return .squat }

        // Curl variants (bicep-specific)
        if name.contains("bicep") && name.contains("curl") { return .bicepCurl }
        if name.contains("arm curl") || name.contains("dumbbell curl") || name.contains("barbell curl") { return .bicepCurl }
        if name.contains("hammer curl") || name.contains("preacher curl") || name.contains("ez curl") { return .bicepCurl }
        if name.contains("standing curl") || name.contains("concentration curl") || name.contains("cable curl") { return .bicepCurl }

        // Shoulder/overhead press
        if name.contains("shoulder press") || name.contains("overhead press") || name.contains("ohp") || name.contains("military press") { return .shoulderPress }
        if name.contains("arnold press") || name.contains("seated press") { return .shoulderPress }
        if name.contains("dumbbell press") && name.contains("shoulder") { return .shoulderPress }

        // Lateral raise
        if name.contains("lateral raise") || name.contains("side raise") || name.contains("lat raise") { return .lateralRaise }

        // Front raise
        if name.contains("front raise") || name.contains("plate raise") { return .frontRaise }

        return nil
    }
}

/// Category for grouping exercises in the picker
enum ExerciseCategory: String, CaseIterable {
    case push = "Push"
    case pull = "Pull"
    case legs = "Legs"
}

/// How the angle/progress value is computed for an exercise
enum AngleMeasurement: Equatable {
    /// Standard 3-joint geometric angle (default for most exercises)
    case geometric
    /// Wrist Y-position relative to hip–shoulder range, mapped to 0°–180° pseudo-angle.
    /// Used for exercises invisible in 2D from the front (e.g., bicep curl).
    case verticalProgress
}

/// Configuration for tracking a specific joint angle
struct JointConfiguration {
    let joint1: VNHumanBodyPoseObservation.JointName  // First joint (e.g., hip)
    let joint2: VNHumanBodyPoseObservation.JointName  // Middle joint - the angle vertex (e.g., knee)
    let joint3: VNHumanBodyPoseObservation.JointName  // Third joint (e.g., ankle)
    let downThreshold: Double  // Angle when in "down" position
    let upThreshold: Double    // Angle when in "up" position
    let description: String

    /// True for exercises that start at bottom (low angle) and go up (e.g., lateral raise).
    /// False (default) for exercises that start at top (high angle) and go down (e.g., squat).
    let startsAtBottom: Bool

    /// How the angle value is computed (geometric vs vertical progress)
    let measurement: AngleMeasurement

    init(
        joint1: VNHumanBodyPoseObservation.JointName,
        joint2: VNHumanBodyPoseObservation.JointName,
        joint3: VNHumanBodyPoseObservation.JointName,
        downThreshold: Double,
        upThreshold: Double,
        description: String,
        startsAtBottom: Bool = false,
        measurement: AngleMeasurement = .geometric
    ) {
        self.joint1 = joint1
        self.joint2 = joint2
        self.joint3 = joint3
        self.downThreshold = downThreshold
        self.upThreshold = upThreshold
        self.description = description
        self.startsAtBottom = startsAtBottom
        self.measurement = measurement
    }

    /// Minimum confidence required for joint detection
    static let minimumConfidence: Float = 0.3

    /// Expected range of motion (degrees) for this exercise
    var expectedROM: Double {
        abs(upThreshold - downThreshold)
    }

    /// Minimum ROM required to count a rep (40% of expected)
    var minimumROM: Double {
        expectedROM * 0.4
    }

    /// Hysteresis buffer to prevent threshold oscillation (8% of expected ROM)
    var hysteresis: Double {
        expectedROM * 0.08
    }
}
