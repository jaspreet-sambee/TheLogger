//
//  CameraPreviewView.swift
//  TheLogger
//
//  Camera preview with pose detection overlay for SwiftUI
//

import SwiftUI
import AVFoundation
import Vision

/// SwiftUI wrapper for camera preview with pose detection
struct CameraPreviewView: UIViewControllerRepresentable {
    @Binding var repCount: Int
    @Binding var currentAngle: Double
    @Binding var feedback: RepCounter.MovementFeedback
    @Binding var detectedPose: DetectedPose?

    let exerciseType: ExerciseType
    let repCounter: RepCounter
    @Binding var showSkeleton: Bool

    func makeUIViewController(context: Context) -> CameraViewController {
        let controller = CameraViewController()
        controller.exerciseType = exerciseType
        controller.showSkeleton = showSkeleton
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: CameraViewController, context: Context) {
        // Update exercise type if changed
        if uiViewController.exerciseType != exerciseType {
            uiViewController.exerciseType = exerciseType
        }
        // Update skeleton visibility
        if uiViewController.showSkeleton != showSkeleton {
            uiViewController.showSkeleton = showSkeleton
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, CameraViewControllerDelegate {
        var parent: CameraPreviewView

        init(_ parent: CameraPreviewView) {
            self.parent = parent
        }

        func cameraViewController(_ controller: CameraViewController, didDetectAngle angle: Double) {
            DispatchQueue.main.async {
                let didCompleteRep = self.parent.repCounter.processAngle(angle)
                self.parent.currentAngle = self.parent.repCounter.currentAngle
                self.parent.feedback = self.parent.repCounter.feedback

                if didCompleteRep {
                    self.parent.repCount = self.parent.repCounter.repCount
                }
            }
        }

        func cameraViewController(_ controller: CameraViewController, didDetectPose pose: DetectedPose) {
            DispatchQueue.main.async {
                self.parent.detectedPose = pose
            }
        }

        func cameraViewControllerDidLoseTracking(_ controller: CameraViewController) {
            DispatchQueue.main.async {
                self.parent.feedback = .noDetection
                self.parent.detectedPose = nil
            }
        }
    }
}

// MARK: - Camera View Controller Delegate

protocol CameraViewControllerDelegate: AnyObject {
    func cameraViewController(_ controller: CameraViewController, didDetectAngle angle: Double)
    func cameraViewController(_ controller: CameraViewController, didDetectPose pose: DetectedPose)
    func cameraViewControllerDidLoseTracking(_ controller: CameraViewController)
}

// MARK: - Camera View Controller

final class CameraViewController: UIViewController {

    // MARK: - Properties

    weak var delegate: CameraViewControllerDelegate?

    var exerciseType: ExerciseType = .squat {
        didSet {
            poseDetector.exerciseType = exerciseType
        }
    }

    var showSkeleton: Bool = true {
        didSet {
            poseOverlayView?.isHidden = !showSkeleton
        }
    }

    private var captureSession: AVCaptureSession?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var poseOverlayView: PoseOverlayView?

    private lazy var poseDetector: PoseDetector = {
        let detector = PoseDetector(exerciseType: exerciseType)
        detector.delegate = self
        return detector
    }()

    private let videoQueue = DispatchQueue(label: "com.thelogger.videoQueue", qos: .userInteractive)

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setupCamera()
        setupOverlay()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        startSession()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopSession()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
        poseOverlayView?.frame = view.bounds
    }

    // MARK: - Setup

    private func setupCamera() {
        let session = AVCaptureSession()
        session.sessionPreset = .high

        // Use front camera for workout tracking (user can see themselves)
        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) else {
            print("[CameraVC] No front camera available")
            return
        }

        do {
            let input = try AVCaptureDeviceInput(device: camera)
            if session.canAddInput(input) {
                session.addInput(input)
            }

            let output = AVCaptureVideoDataOutput()
            output.alwaysDiscardsLateVideoFrames = true
            output.setSampleBufferDelegate(self, queue: videoQueue)

            if session.canAddOutput(output) {
                session.addOutput(output)
            }

            // Set video orientation
            if let connection = output.connection(with: .video) {
                if connection.isVideoRotationAngleSupported(90) {
                    connection.videoRotationAngle = 90
                }
                // Mirror the front camera
                if connection.isVideoMirroringSupported {
                    connection.isVideoMirrored = true
                }
            }

            // Setup preview layer
            let preview = AVCaptureVideoPreviewLayer(session: session)
            preview.videoGravity = .resizeAspectFill
            preview.frame = view.bounds
            view.layer.addSublayer(preview)

            self.captureSession = session
            self.previewLayer = preview

        } catch {
            print("[CameraVC] Error setting up camera: \(error)")
        }
    }

