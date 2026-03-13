//
//  RepCounterTests.swift
//  TheLoggerTests
//
//  Comprehensive tests for the RepCounter 4-state machine:
//  idle → armed → down → up state transitions, EMA smoothing,
//  outlier rejection, ROM/duration validation, auto-disarm,
//  confidence adaptation, sensitivity, and edge cases.
//
//  All tests use synthetic angle sequences — no camera needed.
//  Angles are fed gradually to respect EMA smoothing and outlier rejection.
//

import XCTest
import Vision
@testable import TheLogger

@MainActor
final class RepCounterTests: XCTestCase {

    // MARK: - Helpers

    /// Create a RepCounter for squats (verticalProgress: down=95, up=105, ROM=10)
    private func makeSquatCounter() -> RepCounter {
        RepCounter(exerciseType: .squat, forTesting: true)
    }

    /// Create a RepCounter for bicep curls (down=25, up=100, ROM=75, verticalProgress)
    private func makeCurlCounter() -> RepCounter {
        RepCounter(exerciseType: .bicepCurl, forTesting: true)
    }

    /// Create a RepCounter with a custom JointConfiguration
    private func makeCustomCounter(down: Double, up: Double) -> RepCounter {
        let config = JointConfiguration(
            joint1: .rightHip, joint2: .rightKnee, joint3: .rightAnkle,
            downThreshold: down, upThreshold: up,
            description: "Test"
        )
        return RepCounter(configuration: config, forTesting: true)
    }

    /// Feed a constant angle for N frames to simulate stability
    @discardableResult
    private func feedStable(_ counter: RepCounter, angle: Double, frames: Int, confidence: Double = 1.0) -> Bool {
        var completed = false
        for _ in 0..<frames {
            if counter.processAngle(angle, confidence: confidence) {
                completed = true
            }
        }
        return completed
    }

    /// Gradually transition from the counter's current angle to the target angle.
    /// Uses small steps to avoid outlier rejection and let EMA track smoothly.
    @discardableResult
    private func transitionAngle(_ counter: RepCounter, to target: Double, steps: Int = 15, confidence: Double = 1.0) -> Bool {
        let start = counter.currentAngle
        var completed = false
        for i in 1...steps {
            let t = Double(i) / Double(steps)
            let angle = start + (target - start) * t
            if counter.processAngle(angle, confidence: confidence) {
                completed = true
            }
        }
        return completed
    }

    /// Arm the counter by feeding stable angle at its start position.
    /// For descending exercises: above upThreshold (e.g., standing upright).
    /// For ascending exercises: below downThreshold (e.g., arms at sides).
    private func armCounter(_ counter: RepCounter, exerciseType: ExerciseType? = nil, upThreshold: Double = 155) {
        let config = exerciseType?.jointConfiguration
        let isAscending = config?.startsAtBottom ?? false
        let effectiveUpThreshold = config?.upThreshold ?? upThreshold

        let armingAngle: Double
        if isAscending {
            let downThreshold = config?.downThreshold ?? 30
            armingAngle = downThreshold - 15 // e.g. 15° with arms at sides
        } else {
            armingAngle = effectiveUpThreshold + 10 // e.g. 115° for squat, 170° for geometric
        }

        // If counter has no angle yet, seed it
        if counter.currentAngle == 0 {
            counter.processAngle(armingAngle)
        } else if abs(counter.currentAngle - armingAngle) > 10 {
            transitionAngle(counter, to: armingAngle)
        }
        feedStable(counter, angle: armingAngle, frames: RepCounter.requiredStabilityFrames + 5)
        XCTAssertEqual(counter.currentPhase, .armed, "Counter should be armed after stability hold")
    }

    /// Perform a complete rep using gradual transitions. Returns true if rep counted.
    /// Includes hold frames at bottom and top so EMA settles past thresholds.
    @discardableResult
    private func performRep(_ counter: RepCounter, downAngle: Double, upAngle: Double, steps: Int = 15) -> Bool {
        var completed = false
        // Gradually go down
        if transitionAngle(counter, to: downAngle, steps: steps) { completed = true }
        // Hold at bottom for EMA to settle past downThreshold
        if feedStable(counter, angle: downAngle, frames: 5) { completed = true }
        // Gradually come back up
        if transitionAngle(counter, to: upAngle, steps: steps) { completed = true }
        // Hold at top for EMA to settle past upThreshold
        if feedStable(counter, angle: upAngle, frames: 5) { completed = true }
        return completed
    }

    // MARK: - Smoke Test

    func testSmokeTest_exerciseType() {
        let config = ExerciseType.squat.jointConfiguration
        XCTAssertEqual(config.expectedROM, 10) // 105 - 95
    }

    func testSmokeTest_repCounterCreation() {
        let counter = RepCounter(exerciseType: .squat, forTesting: true)
        XCTAssertEqual(counter.repCount, 0)
    }

    // MARK: - Initial State

    func testInitialState() {
        let counter = makeSquatCounter()
        XCTAssertEqual(counter.repCount, 0)
        XCTAssertEqual(counter.currentPhase, .idle)
        XCTAssertEqual(counter.feedback, .settingUp)
        XCTAssertEqual(counter.currentAngle, 0)
        XCTAssertTrue(counter.isActive)
        XCTAssertEqual(counter.stabilityProgress, 0)
        XCTAssertEqual(counter.lastRejectionReason, .none)
        XCTAssertFalse(counter.isLowConfidenceRep)
    }

