//
//  WorkoutCardRendererTests.swift
//  TheLoggerTests
//
//  Tests for WorkoutCardRenderer share card generation.
//  Validates image dimensions, non-nil output, config defaults, and crash-free edge cases.
//

import XCTest
import UIKit
@testable import TheLogger

final class WorkoutCardRendererTests: XCTestCase {

    // MARK: - Helper

    private func makeTestImage(size: CGSize = CGSize(width: 400, height: 600)) -> UIImage {
        UIGraphicsImageRenderer(size: size).image { ctx in
            UIColor.darkGray.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
        }
    }

    private func makeConfig(
        exerciseName: String = "Bench Press",
        reps: Int = 10,
        weight: Double = 135,
        isPR: Bool = false
    ) -> ShareCardConfig {
        ShareCardConfig(
            photo: makeTestImage(),
            exerciseName: exerciseName,
            reps: reps,
            weight: weight,
            weightUnit: "lbs",
            estimated1RM: weight * (1 + Double(max(reps, 1)) / 30.0),
            isPR: isPR
        )
    }

    // MARK: - Basic rendering

    func testRender_returnsNonNilImage() {
        let result = WorkoutCardRenderer.render(config: makeConfig())
        XCTAssertNotNil(result)
    }

    func testRender_imageDimensions_1080x1920() {
        let result = WorkoutCardRenderer.render(config: makeConfig())
        XCTAssertEqual(result?.size.width, 1080)
        XCTAssertEqual(result?.size.height, 1920)
    }

    func testRender_hasCGImageData() {
        let result = WorkoutCardRenderer.render(config: makeConfig())
        XCTAssertNotNil(result?.cgImage)
    }

    // MARK: - PR flag

    func testRender_withPRFlag_doesNotCrash() {
        let result = WorkoutCardRenderer.render(config: makeConfig(isPR: true))
        XCTAssertNotNil(result)
    }

    func testRender_withoutPRFlag_doesNotCrash() {
        let result = WorkoutCardRenderer.render(config: makeConfig(isPR: false))
        XCTAssertNotNil(result)
    }

    // MARK: - Stat toggles

    func testRender_showExerciseName_false_doesNotCrash() {
        var config = makeConfig()
        config.showExerciseName = false
        XCTAssertNotNil(WorkoutCardRenderer.render(config: config))
    }

    func testRender_showWeightReps_false_doesNotCrash() {
        var config = makeConfig()
        config.showWeightReps = false
        XCTAssertNotNil(WorkoutCardRenderer.render(config: config))
    }

    func testRender_show1RM_true_doesNotCrash() {
        var config = makeConfig()
        config.show1RM = true
        XCTAssertNotNil(WorkoutCardRenderer.render(config: config))
    }

    func testRender_showDate_true_doesNotCrash() {
        var config = makeConfig()
        config.showDate = true
        XCTAssertNotNil(WorkoutCardRenderer.render(config: config))
    }

    func testRender_allStatsEnabled_doesNotCrash() {
        var config = makeConfig(isPR: true)
        config.show1RM = true
        config.showDate = true
        XCTAssertNotNil(WorkoutCardRenderer.render(config: config))
    }

    func testRender_allStatsDisabled_doesNotCrash() {
        var config = makeConfig()
        config.showExerciseName = false
        config.showWeightReps = false
        XCTAssertNotNil(WorkoutCardRenderer.render(config: config))
    }

    // MARK: - Edge cases: content

    func testRender_emptyExerciseName_doesNotCrash() {
        let result = WorkoutCardRenderer.render(config: makeConfig(exerciseName: ""))
        XCTAssertNotNil(result)
    }

    func testRender_veryLongExerciseName_doesNotCrash() {
        let longName = String(repeating: "A", count: 200)
        let result = WorkoutCardRenderer.render(config: makeConfig(exerciseName: longName))
        XCTAssertNotNil(result)
    }

    func testRender_zeroReps_doesNotCrash() {
        let result = WorkoutCardRenderer.render(config: makeConfig(reps: 0))
        XCTAssertNotNil(result)
    }