    private func setupOverlay() {
        let overlay = PoseOverlayView()
        overlay.frame = view.bounds
        overlay.backgroundColor = .clear
        overlay.isUserInteractionEnabled = false
        view.addSubview(overlay)
        self.poseOverlayView = overlay
    }

    private func startSession() {
        videoQueue.async { [weak self] in
            self?.captureSession?.startRunning()
        }
    }

    private func stopSession() {
        videoQueue.async { [weak self] in
            self?.captureSession?.stopRunning()
        }
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

extension CameraViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        poseDetector.processFrame(sampleBuffer)
    }
}

// MARK: - PoseDetectorDelegate

extension CameraViewController: PoseDetectorDelegate {
    func poseDetector(_ detector: PoseDetector, didDetectPose pose: DetectedPose) {
        DispatchQueue.main.async { [weak self] in
            self?.poseOverlayView?.pose = pose
            self?.delegate?.cameraViewController(self!, didDetectPose: pose)
        }
    }

    func poseDetector(_ detector: PoseDetector, didCalculateAngle angle: Double) {
        delegate?.cameraViewController(self, didDetectAngle: angle)
    }

    func poseDetectorDidLoseTracking(_ detector: PoseDetector) {
        DispatchQueue.main.async { [weak self] in
            self?.poseOverlayView?.pose = nil
            if let self = self {
                self.delegate?.cameraViewControllerDidLoseTracking(self)
            }
        }
    }
}

// MARK: - Pose Overlay View

/// Draws the detected pose skeleton on top of the camera preview
final class PoseOverlayView: UIView {

    var pose: DetectedPose? {
        didSet {
            setNeedsDisplay()
        }
    }

    /// Joint connections to draw as lines
    private let connections: [(VNHumanBodyPoseObservation.JointName, VNHumanBodyPoseObservation.JointName)] = [
        // Torso
        (.neck, .root),
        (.neck, .leftShoulder),
        (.neck, .rightShoulder),
        (.leftShoulder, .leftElbow),
        (.leftElbow, .leftWrist),
        (.rightShoulder, .rightElbow),
        (.rightElbow, .rightWrist),
        // Legs
        (.root, .leftHip),
        (.root, .rightHip),
        (.leftHip, .leftKnee),
        (.leftKnee, .leftAnkle),
        (.rightHip, .rightKnee),
        (.rightKnee, .rightAnkle),
    ]

    override func draw(_ rect: CGRect) {
        guard let pose = pose,
              let ctx = UIGraphicsGetCurrentContext() else {
            return
        }

        ctx.setLineCap(.round)
        ctx.setLineJoin(.round)

        // Draw connections (skeleton lines)
        ctx.setStrokeColor(UIColor.systemGreen.cgColor)
        ctx.setLineWidth(4)

        for (joint1, joint2) in connections {
            guard let p1 = pose.joint(joint1),
                  let p2 = pose.joint(joint2) else {
                continue
            }

            let point1 = convertToViewCoordinates(p1)
            let point2 = convertToViewCoordinates(p2)

            ctx.move(to: point1)
            ctx.addLine(to: point2)
        }
        ctx.strokePath()

        // Draw joint points
        ctx.setFillColor(UIColor.white.cgColor)

        for (_, point) in pose.joints {
            let viewPoint = convertToViewCoordinates(point)
            let dotRect = CGRect(x: viewPoint.x - 6, y: viewPoint.y - 6, width: 12, height: 12)
            ctx.fillEllipse(in: dotRect)
        }

        // Draw green border around joints
        ctx.setStrokeColor(UIColor.systemGreen.cgColor)
        ctx.setLineWidth(2)

        for (_, point) in pose.joints {
            let viewPoint = convertToViewCoordinates(point)
            let dotRect = CGRect(x: viewPoint.x - 6, y: viewPoint.y - 6, width: 12, height: 12)
            ctx.strokeEllipse(in: dotRect)
        }
    }

    /// Convert normalized Vision coordinates to view coordinates
    private func convertToViewCoordinates(_ point: CGPoint) -> CGPoint {
        // Vision coordinates: origin at bottom-left, normalized 0-1
        // View coordinates: origin at top-left, pixel values
        return CGPoint(
            x: point.x * bounds.width,
            y: (1 - point.y) * bounds.height  // Flip Y axis
        )
    }
}
