//
//  PoseDetector.swift
//  TheLogger
//
//  Handles pose detection using Apple's Vision framework
//

import Vision
import CoreImage
import UIKit

/// Delegate protocol for receiving pose detection results
protocol PoseDetectorDelegate: AnyObject {
    func poseDetector(_ detector: PoseDetector, didDetectPose pose: DetectedPose)
    func poseDetector(_ detector: PoseDetector, didCalculateAngle angle: Double)
    func poseDetectorDidLoseTracking(_ detector: PoseDetector)
}

/// Represents a detected human pose with normalized coordinates
struct DetectedPose {
    let joints: [VNHumanBodyPoseObservation.JointName: CGPoint]
    let confidence: Float

    /// Get a specific joint location if available
    func joint(_ name: VNHumanBodyPoseObservation.JointName) -> CGPoint? {
        joints[name]
    }
}

/// Handles pose detection using Vision framework
final class PoseDetector {

    // MARK: - Properties

    weak var delegate: PoseDetectorDelegate?

    /// The exercise type being tracked
    var exerciseType: ExerciseType {
        didSet {
            configuration = exerciseType.jointConfiguration
        }
    }

    /// Current joint configuration
    private var configuration: JointConfiguration

    /// Vision request for body pose detection
    private lazy var poseRequest: VNDetectHumanBodyPoseRequest = {
        let request = VNDetectHumanBodyPoseRequest()
        return request
    }()

    /// Tracks consecutive frames without detection
    private var framesWithoutDetection = 0
    private let maxFramesWithoutDetection = 15

    // MARK: - Initialization

    init(exerciseType: ExerciseType) {
        self.exerciseType = exerciseType
        self.configuration = exerciseType.jointConfiguration
    }

    // MARK: - Public Methods

    /// Process a camera frame for pose detection
    /// - Parameter sampleBuffer: The camera frame to process
    func processFrame(_ sampleBuffer: CMSampleBuffer) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up, options: [:])

        do {
            try handler.perform([poseRequest])
            handlePoseResults()
        } catch {
            print("[PoseDetector] Error performing pose request: \(error)")
        }
    }

    /// Process a CIImage for pose detection
    /// - Parameter image: The image to process
    func processImage(_ image: CIImage) {
        let handler = VNImageRequestHandler(ciImage: image, orientation: .up, options: [:])

        do {
            try handler.perform([poseRequest])
            handlePoseResults()
        } catch {
            print("[PoseDetector] Error performing pose request: \(error)")
        }
    }

    // MARK: - Private Methods

    private func handlePoseResults() {
        guard let results = poseRequest.results,
              let observation = results.first else {
            handleNoDetection()
            return
        }

        // Reset no-detection counter
        framesWithoutDetection = 0

        // Extract relevant joints
        let detectedPose = extractPose(from: observation)

        // Calculate angle for rep counting
        if let angle = calculateAngle(from: observation) {
            delegate?.poseDetector(self, didCalculateAngle: angle)
        }

        delegate?.poseDetector(self, didDetectPose: detectedPose)
    }

    private func handleNoDetection() {
        framesWithoutDetection += 1

        if framesWithoutDetection >= maxFramesWithoutDetection {
            delegate?.poseDetectorDidLoseTracking(self)
        }
    }

    private func extractPose(from observation: VNHumanBodyPoseObservation) -> DetectedPose {
        var joints: [VNHumanBodyPoseObservation.JointName: CGPoint] = [:]

        // Extract all available joints
        let jointNames: [VNHumanBodyPoseObservation.JointName] = [
            .nose, .neck,
            .leftShoulder, .rightShoulder,
            .leftElbow, .rightElbow,
            .leftWrist, .rightWrist,
            .leftHip, .rightHip,
            .leftKnee, .rightKnee,
            .leftAnkle, .rightAnkle,
            .root
        ]

        for jointName in jointNames {
            if let point = try? observation.recognizedPoint(jointName),
               point.confidence > JointConfiguration.minimumConfidence {
                // Vision coordinates are normalized (0-1) with origin at bottom-left
                joints[jointName] = point.location
            }
        }

        return DetectedPose(joints: joints, confidence: observation.confidence)
    }

    private func calculateAngle(from observation: VNHumanBodyPoseObservation) -> Double? {
        // Get the three joints needed for angle calculation
        guard let point1 = try? observation.recognizedPoint(configuration.joint1),
              let point2 = try? observation.recognizedPoint(configuration.joint2),
              let point3 = try? observation.recognizedPoint(configuration.joint3),
              point1.confidence > JointConfiguration.minimumConfidence,
              point2.confidence > JointConfiguration.minimumConfidence,
              point3.confidence > JointConfiguration.minimumConfidence else {
            return nil
        }

        // Calculate angle at joint2 (the vertex)
        let angle = angleBetweenPoints(
            p1: point1.location,
            vertex: point2.location,
            p2: point3.location
        )

        return angle
    }

    /// Calculate the angle at the vertex point between two lines
    /// - Parameters:
    ///   - p1: First point
    ///   - vertex: The vertex point (where angle is measured)
    ///   - p2: Second point
    /// - Returns: Angle in degrees
    private func angleBetweenPoints(p1: CGPoint, vertex: CGPoint, p2: CGPoint) -> Double {
        // Vector from vertex to p1
        let v1 = CGVector(dx: p1.x - vertex.x, dy: p1.y - vertex.y)

        // Vector from vertex to p2
        let v2 = CGVector(dx: p2.x - vertex.x, dy: p2.y - vertex.y)

        // Dot product
        let dot = v1.dx * v2.dx + v1.dy * v2.dy

        // Magnitudes
        let mag1 = sqrt(v1.dx * v1.dx + v1.dy * v1.dy)
        let mag2 = sqrt(v2.dx * v2.dx + v2.dy * v2.dy)

        // Avoid division by zero
        guard mag1 > 0 && mag2 > 0 else { return 180 }

        // Calculate angle
        let cosAngle = dot / (mag1 * mag2)

        // Clamp to valid range for acos
        let clampedCos = max(-1, min(1, cosAngle))

        // Convert to degrees
        let angleRadians = acos(clampedCos)
        let angleDegrees = angleRadians * 180 / .pi

        return angleDegrees
    }
}
