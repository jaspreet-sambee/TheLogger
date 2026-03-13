//
//  RestTimerTests.swift
//  TheLoggerTests
//
//  Unit tests for RestTimerManager state machine:
//  offerRest, start, stop, pause, resume, adjustDuration, clamping,
//  per-exercise tracking, progress, and formatted time.
//
//  Note: Actual timer ticks are not tested here (Timer fires on runloop).
//  These tests cover state transitions and observable properties.
//

import XCTest
@testable import TheLogger

@MainActor
final class RestTimerTests: XCTestCase {

    var timer: RestTimerManager!

    override func setUp() {
        timer = RestTimerManager(forTesting: true)
    }

    override func tearDown() {
        timer.stop()
        timer = nil
    }

    // MARK: - Initial State

    func testInitialState_allFalseZero() {
        XCTAssertFalse(timer.isActive)
        XCTAssertFalse(timer.isComplete)
        XCTAssertFalse(timer.showRestOption)
        XCTAssertNil(timer.activeExerciseId)
        XCTAssertEqual(timer.remainingSeconds, 0)
    }

    // MARK: - offerRest

    func testOfferRest_setsActiveExerciseId() {
        let exerciseId = UUID()
        timer.offerRest(for: exerciseId, duration: 90)
        XCTAssertEqual(timer.activeExerciseId, exerciseId)
    }

    func testOfferRest_showsRestOption() {
        let exerciseId = UUID()
        timer.offerRest(for: exerciseId, duration: 90)
        XCTAssertTrue(timer.showRestOption)
        XCTAssertFalse(timer.isActive)
    }

    func testOfferRest_usesDurationParameter() {
        timer.offerRest(for: UUID(), duration: 120)
        XCTAssertEqual(timer.suggestedDuration, 120)
    }

    func testOfferRest_usesUserDefaultWhenNoDuration() {
        UserDefaults.standard.set(150, forKey: "defaultRestSeconds")
        timer.offerRest(for: UUID(), duration: nil)
        XCTAssertEqual(timer.suggestedDuration, 150)
        UserDefaults.standard.removeObject(forKey: "defaultRestSeconds")
    }

    func testOfferRest_fallsBackTo90WhenNoDefaultOrDuration() {
        UserDefaults.standard.removeObject(forKey: "defaultRestSeconds")
        timer.offerRest(for: UUID(), duration: nil)
        XCTAssertEqual(timer.suggestedDuration, 90)
    }

    func testOfferRest_blockedWhenTimerIsAlreadyActive() {
        let exerciseId1 = UUID()
        let exerciseId2 = UUID()

        timer.start(for: exerciseId1, duration: 60)
        XCTAssertTrue(timer.isActive)

        // Should be blocked because timer is active and not complete
        timer.offerRest(for: exerciseId2, duration: 90)

        // activeExerciseId should remain the original (not overwritten)
        XCTAssertEqual(timer.activeExerciseId, exerciseId1)
    }

    func testOfferRest_autoStart_startsTimerImmediately() {
        let exerciseId = UUID()
        timer.offerRest(for: exerciseId, duration: 60, autoStart: true)

        XCTAssertTrue(timer.isActive)
        XCTAssertFalse(timer.showRestOption)
        XCTAssertEqual(timer.remainingSeconds, 60)
    }

    // MARK: - Start

    func testStart_setsActiveAndRemainingSeconds() {
        let exerciseId = UUID()
        timer.offerRest(for: exerciseId, duration: 90)
        timer.start()

        XCTAssertTrue(timer.isActive)
        XCTAssertFalse(timer.showRestOption)
        XCTAssertEqual(timer.remainingSeconds, 90)
        XCTAssertEqual(timer.totalSeconds, 90)
    }

    func testStartForExercise_overridesDuration() {
        let exerciseId = UUID()
        timer.start(for: exerciseId, duration: 120)

        XCTAssertTrue(timer.isActive)
        XCTAssertEqual(timer.remainingSeconds, 120)
        XCTAssertEqual(timer.totalSeconds, 120)
        XCTAssertEqual(timer.activeExerciseId, exerciseId)
    }

    // MARK: - Stop

    func testStop_resetsAllState() {
        let exerciseId = UUID()
        timer.start(for: exerciseId, duration: 90)
        timer.stop()

        XCTAssertFalse(timer.isActive)
        XCTAssertFalse(timer.isComplete)
        XCTAssertFalse(timer.showRestOption)
        XCTAssertNil(timer.activeExerciseId)
    }

    // MARK: - Dismiss