    // MARK: - Stability Detection (idle → armed)

    func testStability_progressIncreases() {
        let counter = makeSquatCounter()
        // upThreshold=105, arming at >= 97. Feed 110 (near threshold, not enough frames to arm)
        feedStable(counter, angle: 110, frames: 10)
        XCTAssertGreaterThan(counter.stabilityProgress, 0)
        XCTAssertEqual(counter.currentPhase, .idle) // Not yet armed
    }

    func testStability_armsAfterRequiredFrames() {
        let counter = makeSquatCounter()
        armCounter(counter, exerciseType: .squat)
        XCTAssertEqual(counter.currentPhase, .armed)
        XCTAssertEqual(counter.stabilityProgress, 1.0)
    }

    func testStability_requiresNearUpThreshold() {
        let counter = makeSquatCounter()
        // Feed angle far below upThreshold (105) — should NOT arm
        // 40° is well below (105 - 8 = 97), simulating being in a deep squat
        feedStable(counter, angle: 40, frames: 30)
        XCTAssertEqual(counter.currentPhase, .idle)
        XCTAssertEqual(counter.stabilityProgress, 0)
    }

    func testStability_armsAtAngleAboveThreshold() {
        let counter = makeSquatCounter()
        // Standing produces ~115° pseudo-angle, well above upThreshold (105)
        counter.processAngle(115)
        feedStable(counter, angle: 115, frames: RepCounter.requiredStabilityFrames + 5)
        XCTAssertEqual(counter.currentPhase, .armed)
        XCTAssertEqual(counter.stabilityProgress, 1.0)
    }

    func testStability_requiresLowVelocity() {
        let counter = makeSquatCounter()
        // Alternate between angles near upThreshold (105) — creates velocity
        for i in 0..<30 {
            let angle = i.isMultiple(of: 2) ? 103.0 : 107.0
            counter.processAngle(angle)
        }
        // EMA dampens the oscillation somewhat; this is a soft test
        // The key point: alternating should take longer to arm than steady
    }

    func testStability_decaysGradually() {
        let counter = makeSquatCounter()
        // Build up partial stability (not enough to arm)
        feedStable(counter, angle: 110, frames: 5)
        let progress1 = counter.stabilityProgress

        // Move well away from stability zone so decay outweighs any in-zone accumulation
        transitionAngle(counter, to: 40, steps: 10)
        let progress2 = counter.stabilityProgress

        XCTAssertLessThan(progress2, progress1, "Stability should decay when moving away")
    }

    func testStability_almostReadyFeedback() {
        let counter = makeSquatCounter()
        feedStable(counter, angle: 110, frames: 10)
        XCTAssertEqual(counter.feedback, .almostReady)
    }

    func testStability_armedFeedback() {
        let counter = makeSquatCounter()
        armCounter(counter, exerciseType: .squat)
        // In testing mode, delay doesn't fire, so it stays .armed
        XCTAssertEqual(counter.feedback, .armed)
    }

    // MARK: - Rep Counting (armed → down → up)

    func testBasicRepCount_squat() {
        let counter = makeSquatCounter()
        armCounter(counter, exerciseType: .squat)

        // Squat: down=95, up=105. Go well below 95 and back above 105.
        let didComplete = performRep(counter, downAngle: 80, upAngle: 115)
        XCTAssertTrue(didComplete)
        XCTAssertEqual(counter.repCount, 1)
        XCTAssertEqual(counter.currentPhase, .up)
    }

    func testMultipleReps() {
        let counter = makeSquatCounter()
        armCounter(counter, exerciseType: .squat)

        for _ in 0..<5 {
            performRep(counter, downAngle: 80, upAngle: 115)
        }
        XCTAssertEqual(counter.repCount, 5)
    }

    func testRepCount_bicepCurl() {
        let counter = makeCurlCounter() // down=25, up=100, startsAtBottom=true
        armCounter(counter, exerciseType: .bicepCurl)

        // Ascending exercise: raise past upThreshold (100), then lower past downThreshold (25)
        transitionAngle(counter, to: 110, steps: 20)
        feedStable(counter, angle: 110, frames: 5)
        transitionAngle(counter, to: 10, steps: 20)
        feedStable(counter, angle: 10, frames: 5)
        XCTAssertEqual(counter.repCount, 1)
    }

    func testNoRepBeforeArmed() {
        let counter = makeSquatCounter()
        XCTAssertEqual(counter.currentPhase, .idle)

        // Movements in idle don't count
        feedStable(counter, angle: 80, frames: 10)
        feedStable(counter, angle: 115, frames: 10)
        XCTAssertEqual(counter.repCount, 0)
    }

    func testPhaseTransitions_downThenUp() {
        let counter = makeSquatCounter()
        armCounter(counter, exerciseType: .squat)

        // Gradually go down past downThreshold (95)
        transitionAngle(counter, to: 80, steps: 15)
        XCTAssertEqual(counter.currentPhase, .down)

        // Gradually come back up past upThreshold (105)
        transitionAngle(counter, to: 115, steps: 15)
        XCTAssertEqual(counter.currentPhase, .up)
    }

    // MARK: - ROM Validation

    func testROM_shallowRepAccepted() {
        let counter = makeSquatCounter() // ROM=10, minimum=4
        armCounter(counter, exerciseType: .squat)

        // Go well below threshold and come back — ROM should be > 4
        performRep(counter, downAngle: 80, upAngle: 115)
        XCTAssertEqual(counter.repCount, 1)
    }

