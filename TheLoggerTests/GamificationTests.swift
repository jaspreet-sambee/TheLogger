//
//  GamificationTests.swift
//  TheLoggerTests
//
//  Tests for GamificationEngine and AchievementManager
//

import XCTest
import SwiftData
@testable import TheLogger

@MainActor
final class GamificationEngineTests: XCTestCase {

    var modelContext: ModelContext!
    var modelContainer: ModelContainer!
    var engine: GamificationEngine!

    override func setUp() async throws {
        let schema = Schema([
            Workout.self,
            Exercise.self,
            WorkoutSet.self,
            ExerciseMemory.self,
            PersonalRecord.self,
            Achievement.self
        ])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        modelContainer = try ModelContainer(for: schema, configurations: [configuration])
        modelContext = ModelContext(modelContainer)
        engine = GamificationEngine()
    }

    // MARK: - Helper

    private func makeWorkout(date: Date, exercises: [(String, [(Int, Double)])] = [], completed: Bool = true) -> Workout {
        let workout = Workout(name: "Test", date: date, isTemplate: false)
        workout.startTime = date
        if completed {
            workout.endTime = Calendar.current.date(byAdding: .hour, value: 1, to: date)
        }
        for (exerciseName, sets) in exercises {
            let exercise = Exercise(name: exerciseName)
            for (reps, weight) in sets {
                exercise.addSet(reps: reps, weight: weight)
            }
            if workout.exercises == nil {
                workout.exercises = [exercise]
            } else {
                workout.exercises?.append(exercise)
            }
        }
        return workout
    }

