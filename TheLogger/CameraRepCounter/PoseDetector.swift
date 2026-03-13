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
    func poseDetector(_ detector: PoseDetector, didCalculateAngle angle: Double, confidence: Double)
    func poseDetectorDidLoseTracking(_ detector: PoseDetector)
    func poseDetector(_ detector: PoseDetector, didChangeConfidenceState isLow: Bool)
}

/// Default implementations so existing conformers don't break
extension PoseDetectorDelegate {
    func poseDetector(_ detector: PoseDetector, didChangeConfidenceState isLow: Bool) {}
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
            lastReportedAngle = nil
        }
    }

    /// Current joint configuration
    private var configuration: JointConfiguration

    /// Last angle returned by calculateAngle — used for continuity filtering
    /// when one arm drops out of bilateral tracking
    private var lastReportedAngle: Double?

    /// Vision request for body pose detection
    private lazy var poseRequest: VNDetectHumanBodyPoseRequest = {
        let request = VNDetectHumanBodyPoseRequest()
        return request
    }()

    /// Tracks consecutive frames without detection
    private var framesWithoutDetection = 0
    private let maxFramesWithoutDetection = 15

    // MARK: - Confidence Tracking

    /// Whether pose confidence is currently too low for counting
    private(set) var isLowConfidence: Bool = false

    /// Running average of recent confidence values
    private(set) var averageConfidence: Double = 1.0

    /// Consecutive frames with confidence < 0.3
    private var lowConfidenceFrameCount: Int = 0
    /// Consecutive frames with confidence > 0.4 (after being low)
    private var recoveryFrameCount: Int = 0

    /// Frames of sustained low confidence before auto-pause
    private let lowConfidenceThreshold: Int = 30     // ~1 second at 30 fps
    /// Frames of recovered confidence before auto-resume
    private let recoveryThreshold: Int = 10          // ~0.33 second

    /// Seconds of sustained low confidence (for torch suggestion)
    private(set) var lowConfidenceDuration: TimeInterval = 0
    private var lowConfidenceStartTime: Date?

    // MARK: - Initialization

    init(exerciseType: ExerciseType) {
        self.exerciseType = exerciseType
        self.configuration = exerciseType.jointConfiguration
    }

    // MARK: - Public Methods

    /// Process a camera frame for pose detection
    func processFrame(_ sampleBuffer: CMSampleBuffer, orientation: CGImagePropertyOrientation = .up) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: orientation, options: [:])

        do {
            try handler.perform([poseRequest])
            handlePoseResults()
        } catch {
            debugLog("[PoseDetector] Error performing pose request: \(error)")
        }
    }

    /// Process a CIImage for pose detection
    func processImage(_ image: CIImage, orientation: CGImagePropertyOrientation = .up) {
        let handler = VNImageRequestHandler(ciImage: image, orientation: orientation, options: [:])

        do {
            try handler.perform([poseRequest])
            handlePoseResults()
        } catch {
            debugLog("[PoseDetector] Error performing pose request: \(error)")
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

        // Update confidence tracking
        let confidence = Double(observation.confidence)
        updateConfidenceTracking(confidence)

        // Extract pose
        let detectedPose = extractPose(from: observation)
        delegate?.poseDetector(self, didDetectPose: detectedPose)

        // Skip angle calculation if confidence is too low (auto-paused)
        guard !isLowConfidence else { return }

        // Calculate angle for rep counting
        if let angle = calculateAngle(from: observation) {
            delegate?.poseDetector(self, didCalculateAngle: angle, confidence: confidence)
        }
    }

    private func updateConfidenceTracking(_ confidence: Double) {
        // EMA of confidence
        averageConfidence = 0.2 * confidence + 0.8 * averageConfidence

        if confidence < 0.3 {
            lowConfidenceFrameCount += 1
            recoveryFrameCount = 0

            // Track duration for torch suggestion
            if lowConfidenceStartTime == nil {
                lowConfidenceStartTime = Date()
            }
            if let start = lowConfidenceStartTime {
                lowConfidenceDuration = Date().timeIntervalSince(start)
            }

            if lowConfidenceFrameCount >= lowConfidenceThreshold && !isLowConfidence {
                isLowConfidence = true
                delegate?.poseDetector(self, didChangeConfidenceState: true)
            }
        } else if confidence > 0.4 && isLowConfidence {
            recoveryFrameCount += 1
            if recoveryFrameCount >= recoveryThreshold {
                isLowConfidence = false
                lowConfidenceFrameCount = 0
                lowConfidenceStartTime = nil
                lowConfidenceDuration = 0
                delegate?.poseDetector(self, didChangeConfidenceState: false)
            }
        } else {
            // Confidence is adequate
            lowConfidenceFrameCount = 0
            recoveryFrameCount = 0
            lowConfidenceStartTime = nil
            lowConfidenceDuration = 0
        }
    }

    private func handleNoDetection() {
        framesWithoutDetection += 1

        if framesWithoutDetection >= maxFramesWithoutDetection {
            delegate?.poseDetectorDidLoseTracking(self)
        }
    }

    private func extractPose(from observation: VNHumanBodyPoseObservation) -> DetectedPose {
        var joints: [VNHumanBodyPoseObservation.JointName: CGPoint] = [:]

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
                joints[jointName] = point.location
            }
        }

        return DetectedPose(joints: joints, confidence: observation.confidence)
    }

    private func calculateAngle(from observation: VNHumanBodyPoseObservation) -> Double? {
        let useVerticalProgress = (configuration.measurement == .verticalProgress)

        let primary: Double?
        let mirrored: Double?

        if useVerticalProgress {
            // Vertical progress: track wrist Y relative to hip–shoulder range
            primary = verticalProgress(
                bottom: configuration.joint1,
                top: configuration.joint2,
                tracked: configuration.joint3,
                from: observation)

            if let m1 = Self.mirrorJointName(configuration.joint1),
               let m2 = Self.mirrorJointName(configuration.joint2),
               let m3 = Self.mirrorJointName(configuration.joint3) {
                mirrored = verticalProgress(bottom: m1, top: m2, tracked: m3, from: observation)
            } else {
                mirrored = nil
            }
        } else {
            // Standard geometric 3-joint angle
            primary = tryAngle(j1: configuration.joint1,
                               j2: configuration.joint2,
                               j3: configuration.joint3,
                               from: observation)

            if let m1 = Self.mirrorJointName(configuration.joint1),
               let m2 = Self.mirrorJointName(configuration.joint2),
               let m3 = Self.mirrorJointName(configuration.joint3) {
                mirrored = tryAngle(j1: m1, j2: m2, j3: m3, from: observation)
            } else {
                mirrored = nil
            }
        }

        switch (primary, mirrored) {
        case let (p?, m?):
            // Ascending exercises: higher angle = more active (e.g., lateral raise)
            // Descending exercises: lower angle = more active (e.g., bicep curl)
            let result = configuration.startsAtBottom ? max(p, m) : min(p, m)
            lastReportedAngle = result
            return result
        case let (p?, nil):
            // One arm dropped out — only use if close to recent trajectory.
            // Prevents the resting arm from pulling EMA back during single-arm exercises.
            if let last = lastReportedAngle, abs(p - last) > 30 {
                return nil
            }
            lastReportedAngle = p
            return p
        case let (nil, m?):
            if let last = lastReportedAngle, abs(m - last) > 30 {
                return nil
            }
            lastReportedAngle = m
            return m
        case (nil, nil): return nil
        }
    }

    /// Compute a pseudo-angle from the tracked joint's vertical position relative to
    /// a bottom–top reference range. Returns 0°–180° where 0 = at bottom, 180 = at top.
    /// Vision coords: (0,0) = bottom-left, Y increases upward.
    private func verticalProgress(
        bottom: VNHumanBodyPoseObservation.JointName,
        top: VNHumanBodyPoseObservation.JointName,
        tracked: VNHumanBodyPoseObservation.JointName,
        from observation: VNHumanBodyPoseObservation
    ) -> Double? {
        guard let bPt = try? observation.recognizedPoint(bottom),
              let tPt = try? observation.recognizedPoint(top),
              let trPt = try? observation.recognizedPoint(tracked),
              bPt.confidence > JointConfiguration.minimumConfidence,
              tPt.confidence > JointConfiguration.minimumConfidence,
              trPt.confidence > JointConfiguration.minimumConfidence else {
            return nil
        }

        let range = tPt.location.y - bPt.location.y
        guard abs(range) > 0.01 else { return nil }

        let progress = (trPt.location.y - bPt.location.y) / range
        let pseudoAngle = min(1, max(0, progress)) * 180.0

        return pseudoAngle
    }

    /// Attempt to compute the angle for a given joint triple
    private func tryAngle(
        j1: VNHumanBodyPoseObservation.JointName,
        j2: VNHumanBodyPoseObservation.JointName,
        j3: VNHumanBodyPoseObservation.JointName,
        from observation: VNHumanBodyPoseObservation
    ) -> Double? {
        guard let point1 = try? observation.recognizedPoint(j1),
              let point2 = try? observation.recognizedPoint(j2),
              let point3 = try? observation.recognizedPoint(j3),
              point1.confidence > JointConfiguration.minimumConfidence,
              point2.confidence > JointConfiguration.minimumConfidence,
              point3.confidence > JointConfiguration.minimumConfidence else {
            return nil
        }

        return angleBetweenPoints(
            p1: point1.location,
            vertex: point2.location,
            p2: point3.location
        )
    }

    /// Returns the mirror-side joint for bilateral tracking
    private static func mirrorJointName(
        _ joint: VNHumanBodyPoseObservation.JointName
    ) -> VNHumanBodyPoseObservation.JointName? {
        switch joint {
        case .rightShoulder: return .leftShoulder
        case .rightElbow:    return .leftElbow
        case .rightWrist:    return .leftWrist
        case .rightHip:      return .leftHip
        case .rightKnee:     return .leftKnee
        case .rightAnkle:    return .leftAnkle
        case .leftShoulder:  return .rightShoulder
        case .leftElbow:     return .rightElbow
        case .leftWrist:     return .rightWrist
        case .leftHip:       return .rightHip
        case .leftKnee:      return .rightKnee
        case .leftAnkle:     return .rightAnkle
        default:             return nil
        }
    }

    /// Calculate the angle at the vertex point between two lines
    private func angleBetweenPoints(p1: CGPoint, vertex: CGPoint, p2: CGPoint) -> Double {
        let v1 = CGVector(dx: p1.x - vertex.x, dy: p1.y - vertex.y)
        let v2 = CGVector(dx: p2.x - vertex.x, dy: p2.y - vertex.y)

        let dot = v1.dx * v2.dx + v1.dy * v2.dy
        let mag1 = sqrt(v1.dx * v1.dx + v1.dy * v1.dy)
        let mag2 = sqrt(v2.dx * v2.dx + v2.dy * v2.dy)

        guard mag1 > 0 && mag2 > 0 else { return 180 }

        let cosAngle = dot / (mag1 * mag2)
        let clampedCos = max(-1, min(1, cosAngle))
        let angleRadians = acos(clampedCos)
        let degrees = angleRadians * 180 / .pi
        // Clamp to 170° — near 180° (collinear joints), acos() amplifies tiny
        // position jitter into large angle swings. No exercise threshold exceeds
        // 160°, so values above 170° are pure noise.
        return min(degrees, 170.0)
    }
}
