//
//  Achievement.swift
//  TheLogger
//
//  Persisted achievement unlock record
//

import Foundation
import SwiftData

@Model
final class Achievement {
    /// Unique slug like "streak-7", "first-pr"
    var id: String = ""
    var unlockedAt: Date = Date()
    var seen: Bool = false

    init(id: String, unlockedAt: Date = Date(), seen: Bool = false) {
        self.id = id
        self.unlockedAt = unlockedAt
        self.seen = seen
    }
}
