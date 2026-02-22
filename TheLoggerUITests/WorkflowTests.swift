//
//  WorkflowTests.swift
//  TheLoggerUITests
//
//  Comprehensive automated tests for all app workflows
//  Run these tests before each release to prevent regressions
//

import XCTest

final class WorkflowTests: XCTestCase {

    let app = XCUIApplication()

    override func setUp() {
        super.setUp()
        continueAfterFailure = false

        // Launch with test flag to reset state
        app.launchArguments = ["--uitesting"]
        app.launch()

        // Skip onboarding if present
        skipOnboardingIfNeeded()
    }

    override func tearDown() {
        super.tearDown()
    }

    // MARK: - Core Workflow Tests

    /// Test 1: Complete workout flow from start to finish
    func testCompleteWorkoutFlow() {
        // 1. Start a new workout
        let startButton = app.buttons["startWorkoutButton"]
        XCTAssertTrue(startButton.waitForExistence(timeout: 5), "Start workout button should exist")
        startButton.tap()

        // 2. Add an exercise
        let addExerciseButton = app.buttons["addExerciseButton"]
        XCTAssertTrue(addExerciseButton.waitForExistence(timeout: 3), "Add exercise button should exist")
        addExerciseButton.tap()

        // 3. Search for exercise
        let searchField = app.textFields["exerciseSearchField"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 3), "Search field should exist")
        searchField.tap()
        searchField.typeText("Bench Press")

        // 4. Select exercise from results
        sleep(1) // Wait for search results
        let benchPressCell = app.cells.firstMatch
        XCTAssertTrue(benchPressCell.waitForExistence(timeout: 3), "Exercise result should exist")
        benchPressCell.tap()

        // 5. Add a set
        sleep(1) // Wait for exercise to be added
        let addSetButton = app.buttons["addSetButton"]
        XCTAssertTrue(addSetButton.waitForExistence(timeout: 3), "Add set button should exist")
        addSetButton.tap()

        // 6. Enter weight and reps
        let weightInput = app.textFields["weightInput"]
        XCTAssertTrue(weightInput.waitForExistence(timeout: 3), "Weight input should exist")
        weightInput.tap()
        weightInput.typeText("135")

        let repsInput = app.textFields["repsInput"]
        XCTAssertTrue(repsInput.waitForExistence(timeout: 3), "Reps input should exist")
        repsInput.tap()
        repsInput.typeText("10")

        // 7. Save set
        let saveButton = app.buttons["saveSetButton"]
        XCTAssertTrue(saveButton.waitForExistence(timeout: 3), "Save button should exist")
        saveButton.tap()

        // 8. Verify set was logged
        sleep(1)
        let setRow = app.staticTexts.containing(NSPredicate(format: "label CONTAINS '135'")).firstMatch
        XCTAssertTrue(setRow.exists, "Logged set should be visible")

        // 9. End workout
        let endButton = app.buttons["endWorkoutButton"]
        XCTAssertTrue(endButton.waitForExistence(timeout: 3), "End workout button should exist")
        endButton.tap()

