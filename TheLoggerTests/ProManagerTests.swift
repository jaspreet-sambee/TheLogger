//
//  ProManagerTests.swift
//  TheLoggerTests
//
//  Tests for ProManager usage gate logic.
//  RevenueCat network calls are NOT tested — only pure Swift logic:
//  usage counters, gates, remaining counts, UserDefaults persistence, error types.
//

import XCTest
@testable import TheLogger

@MainActor
final class ProManagerTests: XCTestCase {

    // Month-keyed UserDefaults helpers (mirrors ProManager's internal keys)
    private var monthKey: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM"
        return f.string(from: Date())
    }
    private var cameraKey: String { "camera-\(monthKey)" }
    private var shareKey: String { "share-\(monthKey)" }

    override func setUpWithError() throws {
        try super.setUpWithError()
        // Explicitly set to 0 (more reliable than removeObject in test contexts)
        UserDefaults.standard.set(0, forKey: cameraKey)
        UserDefaults.standard.set(0, forKey: shareKey)
        UserDefaults.standard.synchronize()
    }

    override func tearDownWithError() throws {
        UserDefaults.standard.removeObject(forKey: cameraKey)
        UserDefaults.standard.removeObject(forKey: shareKey)
        UserDefaults.standard.synchronize()
        try super.tearDownWithError()
    }

    // MARK: - Static limits

    func testCameraLimit_isDefaultFive() {
        XCTAssertEqual(ProManager.cameraSessionLimit, 5)
    }

    func testShareCardLimit_isDefaultThree() {
        XCTAssertEqual(ProManager.shareCardLimit, 3)
    }

    // MARK: - canUseCamera gate

    func testCanUseCamera_whenZeroSessionsUsed_returnsTrue() {
        let manager = ProManager()
        XCTAssertTrue(manager.canUseCamera)
    }

    func testCanUseCamera_whenUnderLimit_returnsTrue() {
        let manager = ProManager()
        manager.recordCameraSession()
        manager.recordCameraSession()
        XCTAssertTrue(manager.canUseCamera)
    }

    func testCanUseCamera_whenAtLimit_returnsFalse() {
        let manager = ProManager()
        for _ in 0..<5 { manager.recordCameraSession() }
        XCTAssertFalse(manager.canUseCamera)
    }

    func testCanUseCamera_whenOverLimit_returnsFalse() {
        // Simulate UserDefaults value already above limit (e.g. data corruption)
        UserDefaults.standard.set(10, forKey: cameraKey)
        let manager = ProManager()
        XCTAssertFalse(manager.canUseCamera)
    }

    // MARK: - canUseShareCard gate

    func testCanUseShareCard_whenZeroUsed_returnsTrue() {
        let manager = ProManager()
        XCTAssertTrue(manager.canUseShareCard)
    }

    func testCanUseShareCard_whenUnderLimit_returnsTrue() {
        let manager = ProManager()
        manager.recordShareCard()
        XCTAssertTrue(manager.canUseShareCard)
    }

    func testCanUseShareCard_whenAtLimit_returnsFalse() {
        let manager = ProManager()
        for _ in 0..<3 { manager.recordShareCard() }
        XCTAssertFalse(manager.canUseShareCard)
    }

    func testCanUseShareCard_whenOverLimit_returnsFalse() {
        UserDefaults.standard.set(10, forKey: shareKey)
        let manager = ProManager()
        XCTAssertFalse(manager.canUseShareCard)
    }

    // MARK: - cameraSessionsRemaining

    func testCameraSessionsRemaining_fullCountWhenUnused() {
        let manager = ProManager()
        XCTAssertEqual(manager.cameraSessionsRemaining, 5)
    }

    func testCameraSessionsRemaining_decreasesAfterRecording() {
        let manager = ProManager()
        manager.recordCameraSession()
        manager.recordCameraSession()
        XCTAssertEqual(manager.cameraSessionsRemaining, 3)
    }

    func testCameraSessionsRemaining_isZeroWhenAtLimit() {
        let manager = ProManager()
        for _ in 0..<5 { manager.recordCameraSession() }
        XCTAssertEqual(manager.cameraSessionsRemaining, 0)
    }

    func testCameraSessionsRemaining_neverNegative() {
        UserDefaults.standard.set(100, forKey: cameraKey)
        let manager = ProManager()
        XCTAssertEqual(manager.cameraSessionsRemaining, 0)
    }

    // MARK: - shareCardsRemaining

    func testShareCardsRemaining_fullCountWhenUnused() {
        let manager = ProManager()
        XCTAssertEqual(manager.shareCardsRemaining, 3)
    }

    func testShareCardsRemaining_decreasesAfterRecording() {
        let manager = ProManager()
        manager.recordShareCard()
        XCTAssertEqual(manager.shareCardsRemaining, 2)
    }

    func testShareCardsRemaining_isZeroWhenAtLimit() {
        let manager = ProManager()
        for _ in 0..<3 { manager.recordShareCard() }
        XCTAssertEqual(manager.shareCardsRemaining, 0)
    }

    func testShareCardsRemaining_neverNegative() {
        UserDefaults.standard.set(100, forKey: shareKey)
        let manager = ProManager()
        XCTAssertEqual(manager.shareCardsRemaining, 0)
    }

    // MARK: - recordCameraSession

    func testRecordCameraSession_startsAtZero() {
        let manager = ProManager()
        XCTAssertEqual(manager.cameraSessionsUsedThisMonth, 0)
    }

    func testRecordCameraSession_incrementsCounter() {
        let manager = ProManager()
        manager.recordCameraSession()
        XCTAssertEqual(manager.cameraSessionsUsedThisMonth, 1)
    }

    func testRecordCameraSession_multipleIncrements() {
        let manager = ProManager()
        for _ in 0..<3 { manager.recordCameraSession() }
        XCTAssertEqual(manager.cameraSessionsUsedThisMonth, 3)
    }

    func testRecordCameraSession_persistsToUserDefaults() {
        let manager = ProManager()
        manager.recordCameraSession()
        manager.recordCameraSession()
        // A new instance reads back from UserDefaults
        let manager2 = ProManager()
        XCTAssertEqual(manager2.cameraSessionsUsedThisMonth, 2)
    }

    // MARK: - recordShareCard

    func testRecordShareCard_startsAtZero() {
        let manager = ProManager()
        XCTAssertEqual(manager.shareCardsUsedThisMonth, 0)
    }

    func testRecordShareCard_incrementsCounter() {
        let manager = ProManager()
        manager.recordShareCard()
        XCTAssertEqual(manager.shareCardsUsedThisMonth, 1)
    }

    func testRecordShareCard_multipleIncrements() {
        let manager = ProManager()
        for _ in 0..<3 { manager.recordShareCard() }
        XCTAssertEqual(manager.shareCardsUsedThisMonth, 3)
    }

    func testRecordShareCard_persistsToUserDefaults() {
        let manager = ProManager()
        manager.recordShareCard()
        let manager2 = ProManager()
        XCTAssertEqual(manager2.shareCardsUsedThisMonth, 1)
    }

    // MARK: - Monthly reset (month-keyed UserDefaults)

    func testMonthlyCounters_oldMonthKey_doesNotAffectCurrentMonth() {
        // Simulate a previous month having used all sessions
        let oldKey = "camera-1999-01"
        UserDefaults.standard.set(5, forKey: oldKey)
        let manager = ProManager()
        XCTAssertEqual(manager.cameraSessionsUsedThisMonth, 0)
        UserDefaults.standard.removeObject(forKey: oldKey)
    }

    func testMonthlyCounters_cameraAndShareKeysAreIndependent() {
        let manager = ProManager()
        for _ in 0..<3 { manager.recordCameraSession() }
        XCTAssertEqual(manager.shareCardsUsedThisMonth, 0, "Share card counter should be unaffected by camera sessions")
    }

    // MARK: - ProManagerError

    func testProManagerError_noPackageAvailable_hasDescription() {
        let error = ProManagerError.noPackageAvailable
        XCTAssertNotNil(error.errorDescription)
        XCTAssertFalse(error.errorDescription!.isEmpty)
    }

    func testProManagerError_isLocalizedError() {
        let error: LocalizedError = ProManagerError.noPackageAvailable
        XCTAssertNotNil(error.errorDescription)
    }
}