    private func daysAgo(_ n: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: -n, to: Calendar.current.startOfDay(for: Date()))!
    }

    // MARK: - Current Streak

    func testCurrentStreakConsecutiveDays() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let workoutDays: Set<Date> = [
            today,
            calendar.date(byAdding: .day, value: -1, to: today)!,
            calendar.date(byAdding: .day, value: -2, to: today)!
        ]

        let streak = engine.computeCurrentStreak(workoutDays: workoutDays, from: today, calendar: calendar)
        XCTAssertEqual(streak, 3)
    }

    func testCurrentStreakGapBreaksStreak() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let workoutDays: Set<Date> = [
            today,
            // skip yesterday
            calendar.date(byAdding: .day, value: -2, to: today)!
        ]

        let streak = engine.computeCurrentStreak(workoutDays: workoutDays, from: today, calendar: calendar)
        XCTAssertEqual(streak, 1)
    }

    func testCurrentStreakNoWorkoutToday() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        let twoDaysAgo = calendar.date(byAdding: .day, value: -2, to: today)!
        let workoutDays: Set<Date> = [yesterday, twoDaysAgo]

        let streak = engine.computeCurrentStreak(workoutDays: workoutDays, from: today, calendar: calendar)
        XCTAssertEqual(streak, 2)
    }

    func testCurrentStreakEmpty() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let streak = engine.computeCurrentStreak(workoutDays: [], from: today, calendar: calendar)
        XCTAssertEqual(streak, 0)
    }

    // MARK: - Best Streak

    func testBestStreakFindsLongest() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        // 3-day streak, gap, 5-day streak
        var days: Set<Date> = []
        for i in 0..<3 { days.insert(calendar.date(byAdding: .day, value: -i, to: today)!) }
        for i in 5..<10 { days.insert(calendar.date(byAdding: .day, value: -i, to: today)!) }

        let best = engine.computeBestStreak(workoutDays: days, calendar: calendar)
        XCTAssertEqual(best, 5)
    }

    func testBestStreakEmpty() {
        let best = engine.computeBestStreak(workoutDays: [], calendar: Calendar.current)
        XCTAssertEqual(best, 0)
    }

    func testBestStreakSingleDay() {
        let today = Calendar.current.startOfDay(for: Date())
        let best = engine.computeBestStreak(workoutDays: [today], calendar: Calendar.current)
        XCTAssertEqual(best, 1)
    }

    // MARK: - Weekly Stats

    func testWeeklyStatsComputesVolume() {
        let workout = makeWorkout(date: Date(), exercises: [
            ("Bench Press", [(10, 135), (8, 155)]),
            ("Squat", [(5, 225)])
        ])

        let stats = engine.computeWeeklyStats(from: [workout])
        // Volume = 10*135 + 8*155 + 5*225 = 1350 + 1240 + 1125 = 3715
        XCTAssertEqual(stats.totalVolume, 3715, accuracy: 0.01)
        XCTAssertEqual(stats.totalSets, 3)
        XCTAssertEqual(stats.totalReps, 23)
        XCTAssertEqual(stats.workoutCount, 1)
    }

    func testWeeklyStatsEmptyWorkouts() {
        let stats = engine.computeWeeklyStats(from: [])
        XCTAssertEqual(stats.totalVolume, 0)
        XCTAssertEqual(stats.totalSets, 0)
        XCTAssertEqual(stats.workoutCount, 0)
        XCTAssertNil(stats.volumeDelta)
    }

    func testWeeklyStatsMuscleBreakdown() {
        let workout = makeWorkout(date: Date(), exercises: [
            ("Bench Press", [(10, 135), (8, 155)]),
            ("Squat", [(5, 225)])
        ])

        let stats = engine.computeWeeklyStats(from: [workout])
        // Bench Press = chest (2 sets), Squat = legs (1 set)
        XCTAssertEqual(stats.muscleBreakdown[.chest], 2)
        XCTAssertEqual(stats.muscleBreakdown[.legs], 1)
    }

    func testWeeklyStatsWeekOverWeekDelta() {
        let calendar = Calendar.current
        guard let lastWeekStart = calendar.date(byAdding: .weekOfYear, value: -1, to: Date()),
              let lastWeekDay = calendar.dateInterval(of: .weekOfYear, for: lastWeekStart)?.start else {
            return
        }
        let lastWeekDate = calendar.date(byAdding: .day, value: 1, to: lastWeekDay)!

        let lastWeekWorkout = makeWorkout(date: lastWeekDate, exercises: [
            ("Bench Press", [(10, 100)])  // volume = 1000
        ])

        let thisWeekWorkout = makeWorkout(date: Date(), exercises: [
            ("Bench Press", [(10, 200)])  // volume = 2000
        ])

        let stats = engine.computeWeeklyStats(from: [thisWeekWorkout, lastWeekWorkout])
        // Delta should be +100%
        if let delta = stats.volumeDelta {
            XCTAssertEqual(delta, 100, accuracy: 0.1)
        } else {
            XCTFail("volumeDelta should not be nil")
        }
    }

    // MARK: - Volume Trend

    func testVolumeTrendProduces8Points() {
        let workouts = (0..<8).map { weekOffset in
            makeWorkout(
                date: Calendar.current.date(byAdding: .weekOfYear, value: -weekOffset, to: Date())!,
                exercises: [("Bench Press", [(10, 100)])]
            )
        }

        let trend = engine.computeVolumeTrend(from: workouts, weeks: 8)
        XCTAssertEqual(trend.count, 8)
    }

    func testVolumeTrendEmptyWorkouts() {
        let trend = engine.computeVolumeTrend(from: [], weeks: 8)
        XCTAssertEqual(trend.count, 8)
        XCTAssertTrue(trend.allSatisfy { $0.volume == 0 })
    }

    // MARK: - Weekly Goal Streak

    func testWeeklyGoalStreakCounts() {
        let calendar = Calendar.current
        var workouts: [Workout] = []

        // Create 4 workouts per week for 3 weeks
        for weekOffset in 0..<3 {
            guard let weekStart = calendar.date(byAdding: .weekOfYear, value: -weekOffset, to: Date()),
                  let weekInterval = calendar.dateInterval(of: .weekOfYear, for: weekStart) else { continue }
            for dayOffset in 0..<4 {
                let date = calendar.date(byAdding: .day, value: dayOffset, to: weekInterval.start)!
                workouts.append(makeWorkout(date: date))
            }
        }

        let streak = engine.computeWeeklyGoalStreak(workouts: workouts, goal: 4, calendar: calendar)
        XCTAssertGreaterThanOrEqual(streak, 3)
    }

    func testWeeklyGoalStreakBreaksWhenNotMet() {
        let calendar = Calendar.current
        // This week: 4 workouts (goal met)
        var workouts: [Workout] = []
        for dayOffset in 0..<4 {
            let date = calendar.date(byAdding: .day, value: -dayOffset, to: Date())!
            workouts.append(makeWorkout(date: date))
        }

        // Last week: 1 workout (goal not met)
        let lastWeekDate = calendar.date(byAdding: .weekOfYear, value: -1, to: Date())!
        workouts.append(makeWorkout(date: lastWeekDate))

        let streak = engine.computeWeeklyGoalStreak(workouts: workouts, goal: 4, calendar: calendar)
        // Should only count current week
        XCTAssertLessThanOrEqual(streak, 1)
    }

    func testWeeklyGoalStreak_exactlyMeetsGoal_counts() {
        let calendar = Calendar.current
        var workouts: [Workout] = []

        // Exactly 4 workouts placed at the start of the current week
        guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: Date()) else { return }
        for dayOffset in 0..<4 {
            let date = calendar.date(byAdding: .day, value: dayOffset, to: weekInterval.start)!
            workouts.append(makeWorkout(date: date))
        }

        let streak = engine.computeWeeklyGoalStreak(workouts: workouts, goal: 4, calendar: calendar)
        XCTAssertGreaterThanOrEqual(streak, 1)
    }

    // MARK: - Streak edge cases

    func testCurrentStreak_futureDatedWorkout_notCounted() {
        let calendar = Calendar.current
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: Date()))!
        let today = calendar.startOfDay(for: Date())

        // Only a future workout — streak should be 0
        let workoutDays: Set<Date> = [tomorrow]
        let streak = engine.computeCurrentStreak(workoutDays: workoutDays, from: today, calendar: calendar)
        XCTAssertEqual(streak, 0)
    }

    func testCurrentStreak_todayAndYesterdayAndFuture_countsTodayAndYesterday() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!

        let workoutDays: Set<Date> = [today, yesterday, tomorrow]
        let streak = engine.computeCurrentStreak(workoutDays: workoutDays, from: today, calendar: calendar)
        XCTAssertEqual(streak, 2) // today + yesterday only
    }

    func testVolumeTrend_weeksWithNoWorkouts_showZeroVolume() {
        // Only one workout this week; all other weeks should show 0
        let thisWeek = makeWorkout(date: Date(), exercises: [("Bench Press", [(10, 100)])])
        let trend = engine.computeVolumeTrend(from: [thisWeek], weeks: 8)

        XCTAssertEqual(trend.count, 8)
        // At least 7 of the 8 weeks should have 0 volume
        let zeroWeeks = trend.filter { $0.volume == 0 }.count
        XCTAssertGreaterThanOrEqual(zeroWeeks, 7)
    }

    func testWeeklyStats_muscleBreakdownMultipleExercises_allGroupsCounted() {
        let workout = makeWorkout(date: Date(), exercises: [
            ("Bench Press", [(10, 135), (8, 155)]),  // chest: 2 sets
            ("Squat", [(5, 225), (5, 225)]),          // legs: 2 sets
            ("Overhead Press", [(8, 95)])              // shoulders: 1 set
        ])

        let stats = engine.computeWeeklyStats(from: [workout])
        XCTAssertEqual(stats.muscleBreakdown[.chest], 2)
        XCTAssertEqual(stats.muscleBreakdown[.legs], 2)
        XCTAssertEqual(stats.muscleBreakdown[.shoulders], 1)
    }

    func testWeeklyStats_noWorkoutsThisWeek_returnsZeros() {
        // Only workouts from last month
        let oldDate = Calendar.current.date(byAdding: .month, value: -1, to: Date())!
        let oldWorkout = makeWorkout(date: oldDate, exercises: [("Bench Press", [(10, 135)])])
        let stats = engine.computeWeeklyStats(from: [oldWorkout])

        XCTAssertEqual(stats.totalVolume, 0)
        XCTAssertEqual(stats.totalSets, 0)
        XCTAssertEqual(stats.workoutCount, 0)
    }

    // MARK: - Refresh

    func testRefreshPopulatesAllFields() {
        let workout = makeWorkout(date: Date(), exercises: [
            ("Bench Press", [(10, 135)])
        ])
        modelContext.insert(workout)
        try? modelContext.save()

        let pr = PersonalRecord(exerciseName: "bench press", weight: 135, reps: 10, workoutId: workout.id)
        modelContext.insert(pr)
        try? modelContext.save()

        engine.refresh(workouts: [workout], prs: [pr], weeklyGoal: 4)

        XCTAssertGreaterThan(engine.weeklyStats.totalVolume, 0)
        XCTAssertEqual(engine.volumeTrend.count, 8)
        XCTAssertGreaterThanOrEqual(engine.thisWeekPRCount, 1)
    }
}

