//
//  ChallengeGenerator.swift
//  TheLogger
//
//  Generates rest day challenges — quiz questions from user data, quick hit exercises
//

import Foundation
import SwiftData

struct ChallengeGenerator {

    // MARK: - Quick Hit

    static func generateQuickHit() -> DailyChallenge {
        let exercise = QuickHitExercise.allCases.randomElement() ?? .pushups
        return DailyChallenge(
            id: todayId(),
            date: Date(),
            category: .quickHit,
            quickHitExercise: exercise,
            quickHitTarget: exercise.baseTarget
        )
    }

    /// Random quick hit from spin wheel
    static func generateRandomQuickHit() -> DailyChallenge {
        return generateQuickHit()
    }

    // MARK: - Quiz (from user's workout data)

    static func generateQuiz(workouts: [Workout], prs: [PersonalRecord]) -> DailyChallenge? {
        var questions: [QuizQuestion] = []

        // Q1: PR question (if they have PRs)
        if let prQ = generatePRQuestion(prs: prs) {
            questions.append(prQ)
        }

        // Q2: Total workouts question
        let completedCount = workouts.filter { $0.isCompleted && !$0.isTemplate }.count
        if completedCount >= 3 {
            questions.append(generateCountQuestion(
                id: "total-workouts",
                question: "How many workouts have you logged?",
                correctValue: completedCount,
                variance: 0.3
            ))
        }

        // Q3: Most trained exercise
        if let exerciseQ = generateMostTrainedQuestion(workouts: workouts) {
            questions.append(exerciseQ)
        }

        // Q4: Weekly volume question
        if let volumeQ = generateVolumeQuestion(workouts: workouts) {
            questions.append(volumeQ)
        }

        // Q5: Streak question
        if let streakQ = generateStreakQuestion() {
            questions.append(streakQ)
        }

        guard questions.count >= 3 else { return nil } // Need at least 3 questions

        let selected = Array(questions.shuffled().prefix(5))
        return DailyChallenge(
            id: todayId(),
            date: Date(),
            category: .quiz,
            quizQuestions: selected
        )
    }

    // MARK: - Check if quiz is available

    static func canGenerateQuiz(workouts: [Workout], prs: [PersonalRecord]) -> Bool {
        let completed = workouts.filter { $0.isCompleted && !$0.isTemplate }.count
        return completed >= 5 && !prs.isEmpty
    }

    // MARK: - Question Generators

    private static func generatePRQuestion(prs: [PersonalRecord]) -> QuizQuestion? {
        guard let pr = prs.randomElement() else { return nil }
        let displayWeight = UnitFormatter.convertToDisplay(pr.weight)
        let correctStr = pr.isBodyweight
            ? "BW × \(pr.reps)"
            : "\(Int(displayWeight)) \(UnitFormatter.weightUnit) × \(pr.reps)"

        var options = [correctStr]
        // Generate wrong answers
        if pr.isBodyweight {
            let wrongReps = [pr.reps - 3, pr.reps + 2, pr.reps + 5].filter { $0 > 0 }
            options += wrongReps.prefix(3).map { "BW × \($0)" }
        } else {
            let wrongWeights = [displayWeight - 20, displayWeight + 10, displayWeight - 10].filter { $0 > 0 }
            options += wrongWeights.prefix(3).map { "\(Int($0)) \(UnitFormatter.weightUnit) × \(pr.reps)" }
        }

        options = Array(options.prefix(4)).shuffled()
        let correctIdx = options.firstIndex(of: correctStr) ?? 0

        return QuizQuestion(
            id: "pr-\(pr.exerciseName)",
            question: "What's your \(pr.exerciseName) personal record?",
            options: options,
            correctIndex: correctIdx
        )
    }

    private static func generateCountQuestion(id: String, question: String, correctValue: Int, variance: Double) -> QuizQuestion {
        let spread = max(3, Int(Double(correctValue) * variance))
        var options = ["\(correctValue)"]
        let wrongValues = [correctValue - spread, correctValue + spread / 2, correctValue + spread].filter { $0 > 0 && $0 != correctValue }
        options += wrongValues.map { "\($0)" }
        options = Array(Set(options)).prefix(4).shuffled()
        if !options.contains("\(correctValue)") {
            options[0] = "\(correctValue)"
            options.shuffle()
        }
        let correctIdx = options.firstIndex(of: "\(correctValue)") ?? 0
        return QuizQuestion(id: id, question: question, options: Array(options), correctIndex: correctIdx)
    }

    private static func generateMostTrainedQuestion(workouts: [Workout]) -> QuizQuestion? {
        let completed = workouts.filter { $0.isCompleted && !$0.isTemplate }
        var exerciseCounts: [String: Int] = [:]
        for w in completed {
            for ex in w.exercisesByOrder {
                exerciseCounts[ex.name, default: 0] += 1
            }
        }
        guard exerciseCounts.count >= 4 else { return nil }
        let sorted = exerciseCounts.sorted { $0.value > $1.value }
        let correct = sorted[0].key
        let wrong = sorted.dropFirst().prefix(3).map(\.key)
        var options = [correct] + wrong
        options.shuffle()
        let correctIdx = options.firstIndex(of: correct) ?? 0
        return QuizQuestion(
            id: "most-trained",
            question: "Which exercise have you done the most?",
            options: options,
            correctIndex: correctIdx
        )
    }

    private static func generateVolumeQuestion(workouts: [Workout]) -> QuizQuestion? {
        let cal = Calendar.current
        guard let weekInterval = cal.dateInterval(of: .weekOfYear, for: Date()) else { return nil }
        let thisWeek = workouts.filter { $0.isCompleted && !$0.isTemplate && weekInterval.contains($0.date) }
        guard !thisWeek.isEmpty else { return nil }

        var totalVolume: Double = 0
        for w in thisWeek {
            for ex in w.exercisesByOrder {
                for s in ex.setsByOrder where s.type.countsForPR {
                    totalVolume += s.weight * Double(s.reps)
                }
            }
        }
        let displayVolume = UnitFormatter.convertToDisplay(totalVolume)
        let rounded = Int(displayVolume / 100) * 100 // round to nearest 100

        return generateCountQuestion(
            id: "weekly-volume",
            question: "Roughly how much volume did you lift this week?",
            correctValue: rounded,
            variance: 0.25
        )
    }

    private static func generateStreakQuestion() -> QuizQuestion? {
        // Read streak from UserDefaults (GamificationEngine stores it)
        // For now, return nil — will be connected when GamificationEngine is accessible
        return nil
    }

    private static func todayId() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }
}