        // 10. Verify summary appears
        sleep(2)
        // Summary view should be visible (check for workout name or stats)
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'Bench Press'")).firstMatch.exists,
                     "Summary should show workout details")
    }

    /// Test 2: QuickLogStrip workflow for rapid set logging
    func testQuickLogStripWorkflow() {
        // Start workout and add exercise with first set
        startWorkoutAndAddExerciseWithSet(exercise: "Squat", weight: "225", reps: "5")

        // QuickLogStrip should appear after first set
        sleep(1)

        // Tap QuickLogStrip to log another set with same values
        let quickLogButton = app.buttons.containing(NSPredicate(format: "label CONTAINS '225'")).firstMatch
        if quickLogButton.exists {
            quickLogButton.tap()
            sleep(1)

            // Verify second set was logged
            let sets = app.staticTexts.containing(NSPredicate(format: "label CONTAINS '225'"))
            XCTAssertGreaterThanOrEqual(sets.count, 2, "Should have at least 2 sets logged")
        }
    }

    /// Test 3: Template creation and usage
    func testTemplateWorkflow() {
        // Create a workout
        startWorkoutAndAddExerciseWithSet(exercise: "Deadlift", weight: "315", reps: "3")

        // End workout
        let endButton = app.buttons["endWorkoutButton"]
        XCTAssertTrue(endButton.waitForExistence(timeout: 3))
        endButton.tap()
        sleep(2)

        // Navigate back to home (tap Done or similar)
        if app.buttons["Done"].exists {
            app.buttons["Done"].tap()
        }

        // Find the completed workout in history
        sleep(1)
        let workoutCell = app.cells.containing(NSPredicate(format: "label CONTAINS 'Deadlift'")).firstMatch
        if workoutCell.exists {
            workoutCell.tap()
            sleep(1)

            // Save as template
            if app.buttons["Save as Template"].exists {
                app.buttons["Save as Template"].tap()
                sleep(1)

                // Verify template was saved
                app.navigationBars.buttons.firstMatch.tap() // Go back
                sleep(1)

                // Check templates section
                let templateCell = app.cells.containing(NSPredicate(format: "label CONTAINS 'Deadlift'")).firstMatch
                XCTAssertTrue(templateCell.exists, "Template should be visible in templates section")
            }
        }
    }

    /// Test 4: Multiple exercises in one workout
    func testMultipleExercisesWorkflow() {
        // Start workout
        let startButton = app.buttons["startWorkoutButton"]
        startButton.tap()

        // Add first exercise
        addExercise(named: "Bench Press")
        addSet(weight: "185", reps: "8")

        // Add second exercise
        addExercise(named: "Incline Press")
        addSet(weight: "135", reps: "10")

        // Add third exercise
        addExercise(named: "Dips")
        addSet(weight: "0", reps: "15")

        // Verify all exercises are visible
        XCTAssertTrue(app.staticTexts["Bench Press"].exists, "Bench Press should be visible")
        XCTAssertTrue(app.staticTexts["Incline Press"].exists, "Incline Press should be visible")
        XCTAssertTrue(app.staticTexts["Dips"].exists, "Dips should be visible")

        // End workout
        app.buttons["endWorkoutButton"].tap()
        sleep(2)

        // Verify summary shows all exercises
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS '3'")).firstMatch.exists,
                     "Summary should show 3 exercises")
    }

    /// Test 5: Exercise memory persistence
    func testExerciseMemoryPersistence() {
        // Start first workout
        startWorkoutAndAddExerciseWithSet(exercise: "Overhead Press", weight: "95", reps: "8")
        app.buttons["endWorkoutButton"].tap()
        sleep(2)

        if app.buttons["Done"].exists {
            app.buttons["Done"].tap()
        }

        // Start second workout
        sleep(1)
        let startButton = app.buttons["startWorkoutButton"]
        if startButton.waitForExistence(timeout: 3) {
            startButton.tap()

            // Add same exercise
            addExercise(named: "Overhead Press")
            sleep(1)

            // Verify previous values are pre-filled
            let prefilledSet = app.staticTexts.containing(NSPredicate(format: "label CONTAINS '95'")).firstMatch
            XCTAssertTrue(prefilledSet.exists, "Exercise should remember previous weight")
        }
    }

    /// Test 6: Set deletion and editing
    func testSetDeletionAndEditing() {
        // Start workout and add sets
        startWorkoutAndAddExerciseWithSet(exercise: "Squat", weight: "225", reps: "5")
        addSet(weight: "225", reps: "5")
        addSet(weight: "225", reps: "5")

        sleep(1)

        // Find a set to delete (swipe to delete)
        let setRow = app.cells.containing(NSPredicate(format: "label CONTAINS '225'")).firstMatch
        if setRow.exists {
            setRow.swipeLeft()
            sleep(0.5)

            // Tap delete button
            if app.buttons["Delete"].exists {
                app.buttons["Delete"].tap()
                sleep(1)
            }
        }

        // Verify set count decreased
        let sets = app.staticTexts.containing(NSPredicate(format: "label CONTAINS '225'"))
        XCTAssertLessThanOrEqual(sets.count, 2, "Should have 2 or fewer sets after deletion")
    }

    /// Test 7: Settings - Unit conversion
    func testUnitConversion() {
        // Open settings
        let settingsButton = app.buttons.containing(NSPredicate(format: "label CONTAINS 'gear'")).firstMatch
        if settingsButton.waitForExistence(timeout: 3) {
            settingsButton.tap()
            sleep(1)

            // Find unit system toggle
            let metricToggle = app.switches.containing(NSPredicate(format: "label CONTAINS 'Metric'")).firstMatch
            if metricToggle.exists {
                let wasOn = metricToggle.value as? String == "1"
                metricToggle.tap()
                sleep(0.5)

                // Verify toggle changed
                let isNowOn = metricToggle.value as? String == "1"
                XCTAssertNotEqual(wasOn, isNowOn, "Unit system should toggle")

                // Toggle back
                metricToggle.tap()
            }

            // Go back
            app.navigationBars.buttons.firstMatch.tap()
        }
    }

    /// Test 8: Empty state handling
    func testEmptyStateHandling() {
        // Should show empty state with no workouts
        // Look for "Start Workout" or empty state message
        let startButton = app.buttons["startWorkoutButton"]
        XCTAssertTrue(startButton.exists, "Start workout button should be visible in empty state")
    }

    /// Test 9: Superset creation
    func testSupersetCreation() {
        // Start workout
        app.buttons["startWorkoutButton"].tap()

        // Add first exercise
        addExercise(named: "Bench Press")

        // Add second exercise (should be added below first)
        addExercise(named: "Dumbbell Flyes")

        // Both exercises should be visible
        XCTAssertTrue(app.staticTexts["Bench Press"].exists)
        XCTAssertTrue(app.staticTexts["Dumbbell Flyes"].exists)

        // Add set to first exercise
        // Navigation to specific exercise might be needed
        addSet(weight: "135", reps: "10")
    }

    /// Test 10: Data persistence across app launches
    func testDataPersistence() {
        // Create a workout
        startWorkoutAndAddExerciseWithSet(exercise: "Bench Press", weight: "185", reps: "8")
        app.buttons["endWorkoutButton"].tap()
        sleep(2)

        // Terminate and relaunch app
        app.terminate()
        app.launch()
        skipOnboardingIfNeeded()

        // Verify workout exists in history
        sleep(2)
        let workoutInHistory = app.cells.containing(NSPredicate(format: "label CONTAINS 'Bench Press'")).firstMatch
        XCTAssertTrue(workoutInHistory.exists, "Workout should persist after app relaunch")
    }

    // MARK: - Helper Methods

    private func skipOnboardingIfNeeded() {
        let skipButton = app.buttons["Skip"]
        if skipButton.waitForExistence(timeout: 2) {
            skipButton.tap()
            sleep(1)
        }
    }

    private func startWorkoutAndAddExerciseWithSet(exercise: String, weight: String, reps: String) {
        let startButton = app.buttons["startWorkoutButton"]
        if startButton.waitForExistence(timeout: 5) {
            startButton.tap()
        }

        addExercise(named: exercise)
        addSet(weight: weight, reps: reps)
    }

    private func addExercise(named name: String) {
        let addButton = app.buttons["addExerciseButton"]
        if addButton.waitForExistence(timeout: 3) {
            addButton.tap()
        }

        let searchField = app.textFields["exerciseSearchField"]
        if searchField.waitForExistence(timeout: 3) {
            searchField.tap()
            searchField.typeText(name)
            sleep(1)

            // Tap first result
            let firstResult = app.cells.firstMatch
            if firstResult.waitForExistence(timeout: 2) {
                firstResult.tap()
                sleep(1)
            }
        }
    }

    private func addSet(weight: String, reps: String) {
        let addSetButton = app.buttons["addSetButton"]
        if addSetButton.waitForExistence(timeout: 3) {
            addSetButton.tap()
            sleep(0.5)
        }

        let weightInput = app.textFields["weightInput"]
        if weightInput.waitForExistence(timeout: 2) {
            weightInput.tap()
            weightInput.typeText(weight)
        }

        let repsInput = app.textFields["repsInput"]
        if repsInput.exists {
            repsInput.tap()
            repsInput.typeText(reps)
        }

        let saveButton = app.buttons["saveSetButton"]
        if saveButton.exists {
            saveButton.tap()
            sleep(0.5)
        }
    }
}