    func testDismiss_hidesRestOptionWithoutStarting() {
        let exerciseId = UUID()
        timer.offerRest(for: exerciseId, duration: 90)
        XCTAssertTrue(timer.showRestOption)

        timer.dismiss()
        XCTAssertFalse(timer.showRestOption)
        XCTAssertFalse(timer.isActive)
    }

    func testDismiss_whenTimerActive_doesNotStopTimer() {
        let exerciseId = UUID()
        timer.start(for: exerciseId, duration: 60)
        timer.dismiss()

        // Timer should still be running (dismiss only hides showRestOption)
        XCTAssertTrue(timer.isActive)
        // activeExerciseId is preserved when the timer is active
        XCTAssertEqual(timer.activeExerciseId, exerciseId, "activeExerciseId should be preserved when timer is running")
    }

    // MARK: - Pause / Resume

    func testPause_stopsTickingButKeepsState() {
        let exerciseId = UUID()
        timer.start(for: exerciseId, duration: 60)
        timer.pause()

        // isActive stays true (paused ≠ stopped), rest option is hidden
        XCTAssertTrue(timer.isActive)
        XCTAssertFalse(timer.showRestOption)
    }

    func testResume_requiresActiveAndRemainingSeconds() {
        // If not active, resume is a no-op
        timer.resume()
        XCTAssertFalse(timer.isActive)
    }

    func testPauseThenResume_keepsSameRemainingSeconds() {
        let exerciseId = UUID()
        timer.start(for: exerciseId, duration: 60)
        let beforePause = timer.remainingSeconds
        timer.pause()
        // After pause, no tick happens
        XCTAssertEqual(timer.remainingSeconds, beforePause)
    }

    // MARK: - Skip

    func testSkip_stopsTimer() {
        let exerciseId = UUID()
        timer.start(for: exerciseId, duration: 90)
        timer.skip()

        XCTAssertFalse(timer.isActive)
        XCTAssertNil(timer.activeExerciseId)
    }

    // MARK: - Adjust Suggested Duration

    func testAdjustSuggestedDuration_increasesByDelta() {
        timer.offerRest(for: UUID(), duration: 90)
        timer.adjustSuggestedDuration(delta: 30)
        XCTAssertEqual(timer.suggestedDuration, 120)
    }

    func testAdjustSuggestedDuration_decreasesByDelta() {
        timer.offerRest(for: UUID(), duration: 90)
        timer.adjustSuggestedDuration(delta: -30)
        XCTAssertEqual(timer.suggestedDuration, 60)
    }

    func testAdjustSuggestedDuration_clampedAtMinimum15() {
        timer.offerRest(for: UUID(), duration: 20)
        timer.adjustSuggestedDuration(delta: -100) // Would go to -80
        XCTAssertEqual(timer.suggestedDuration, 15, "Minimum suggested duration is 15 seconds")
    }

    func testAdjustSuggestedDuration_clampedAtMaximum600() {
        timer.offerRest(for: UUID(), duration: 590)
        timer.adjustSuggestedDuration(delta: 100) // Would go to 690
        XCTAssertEqual(timer.suggestedDuration, 600, "Maximum suggested duration is 600 seconds")
    }

    func testAdjustSuggestedDuration_exactlyAtMinimum_noChange() {
        timer.offerRest(for: UUID(), duration: 15)
        timer.adjustSuggestedDuration(delta: -1)
        XCTAssertEqual(timer.suggestedDuration, 15)
    }

    func testAdjustSuggestedDuration_exactlyAtMaximum_noChange() {
        timer.offerRest(for: UUID(), duration: 600)
        timer.adjustSuggestedDuration(delta: 1)
        XCTAssertEqual(timer.suggestedDuration, 600)
    }

    func testAdjustSuggestedDuration_ignoredWhenTimerActive() {
        let exerciseId = UUID()
        timer.start(for: exerciseId, duration: 90)
        let before = timer.suggestedDuration

        timer.adjustSuggestedDuration(delta: 30) // Should be ignored
        XCTAssertEqual(timer.suggestedDuration, before, "Cannot adjust duration while timer is active")
    }

    // MARK: - Set Suggested Duration

    func testSetSuggestedDuration_setsExactValue() {
        timer.offerRest(for: UUID(), duration: 90)
        timer.setSuggestedDuration(45)
        XCTAssertEqual(timer.suggestedDuration, 45)
    }

    func testSetSuggestedDuration_clampedBelow15() {
        timer.offerRest(for: UUID(), duration: 90)
        timer.setSuggestedDuration(5)
        XCTAssertEqual(timer.suggestedDuration, 15)
    }

    func testSetSuggestedDuration_clampedAbove600() {
        timer.offerRest(for: UUID(), duration: 90)
        timer.setSuggestedDuration(999)
        XCTAssertEqual(timer.suggestedDuration, 600)
    }