    func testRender_zeroWeight_doesNotCrash() {
        let result = WorkoutCardRenderer.render(config: makeConfig(weight: 0))
        XCTAssertNotNil(result)
    }

    func testRender_veryHighWeight_doesNotCrash() {
        let result = WorkoutCardRenderer.render(config: makeConfig(weight: 10_000))
        XCTAssertNotNil(result)
    }

    func testRender_veryHighReps_doesNotCrash() {
        let result = WorkoutCardRenderer.render(config: makeConfig(reps: 999))
        XCTAssertNotNil(result)
    }

    // MARK: - Edge cases: photo

    func testRender_photoFlipped_doesNotCrash() {
        var config = makeConfig()
        config.isPhotoFlipped = true
        XCTAssertNotNil(WorkoutCardRenderer.render(config: config))
    }

    func testRender_photoScaleAboveOne_doesNotCrash() {
        var config = makeConfig()
        config.photoScale = 2.5
        XCTAssertNotNil(WorkoutCardRenderer.render(config: config))
    }

    func testRender_photoOffset_doesNotCrash() {
        var config = makeConfig()
        config.photoOffset = CGPoint(x: 200, y: -300)
        XCTAssertNotNil(WorkoutCardRenderer.render(config: config))
    }

    func testRender_landscapePhoto_stillProduces1080x1920() {
        var config = makeConfig()
        config.photo = makeTestImage(size: CGSize(width: 1920, height: 1080))
        let result = WorkoutCardRenderer.render(config: config)
        XCTAssertEqual(result?.size.width, 1080)
        XCTAssertEqual(result?.size.height, 1920)
    }

    func testRender_squarePhoto_doesNotCrash() {
        var config = makeConfig()
        config.photo = makeTestImage(size: CGSize(width: 500, height: 500))
        XCTAssertNotNil(WorkoutCardRenderer.render(config: config))
    }

    func testRender_statsOffset_doesNotCrash() {
        var config = makeConfig()
        config.statsOffset = CGPoint(x: 100, y: -200)
        XCTAssertNotNil(WorkoutCardRenderer.render(config: config))
    }

    func testRender_extremeStatsOffset_doesNotCrash() {
        var config = makeConfig()
        config.statsOffset = CGPoint(x: 5000, y: 5000)
        XCTAssertNotNil(WorkoutCardRenderer.render(config: config))
    }

    // MARK: - Metric units

    func testRender_metricUnit_doesNotCrash() {
        var config = ShareCardConfig(
            photo: makeTestImage(),
            exerciseName: "Squat",
            reps: 5,
            weight: 100,
            weightUnit: "kg",
            estimated1RM: 116.7,
            isPR: false
        )
        XCTAssertNotNil(WorkoutCardRenderer.render(config: config))
    }

    // MARK: - ShareCardConfig defaults

    func testShareCardConfig_defaultShowExerciseName_isTrue() {
        XCTAssertTrue(makeConfig().showExerciseName)
    }

    func testShareCardConfig_defaultShowWeightReps_isTrue() {
        XCTAssertTrue(makeConfig().showWeightReps)
    }

    func testShareCardConfig_defaultShow1RM_isFalse() {
        XCTAssertFalse(makeConfig().show1RM)
    }

    func testShareCardConfig_defaultShowDate_isFalse() {
        XCTAssertFalse(makeConfig().showDate)
    }

    func testShareCardConfig_defaultPhotoScale_isOne() {
        XCTAssertEqual(makeConfig().photoScale, 1.0)
    }

    func testShareCardConfig_defaultIsPhotoFlipped_isFalse() {
        XCTAssertFalse(makeConfig().isPhotoFlipped)
    }

    func testShareCardConfig_defaultStatsOffset_isZero() {
        XCTAssertEqual(makeConfig().statsOffset, .zero)
    }

    func testShareCardConfig_defaultPhotoOffset_isZero() {
        XCTAssertEqual(makeConfig().photoOffset, .zero)
    }
}