// MARK: - Achievement Manager Tests

@MainActor
final class AchievementManagerTests: XCTestCase {

    var modelContext: ModelContext!
    var modelContainer: ModelContainer!

    override func setUp() async throws {
        let schema = Schema([
            Workout.self,
            Exercise.self,
            WorkoutSet.self,
            ExerciseMemory.self,
            PersonalRecord.self,
            Achievement.self
        ])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        modelContainer = try ModelContainer(for: schema, configurations: [configuration])
        modelContext = ModelContext(modelContainer)
    }

    private func makeWorkout(date: Date = Date(), exercises: [(String, [(Int, Double)])] = [], startHour: Int? = nil) -> Workout {
        let workout = Workout(name: "Test", date: date, isTemplate: false)
        let calendar = Calendar.current
        if let hour = startHour {
            var components = calendar.dateComponents([.year, .month, .day], from: date)
            components.hour = hour
            components.minute = 0
            workout.startTime = calendar.date(from: components) ?? date
        } else {
            workout.startTime = date
        }
        workout.endTime = calendar.date(byAdding: .hour, value: 1, to: workout.startTime ?? date)

        for (exerciseName, sets) in exercises {
            let exercise = Exercise(name: exerciseName)
            for (reps, weight) in sets {
                exercise.addSet(reps: reps, weight: weight)
            }
            if workout.exercises == nil {
                workout.exercises = [exercise]
            } else {
                workout.exercises?.append(exercise)
            }
        }
        return workout
    }

    // MARK: - First Workout

    func testFirstWorkoutAchievement() {
        let workout = makeWorkout()
        let streakData = StreakData(current: 1, bestEver: 1, weeklyGoalStreak: 0, workoutDays: [:])
        let context = AchievementManager.buildContext(workouts: [workout], prs: [], streakData: streakData)
        let unlocked = AchievementManager.checkAll(context: context, alreadyUnlocked: [])

        XCTAssertTrue(unlocked.contains(where: { $0.id == "first-workout" }))
    }

    func testFirstWorkoutNotDuplicated() {
        let workout = makeWorkout()
        let streakData = StreakData(current: 1, bestEver: 1, weeklyGoalStreak: 0, workoutDays: [:])
        let context = AchievementManager.buildContext(workouts: [workout], prs: [], streakData: streakData)
        let unlocked = AchievementManager.checkAll(context: context, alreadyUnlocked: ["first-workout"])

        XCTAssertFalse(unlocked.contains(where: { $0.id == "first-workout" }))
    }

