import XCTest

/// Demo scenarios for recording app demonstration videos.
/// Each test method corresponds to a workflow YAML file in VideoAutomation/workflows/
///
/// Usage:
///   These tests are run automatically by the record-video.sh script.
///   Each test method demonstrates a specific app flow for marketing videos.
///
/// Naming Convention:
///   - Method name: test<WorkflowName>Demo
///   - Workflow file: <workflow-name>.yaml
///   - Example: testNewWorkoutDemo -> new-workout.yaml
final class DemoScenarios: XCTestCase {

    let app = XCUIApplication()

    override func setUp() {
        super.setUp()
        continueAfterFailure = true

        // Launch with clean state for demos
        app.launchArguments = ["--demo-mode"]
        app.launch()

        // Wait for app to be ready
        sleep(1)
    }

    override func tearDown() {
        super.tearDown()
    }

    // MARK: - New Workout Demo

    /// Demonstrates creating a new workout, adding an exercise, and logging a set.
    /// Workflow: new-workout.yaml
    func testNewWorkoutDemo() {
        // Wait for home screen
        let startButton = app.buttons["startWorkoutButton"]
        XCTAssertTrue(startButton.waitForExistence(timeout: 5), "Start workout button should exist")

        // Tap "Start Workout"
        startButton.tap()
        sleep(1)

        // Tap "Add Exercise"
        let addExerciseButton = app.buttons["addExerciseButton"]
        if addExerciseButton.waitForExistence(timeout: 3) {
            addExerciseButton.tap()
            sleep(1)
        }

        // Search for exercise
        let searchField = app.textFields["exerciseSearchField"]
        if searchField.waitForExistence(timeout: 3) {
            searchField.tap()
            searchField.typeText("Bench Press")
            sleep(1)
        }

        // Select from results
        let benchPressResult = app.cells["exerciseResult_Bench Press"]
        if benchPressResult.waitForExistence(timeout: 3) {
            benchPressResult.tap()
            sleep(1)
        }

        // Add a set
        let addSetButton = app.buttons["addSetButton"]
        if addSetButton.waitForExistence(timeout: 3) {
            addSetButton.tap()
            sleep(1)
        }

        // Enter weight
        let weightInput = app.textFields["weightInput"]
        if weightInput.waitForExistence(timeout: 3) {
            weightInput.tap()
            weightInput.typeText("135")
        }

        // Enter reps
        let repsInput = app.textFields["repsInput"]
        if repsInput.waitForExistence(timeout: 3) {
            repsInput.tap()
            repsInput.typeText("10")
        }

        // Save set
        let saveSetButton = app.buttons["saveSetButton"]
        if saveSetButton.waitForExistence(timeout: 3) {
            saveSetButton.tap()
        }

        // Hold to show the result
        sleep(3)
    }

    // MARK: - Add Exercise Demo

    /// Demonstrates searching and adding multiple exercises.
    /// Workflow: add-exercise.yaml
    func testAddExerciseDemo() {
        // Start a workout first
        let startButton = app.buttons["startWorkoutButton"]
        if startButton.waitForExistence(timeout: 5) {
            startButton.tap()
            sleep(1)
        }

        // Add first exercise - Squat
        addExercise(named: "Squat")
        sleep(1)

        // Add second exercise - Deadlift
        addExercise(named: "Deadlift")
        sleep(1)

        // Add third exercise - Overhead Press
        addExercise(named: "Overhead Press")
        sleep(2)
    }

    // MARK: - Complete Workout Demo

    /// Demonstrates completing a full workout with summary.
    /// Workflow: complete-workout.yaml
    func testCompleteWorkoutDemo() {
        // Start workout
        let startButton = app.buttons["startWorkoutButton"]
        if startButton.waitForExistence(timeout: 5) {
            startButton.tap()
            sleep(1)
        }

        // Add an exercise and set quickly
        addExercise(named: "Bench Press")

        // Add a quick set (use inline if available)
        let addSetButton = app.buttons["addSetButton"]
        if addSetButton.waitForExistence(timeout: 2) {
            addSetButton.tap()
            sleep(1)

            // Quick input
            let weightInput = app.textFields["weightInput"]
            if weightInput.exists {
                weightInput.tap()
                weightInput.typeText("225")
            }

            let repsInput = app.textFields["repsInput"]
            if repsInput.exists {
                repsInput.tap()
                repsInput.typeText("5")
            }

            let saveButton = app.buttons["saveSetButton"]
            if saveButton.exists {
                saveButton.tap()
            }
        }

        sleep(1)

        // End workout
        let endButton = app.buttons["endWorkoutButton"]
        if endButton.waitForExistence(timeout: 3) {
            endButton.tap()
            sleep(2)
        }

        // Show summary screen
        sleep(3)
    }

    // MARK: - Template Demo

    /// Demonstrates creating and using a workout template.
    /// Workflow: template.yaml
    func testTemplateDemo() {
        // This would show template creation/usage flow
        // Implementation depends on template UI structure
        sleep(5)
    }

    // MARK: - Helper Methods

    private func addExercise(named name: String) {
        let addExerciseButton = app.buttons["addExerciseButton"]
        if addExerciseButton.waitForExistence(timeout: 3) {
            addExerciseButton.tap()
            sleep(1)
        }

        let searchField = app.textFields["exerciseSearchField"]
        if searchField.waitForExistence(timeout: 3) {
            searchField.tap()
            searchField.typeText(name)
            sleep(1)
        }

        // Try to find the exercise result
        let resultCell = app.cells["exerciseResult_\(name)"]
        if resultCell.waitForExistence(timeout: 3) {
            resultCell.tap()
        } else {
            // Fallback: tap first result
            let firstResult = app.cells.element(boundBy: 0)
            if firstResult.waitForExistence(timeout: 2) {
                firstResult.tap()
            }
        }
        sleep(1)
    }
}