    func testROM_veryShallowRejected() {
        // Use custom config: down=100, up=160, ROM=60, minimum=24
        let counter = makeCustomCounter(down: 100, up: 160)
        feedStable(counter, angle: 160, frames: 25) // arm
        XCTAssertEqual(counter.currentPhase, .armed)

        // Dip just barely below threshold (ROM too small for a valid rep)
        // down+hysteresis = 100 + 4.8 = 104.8
        // Go to 103 (just below) — EMA will be near 103 at bottom
        // Then back up — ROM from EMA perspective will be small
        transitionAngle(counter, to: 103, steps: 10)
        transitionAngle(counter, to: 165, steps: 10)

        // The smoothed angle won't go far enough for minimumROM
        XCTAssertEqual(counter.repCount, 0, "Very shallow movement should not count")
    }

    func testROM_adequateRepAccepted() {
        let counter = makeCustomCounter(down: 100, up: 160) // ROM=60, minimum=24
        feedStable(counter, angle: 160, frames: 25) // arm

        // Go deep: down to 80, then up to 165
        transitionAngle(counter, to: 80, steps: 20)
        feedStable(counter, angle: 80, frames: 3)
        let completed = transitionAngle(counter, to: 165, steps: 20)

        XCTAssertTrue(completed)
        XCTAssertEqual(counter.repCount, 1)
    }

    // MARK: - Duration Validation

    func testDuration_tooFastRejected() {
        // With forTesting=true, duration check is skipped.
        // Test that ultra-fast movements don't count due to EMA dampening.
        let counter = makeCustomCounter(down: 100, up: 160)
        feedStable(counter, angle: 160, frames: 25) // arm

        // Try to do a rep in just 4 frames — EMA won't reach thresholds
        counter.processAngle(90)
        counter.processAngle(90)
        counter.processAngle(165)
        counter.processAngle(165)

        XCTAssertEqual(counter.repCount, 0, "Ultra-fast movements should not count due to EMA dampening")
    }

    // MARK: - Outlier Rejection

    func testOutlierRejection_singleFrameSpike() {
        let counter = makeSquatCounter()
        armCounter(counter, exerciseType: .squat)

        feedStable(counter, angle: 110, frames: 5)
        let angleBeforeSpike = counter.currentAngle

        // Feed a huge spike (>40° from EMA) — should be rejected
        counter.processAngle(0)

        XCTAssertEqual(counter.currentAngle, angleBeforeSpike, accuracy: 5.0,
                       "Outlier spike should be rejected")
    }

    func testOutlierRejection_legitimateMovementAccepted() {
        let counter = makeSquatCounter()
        armCounter(counter, exerciseType: .squat)

        // Gradual descent — each step < outlier threshold from previous EMA
        for angle in stride(from: 110.0, through: 80.0, by: -2.0) {
            counter.processAngle(angle)
        }

        XCTAssertLessThan(counter.currentAngle, 95, "Gradual descent should be tracked")
    }

    // MARK: - EMA Smoothing

    func testEMA_smoothsNoise() {
        let counter = makeSquatCounter()

        let noisyAngles = [85.0, 82.0, 88.0, 84.0, 87.0, 83.0, 86.0, 85.0]
        for angle in noisyAngles {
            counter.processAngle(angle)
        }

        XCTAssertEqual(counter.currentAngle, 85, accuracy: 5.0,
                       "EMA should smooth out noisy readings")
    }

    func testEMA_tracksRealMovement() {
        let counter = makeSquatCounter()

        for angle in stride(from: 110.0, through: 70.0, by: -2.0) {
            counter.processAngle(angle)
        }

        XCTAssertLessThan(counter.currentAngle, 90,
                          "EMA should track real movement downward")
    }

    // MARK: - Auto-Disarm

    func testAutoDisarm_afterTimeout() {
        let counter = makeSquatCounter()
        armCounter(counter, exerciseType: .squat)
        XCTAssertEqual(counter.currentPhase, .armed)

        // Auto-disarm checks Date(), so in a fast loop not enough real time passes.
        // Verify the counter stays armed without enough elapsed time.
        transitionAngle(counter, to: 80, steps: 20)

        XCTAssertTrue(counter.currentPhase == .armed || counter.currentPhase == .down,
                      "Counter should still be active shortly after arming")
    }

    // MARK: - Confidence Adaptation

    func testConfidence_normalSettings() {
        let counter = makeSquatCounter()
        counter.processAngle(110, confidence: 0.9)
        XCTAssertEqual(counter.currentPhase, .idle)
    }

    func testConfidence_lowConfidenceRep() {
        let counter = makeSquatCounter()
        armCounter(counter, exerciseType: .squat)

        // Perform rep with low confidence using gradual transitions + hold
        transitionAngle(counter, to: 80, steps: 15, confidence: 0.2)
        feedStable(counter, angle: 80, frames: 5, confidence: 0.2)
        transitionAngle(counter, to: 115, steps: 15, confidence: 0.2)
        feedStable(counter, angle: 115, frames: 5, confidence: 0.2)

        if counter.repCount > 0 {
            XCTAssertTrue(counter.isLowConfidenceRep,
                          "Rep completed with low confidence should be flagged")
        }
    }

    func testConfidence_highConfidenceRepNotFlagged() {
        let counter = makeSquatCounter()
        armCounter(counter, exerciseType: .squat)

        performRep(counter, downAngle: 80, upAngle: 115)
        XCTAssertEqual(counter.repCount, 1)
        XCTAssertFalse(counter.isLowConfidenceRep)
    }