    // MARK: - Streak Achievements

    func testStreakAchievements() {
        let streakData = StreakData(current: 7, bestEver: 7, weeklyGoalStreak: 0, workoutDays: [:])
        let workouts = (0..<7).map { i in
            makeWorkout(date: Calendar.current.date(byAdding: .day, value: -i, to: Date())!)
        }
        let context = AchievementManager.buildContext(workouts: workouts, prs: [], streakData: streakData)
        let unlocked = AchievementManager.checkAll(context: context, alreadyUnlocked: [])

        XCTAssertTrue(unlocked.contains(where: { $0.id == "streak-3" }))
        XCTAssertTrue(unlocked.contains(where: { $0.id == "streak-7" }))
        XCTAssertFalse(unlocked.contains(where: { $0.id == "streak-14" }))
    }

    // MARK: - PR Achievements

    func testFirstPRAchievement() {
        let pr = PersonalRecord(exerciseName: "bench press", weight: 135, reps: 10, workoutId: UUID())
        let streakData = StreakData.empty
        let context = AchievementManager.buildContext(workouts: [], prs: [pr], streakData: streakData)
        let unlocked = AchievementManager.checkAll(context: context, alreadyUnlocked: [])

        XCTAssertTrue(unlocked.contains(where: { $0.id == "first-pr" }))
    }

    func testBodyweightPRAchievement() {
        let pr = PersonalRecord(exerciseName: "pull-up", weight: 0, reps: 15, workoutId: UUID())
        let streakData = StreakData.empty
        let context = AchievementManager.buildContext(workouts: [], prs: [pr], streakData: streakData)
        let unlocked = AchievementManager.checkAll(context: context, alreadyUnlocked: [])

        XCTAssertTrue(unlocked.contains(where: { $0.id == "bodyweight-pr" }))
    }

    func testPR10Achievement() {
        let prs = (0..<10).map { i in
            PersonalRecord(exerciseName: "exercise-\(i)", weight: Double(i + 1) * 10, reps: 10, workoutId: UUID())
        }
        let streakData = StreakData.empty
        let context = AchievementManager.buildContext(workouts: [], prs: prs, streakData: streakData)
        let unlocked = AchievementManager.checkAll(context: context, alreadyUnlocked: [])

        XCTAssertTrue(unlocked.contains(where: { $0.id == "pr-10" }))
    }

    // MARK: - Volume Achievements

    func testSets100Achievement() {
        // Create workouts with 100+ total sets
        let workout = makeWorkout(exercises: [
            ("Bench Press", Array(repeating: (10, 100.0), count: 50)),
            ("Squat", Array(repeating: (10, 100.0), count: 51))
        ])
        let streakData = StreakData.empty
        let context = AchievementManager.buildContext(workouts: [workout], prs: [], streakData: streakData)
        let unlocked = AchievementManager.checkAll(context: context, alreadyUnlocked: [])

        XCTAssertTrue(unlocked.contains(where: { $0.id == "sets-100" }))
    }

    func testVolume10kAchievement() {
        // 10 reps * 100 lbs * 10 sets = 10,000
        let workout = makeWorkout(exercises: [
            ("Bench Press", Array(repeating: (10, 100.0), count: 10))
        ])
        let streakData = StreakData.empty
        let context = AchievementManager.buildContext(workouts: [workout], prs: [], streakData: streakData)
        let unlocked = AchievementManager.checkAll(context: context, alreadyUnlocked: [])

        XCTAssertTrue(unlocked.contains(where: { $0.id == "volume-10k" }))
    }

    // MARK: - Variety Achievements

    func testExercises10Achievement() {
        let exercises = (0..<10).map { i in ("Exercise \(i)", [(10, 100.0)]) }
        let workout = makeWorkout(exercises: exercises)
        let streakData = StreakData.empty
        let context = AchievementManager.buildContext(workouts: [workout], prs: [], streakData: streakData)
        let unlocked = AchievementManager.checkAll(context: context, alreadyUnlocked: [])

        XCTAssertTrue(unlocked.contains(where: { $0.id == "exercises-10" }))
    }

    func testAllMusclesAchievement() {
        let workout = makeWorkout(exercises: [
            ("Bench Press", [(10, 100)]),     // chest
            ("Deadlift", [(5, 200)]),         // back
            ("Overhead Press", [(8, 80)]),     // shoulders
            ("Barbell Curl", [(12, 50)]),      // arms
            ("Squat", [(5, 225)]),             // legs
            ("Plank", [(1, 0)])               // core
        ])
        let streakData = StreakData.empty
        let context = AchievementManager.buildContext(workouts: [workout], prs: [], streakData: streakData)
        let unlocked = AchievementManager.checkAll(context: context, alreadyUnlocked: [])

        XCTAssertTrue(unlocked.contains(where: { $0.id == "all-muscles" }))
    }

    // MARK: - Dedication Achievements

