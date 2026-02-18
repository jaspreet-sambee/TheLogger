//
//  ExerciseType.swift
//  TheLogger
//
//  Exercise definitions for camera-based rep counting
//

import Vision

/// Supported exercise types for camera rep counting
enum ExerciseType: String, CaseIterable {
    // Existing
    case squat = "Squat"
    case pushUp = "Push-up"
    case bicepCurl = "Bicep Curl"
    case shoulderPress = "Shoulder Press"
    case lunge = "Lunge"

    // New - Upper Body
    case tricepExtension = "Tricep Extension"
    case lateralRaise = "Lateral Raise"
    case bentOverRow = "Bent Over Row"
    case chestFly = "Chest Fly"
    case tricepDip = "Tricep Dip"

    // New - Lower Body
    case legExtension = "Leg Extension"
    case legCurl = "Leg Curl"
    case romanianDeadlift = "Romanian Deadlift"
    case calfRaise = "Calf Raise"
    case pullUp = "Pull-up"

    /// The joints used to calculate the primary angle for this exercise
    var jointConfiguration: JointConfiguration {
        switch self {

        // MARK: - Existing Exercises

        case .squat:
            return JointConfiguration(
                joint1: .rightHip,
                joint2: .rightKnee,
                joint3: .rightAnkle,
                downThreshold: 110,   // Knee angle when squatting
                upThreshold: 155,     // Knee angle when standing
                description: "Track knee bend"
            )
        case .pushUp:
            return JointConfiguration(
                joint1: .rightShoulder,
                joint2: .rightElbow,
                joint3: .rightWrist,
                downThreshold: 100,   // Elbow angle at bottom
                upThreshold: 155,     // Elbow angle at top
                description: "Track elbow bend"
            )
        case .bicepCurl:
            return JointConfiguration(
                joint1: .rightShoulder,
                joint2: .rightElbow,
                joint3: .rightWrist,
                downThreshold: 50,    // Elbow angle at top of curl (flexed)
                upThreshold: 140,     // Elbow angle at bottom (extended)
                description: "Track elbow curl"
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
        case .lunge:
            return JointConfiguration(
                joint1: .rightHip,
                joint2: .rightKnee,
                joint3: .rightAnkle,
                downThreshold: 100,   // Front knee angle at bottom
                upThreshold: 155,     // Knee angle when standing
                description: "Track front knee bend"
            )

        // MARK: - New Upper Body Exercises

        case .tricepExtension:
            // Overhead tricep extension: elbow starts bent behind head, extends upward
            // Inverted: small angle = bent (down), large angle = extended (up)
            return JointConfiguration(
                joint1: .rightShoulder,
                joint2: .rightElbow,
                joint3: .rightWrist,
                downThreshold: 55,    // Elbow angle when bent (weight behind head)
                upThreshold: 145,     // Elbow angle when extended (weight overhead)
                description: "Track elbow extension"
            )
        case .lateralRaise:
            // Track angle at shoulder: arm hangs down (small angle) → raised to side (large angle)
            // Hip-Shoulder-Wrist angle increases as arm raises
            return JointConfiguration(
                joint1: .rightHip,
                joint2: .rightShoulder,
                joint3: .rightWrist,
                downThreshold: 30,    // Arm at side (small hip-shoulder-wrist angle)
                upThreshold: 75,      // Arm raised to ~shoulder height
                description: "Track arm raise"
            )
        case .bentOverRow:
            // Pulling motion: elbow extends (arm straight down) → flexes (pulls up)
            // Inverted: small angle = pulled up (top), large angle = extended (bottom)
            return JointConfiguration(
                joint1: .rightShoulder,
                joint2: .rightElbow,
                joint3: .rightWrist,
                downThreshold: 55,    // Elbow angle when pulled up (flexed)
                upThreshold: 140,     // Elbow angle when extended (arm hanging)
                description: "Track elbow pull"
            )
        case .chestFly:
            // Cable/dumbbell fly: arms wide → arms together in front
            // Track shoulder angle: hip-shoulder-wrist
            // Arms wide = large angle, arms together = small angle
            return JointConfiguration(
                joint1: .rightHip,
                joint2: .rightShoulder,
                joint3: .rightWrist,
                downThreshold: 30,    // Arms together in front (small angle)
                upThreshold: 80,      // Arms wide open (large angle)
                description: "Track chest squeeze"
            )
        case .tricepDip:
            // Dip motion: elbow bends (lowering) → extends (pushing up)
            // Same joint pattern as push-up but different thresholds
            return JointConfiguration(
                joint1: .rightShoulder,
                joint2: .rightElbow,
                joint3: .rightWrist,
                downThreshold: 90,    // Elbow angle at bottom of dip
                upThreshold: 150,     // Elbow angle at top (arms extended)
                description: "Track dip depth"
            )

        // MARK: - New Lower Body Exercises

        case .legExtension:
            // Seated: knee starts bent → leg extends straight out
            // Same joints as squat but with adjusted thresholds for seated position
            return JointConfiguration(
                joint1: .rightHip,
                joint2: .rightKnee,
                joint3: .rightAnkle,
                downThreshold: 85,    // Knee bent (seated starting position)
                upThreshold: 150,     // Knee extended (leg straight)
                description: "Track knee extension"
            )
        case .legCurl:
            // Inverted of leg extension: leg starts straight → curls to bend knee
            // Small angle = curled (top), large angle = straight (bottom)
            return JointConfiguration(
                joint1: .rightHip,
                joint2: .rightKnee,
                joint3: .rightAnkle,
                downThreshold: 70,    // Knee angle when fully curled
                upThreshold: 150,     // Knee angle when straight
                description: "Track knee curl"
            )
        case .romanianDeadlift:
            // Hip hinge: track shoulder-hip-knee angle
            // Standing upright = large angle, bent over = small angle
            return JointConfiguration(
                joint1: .rightShoulder,
                joint2: .rightHip,
                joint3: .rightKnee,
                downThreshold: 100,   // Hip angle when bent over
                upThreshold: 155,     // Hip angle when standing upright
                description: "Track hip hinge"
            )
        case .calfRaise:
            // Track knee-ankle angle using ankle as vertex
            // Foot flat = one angle, raised on toes = different angle
            // Using hip-knee-ankle: standing straight = large angle, slight knee bend at top = smaller
            // Actually better: track the hip vertical displacement relative to ankle
            // Simplest approach: use knee angle which changes slightly during calf raise
            return JointConfiguration(
                joint1: .rightHip,
                joint2: .rightKnee,
                joint3: .rightAnkle,
                downThreshold: 165,   // Slight knee flex at bottom
                upThreshold: 175,     // Full extension on toes
                description: "Track calf extension"
            )
        case .pullUp:
            // Similar to bicep curl: elbow angle decreases as you pull up
            // Arms extended at bottom (large angle) → flexed at top (small angle)
            return JointConfiguration(
                joint1: .rightShoulder,
                joint2: .rightElbow,
                joint3: .rightWrist,
                downThreshold: 60,    // Elbow angle at top (chin over bar)
                upThreshold: 145,     // Elbow angle at bottom (hanging)
                description: "Track pull-up"
            )
        }
    }

    /// System image for UI display
    var systemImage: String {
        switch self {
        case .squat: return "figure.strengthtraining.traditional"
        case .pushUp: return "figure.core.training"
        case .bicepCurl: return "figure.arms.open"
        case .lunge: return "figure.walk"
        case .shoulderPress: return "figure.arms.open"
        case .tricepExtension: return "figure.arms.open"
        case .lateralRaise: return "figure.arms.open"
        case .bentOverRow: return "figure.strengthtraining.functional"
        case .chestFly: return "figure.arms.open"
        case .tricepDip: return "figure.strengthtraining.functional"
        case .legExtension: return "figure.strengthtraining.traditional"
        case .legCurl: return "figure.strengthtraining.traditional"
        case .romanianDeadlift: return "figure.strengthtraining.functional"
        case .calfRaise: return "figure.walk"
        case .pullUp: return "figure.climbing"
        }
    }

    /// Category for grouping in the picker
    var category: ExerciseCategory {
        switch self {
        case .pushUp, .shoulderPress, .chestFly, .tricepExtension, .tricepDip, .lateralRaise:
            return .push
        case .bicepCurl, .bentOverRow, .pullUp:
            return .pull
        case .squat, .lunge, .legExtension, .legCurl, .romanianDeadlift, .calfRaise:
            return .legs
        }
    }

    /// Attempt to match exercise name to a supported type
    static func from(exerciseName: String) -> ExerciseType? {
        let name = exerciseName.lowercased()

        // Squat variants
        if name.contains("squat") { return .squat }

        // Push-up variants
        if name.contains("push-up") || name.contains("pushup") || name.contains("push up") { return .pushUp }

        // Curl variants (bicep-specific)
        if name.contains("bicep") && name.contains("curl") { return .bicepCurl }
        if name.contains("arm curl") || name.contains("dumbbell curl") || name.contains("barbell curl") { return .bicepCurl }
        if name.contains("hammer curl") || name.contains("preacher curl") || name.contains("ez curl") { return .bicepCurl }

        // Tricep extension variants
        if name.contains("tricep") && (name.contains("extension") || name.contains("overhead") || name.contains("skull")) { return .tricepExtension }
        if name.contains("french press") { return .tricepExtension }

        // Tricep dip
        if name.contains("dip") || name.contains("tricep dip") { return .tricepDip }

        // Shoulder/overhead press
        if name.contains("shoulder press") || name.contains("overhead press") || name.contains("ohp") || name.contains("military press") { return .shoulderPress }

        // Lateral raise
        if name.contains("lateral raise") || name.contains("side raise") || name.contains("lat raise") { return .lateralRaise }

        // Chest fly
        if name.contains("fly") || name.contains("flye") || name.contains("pec deck") { return .chestFly }

        // Bent over row
        if name.contains("row") && (name.contains("bent") || name.contains("barbell") || name.contains("dumbbell")) { return .bentOverRow }
        if name.contains("row") && !name.contains("upright") { return .bentOverRow }

        // Pull-up / chin-up
        if name.contains("pull-up") || name.contains("pullup") || name.contains("pull up") { return .pullUp }
        if name.contains("chin-up") || name.contains("chinup") || name.contains("chin up") { return .pullUp }

        // Lunge variants
        if name.contains("lunge") { return .lunge }

        // Leg extension
        if name.contains("leg extension") || name.contains("quad extension") { return .legExtension }

        // Leg curl
        if name.contains("leg curl") || name.contains("hamstring curl") { return .legCurl }

        // Romanian deadlift / hip hinge
        if name.contains("romanian") || name.contains("rdl") || name.contains("stiff leg") { return .romanianDeadlift }
        if name.contains("deadlift") && !name.contains("sumo") { return .romanianDeadlift }

        // Calf raise
        if name.contains("calf raise") || name.contains("calf press") { return .calfRaise }

        return nil
    }
}

/// Category for grouping exercises in the picker
enum ExerciseCategory: String, CaseIterable {
    case push = "Push"
    case pull = "Pull"
    case legs = "Legs"
}

/// Configuration for tracking a specific joint angle
struct JointConfiguration {
    let joint1: VNHumanBodyPoseObservation.JointName  // First joint (e.g., hip)
    let joint2: VNHumanBodyPoseObservation.JointName  // Middle joint - the angle vertex (e.g., knee)
    let joint3: VNHumanBodyPoseObservation.JointName  // Third joint (e.g., ankle)
    let downThreshold: Double  // Angle when in "down" position
    let upThreshold: Double    // Angle when in "up" position
    let description: String

    /// Minimum confidence required for joint detection
    static let minimumConfidence: Float = 0.3
}