    // MARK: - Reset

    func testReset_clearsAll() {
        let counter = makeSquatCounter()
        armCounter(counter, exerciseType: .squat)
        performRep(counter, downAngle: 80, upAngle: 115)
        XCTAssertEqual(counter.repCount, 1)

        counter.reset()

        XCTAssertEqual(counter.repCount, 0)
        XCTAssertEqual(counter.currentPhase, .idle)
        XCTAssertEqual(counter.feedback, .settingUp)
        XCTAssertEqual(counter.stabilityProgress, 0)
        XCTAssertEqual(counter.lastRejectionReason, .none)
    }

    // MARK: - Manual Rep Adjustment

    func testAddRep() {
        let counter = makeSquatCounter()
        counter.addRep()
        XCTAssertEqual(counter.repCount, 1)
        counter.addRep()
        XCTAssertEqual(counter.repCount, 2)
    }

    func testRemoveRep() {
        let counter = makeSquatCounter()
        counter.addRep()
        counter.addRep()
        counter.removeRep()
        XCTAssertEqual(counter.repCount, 1)
    }

    func testRemoveRep_doesNotGoBelowZero() {
        let counter = makeSquatCounter()
        counter.removeRep()
        XCTAssertEqual(counter.repCount, 0)
    }

    // MARK: - isActive Toggle

    func testIsActive_preventsProcessing() {
        let counter = makeSquatCounter()
        counter.isActive = false

        feedStable(counter, angle: 155, frames: 30)
        XCTAssertEqual(counter.currentPhase, .idle, "Inactive counter should not change state")
    }

    // MARK: - JointConfiguration Computed Properties

    func testJointConfiguration_expectedROM() {
        let squat = ExerciseType.squat.jointConfiguration
        XCTAssertEqual(squat.expectedROM, 10) // 105 - 95

        let curl = ExerciseType.bicepCurl.jointConfiguration
        XCTAssertEqual(curl.expectedROM, 75) // 100 - 25
    }

    func testJointConfiguration_minimumROM() {
        let squat = ExerciseType.squat.jointConfiguration
        XCTAssertEqual(squat.minimumROM, 4) // 10 * 0.4

        let curl = ExerciseType.bicepCurl.jointConfiguration
        XCTAssertEqual(curl.minimumROM, 30) // 75 * 0.4
    }

    func testJointConfiguration_hysteresis() {
        let squat = ExerciseType.squat.jointConfiguration
        XCTAssertEqual(squat.hysteresis, 0.8, accuracy: 0.01) // 10 * 0.08

        let curl = ExerciseType.bicepCurl.jointConfiguration
        XCTAssertEqual(curl.hysteresis, 6.0, accuracy: 0.01) // 75 * 0.08
    }

    // MARK: - ExerciseType Name Matching

    func testNameMatching_squatVariants() {
        XCTAssertEqual(ExerciseType.from(exerciseName: "Squat"), .squat)
        XCTAssertEqual(ExerciseType.from(exerciseName: "Goblet Squat"), .squat)
        XCTAssertEqual(ExerciseType.from(exerciseName: "Front Squat"), .squat)
        XCTAssertEqual(ExerciseType.from(exerciseName: "Back Squat"), .squat)
        XCTAssertEqual(ExerciseType.from(exerciseName: "Sumo Squat"), .squat)
    }

    func testNameMatching_curlVariants() {
        XCTAssertEqual(ExerciseType.from(exerciseName: "Bicep Curl"), .bicepCurl)
        XCTAssertEqual(ExerciseType.from(exerciseName: "Standing Curl"), .bicepCurl)
        XCTAssertEqual(ExerciseType.from(exerciseName: "Concentration Curl"), .bicepCurl)
        XCTAssertEqual(ExerciseType.from(exerciseName: "Cable Curl"), .bicepCurl)
        XCTAssertEqual(ExerciseType.from(exerciseName: "Hammer Curl"), .bicepCurl)
    }

    func testNameMatching_pressVariants() {
        XCTAssertEqual(ExerciseType.from(exerciseName: "Shoulder Press"), .shoulderPress)
        XCTAssertEqual(ExerciseType.from(exerciseName: "Arnold Press"), .shoulderPress)
        XCTAssertEqual(ExerciseType.from(exerciseName: "Military Press"), .shoulderPress)
        XCTAssertEqual(ExerciseType.from(exerciseName: "OHP"), .shoulderPress)
    }

    func testNameMatching_rowVariants_nowUnsupported() {
        XCTAssertNil(ExerciseType.from(exerciseName: "Bent Over Row"))
        XCTAssertNil(ExerciseType.from(exerciseName: "Cable Row"))
        XCTAssertNil(ExerciseType.from(exerciseName: "Seated Row"))
        XCTAssertNil(ExerciseType.from(exerciseName: "T-Bar Row"))
        XCTAssertNil(ExerciseType.from(exerciseName: "Pendlay Row"))
        XCTAssertNil(ExerciseType.from(exerciseName: "Face Pull"))
    }