    func testEarlyBirdAchievement() {
        let workout = makeWorkout(startHour: 5)
        let streakData = StreakData.empty
        let context = AchievementManager.buildContext(workouts: [workout], prs: [], streakData: streakData)
        let unlocked = AchievementManager.checkAll(context: context, alreadyUnlocked: [])

        XCTAssertTrue(unlocked.contains(where: { $0.id == "early-bird" }))
    }

    func testNightOwlAchievement() {
        let workout = makeWorkout(startHour: 22)
        let streakData = StreakData.empty
        let context = AchievementManager.buildContext(workouts: [workout], prs: [], streakData: streakData)
        let unlocked = AchievementManager.checkAll(context: context, alreadyUnlocked: [])

        XCTAssertTrue(unlocked.contains(where: { $0.id == "night-owl" }))
    }

    func testWorkouts10Achievement() {
        let workouts = (0..<10).map { i in
            makeWorkout(date: Calendar.current.date(byAdding: .day, value: -i, to: Date())!)
        }
        let streakData = StreakData.empty
        let context = AchievementManager.buildContext(workouts: workouts, prs: [], streakData: streakData)
        let unlocked = AchievementManager.checkAll(context: context, alreadyUnlocked: [])

        XCTAssertTrue(unlocked.contains(where: { $0.id == "workouts-10" }))
    }

    // MARK: - Progress

    func testProgressReturnsPartialValue() {
        // 5 out of 10 workouts needed
        let workouts = (0..<5).map { i in
            makeWorkout(date: Calendar.current.date(byAdding: .day, value: -i, to: Date())!)
        }
        let streakData = StreakData.empty
        let context = AchievementManager.buildContext(workouts: workouts, prs: [], streakData: streakData)

        let progress = AchievementManager.progress(for: "workouts-10", context: context)
        XCTAssertEqual(progress, 0.5, accuracy: 0.01)
    }

    func testProgressReturns1WhenComplete() {
        let workouts = (0..<15).map { i in
            makeWorkout(date: Calendar.current.date(byAdding: .day, value: -i, to: Date())!)
        }
        let streakData = StreakData.empty
        let context = AchievementManager.buildContext(workouts: workouts, prs: [], streakData: streakData)

        let progress = AchievementManager.progress(for: "workouts-10", context: context)
        XCTAssertEqual(progress, 1.0)
    }

    // MARK: - Definition Count

    func testDefinitionCount() {
        // Should have ~30 achievements
        let count = AchievementManager.definitions.count
        XCTAssertGreaterThanOrEqual(count, 28)
        XCTAssertLessThanOrEqual(count, 35)
    }

    func testAllDefinitionsHaveUniqueIds() {
        let ids = AchievementManager.definitions.map(\.id)
        XCTAssertEqual(ids.count, Set(ids).count, "All achievement IDs should be unique")
    }

    func testAllCategoriesRepresented() {
        let categories = Set(AchievementManager.definitions.map(\.category))
        for category in AchievementCategory.allCases {
            XCTAssertTrue(categories.contains(category), "Missing category: \(category.rawValue)")
        }
    }

    // MARK: - Goal Streak Achievement

    func testGoalGetterAchievement() {
        let streakData = StreakData(current: 1, bestEver: 1, weeklyGoalStreak: 4, workoutDays: [:])
        let context = AchievementManager.buildContext(workouts: [], prs: [], streakData: streakData)
        let unlocked = AchievementManager.checkAll(context: context, alreadyUnlocked: [])

        XCTAssertTrue(unlocked.contains(where: { $0.id == "goal-4" }))
    }

    func testGoal12Achievement() {
        let streakData = StreakData(current: 1, bestEver: 1, weeklyGoalStreak: 12, workoutDays: [:])
        let context = AchievementManager.buildContext(workouts: [], prs: [], streakData: streakData)
        let unlocked = AchievementManager.checkAll(context: context, alreadyUnlocked: [])

        XCTAssertTrue(unlocked.contains(where: { $0.id == "goal-12" }))
    }

    func testGoal4NotUnlockedWithThreeWeeks() {
        let streakData = StreakData(current: 1, bestEver: 1, weeklyGoalStreak: 3, workoutDays: [:])
        let context = AchievementManager.buildContext(workouts: [], prs: [], streakData: streakData)
        let unlocked = AchievementManager.checkAll(context: context, alreadyUnlocked: [])

        XCTAssertFalse(unlocked.contains(where: { $0.id == "goal-4" }))
    }

    // MARK: - Missing Streak Achievements

    func testStreak14Achievement() {
        let streakData = StreakData(current: 14, bestEver: 14, weeklyGoalStreak: 0, workoutDays: [:])
        let context = AchievementManager.buildContext(workouts: [], prs: [], streakData: streakData)
        let unlocked = AchievementManager.checkAll(context: context, alreadyUnlocked: [])

        XCTAssertTrue(unlocked.contains(where: { $0.id == "streak-14" }))
        XCTAssertTrue(unlocked.contains(where: { $0.id == "streak-7" }))
        XCTAssertTrue(unlocked.contains(where: { $0.id == "streak-3" }))
        XCTAssertFalse(unlocked.contains(where: { $0.id == "streak-30" }))
    }

