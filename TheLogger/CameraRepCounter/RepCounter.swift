//
//  RepCounter.swift
//  TheLogger
//
//  4-state machine for counting exercise reps with false-positive prevention.
//  States: idle → armed → down → up → down → up → ... → (auto-disarm) → idle
//

import Foundation
import UIKit

/// Counts repetitions by tracking joint angle transitions through a 4-state machine.
///
/// **Idle**: Camera on, angles observed, but no reps counted. Waits for stability.
/// **Armed**: User in starting position — ready for first rep.
/// **Down**: User in lowering/eccentric phase.
/// **Up**: Rep completed, waiting for next descent.
@Observable
nonisolated final class RepCounter {

    // MARK: - Types

    /// The current phase of the repetition state machine
    enum Phase: String {
        case idle = "IDLE"      // Observing, waiting for stability
        case armed = "ARMED"    // Stable in start position, ready
        case down = "DOWN"      // Flexed / bottom position
        case up = "UP"          // Extended / top — rep just completed or returning
    }

    /// Feedback for the current movement state
    enum MovementFeedback: String {
        case settingUp = "Setting up..."
        case almostReady = "Hold steady..."
        case armed = "Ready!"
        case ready = "Ready"
        case goingDown = "Going down..."
        case holdingDown = "At bottom"
        case goingUp = "Coming up..."
        case repComplete = "Rep!"
        case tooShallow = "Go deeper"
        case tooFast = "Too fast"
        case noDetection = "Position yourself in frame"
        case lowVisibility = "Low visibility"
    }

    /// Reason why a rep candidate was rejected
    enum RejectionReason {
        case none
        case tooShallow
        case tooFast
        case notArmed
        case lowConfidence
    }

    // MARK: - Observable Properties

    /// Current rep count
    private(set) var repCount: Int = 0

    /// Current state machine phase
    private(set) var currentPhase: Phase = .idle

    /// Current feedback message
    private(set) var feedback: MovementFeedback = .settingUp

    /// Current smoothed angle (for display/debug)
    private(set) var currentAngle: Double = 0

    /// Reason the last rep candidate was rejected (for toast display)
    private(set) var lastRejectionReason: RejectionReason = .none

    /// Arming stability progress (0..1) — drives progress bar in UI
    private(set) var stabilityProgress: Double = 0

    /// Whether the most recent completed rep had low confidence
    private(set) var isLowConfidenceRep: Bool = false

    /// Number of reps rejected for insufficient ROM
    private(set) var rejectedShallowCount: Int = 0

    /// Number of reps rejected for being too fast
    private(set) var rejectedFastCount: Int = 0

    /// Whether detection is currently active
    var isActive: Bool = true

    /// ROM multiplier for sensitivity control (0.25 = easy, 0.4 = normal, 0.5 = strict)
    var sensitivityMultiplier: Double = 0.4

    /// Minimum rep duration override for sensitivity control
    var minimumRepDurationOverride: TimeInterval = 0.6

    // MARK: - Diagnostics

    /// Total frames processed by processAngle (including outlier-rejected)
    private(set) var debugFrameCount: Int = 0

    /// Frames that passed outlier filter and reached the state machine
    private(set) var debugAcceptedFrames: Int = 0

    /// Whether the last frame was rejected by the outlier filter
    private(set) var debugLastOutlierRejected: Bool = false

    /// Last computed isNearStart value in processIdle
    private(set) var debugIsNearStart: Bool = false

    /// Last computed isStable value in processIdle
    private(set) var debugIsStable: Bool = false

    // MARK: - Configuration

    private let configuration: JointConfiguration
    private let forTesting: Bool

    // MARK: - EMA Smoothing

    /// Exponential moving average of the angle
    private var emaAngle: Double?
    /// Previous EMA value — used to compute angular velocity
    private var previousEmaAngle: Double?
    /// Current angular velocity (°/frame)
    private(set) var angularVelocity: Double = 0

    private let normalAlpha: Double = 0.3
    private let heavyAlpha: Double = 0.15
    private var currentAlpha: Double = 0.3

    // MARK: - Outlier Rejection

    private var normalOutlierThreshold: Double {
        max(40.0, configuration.expectedROM)
    }
    private var tightOutlierThreshold: Double {
        max(25.0, configuration.expectedROM * 0.6)
    }
    private var currentOutlierThreshold: Double = 40.0

    // MARK: - Stability Detection (idle → armed)

    private var stabilityFrameCount: Int = 0
    /// Frames of stable position required (~0.4s at 30 fps)
    static let requiredStabilityFrames: Int = 12
    /// Angle must be within this range of upThreshold
    static let stabilityAngleTolerance: Double = 8.0
    /// Angular velocity must be below this (°/frame)
    static let stabilityVelocityThreshold: Double = 8.0

    // MARK: - Rep Validation

    /// Angle at the start of the current rep cycle
    private var repStartAngle: Double?
    /// Minimum angle observed during current rep cycle
    private var repMinAngle: Double = .greatestFiniteMagnitude
    /// Maximum angle observed during current rep cycle
    private var repMaxAngle: Double = -.greatestFiniteMagnitude
    /// Time when the "down" phase started
    private var phaseStartTime: Date?
    /// Minimum time for a full rep cycle (down → up)
    static let minimumRepDuration: TimeInterval = 0.6

    // MARK: - Auto-Disarm

    /// Time of the last completed rep (or arming time)
    private var lastRepTime: Date = .distantPast
    /// Seconds of inactivity before returning to idle
    static let autoDisarmTimeout: TimeInterval = 8.0

    // MARK: - Confidence Tracking

    /// Accumulated confidence during current rep cycle
    private var repConfidenceSum: Double = 0
    /// Number of confidence samples during current rep cycle
    private var repConfidenceCount: Int = 0

    // MARK: - Peak Contraction Callback

    /// Called whenever the tracked joint reaches a new extreme depth during the down phase.
    /// Use this to capture the frame for a share card. Fires on the calling thread (main).
    var onPeakContraction: (() -> Void)?

    // MARK: - Initialization

    init(exerciseType: ExerciseType, forTesting: Bool = false) {
        self.configuration = exerciseType.jointConfiguration
        self.forTesting = forTesting
        self.currentOutlierThreshold = max(40.0, exerciseType.jointConfiguration.expectedROM)
    }

    init(configuration: JointConfiguration, forTesting: Bool = false) {
        self.configuration = configuration
        self.forTesting = forTesting
        self.currentOutlierThreshold = max(40.0, configuration.expectedROM)
    }

    // MARK: - Public Methods

    /// Process a new angle reading and detect reps.
    /// - Parameters:
    ///   - angle: Raw joint angle in degrees
    ///   - confidence: Pose detection confidence (0..1). Adjusts smoothing.
    /// - Returns: `true` if a rep was just completed
    @discardableResult
    func processAngle(_ angle: Double, confidence: Double = 1.0) -> Bool {
        guard isActive else { return false }

        debugFrameCount += 1

        // Adaptive smoothing based on confidence
        updateSmoothingForConfidence(confidence)

        // Outlier rejection: discard single-frame jumps
        if let ema = emaAngle, abs(angle - ema) > currentOutlierThreshold {
            debugLastOutlierRejected = true
            return false
        }
        debugLastOutlierRejected = false
        debugAcceptedFrames += 1

        // EMA smoothing
        let smoothed: Double
        if let prev = emaAngle {
            smoothed = currentAlpha * angle + (1 - currentAlpha) * prev
        } else {
            smoothed = angle
        }

        // Angular velocity (°/frame)
        if let prev = previousEmaAngle {
            angularVelocity = abs(smoothed - prev)
        }
        previousEmaAngle = emaAngle
        emaAngle = smoothed
        currentAngle = smoothed

        // Track confidence for current rep
        repConfidenceSum += confidence
        repConfidenceCount += 1

        // Check auto-disarm
        checkAutoDisarm(angle: smoothed)

        // State machine
        return processStateMachine(angle: smoothed, confidence: confidence)
    }

    /// Reset the counter to initial state
    func reset() {
        repCount = 0
        currentPhase = .idle
        feedback = .settingUp
        emaAngle = nil
        previousEmaAngle = nil
        angularVelocity = 0
        stabilityFrameCount = 0
        stabilityProgress = 0
        repStartAngle = nil
        repMinAngle = .greatestFiniteMagnitude
        repMaxAngle = -.greatestFiniteMagnitude
        phaseStartTime = nil
        lastRejectionReason = .none
        isLowConfidenceRep = false
        rejectedShallowCount = 0
        rejectedFastCount = 0
        repConfidenceSum = 0
        repConfidenceCount = 0
        lastRepTime = .distantPast
        debugFrameCount = 0
        debugAcceptedFrames = 0
        debugLastOutlierRejected = false
        debugIsNearStart = false
        debugIsStable = false
    }

    /// Manually add a rep
    func addRep() {
        repCount += 1
        triggerHaptic()
    }

    /// Manually remove a rep
    func removeRep() {
        if repCount > 0 {
            repCount -= 1
        }
    }

    // MARK: - Private: State Machine

    private func processStateMachine(angle: Double, confidence: Double) -> Bool {
        switch currentPhase {
        case .idle:
            return processIdle(angle: angle)
        case .armed:
            return processArmed(angle: angle, confidence: confidence)
        case .down:
            return processDown(angle: angle, confidence: confidence)
        case .up:
            return processUp(angle: angle, confidence: confidence)
        }
    }

    // MARK: idle

    private func processIdle(angle: Double) -> Bool {
        let isNearStart: Bool
        if configuration.startsAtBottom {
            isNearStart = angle <= (configuration.downThreshold + Self.stabilityAngleTolerance)
        } else {
            isNearStart = angle >= (configuration.upThreshold - Self.stabilityAngleTolerance)
        }
        let isStable = angularVelocity < Self.stabilityVelocityThreshold
        debugIsNearStart = isNearStart
        debugIsStable = isStable

        if isNearStart && isStable {
            stabilityFrameCount += 1
            stabilityProgress = min(1.0, Double(stabilityFrameCount) / Double(Self.requiredStabilityFrames))

            if stabilityFrameCount >= Self.requiredStabilityFrames {
                // Transition → armed
                currentPhase = .armed
                feedback = .armed
                stabilityProgress = 1.0
                lastRepTime = Date() // reset disarm timer on arming

                // Fade "Ready!" → "Ready" after a short delay
                if !forTesting {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
                        guard let self else { return }
                        if self.currentPhase == .armed || self.currentPhase == .up {
                            self.feedback = .ready
                        }
                    }
                }
            } else {
                feedback = .almostReady
            }
        } else {
            // Gradual stability decay (forgives brief wobbles)
            if stabilityFrameCount > 0 {
                stabilityFrameCount = max(0, stabilityFrameCount - 1)
                stabilityProgress = Double(stabilityFrameCount) / Double(Self.requiredStabilityFrames)
            }
            feedback = .settingUp
        }
        return false
    }

    // MARK: armed

    private func processArmed(angle: Double, confidence: Double) -> Bool {
        // Armed is functionally "up" — looking for the user to go down
        return processUpPhase(angle: angle, confidence: confidence, isFirstRep: true)
    }

    // MARK: down

    private func processDown(angle: Double, confidence: Double) -> Bool {
        // Track ROM extremes — fire peak contraction callback when we reach a new extreme
        let isNewExtreme = configuration.startsAtBottom ? angle > repMaxAngle : angle < repMinAngle
        repMinAngle = min(repMinAngle, angle)
        repMaxAngle = max(repMaxAngle, angle)

        if isNewExtreme {
            onPeakContraction?()
        }

        let hysteresis = configuration.hysteresis

        if configuration.startsAtBottom {
            // Ascending exercises: rep completes when angle DROPS back past downThreshold
            if angle < (configuration.downThreshold + hysteresis) {
                return validateAndCompleteRep(confidence: confidence)
            } else if angle < (configuration.upThreshold - 15) {
                feedback = .goingDown
            }
        } else {
            // Descending exercises: rep completes when angle RISES back past upThreshold
            if angle > (configuration.upThreshold - hysteresis) {
                return validateAndCompleteRep(confidence: confidence)
            } else if angle > (configuration.downThreshold + 15) {
                feedback = .goingUp
            }
        }

        return false
    }

    // MARK: up

    private func processUp(angle: Double, confidence: Double) -> Bool {
        return processUpPhase(angle: angle, confidence: confidence, isFirstRep: false)
    }

    /// Common logic for armed and up phases — looking for movement away from start position
    private func processUpPhase(angle: Double, confidence: Double, isFirstRep: Bool) -> Bool {
        let hysteresis = configuration.hysteresis

        if configuration.startsAtBottom {
            // Ascending exercises: start low, look for angle to RISE past upThreshold
            if angle > (configuration.upThreshold - hysteresis) {
                currentPhase = .down  // "down" phase = peak of ascending movement
                feedback = .holdingDown
                phaseStartTime = Date()
                repStartAngle = angle
                repMinAngle = angle
                repMaxAngle = angle
                repConfidenceSum = confidence
                repConfidenceCount = 1
            } else if angle > (configuration.downThreshold + 20) {
                feedback = .goingUp
            } else if !isFirstRep {
                feedback = .ready
            }
        } else {
            // Descending exercises: start high, look for angle to DROP past downThreshold
            if angle < (configuration.downThreshold + hysteresis) {
                currentPhase = .down
                feedback = .holdingDown
                phaseStartTime = Date()
                repStartAngle = angle
                repMinAngle = angle
                repMaxAngle = angle
                repConfidenceSum = confidence
                repConfidenceCount = 1
            } else if angle < (configuration.upThreshold - 20) {
                feedback = .goingDown
            } else if !isFirstRep {
                feedback = .ready
            }
        }

        return false
    }

    // MARK: - Rep Validation

    private func validateAndCompleteRep(confidence: Double) -> Bool {
        // 1. Minimum ROM (scaled by sensitivity)
        let actualROM = repMaxAngle - repMinAngle
        let requiredROM = configuration.expectedROM * sensitivityMultiplier
        if actualROM < requiredROM {
            rejectRep(reason: .tooShallow)
            return false
        }

        // 2. Minimum duration (skipped in test mode — processAngle calls are instantaneous)
        if !forTesting, let startTime = phaseStartTime {
            let duration = Date().timeIntervalSince(startTime)
            if duration < minimumRepDurationOverride {
                rejectRep(reason: .tooFast)
                return false
            }
        }

        // 3. Flag low-confidence reps
        let avgConfidence = repConfidenceCount > 0
            ? repConfidenceSum / Double(repConfidenceCount)
            : 1.0
        isLowConfidenceRep = avgConfidence < 0.4

        return completeRep()
    }

    private func completeRep() -> Bool {
        lastRepTime = Date()
        currentPhase = .up
        repCount += 1
        feedback = .repComplete
        lastRejectionReason = .none

        triggerHaptic()

        // Reset rep-cycle tracking
        resetRepTracking()

        // Fade "Rep!" → "Ready"
        if !forTesting {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                if self?.feedback == .repComplete {
                    self?.feedback = .ready
                }
            }
        }

        return true
    }

    private func rejectRep(reason: RejectionReason) {
        lastRejectionReason = reason
        currentPhase = .up

        switch reason {
        case .tooShallow: rejectedShallowCount += 1
        case .tooFast:    rejectedFastCount += 1
        default: break
        }

        if !forTesting {
            let reasonStr: String
            switch reason {
            case .tooShallow: reasonStr = "shallow"
            case .tooFast: reasonStr = "fast"
            default: reasonStr = "other"
            }
            Analytics.send(Analytics.Signal.cameraRepRejected, parameters: ["reason": reasonStr])
        }

        resetRepTracking()

        switch reason {
        case .tooShallow: feedback = .tooShallow
        case .tooFast:    feedback = .tooFast
        default: break
        }

        // Clear rejection feedback after delay
        if !forTesting {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
                if self?.feedback == .tooShallow || self?.feedback == .tooFast {
                    self?.feedback = .ready
                }
            }
        }
    }

    private func resetRepTracking() {
        repStartAngle = nil
        repMinAngle = .greatestFiniteMagnitude
        repMaxAngle = -.greatestFiniteMagnitude
        phaseStartTime = nil
        repConfidenceSum = 0
        repConfidenceCount = 0
    }

    // MARK: - Auto-Disarm

    private func checkAutoDisarm(angle: Double) {
        guard currentPhase == .armed || currentPhase == .up else { return }

        let timeSinceLastActivity = Date().timeIntervalSince(lastRepTime)

        // For ascending exercises, the rest position is near downThreshold.
        // For descending exercises, the rest position is near upThreshold.
        let restThreshold = configuration.startsAtBottom ? configuration.downThreshold : configuration.upThreshold
        let farFromExerciseZone = abs(angle - restThreshold) > configuration.expectedROM * 0.6

        if timeSinceLastActivity > Self.autoDisarmTimeout && farFromExerciseZone {
            currentPhase = .idle
            feedback = .settingUp
            stabilityFrameCount = 0
            stabilityProgress = 0
        }
    }

    // MARK: - Confidence Adaptation

    private func updateSmoothingForConfidence(_ confidence: Double) {
        if confidence > 0.7 {
            currentAlpha = normalAlpha
            currentOutlierThreshold = normalOutlierThreshold
        } else if confidence > 0.3 {
            // Medium confidence — heavier smoothing, tighter outlier rejection
            currentAlpha = heavyAlpha
            currentOutlierThreshold = tightOutlierThreshold
        }
        // Below 0.3: caller should pause processing entirely
    }

    // MARK: - Haptics

    private func triggerHaptic() {
        guard !forTesting else { return }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }
}