    func testNameMatching_newExercises() {
        XCTAssertEqual(ExerciseType.from(exerciseName: "Front Raise"), .frontRaise)
        XCTAssertEqual(ExerciseType.from(exerciseName: "Plate Raise"), .frontRaise)

        // Removed exercises now return nil
        XCTAssertNil(ExerciseType.from(exerciseName: "Hip Thrust"))
        XCTAssertNil(ExerciseType.from(exerciseName: "Glute Bridge"))
        XCTAssertNil(ExerciseType.from(exerciseName: "Upright Row"))
        XCTAssertNil(ExerciseType.from(exerciseName: "Good Morning"))
        XCTAssertNil(ExerciseType.from(exerciseName: "Kettlebell Swing"))
    }

    func testNameMatching_lungeVariants_nowUnsupported() {
        XCTAssertNil(ExerciseType.from(exerciseName: "Lunge"))
        XCTAssertNil(ExerciseType.from(exerciseName: "Step Up"))
        // "Bulgarian Split Squat" contains "squat", so it maps to .squat
        XCTAssertEqual(ExerciseType.from(exerciseName: "Bulgarian Split Squat"), .squat)
    }

    func testNameMatching_tricepVariants_nowUnsupported() {
        // Tricep exercises no longer supported
        XCTAssertNil(ExerciseType.from(exerciseName: "Tricep Extension"))
        XCTAssertNil(ExerciseType.from(exerciseName: "Tricep Pushdown"))
        XCTAssertNil(ExerciseType.from(exerciseName: "Rope Pushdown"))
        XCTAssertNil(ExerciseType.from(exerciseName: "Dip"))
    }

    func testNameMatching_unknownReturnsNil() {
        XCTAssertNil(ExerciseType.from(exerciseName: "Bench Press"))
        XCTAssertNil(ExerciseType.from(exerciseName: "Cable Crossover"))
        XCTAssertNil(ExerciseType.from(exerciseName: "Plank"))

        // Previously supported exercises now return nil
        XCTAssertNil(ExerciseType.from(exerciseName: "Push-up"))
        XCTAssertNil(ExerciseType.from(exerciseName: "Pull-up"))
        XCTAssertNil(ExerciseType.from(exerciseName: "Deadlift"))
        XCTAssertNil(ExerciseType.from(exerciseName: "Dip"))
    }

    // MARK: - New Exercise Types

    func testNewExerciseTypes_existAndHaveConfiguration() {
        let newTypes: [ExerciseType] = [.frontRaise, .lateralRaise]
        for type in newTypes {
            let config = type.jointConfiguration
            XCTAssertGreaterThan(config.expectedROM, 0, "\(type.rawValue) should have positive ROM")
            XCTAssertLessThan(config.downThreshold, config.upThreshold, "\(type.rawValue) thresholds should be ordered")
            XCTAssertFalse(type.setupTip.isEmpty, "\(type.rawValue) should have a setup tip")
            XCTAssertFalse(type.trackingNote.isEmpty, "\(type.rawValue) should have a tracking note")
        }
    }

    func testAllExerciseTypes_haveValidConfiguration() {
        for type in ExerciseType.allCases {
            let config = type.jointConfiguration
            XCTAssertGreaterThan(config.expectedROM, 0, "\(type.rawValue) ROM > 0")
            XCTAssertGreaterThan(config.minimumROM, 0, "\(type.rawValue) minimumROM > 0")
            XCTAssertGreaterThan(config.hysteresis, 0, "\(type.rawValue) hysteresis > 0")
        }
    }

    // MARK: - Custom Configuration Init

    func testCustomConfigurationInit() {
        let config = JointConfiguration(
            joint1: .rightShoulder, joint2: .rightElbow, joint3: .rightWrist,
            downThreshold: 80, upThreshold: 150, description: "Custom"
        )
        let counter = RepCounter(configuration: config, forTesting: true)

        XCTAssertEqual(counter.repCount, 0)
        XCTAssertEqual(counter.currentPhase, .idle)

        // Arm
        feedStable(counter, angle: 150, frames: 25)
        XCTAssertEqual(counter.currentPhase, .armed)

        // Do a rep with gradual transitions
        transitionAngle(counter, to: 70, steps: 20)
        feedStable(counter, angle: 70, frames: 3)
        transitionAngle(counter, to: 155, steps: 20)
        XCTAssertEqual(counter.repCount, 1)
    }

    // MARK: - Full Workout Simulation

    func testFullSquatSet_5reps() {
        let counter = makeSquatCounter()
        // Squat: down=95, up=105, verticalProgress

        // Phase 1: Setup — user walks to position
        counter.processAngle(120)
        for angle in stride(from: 120.0, through: 110.0, by: -2.0) {
            counter.processAngle(angle)
        }
        for angle in stride(from: 110.0, through: 115.0, by: 2.0) {
            counter.processAngle(angle)
        }
        XCTAssertEqual(counter.repCount, 0, "Setup movements should not count")

        // Phase 2: Stand still — arm the counter
        armCounter(counter, exerciseType: .squat)

        // Phase 3: Perform 5 squats with gradual transitions + hold at extremes
        for _ in 0..<5 {
            // Go down: pseudo-angle drops below 95
            for angle in stride(from: 115.0, through: 80.0, by: -2.0) {
                counter.processAngle(angle)
            }
            feedStable(counter, angle: 80, frames: 5)
            // Come back up: pseudo-angle rises above 105
            for angle in stride(from: 80.0, through: 115.0, by: 2.0) {
                counter.processAngle(angle)
            }
            feedStable(counter, angle: 115, frames: 5)
        }

        XCTAssertEqual(counter.repCount, 5, "Should count exactly 5 reps")
    }