    func testStreak30Achievement() {
        let streakData = StreakData(current: 30, bestEver: 30, weeklyGoalStreak: 0, workoutDays: [:])
        let context = AchievementManager.buildContext(workouts: [], prs: [], streakData: streakData)
        let unlocked = AchievementManager.checkAll(context: context, alreadyUnlocked: [])

        XCTAssertTrue(unlocked.contains(where: { $0.id == "streak-30" }))
        XCTAssertFalse(unlocked.contains(where: { $0.id == "streak-100" }))
    }

    func testStreak100Achievement() {
        let streakData = StreakData(current: 100, bestEver: 100, weeklyGoalStreak: 0, workoutDays: [:])
        let context = AchievementManager.buildContext(workouts: [], prs: [], streakData: streakData)
        let unlocked = AchievementManager.checkAll(context: context, alreadyUnlocked: [])

        XCTAssertTrue(unlocked.contains(where: { $0.id == "streak-100" }))
    }

    // MARK: - Missing PR Achievements

    func testPR25Achievement() {
        let prs = (0..<25).map { i in
            PersonalRecord(exerciseName: "exercise-\(i)", weight: Double(i + 1) * 10, reps: 10, workoutId: UUID())
        }
        let context = AchievementManager.buildContext(workouts: [], prs: prs, streakData: .empty)
        let unlocked = AchievementManager.checkAll(context: context, alreadyUnlocked: [])

        XCTAssertTrue(unlocked.contains(where: { $0.id == "pr-25" }))
    }

    func testPR50Achievement() {
        let prs = (0..<50).map { i in
            PersonalRecord(exerciseName: "exercise-\(i)", weight: Double(i + 1) * 10, reps: 10, workoutId: UUID())
        }
        let context = AchievementManager.buildContext(workouts: [], prs: prs, streakData: .empty)
        let unlocked = AchievementManager.checkAll(context: context, alreadyUnlocked: [])

        XCTAssertTrue(unlocked.contains(where: { $0.id == "pr-50" }))
        XCTAssertTrue(unlocked.contains(where: { $0.id == "pr-25" }))
        XCTAssertTrue(unlocked.contains(where: { $0.id == "pr-10" }))
    }

    func testPR10NotUnlockedWithNinePRs() {
        let prs = (0..<9).map { i in
            PersonalRecord(exerciseName: "exercise-\(i)", weight: 100, reps: 10, workoutId: UUID())
        }
        let context = AchievementManager.buildContext(workouts: [], prs: prs, streakData: .empty)
        let unlocked = AchievementManager.checkAll(context: context, alreadyUnlocked: [])

        XCTAssertFalse(unlocked.contains(where: { $0.id == "pr-10" }))
    }

    // MARK: - Missing Volume/Sets Achievements

    func testSets500Achievement() {
        let workout = makeWorkout(exercises: [
            ("Bench Press", Array(repeating: (10, 100.0), count: 250)),
            ("Squat", Array(repeating: (10, 100.0), count: 251))
        ])
        let context = AchievementManager.buildContext(workouts: [workout], prs: [], streakData: .empty)
        let unlocked = AchievementManager.checkAll(context: context, alreadyUnlocked: [])

        XCTAssertTrue(unlocked.contains(where: { $0.id == "sets-500" }))
        XCTAssertFalse(unlocked.contains(where: { $0.id == "sets-1000" }))
    }

    func testSets1000Achievement() {
        let workout = makeWorkout(exercises: [
            ("Bench Press", Array(repeating: (10, 100.0), count: 500)),
            ("Squat", Array(repeating: (10, 100.0), count: 501))
        ])
        let context = AchievementManager.buildContext(workouts: [workout], prs: [], streakData: .empty)
        let unlocked = AchievementManager.checkAll(context: context, alreadyUnlocked: [])

        XCTAssertTrue(unlocked.contains(where: { $0.id == "sets-1000" }))
    }

    func testVolume100kAchievement() {
        // 10 reps * 100 lbs * 100 sets = 100,000
        let workout = makeWorkout(exercises: [
            ("Bench Press", Array(repeating: (10, 100.0), count: 100))
        ])
        let context = AchievementManager.buildContext(workouts: [workout], prs: [], streakData: .empty)
        let unlocked = AchievementManager.checkAll(context: context, alreadyUnlocked: [])

        XCTAssertTrue(unlocked.contains(where: { $0.id == "volume-100k" }))
        XCTAssertFalse(unlocked.contains(where: { $0.id == "volume-1m" }))
    }

    func testVolume1mAchievement() {
        // 10 reps * 100 lbs * 1000 sets = 1,000,000
        let workout = makeWorkout(exercises: [
            ("Bench Press", Array(repeating: (10, 100.0), count: 1000))
        ])
        let context = AchievementManager.buildContext(workouts: [workout], prs: [], streakData: .empty)
        let unlocked = AchievementManager.checkAll(context: context, alreadyUnlocked: [])

        XCTAssertTrue(unlocked.contains(where: { $0.id == "volume-1m" }))
    }

    // MARK: - Missing Variety Achievements

