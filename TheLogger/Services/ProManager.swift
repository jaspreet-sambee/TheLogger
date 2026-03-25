//
//  ProManager.swift
//  TheLogger
//
//  Manages Pro subscription state and free-tier usage limits via RevenueCat.
//  Inject into the SwiftUI environment at app root; read via @Environment(ProManager.self).
//

import Foundation
import RevenueCat

@Observable nonisolated final class ProManager: NSObject {

    // MARK: - Singleton

    static let shared = ProManager()

    // MARK: - State

    private(set) var isPro: Bool = false
    private(set) var cameraSessionsUsedThisMonth: Int = 0
    private(set) var shareCardsUsedThisMonth: Int = 0

    // MARK: - Limits

    static let cameraSessionLimit = 5
    static let shareCardLimit = 3

    // MARK: - Computed gates

    var canUseCamera: Bool {
        isPro || cameraSessionsUsedThisMonth < Self.cameraSessionLimit
    }

    var canUseShareCard: Bool {
        isPro || shareCardsUsedThisMonth < Self.shareCardLimit
    }

    var cameraSessionsRemaining: Int {
        max(0, Self.cameraSessionLimit - cameraSessionsUsedThisMonth)
    }

    var shareCardsRemaining: Int {
        max(0, Self.shareCardLimit - shareCardsUsedThisMonth)
    }

    // MARK: - Init

    override init() {
        super.init()
        loadCounters()
    }

    // MARK: - Subscription check

    /// Call on app launch. Reads cached entitlements — no network required.
    func checkSubscriptionStatus() async {
        #if DEBUG
        // TEMP: force Pro in debug builds — set to true to test Pro features, false to test upgrade gates
        isPro = true
        return
        #endif
        do {
            let info = try await Purchases.shared.customerInfo()
            isPro = info.entitlements["pro"]?.isActive == true
        } catch {
            debugLog("[ProManager] Failed to check subscription status: \(error)")
        }
    }

    // MARK: - Purchase

    /// Fetches the current offering and purchases the Pro monthly package.
    func purchase() async throws {
        let offerings = try await Purchases.shared.offerings()
        guard let package = offerings.current?.availablePackages.first(where: { $0.packageType == .monthly })
                ?? offerings.current?.availablePackages.first else {
            throw ProManagerError.noPackageAvailable
        }
        let result = try await Purchases.shared.purchase(package: package)
        isPro = result.customerInfo.entitlements["pro"]?.isActive == true
    }

    // MARK: - Restore

    func restore() async throws {
        let info = try await Purchases.shared.restorePurchases()
        isPro = info.entitlements["pro"]?.isActive == true
    }

    // MARK: - Usage recording

    func recordCameraSession() {
        guard !isPro else { return }
        cameraSessionsUsedThisMonth += 1
        UserDefaults.standard.set(cameraSessionsUsedThisMonth, forKey: cameraKey)
    }

    func recordShareCard() {
        guard !isPro else { return }
        shareCardsUsedThisMonth += 1
        UserDefaults.standard.set(shareCardsUsedThisMonth, forKey: shareKey)
    }

    // MARK: - Counters (month-keyed UserDefaults)

    private var monthKey: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM"
        return f.string(from: Date())
    }

    private var cameraKey: String { "camera-\(monthKey)" }
    private var shareKey:  String { "share-\(monthKey)"  }

    private func loadCounters() {
        let defaults = UserDefaults.standard
        cameraSessionsUsedThisMonth = defaults.integer(forKey: cameraKey)
        shareCardsUsedThisMonth     = defaults.integer(forKey: shareKey)
    }
}

// MARK: - PurchasesDelegate (live subscription updates)

extension ProManager: PurchasesDelegate {
    func purchases(_ purchases: Purchases, receivedUpdated customerInfo: CustomerInfo) {
        isPro = customerInfo.entitlements["pro"]?.isActive == true
    }
}

// MARK: - Errors

enum ProManagerError: LocalizedError {
    case noPackageAvailable

    var errorDescription: String? {
        switch self {
        case .noPackageAvailable:
            return "Could not load subscription options. Please try again later."
        }
    }
}
