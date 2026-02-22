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
        app.launchArguments = ["--uitesting"]
        app.launch()

        // Wait for app to be ready
        sleep(2)
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
        sleep(2)

        // Add Bench Press exercise
        let addExerciseButton = app.buttons["addExerciseButton"]
        if addExerciseButton.waitForExistence(timeout: 3) {
            addExerciseButton.tap()
            sleep(1)
        }

        // Search for Bench Press
        let searchField = app.textFields["exerciseSearchField"]
        if searchField.waitForExistence(timeout: 3) {
            searchField.tap()
            sleep(1)
            searchField.typeText("Bench")
            sleep(2)

            // Dismiss keyboard
            if app.toolbars.buttons["Done"].exists {
                app.toolbars.buttons["Done"].tap()
                sleep(1)
            }

            // Tap first result containing "Bench"
            let firstBenchButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Bench'")).firstMatch
            if firstBenchButton.waitForExistence(timeout: 2) {
                var attempts = 0
                while !firstBenchButton.isHittable && attempts < 3 {
                    sleep(1)
                    attempts += 1
                }
                if firstBenchButton.isHittable {
                    firstBenchButton.tap()
                    sleep(1)
                }
            }
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
            sleep(1)
            weightInput.typeText("135")
            sleep(1)
        }

        // Enter reps (tap multiple times to ensure keyboard focus)
        let repsInput = app.textFields["repsInput"]
        if repsInput.waitForExistence(timeout: 3) {
            sleep(1)
            repsInput.tap()
            sleep(2)
            repsInput.tap()
            sleep(1)
            repsInput.typeText("10")
            sleep(1)
        }

        // Save set
        let saveSetButton = app.buttons["saveSetButton"]
        if saveSetButton.waitForExistence(timeout: 3) {
            saveSetButton.tap()
            sleep(2)
        }

        // Hold to show the completed set in the list
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
    /// Workflow: template-workflow.yaml
    func testTemplateWorkflowDemo() {
        // For now, just show templates section
        // Navigate to templates if visible
        sleep(5)
    }

    // MARK: - QuickLogStrip Demo

    /// Demonstrates ultra-fast set logging with QuickLogStrip.
    /// Workflow: quicklog-strip.yaml
    func testQuicklogStripDemo() {
        // Start workout
        let startButton = app.buttons["startWorkoutButton"]
        if startButton.waitForExistence(timeout: 5) {
            startButton.tap()
            wait(1.0)  // navigation transition
        }

        // Add Bench Press — QuickLogStrip auto-opens for new exercises
        addExercise(named: "Bench Press")
        wait(0.5)

        // Set reps via tap-to-enter (auto-chains into weight input sheet).
        // Deliberate pauses around each action let the viewer read the UI.
        let repsButton = app.buttons.matching(
            NSPredicate(format: "label == 'Tap to enter custom reps'")
        ).firstMatch
        if repsButton.waitForExistence(timeout: 3) && repsButton.isHittable {
            repsButton.tap()
            wait(0.7)  // sheet open — let viewer see the empty Reps field

            let repsField = app.textFields["Reps"]
            if repsField.waitForExistence(timeout: 2) {
                wait(0.3)       // brief pause on empty field (telegraphs intent)
                repsField.typeText("8")
                wait(0.5)       // hold on "8" so viewer reads it
            }
            app.buttons["Done"].firstMatch.tap()
            wait(0.7)  // auto-chain: reps sheet closes, weight sheet opens

            let weightField = app.textFields["Weight"]
            if weightField.waitForExistence(timeout: 2) {
                wait(0.3)       // brief pause on empty Weight field
                weightField.typeText("135")
                wait(0.5)       // hold on "135" so viewer reads it
            }
            app.buttons["Done"].firstMatch.tap()
            wait(0.7)  // sheet dismissed — QuickLogStrip shows 8 | 135
        }

        // Pause so viewer sees the pre-filled strip before the first commit
        wait(1.0)
        let commitButton = app.buttons["quickLogCommitButton"]
        if commitButton.waitForExistence(timeout: 3) && commitButton.isHittable {
            commitButton.tap()
            wait(0.8)  // slight longer pause after first commit — "oh that was fast"
        }

        // QuickLogStrip now shows 8 × 135 pre-filled — rapid-fire 3 more sets
        for _ in 1...3 {
            let quickCommit = app.buttons["quickLogCommitButton"]
            if quickCommit.waitForExistence(timeout: 3) && quickCommit.isHittable {
                quickCommit.tap()
                wait(0.7)
            }
        }

        // Hold on the 4 completed sets so viewer reads the result
        wait(3.0)
    }

    // MARK: - PR Celebration Demo

    /// Demonstrates PR celebration animation.
    /// Workflow: pr-celebration.yaml
    func testPrCelebrationDemo() {
        startWorkoutAndLogSet(exercise: "Squat", weight: "315", reps: "5")

        // PR celebration should trigger (if it's first time)
        sleep(5) // Hold on celebration
    }

    // MARK: - Live Activity Demo

    /// Demonstrates Live Activity on lock screen.
    /// Workflow: live-activity.yaml
    func testLiveActivityDemo() {
        startWorkoutAndLogSet(exercise: "Deadlift", weight: "405", reps: "3")

        // Lock the device to show Live Activity
        sleep(1)
        XCUIDevice.shared.perform(NSSelectorFromString("pressLockButton"))
        sleep(3)

        // Unlock
        XCUIDevice.shared.perform(NSSelectorFromString("pressLockButton"))
        sleep(2)
    }

    // MARK: - Progress Chart Demo

    /// Demonstrates progress tracking charts.
    /// Workflow: progress-chart.yaml
    func testProgressChartDemo() {
        // This would navigate to an exercise detail view with chart
        // For now, placeholder
        sleep(5)
    }

    // MARK: - Rest Timer Demo

    /// Demonstrates rest timer functionality.
    /// Workflow: rest-timer.yaml
    func testRestTimerDemo() {
        // Re-launch with rest timer enabled (disabled by default in --uitesting mode)
        app.terminate()
        app.launchArguments = ["--uitesting", "--enable-rest-timer"]
        app.launch()
        sleep(2)

        startWorkoutAndLogSet(exercise: "Bench Press", weight: "225", reps: "5")

        // Rest timer offer should appear — tap to start it
        let restButton = app.buttons.containing(NSPredicate(format: "label CONTAINS 'Rest'")).firstMatch
        if restButton.waitForExistence(timeout: 5) && restButton.isHittable {
            restButton.tap()
            sleep(3)
        }

        // Timer counts down — hold so viewer sees it
        sleep(4)
    }

    // MARK: - Helper Methods

    /// Sub-second sleep helper (sleep() only accepts whole seconds).
    private func wait(_ seconds: TimeInterval) {
        Thread.sleep(forTimeInterval: seconds)
    }

    /// Starts a workout, adds the given exercise, and logs one set via QuickLogStrip.
    private func startWorkoutAndLogSet(exercise: String, weight: String, reps: String) {
        let startButton = app.buttons["startWorkoutButton"]
        if startButton.waitForExistence(timeout: 5) {
            startButton.tap()
            wait(1.0)  // navigation transition
        }

        // Add exercise — QuickLogStrip auto-opens for new exercises during active workout
        addExercise(named: exercise)
        wait(0.5)

        logSetViaQuickLogStrip(reps: reps, weight: weight)
    }

    /// Logs a set using the QuickLogStrip (tap-to-enter reps → auto-chain to weight → commit).
    private func logSetViaQuickLogStrip(reps: String, weight: String) {
        let repsButton = app.buttons.matching(
            NSPredicate(format: "label == 'Tap to enter custom reps'")
        ).firstMatch
        if repsButton.waitForExistence(timeout: 3) && repsButton.isHittable {
            repsButton.tap()
            wait(0.7)  // sheet open
            let repsField = app.textFields["Reps"]
            if repsField.waitForExistence(timeout: 2) {
                wait(0.3)
                repsField.typeText(reps)
                wait(0.5)  // hold on typed value
            }
            app.buttons["Done"].firstMatch.tap()
            wait(0.7)  // auto-chain opens weight sheet
            let weightField = app.textFields["Weight"]
            if weightField.waitForExistence(timeout: 2) {
                wait(0.3)
                weightField.typeText(weight)
                wait(0.5)  // hold on typed value
            }
            app.buttons["Done"].firstMatch.tap()
            wait(0.7)
        }

        let commitButton = app.buttons["quickLogCommitButton"]
        if commitButton.waitForExistence(timeout: 3) && commitButton.isHittable {
            commitButton.tap()
            wait(0.8)
        }
    }

    // MARK: - Existing Helper Methods

    private func addExercise(named name: String) {
        let addExerciseButton = app.buttons["addExerciseButton"]
        if addExerciseButton.waitForExistence(timeout: 3) {
            addExerciseButton.tap()
            wait(0.4)  // sheet open animation
        }

        let searchField = app.textFields["exerciseSearchField"]
        if searchField.waitForExistence(timeout: 3) {
            searchField.tap()
            wait(0.3)
            searchField.typeText(name)
            wait(0.3)
            // Results are visible above the keyboard — tap directly without dismissing
        }

        // The result cell accessibility type is Button in XCUITest — go straight to button
        // search to avoid wasting 3s on a cell waitForExistence that will always time out.
        let resultButton = app.buttons["exerciseResult_\(name)"]
        if resultButton.waitForExistence(timeout: 3) && resultButton.isHittable {
            resultButton.tap()
        } else {
            // Last resort: any button whose label contains the name
            let anyMatch = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", name)).firstMatch
            if anyMatch.waitForExistence(timeout: 2) && anyMatch.isHittable {
                anyMatch.tap()
            }
        }
        wait(0.5)  // sheet dismiss + exercise card appears
    }
}