    func testExercises25Achievement() {
        let exercises = (0..<25).map { i in ("Exercise \(i)", [(10, 100.0)]) }
        let workout = makeWorkout(exercises: exercises)
        let context = AchievementManager.buildContext(workouts: [workout], prs: [], streakData: .empty)
        let unlocked = AchievementManager.checkAll(context: context, alreadyUnlocked: [])

        XCTAssertTrue(unlocked.contains(where: { $0.id == "exercises-25" }))
        XCTAssertFalse(unlocked.contains(where: { $0.id == "exercises-50" }))
    }

    func testExercises50Achievement() {
        let exercises = (0..<50).map { i in ("Exercise \(i)", [(10, 100.0)]) }
        let workout = makeWorkout(exercises: exercises)
        let context = AchievementManager.buildContext(workouts: [workout], prs: [], streakData: .empty)
        let unlocked = AchievementManager.checkAll(context: context, alreadyUnlocked: [])

        XCTAssertTrue(unlocked.contains(where: { $0.id == "exercises-50" }))
    }

    func testCompoundKingAchievement() {
        // Use 10 known compound exercises from the library
        let compoundExercises = [
            "Bench Press", "Squat", "Deadlift", "Overhead Press", "Pull-Up",
            "Barbell Row", "Incline Bench Press", "Dumbbell Bench Press", "Chin-Up", "Dips (Chest)"
        ]
        let exercises = compoundExercises.map { ($0, [(10, 100.0)]) }
        let workout = makeWorkout(exercises: exercises)
        let context = AchievementManager.buildContext(workouts: [workout], prs: [], streakData: .empty)
        let unlocked = AchievementManager.checkAll(context: context, alreadyUnlocked: [])

        XCTAssertTrue(unlocked.contains(where: { $0.id == "compound-king" }))
    }

    func testCompoundKingNotUnlockedWithNineCompounds() {
        let compoundExercises = [
            "Bench Press", "Squat", "Deadlift", "Overhead Press", "Pull-Up",
            "Barbell Row", "Incline Bench Press", "Dumbbell Bench Press", "Chin-Up"
        ]
        let exercises = compoundExercises.map { ($0, [(10, 100.0)]) }
        let workout = makeWorkout(exercises: exercises)
        let context = AchievementManager.buildContext(workouts: [workout], prs: [], streakData: .empty)
        let unlocked = AchievementManager.checkAll(context: context, alreadyUnlocked: [])

        XCTAssertFalse(unlocked.contains(where: { $0.id == "compound-king" }))
    }

    // MARK: - Missing Dedication Achievements

    func testWorkouts50Achievement() {
        let workouts = (0..<50).map { i in
            makeWorkout(date: Calendar.current.date(byAdding: .day, value: -i, to: Date())!)
        }
        let context = AchievementManager.buildContext(workouts: workouts, prs: [], streakData: .empty)
        let unlocked = AchievementManager.checkAll(context: context, alreadyUnlocked: [])

        XCTAssertTrue(unlocked.contains(where: { $0.id == "workouts-50" }))
        XCTAssertFalse(unlocked.contains(where: { $0.id == "workouts-100" }))
    }

    func testWorkouts100Achievement() {
        let workouts = (0..<100).map { i in
            makeWorkout(date: Calendar.current.date(byAdding: .day, value: -i, to: Date())!)
        }
        let context = AchievementManager.buildContext(workouts: workouts, prs: [], streakData: .empty)
        let unlocked = AchievementManager.checkAll(context: context, alreadyUnlocked: [])

        XCTAssertTrue(unlocked.contains(where: { $0.id == "workouts-100" }))
        XCTAssertFalse(unlocked.contains(where: { $0.id == "workouts-500" }))
    }

    func testWorkouts500Achievement() {
        let workouts = (0..<500).map { i in
            makeWorkout(date: Calendar.current.date(byAdding: .day, value: -i, to: Date())!)
        }
        let context = AchievementManager.buildContext(workouts: workouts, prs: [], streakData: .empty)
        let unlocked = AchievementManager.checkAll(context: context, alreadyUnlocked: [])

        XCTAssertTrue(unlocked.contains(where: { $0.id == "workouts-500" }))
    }

    func testWeekendWarriorAchievement() {
        let calendar = Calendar.current
        // Find the last 4 Saturdays
        var saturdays: [Date] = []
        var date = Date()
        while saturdays.count < 4 {
            let weekday = calendar.component(.weekday, from: date)
            if weekday == 7 { // Saturday
                saturdays.append(date)
            }
            date = calendar.date(byAdding: .day, value: -1, to: date)!
        }
        let workouts = saturdays.map { makeWorkout(date: $0) }
        let context = AchievementManager.buildContext(workouts: workouts, prs: [], streakData: .empty)
        let unlocked = AchievementManager.checkAll(context: context, alreadyUnlocked: [])

        XCTAssertTrue(unlocked.contains(where: { $0.id == "weekend-warrior" }))
    }