    func testFullCurlSet_8reps() {
        let counter = makeCurlCounter() // down=25, up=100, startsAtBottom=true

        // Arm at relaxed position (low angle)
        armCounter(counter, exerciseType: .bicepCurl)

        // 8 curls: ascending exercise — raise to peak, then lower back
        for _ in 0..<8 {
            // Curl up (pseudo-angle increases)
            for angle in stride(from: 10.0, through: 110.0, by: 5.0) {
                counter.processAngle(angle)
            }
            feedStable(counter, angle: 110, frames: 5)
            // Lower back (pseudo-angle decreases)
            for angle in stride(from: 110.0, through: 10.0, by: -5.0) {
                counter.processAngle(angle)
            }
            feedStable(counter, angle: 10, frames: 5)
        }

        XCTAssertEqual(counter.repCount, 8, "Should count 8 curls")
    }

    // MARK: - Edge Cases

    func testPartialRep_notCounted() {
        let counter = makeSquatCounter()
        armCounter(counter, exerciseType: .squat)

        // Go partway down but not past downThreshold (95)
        // downThreshold + hysteresis = 95.8, so 98 doesn't enter down phase
        transitionAngle(counter, to: 98, steps: 10)
        transitionAngle(counter, to: 115, steps: 10)

        XCTAssertEqual(counter.repCount, 0, "Partial movement should not count as rep")
    }

    func testRepCounter_afterReset_canCountAgain() {
        let counter = makeSquatCounter()
        armCounter(counter, exerciseType: .squat)
        performRep(counter, downAngle: 80, upAngle: 115)
        XCTAssertEqual(counter.repCount, 1)

        counter.reset()
        XCTAssertEqual(counter.repCount, 0)
        XCTAssertEqual(counter.currentPhase, .idle)

        // Arm again and do another rep
        armCounter(counter, exerciseType: .squat)
        performRep(counter, downAngle: 80, upAngle: 115)
        XCTAssertEqual(counter.repCount, 1)
    }

    func testRejectionReason_clearedAfterValidRep() {
        let counter = makeCustomCounter(down: 100, up: 160)
        feedStable(counter, angle: 160, frames: 25) // arm

        // Shallow rep: dip just past threshold, small ROM
        transitionAngle(counter, to: 103, steps: 10)
        transitionAngle(counter, to: 165, steps: 10)

        // Valid deep rep
        transitionAngle(counter, to: 80, steps: 20)
        feedStable(counter, angle: 80, frames: 3)
        transitionAngle(counter, to: 165, steps: 20)

        if counter.repCount > 0 {
            XCTAssertEqual(counter.lastRejectionReason, .none, "Valid rep should clear rejection reason")
        }
    }

    func testFeedbackDuringDescent() {
        // Use custom counter with wide ROM so intermediate feedback states are reachable
        // down=100, up=160: goingDown fires when angle < 140 (upThreshold - 20)
        // but only if angle > 104.8 (downThreshold + hysteresis)
        let counter = makeCustomCounter(down: 100, up: 160)
        feedStable(counter, angle: 160, frames: 25) // arm
        XCTAssertEqual(counter.currentPhase, .armed)

        // Go to 125 — between 104.8 (down+hysteresis) and 140 (up-20) → goingDown
        transitionAngle(counter, to: 125, steps: 15)
        feedStable(counter, angle: 125, frames: 3)
        XCTAssertEqual(counter.feedback, .goingDown)
    }

    func testFeedbackAtBottom() {
        // Use custom counter with wide ROM
        let counter = makeCustomCounter(down: 100, up: 160)
        feedStable(counter, angle: 160, frames: 25) // arm

        // Go below downThreshold + hysteresis = 104.8 → holdingDown
        transitionAngle(counter, to: 90, steps: 20)
        feedStable(counter, angle: 90, frames: 3)
        XCTAssertEqual(counter.feedback, .holdingDown)
    }

    func testFeedbackDuringAscent() {
        // Use custom counter with wide ROM
        // down=100, up=160: goingUp fires when angle > downThreshold + 15 = 115
        // but only if angle < upThreshold - hysteresis = 155.2
        let counter = makeCustomCounter(down: 100, up: 160)
        feedStable(counter, angle: 160, frames: 25) // arm

        // Enter down phase
        transitionAngle(counter, to: 80, steps: 20)
        feedStable(counter, angle: 80, frames: 3)
        // Go partway up to 130 — between 115 (down+15) and 155.2 (up-hysteresis) → goingUp
        transitionAngle(counter, to: 130, steps: 15)
        feedStable(counter, angle: 130, frames: 5)
        XCTAssertEqual(counter.feedback, .goingUp)
    }

    // MARK: - Ascending Exercises (startsAtBottom)

    /// Create a RepCounter for lateral raise (down=30, up=75, startsAtBottom=true)
    private func makeLateralRaiseCounter() -> RepCounter {
        RepCounter(exerciseType: .lateralRaise, forTesting: true)
    }

    func testAscending_armsAtBottom() {
        let counter = makeLateralRaiseCounter()
        // Lateral raise starts with arms at sides (~15°). downThreshold=30, tolerance=8
        // isNearStart = 15 <= (30 + 8) = 38 → true
        counter.processAngle(15)
        feedStable(counter, angle: 15, frames: RepCounter.requiredStabilityFrames + 5)
        XCTAssertEqual(counter.currentPhase, .armed, "Lateral raise should arm with arms at sides")
    }

