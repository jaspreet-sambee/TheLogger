//
//  UnitFormatter.swift
//  TheLogger
//
//  Unit system and weight formatting utilities
//

import Foundation
import SwiftUI

// MARK: - Unit System

enum UnitSystem: String, CaseIterable, Identifiable {
    case imperial = "Imperial"
    case metric = "Metric"

    var id: String { rawValue }

    var weightUnit: String {
        switch self {
        case .imperial: return "lbs"
        case .metric: return "kg"
        }
    }

    var weightUnitFull: String {
        switch self {
        case .imperial: return "pounds"
        case .metric: return "kilograms"
        }
    }
}

/// Global unit formatting helper
struct UnitFormatter {
    /// Current unit system from UserDefaults
    static var currentSystem: UnitSystem {
        let stored = UserDefaults.standard.string(forKey: "unitSystem") ?? "Imperial"
        return UnitSystem(rawValue: stored) ?? .imperial
    }

    /// Format weight for display with unit
    static func formatWeight(_ weight: Double, showUnit: Bool = true) -> String {
        let displayWeight = convertToDisplay(weight)
        if showUnit {
            return String(format: "%.1f %@", displayWeight, currentSystem.weightUnit)
        }
        return String(format: "%.1f", displayWeight)
    }

    /// Format weight without decimals
    static func formatWeightCompact(_ weight: Double, showUnit: Bool = true) -> String {
        let displayWeight = convertToDisplay(weight)
        if showUnit {
            return String(format: "%.0f %@", displayWeight, currentSystem.weightUnit)
        }
        return String(format: "%.0f", displayWeight)
    }

    /// Convert stored weight (always in lbs) to display unit
    static func convertToDisplay(_ weightInLbs: Double) -> Double {
        switch currentSystem {
        case .imperial:
            return weightInLbs
        case .metric:
            return weightInLbs * 0.453592  // lbs to kg
        }
    }

    /// Convert display weight to storage (always lbs)
    static func convertToStorage(_ displayWeight: Double) -> Double {
        switch currentSystem {
        case .imperial:
            return displayWeight
        case .metric:
            return displayWeight / 0.453592  // kg to lbs
        }
    }

    /// Get the weight unit abbreviation
    static var weightUnit: String {
        currentSystem.weightUnit
    }

    /// Format duration in seconds as "M:SS" (e.g. 0:45, 1:30)
    static func formatDuration(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%d:%02d", m, s)
    }
}

/// Environment key for unit system
struct UnitSystemKey: EnvironmentKey {
    static let defaultValue: UnitSystem = .imperial
}

extension EnvironmentValues {
    var unitSystem: UnitSystem {
        get { self[UnitSystemKey.self] }
        set { self[UnitSystemKey.self] = newValue }
    }
}