    func testWeekendWarriorNotUnlockedWithThreeWeekendWorkouts() {
        let calendar = Calendar.current
        var saturdays: [Date] = []
        var date = Date()
        while saturdays.count < 3 {
            let weekday = calendar.component(.weekday, from: date)
            if weekday == 7 {
                saturdays.append(date)
            }
            date = calendar.date(byAdding: .day, value: -1, to: date)!
        }
        let workouts = saturdays.map { makeWorkout(date: $0) }
        let context = AchievementManager.buildContext(workouts: workouts, prs: [], streakData: .empty)
        let unlocked = AchievementManager.checkAll(context: context, alreadyUnlocked: [])

        XCTAssertFalse(unlocked.contains(where: { $0.id == "weekend-warrior" }))
    }

    // MARK: - buildContext correctness

    func testBuildContext_excludesTemplateWorkouts() {
        let template = Workout(name: "Template", date: Date(), isTemplate: true)
        template.startTime = Date().addingTimeInterval(-3600)
        template.endTime = Date()
        let ex = Exercise(name: "Bench Press")
        ex.addSet(reps: 10, weight: 135)
        template.exercises = [ex]

        let context = AchievementManager.buildContext(workouts: [template], prs: [], streakData: .empty)
        // Template should be excluded — first-workout should NOT unlock
        let unlocked = AchievementManager.checkAll(context: context, alreadyUnlocked: [])
        XCTAssertFalse(unlocked.contains(where: { $0.id == "first-workout" }))
    }

    func testBuildContext_excludesIncompleteWorkouts() {
        let active = Workout(name: "In Progress", date: Date(), isTemplate: false)
        active.startTime = Date().addingTimeInterval(-3600)
        // No endTime → not completed

        let context = AchievementManager.buildContext(workouts: [active], prs: [], streakData: .empty)
        let unlocked = AchievementManager.checkAll(context: context, alreadyUnlocked: [])
        XCTAssertFalse(unlocked.contains(where: { $0.id == "first-workout" }))
    }

    func testBuildContext_uniqueExercisesNormalized() {
        // "Bench Press" and "bench press" should be counted as 1 unique exercise
        let workout = makeWorkout(exercises: [
            ("Bench Press", [(10, 100.0)]),
            ("bench press", [(10, 100.0)])
        ])
        let context = AchievementManager.buildContext(workouts: [workout], prs: [], streakData: .empty)
        XCTAssertEqual(context.uniqueExercises.count, 1)
    }

    func testBuildContext_earlyBirdDetected() {
        let workout = makeWorkout(startHour: 5)
        let context = AchievementManager.buildContext(workouts: [workout], prs: [], streakData: .empty)
        XCTAssertTrue(context.hasEarlyBirdWorkout)
    }

    func testBuildContext_earlyBirdNotDetectedAt7AM() {
        let workout = makeWorkout(startHour: 7)
        let context = AchievementManager.buildContext(workouts: [workout], prs: [], streakData: .empty)
        XCTAssertFalse(context.hasEarlyBirdWorkout)
    }

    func testBuildContext_nightOwlDetected() {
        let workout = makeWorkout(startHour: 22)
        let context = AchievementManager.buildContext(workouts: [workout], prs: [], streakData: .empty)
        XCTAssertTrue(context.hasNightOwlWorkout)
    }

    func testBuildContext_nightOwlNotDetectedAt8PM() {
        let workout = makeWorkout(startHour: 20)
        let context = AchievementManager.buildContext(workouts: [workout], prs: [], streakData: .empty)
        XCTAssertFalse(context.hasNightOwlWorkout)
    }

    func testBuildContext_totalSetsAcrossWorkouts() {
        let w1 = makeWorkout(exercises: [("Bench Press", [(10, 100.0), (8, 110.0)])])
        let w2 = makeWorkout(exercises: [("Squat", [(5, 200.0), (5, 200.0), (5, 200.0)])])
        let context = AchievementManager.buildContext(workouts: [w1, w2], prs: [], streakData: .empty)
        XCTAssertEqual(context.totalSets, 5)
    }

    func testBuildContext_totalVolumeAcrossWorkouts() {
        // 10×100 + 8×110 = 1880
        let workout = makeWorkout(exercises: [("Bench Press", [(10, 100.0), (8, 110.0)])])
        let context = AchievementManager.buildContext(workouts: [workout], prs: [], streakData: .empty)
        XCTAssertEqual(context.totalVolume, 1880.0, accuracy: 0.01)
    }

    // MARK: - Achievement Model

    // MARK: - Achievement Model

    func testAchievementModelPersistence() {
        let achievement = Achievement(id: "test-achievement")
        modelContext.insert(achievement)
        try? modelContext.save()

        let descriptor = FetchDescriptor<Achievement>()
        let fetched = try? modelContext.fetch(descriptor)

        XCTAssertEqual(fetched?.count, 1)
        XCTAssertEqual(fetched?.first?.id, "test-achievement")
        XCTAssertFalse(fetched?.first?.seen ?? true)
    }

    func testAchievementSeenFlag() {
        let achievement = Achievement(id: "test-seen")
        modelContext.insert(achievement)
        try? modelContext.save()

        achievement.seen = true
        try? modelContext.save()

        let descriptor = FetchDescriptor<Achievement>()
        let fetched = try? modelContext.fetch(descriptor)
        XCTAssertTrue(fetched?.first?.seen ?? false)
    }
}