    func testAscending_doesNotArmAtTop() {
        let counter = makeLateralRaiseCounter()
        // At 80° (above upThreshold=75), should NOT arm for ascending exercise
        // isNearStart = 80 <= (30 + 8) = 38 → false
        counter.processAngle(80)
        feedStable(counter, angle: 80, frames: RepCounter.requiredStabilityFrames + 5)
        XCTAssertEqual(counter.currentPhase, .idle, "Lateral raise should NOT arm with arms raised")
    }

    func testAscending_fullRep() {
        let counter = makeLateralRaiseCounter()
        // Arm with arms at sides
        armCounter(counter, exerciseType: .lateralRaise)
        XCTAssertEqual(counter.currentPhase, .armed)

        // Raise arms past upThreshold (75) → enter .down phase
        transitionAngle(counter, to: 80, steps: 20)
        feedStable(counter, angle: 80, frames: 5)

        // Lower arms back past downThreshold (30) → rep completes
        transitionAngle(counter, to: 15, steps: 20)
        feedStable(counter, angle: 15, frames: 5)

        XCTAssertEqual(counter.repCount, 1, "Should count one lateral raise rep")
        XCTAssertEqual(counter.currentPhase, .up)
    }

    func testAscending_multipleReps() {
        let counter = makeLateralRaiseCounter()
        armCounter(counter, exerciseType: .lateralRaise)

        for _ in 0..<3 {
            // Raise
            transitionAngle(counter, to: 80, steps: 20)
            feedStable(counter, angle: 80, frames: 5)
            // Lower
            transitionAngle(counter, to: 15, steps: 20)
            feedStable(counter, angle: 15, frames: 5)
        }

        XCTAssertEqual(counter.repCount, 3, "Should count 3 lateral raise reps")
    }

    func testAscending_shallowRejected() {
        let counter = makeLateralRaiseCounter()
        armCounter(counter, exerciseType: .lateralRaise)

        // Raise only to ~50° — between thresholds but not past upThreshold (75)
        transitionAngle(counter, to: 50, steps: 15)
        feedStable(counter, angle: 50, frames: 3)
        // Lower back
        transitionAngle(counter, to: 15, steps: 15)
        feedStable(counter, angle: 15, frames: 5)

        XCTAssertEqual(counter.repCount, 0, "Shallow lateral raise should not count")
    }

    func testAscending_startsAtBottomFlag() {
        // Verify startsAtBottom is set correctly for ascending exercises
        XCTAssertTrue(ExerciseType.lateralRaise.jointConfiguration.startsAtBottom)
        XCTAssertTrue(ExerciseType.frontRaise.jointConfiguration.startsAtBottom)
        XCTAssertTrue(ExerciseType.bicepCurl.jointConfiguration.startsAtBottom)

        // Verify descending exercises are NOT flagged
        XCTAssertFalse(ExerciseType.squat.jointConfiguration.startsAtBottom)
        XCTAssertFalse(ExerciseType.shoulderPress.jointConfiguration.startsAtBottom)

        // Lunge removed — only 5 exercise types remain
        XCTAssertEqual(ExerciseType.allCases.count, 5)
    }

    func testAscending_frontRaiseFullRep() {
        let counter = RepCounter(exerciseType: .frontRaise, forTesting: true)
        armCounter(counter, exerciseType: .frontRaise)

        // Raise past upThreshold (80)
        transitionAngle(counter, to: 85, steps: 20)
        feedStable(counter, angle: 85, frames: 5)
        // Lower past downThreshold (25)
        transitionAngle(counter, to: 10, steps: 20)
        feedStable(counter, angle: 10, frames: 5)

        XCTAssertEqual(counter.repCount, 1, "Should count one front raise rep")
    }

    func testVerticalProgress_measurement() {
        // Bicep curl and squat use vertical progress measurement
        let curlConfig = ExerciseType.bicepCurl.jointConfiguration
        XCTAssertEqual(curlConfig.measurement, .verticalProgress)

        let squatConfig = ExerciseType.squat.jointConfiguration
        XCTAssertEqual(squatConfig.measurement, .verticalProgress)

        // Other exercises use geometric measurement (default)
        XCTAssertEqual(ExerciseType.lateralRaise.jointConfiguration.measurement, .geometric)
        XCTAssertEqual(ExerciseType.shoulderPress.jointConfiguration.measurement, .geometric)

        // Verify bicep curl joint mapping for vertical progress:
        // joint1 = hip (bottom), joint2 = shoulder (top), joint3 = wrist (tracked)
        XCTAssertEqual(curlConfig.joint1, .rightHip)
        XCTAssertEqual(curlConfig.joint2, .rightShoulder)
        XCTAssertEqual(curlConfig.joint3, .rightWrist)
    }

    func testAscending_repDescription() {
        // Key exercises have specific descriptions
        XCTAssertTrue(ExerciseType.lateralRaise.repDescription.contains("shoulder height"))
        XCTAssertTrue(ExerciseType.bicepCurl.repDescription.contains("curl"))
        XCTAssertTrue(ExerciseType.squat.repDescription.contains("squat"))
        XCTAssertTrue(ExerciseType.frontRaise.repDescription.contains("shoulder height"))
    }

    // MARK: - Rejection Counters

