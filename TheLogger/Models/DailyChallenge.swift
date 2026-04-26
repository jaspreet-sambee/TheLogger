//
//  DailyChallenge.swift
//  TheLogger
//
//  Model for rest day challenges — keeps streak alive without a gym visit
//

import Foundation

// MARK: - Challenge Types

enum ChallengeCategory: String, Codable {
    case quiz = "quiz"
    case quickHit = "quickHit"
}

enum QuickHitExercise: String, Codable, CaseIterable {
    case pushups = "Pushups"
    case squats = "Bodyweight Squats"
    case plank = "Plank Hold"
    case burpees = "Burpees"
    case lunges = "Lunges"
    case mountainClimbers = "Mountain Climbers"

    var icon: String {
        switch self {
        case .pushups: return "🫸"
        case .squats: return "🦵"
        case .plank: return "🧘"
        case .burpees: return "🏋️"
        case .lunges: return "🚶"
        case .mountainClimbers: return "⛰️"
        }
    }

    var isTimeBased: Bool {
        self == .plank
    }

    /// Base target (reps or seconds) — scaled by user's fitness level
    var baseTarget: Int {
        switch self {
        case .pushups: return 40
        case .squats: return 50
        case .plank: return 60  // seconds
        case .burpees: return 20
        case .lunges: return 30
        case .mountainClimbers: return 40
        }
    }
}

// MARK: - Quiz Question

struct QuizQuestion: Codable, Identifiable {
    let id: String
    let question: String
    let options: [String]
    let correctIndex: Int

    var correctAnswer: String { options[correctIndex] }
}

// MARK: - Daily Challenge

struct DailyChallenge: Codable {
    let id: String              // "2026-04-01"
    let date: Date
    let category: ChallengeCategory
    var isCompleted: Bool = false

    // Quick Hit specific
    var quickHitExercise: QuickHitExercise?
    var quickHitTarget: Int?
    var quickHitProgress: Int = 0

    // Quiz specific
    var quizQuestions: [QuizQuestion]?
    var quizScore: Int = 0
    var quizAnswered: Int = 0

    // XP reward
    var xpReward: Int { isCompleted ? 30 : 0 }
}

// MARK: - Persistence (UserDefaults)

extension DailyChallenge {
    private static let storageKey = "dailyChallenge"

    static func loadToday() -> DailyChallenge? {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let challenge = try? JSONDecoder().decode(DailyChallenge.self, from: data) else {
            return nil
        }
        // Only return if it's from today
        return Calendar.current.isDateInToday(challenge.date) ? challenge : nil
    }

    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: DailyChallenge.storageKey)
        }
    }

    static func clearToday() {
        UserDefaults.standard.removeObject(forKey: storageKey)
    }
}