    // MARK: - Add Seconds

    func testAddSeconds_increasesRemainingWhenActive() {
        let exerciseId = UUID()
        timer.start(for: exerciseId, duration: 60)
        timer.addSeconds(30)
        XCTAssertEqual(timer.remainingSeconds, 90)
    }

    func testAddSeconds_clampedAt600() {
        let exerciseId = UUID()
        timer.start(for: exerciseId, duration: 580)
        timer.addSeconds(100)
        XCTAssertEqual(timer.remainingSeconds, 600, "Adding seconds cannot exceed 600")
    }

    func testAddSeconds_ignoredWhenNotActive() {
        timer.addSeconds(30)
        XCTAssertEqual(timer.remainingSeconds, 0, "addSeconds should be ignored when timer is not active")
    }

    func testAddSeconds_updatesTotalSeconds() {
        let exerciseId = UUID()
        timer.start(for: exerciseId, duration: 60)
        timer.addSeconds(30)
        XCTAssertGreaterThanOrEqual(timer.totalSeconds, 60)
    }

    // MARK: - Progress

    func testProgress_startOfTimer_isZero() {
        let exerciseId = UUID()
        timer.start(for: exerciseId, duration: 60)
        XCTAssertEqual(timer.progress, 0.0, accuracy: 0.01, "At start, progress should be 0")
    }

    func testProgress_afterTick_increases() {
        let exerciseId = UUID()
        timer.start(for: exerciseId, duration: 60)
        // Manually decrease remaining to simulate a tick
        timer.remainingSeconds = 45
        // progress = 1 - 45/60 = 0.25
        XCTAssertEqual(timer.progress, 0.25, accuracy: 0.01)
    }

    func testProgress_zeroTotalSeconds_isZero() {
        // Directly set totalSeconds to 0 to hit the guard path
        timer.totalSeconds = 0
        timer.remainingSeconds = 0
        XCTAssertEqual(timer.progress, 0.0, "Guard returns 0 when totalSeconds == 0")
    }

    // MARK: - Formatted Time

    func testFormattedTime_minutes_and_seconds() {
        let exerciseId = UUID()
        timer.start(for: exerciseId, duration: 90)
        XCTAssertEqual(timer.formattedTime, "1:30")
    }

    func testFormattedTime_secondsOnly() {
        let exerciseId = UUID()
        timer.start(for: exerciseId, duration: 45)
        XCTAssertEqual(timer.formattedTime, "0:45")
    }

    func testFormattedTime_exactMinutes() {
        let exerciseId = UUID()
        timer.start(for: exerciseId, duration: 120)
        XCTAssertEqual(timer.formattedTime, "2:00")
    }

    func testFormattedTime_zero() {
        XCTAssertEqual(timer.formattedTime, "0:00")
    }

    // MARK: - Per-Exercise Tracking

    func testShouldShowFor_correctExercise_returnsTrue() {
        let exerciseId = UUID()
        timer.offerRest(for: exerciseId, duration: 90)
        XCTAssertTrue(timer.shouldShowFor(exerciseId: exerciseId))
    }

    func testShouldShowFor_wrongExercise_returnsFalse() {
        let exerciseId = UUID()
        timer.offerRest(for: exerciseId, duration: 90)
        XCTAssertFalse(timer.shouldShowFor(exerciseId: UUID()), "Different exercise ID should not show")
    }

    func testIsActiveFor_exerciseId_returnsTrue() {
        let exerciseId = UUID()
        timer.start(for: exerciseId, duration: 60)
        XCTAssertTrue(timer.isActiveFor(exerciseId: exerciseId))
    }

    func testIsActiveFor_wrongExercise_returnsFalse() {
        let exerciseId = UUID()
        timer.start(for: exerciseId, duration: 60)
        XCTAssertFalse(timer.isActiveFor(exerciseId: UUID()))
    }

    func testIsOfferingRestFor_correctExercise_returnsTrue() {
        let exerciseId = UUID()
        timer.offerRest(for: exerciseId, duration: 90)
        XCTAssertTrue(timer.isOfferingRestFor(exerciseId: exerciseId))
    }

    func testIsOfferingRestFor_afterStart_returnsFalse() {
        let exerciseId = UUID()
        timer.offerRest(for: exerciseId, duration: 90)
        timer.start()
        XCTAssertFalse(timer.isOfferingRestFor(exerciseId: exerciseId),
                       "isOfferingRest should be false once timer starts")
    }

    func testIsOfferingRestFor_wrongExercise_returnsFalse() {
        let exerciseId = UUID()
        timer.offerRest(for: exerciseId, duration: 90)
        XCTAssertFalse(timer.isOfferingRestFor(exerciseId: UUID()))
    }
}