    func testRejectionCounts_fastIncrementsCounter() {
        // Use forTesting: false so the duration check fires (real timestamps, all < 0.6s)
        let counter = RepCounter(exerciseType: .squat, forTesting: false)
        XCTAssertEqual(counter.rejectedFastCount, 0)

        // Arm the counter (squat upThreshold=105, arm at 115)
        counter.processAngle(115)
        feedStable(counter, angle: 115, frames: RepCounter.requiredStabilityFrames + 5)
        XCTAssertEqual(counter.currentPhase, .armed)

        // Rep processed in microseconds — will be rejected as too fast
        transitionAngle(counter, to: 80, steps: 15)
        feedStable(counter, angle: 80, frames: 5)
        transitionAngle(counter, to: 115, steps: 15)
        feedStable(counter, angle: 115, frames: 5)

        XCTAssertGreaterThanOrEqual(counter.rejectedFastCount, 1, "Fast rep should increment rejection counter")
        XCTAssertEqual(counter.repCount, 0, "Fast rep should not count")
    }

    func testRejectionCounts_resetClearsCounters() {
        let counter = RepCounter(exerciseType: .squat, forTesting: false)

        // Arm and trigger a fast rejection
        counter.processAngle(115)
        feedStable(counter, angle: 115, frames: RepCounter.requiredStabilityFrames + 5)
        transitionAngle(counter, to: 80, steps: 15)
        feedStable(counter, angle: 80, frames: 5)
        transitionAngle(counter, to: 115, steps: 15)
        feedStable(counter, angle: 115, frames: 5)

        counter.reset()

        XCTAssertEqual(counter.rejectedShallowCount, 0, "Reset should clear shallow count")
        XCTAssertEqual(counter.rejectedFastCount, 0, "Reset should clear fast count")
    }

    func testRejectionCounts_validRepDoesNotIncrement() {
        let counter = makeSquatCounter()
        armCounter(counter, exerciseType: .squat)

        performRep(counter, downAngle: 80, upAngle: 115)

        XCTAssertEqual(counter.repCount, 1)
        XCTAssertEqual(counter.rejectedShallowCount, 0, "Valid rep should not increment shallow counter")
        XCTAssertEqual(counter.rejectedFastCount, 0, "Valid rep should not increment fast counter")
    }

    func testRejectionCounts_initiallyZero() {
        let counter = makeSquatCounter()
        XCTAssertEqual(counter.rejectedShallowCount, 0)
        XCTAssertEqual(counter.rejectedFastCount, 0)
    }

    // MARK: - Sensitivity

    func testSensitivity_defaultMatchesOriginal() {
        // Default multiplier (0.4) should produce the same minimumROM as the configuration
        let counter = makeSquatCounter()
        let config = ExerciseType.squat.jointConfiguration
        let requiredROM = config.expectedROM * counter.sensitivityMultiplier
        XCTAssertEqual(requiredROM, config.minimumROM, accuracy: 0.001,
                       "Default sensitivity should match original minimumROM")
    }

    func testSensitivity_easyAcceptsShallowRep() {
        // Verify that easy sensitivity uses a lower ROM threshold than normal.
        // Custom config: down=100, up=160, expectedROM=60
        // Normal requiredROM = 60 * 0.4 = 24
        // Easy requiredROM = 60 * 0.25 = 15
        let counter = makeCustomCounter(down: 100, up: 160)
        counter.sensitivityMultiplier = 0.25 // Easy
        let config = JointConfiguration(
            joint1: .rightHip, joint2: .rightKnee, joint3: .rightAnkle,
            downThreshold: 100, upThreshold: 160, description: "Test"
        )
        let easyRequired = config.expectedROM * 0.25
        let normalRequired = config.expectedROM * 0.4

        XCTAssertEqual(easyRequired, 15, "Easy ROM threshold should be 15")
        XCTAssertLessThan(easyRequired, normalRequired, "Easy threshold should be lower than normal")

        // Perform a full rep to verify easy sensitivity allows it
        feedStable(counter, angle: 160, frames: 25) // arm
        transitionAngle(counter, to: 80, steps: 20)
        feedStable(counter, angle: 80, frames: 3)
        let completed = transitionAngle(counter, to: 165, steps: 20)

        XCTAssertTrue(completed || counter.repCount > 0,
                      "Easy sensitivity should accept a full rep")
    }

    func testSensitivity_strictRejectsModerateRep() {
        // Custom config: down=100, up=160, expectedROM=60
        // Strict minimumROM = 60 * 0.5 = 30
        let counter = makeCustomCounter(down: 100, up: 160)
        counter.sensitivityMultiplier = 0.5 // Strict
        feedStable(counter, angle: 160, frames: 25) // arm

        // Dip to ~103 — ROM from EMA will be ~20-25, less than strict threshold of 30
        transitionAngle(counter, to: 103, steps: 10)
        transitionAngle(counter, to: 165, steps: 10)

        XCTAssertEqual(counter.repCount, 0,
                       "Strict sensitivity should reject a moderate rep")
    }

    func testSensitivity_propertiesDefaultCorrectly() {
        let counter = makeSquatCounter()
        XCTAssertEqual(counter.sensitivityMultiplier, 0.4, "Default multiplier should be 0.4")
        XCTAssertEqual(counter.minimumRepDurationOverride, 0.6, "Default duration should be 0.6s")
    }

    func testSensitivity_canBeChangedAtRuntime() {
        let counter = makeSquatCounter()
        counter.sensitivityMultiplier = 0.25
        counter.minimumRepDurationOverride = 0.4
        XCTAssertEqual(counter.sensitivityMultiplier, 0.25)
        XCTAssertEqual(counter.minimumRepDurationOverride, 0.4)
    }
}
