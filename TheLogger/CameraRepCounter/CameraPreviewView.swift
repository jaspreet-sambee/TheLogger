//
//  CameraPreviewView.swift
//  TheLogger
//
//  Camera preview with pose detection overlay for SwiftUI
//

import SwiftUI
import AVFoundation
import CoreMotion
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
    @Binding var isTooFlat: Bool
    @Binding var isLowConfidence: Bool
    @Binding var poseConfidence: Double
    @Binding var peakContractionFrame: UIImage?

    func makeUIViewController(context: Context) -> CameraViewController {
        let controller = CameraViewController()
        controller.exerciseType = exerciseType
        controller.showSkeleton = showSkeleton
        controller.delegate = context.coordinator

        // Wire peak contraction capture — fires on main thread each time a new extreme is reached
        repCounter.onPeakContraction = { [weak controller] in
            controller?.captureCurrentFrameAsPeakContraction()
        }

        return controller
    }

    func updateUIViewController(_ uiViewController: CameraViewController, context: Context) {
        if uiViewController.exerciseType != exerciseType {
            uiViewController.exerciseType = exerciseType
        }
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

        func cameraViewController(_ controller: CameraViewController, didDetectAngle angle: Double, confidence: Double) {
            DispatchQueue.main.async {
                let didCompleteRep = self.parent.repCounter.processAngle(angle, confidence: confidence)
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
                self.parent.poseConfidence = Double(pose.confidence)
            }
        }

        func cameraViewControllerDidLoseTracking(_ controller: CameraViewController) {
            DispatchQueue.main.async {
                self.parent.feedback = .noDetection
                self.parent.detectedPose = nil
            }
        }

        func cameraViewController(_ controller: CameraViewController, didChangeTooFlat isTooFlat: Bool) {
            DispatchQueue.main.async {
                self.parent.isTooFlat = isTooFlat
            }
        }

        func cameraViewController(_ controller: CameraViewController, didChangeLowConfidence isLow: Bool) {
            DispatchQueue.main.async {
                self.parent.isLowConfidence = isLow
                if isLow {
                    self.parent.feedback = .lowVisibility
                }
            }
        }

        func cameraViewController(_ controller: CameraViewController, didCapturePeakFrame image: UIImage) {
            DispatchQueue.main.async {
                self.parent.peakContractionFrame = image
            }
        }
    }
}

// MARK: - Camera View Controller Delegate

protocol CameraViewControllerDelegate: AnyObject {
    func cameraViewController(_ controller: CameraViewController, didDetectAngle angle: Double, confidence: Double)
    func cameraViewController(_ controller: CameraViewController, didDetectPose pose: DetectedPose)
    func cameraViewControllerDidLoseTracking(_ controller: CameraViewController)
    func cameraViewController(_ controller: CameraViewController, didChangeTooFlat isTooFlat: Bool)
    func cameraViewController(_ controller: CameraViewController, didChangeLowConfidence isLow: Bool)
    func cameraViewController(_ controller: CameraViewController, didCapturePeakFrame image: UIImage)
}

// MARK: - Camera View Controller

final class CameraViewController: UIViewController {

    // MARK: - Properties

    weak var delegate: CameraViewControllerDelegate?

    var exerciseType: ExerciseType = .squat {
        didSet {
            poseDetector.exerciseType = exerciseType
            poseOverlayView?.exerciseType = exerciseType
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

    // MARK: - Peak Contraction Frame Capture

    /// Rolling cache of the latest pixel buffer — overwritten each frame on videoQueue
    private var latestPixelBuffer: CVPixelBuffer?
    private let pixelBufferLock = NSLock()
    private lazy var ciContext = CIContext()

    /// Called on main thread when RepCounter fires onPeakContraction.
    /// Snapshots the latest pixel buffer and notifies the delegate.
    func captureCurrentFrameAsPeakContraction() {
        pixelBufferLock.lock()
        let pb = latestPixelBuffer
        pixelBufferLock.unlock()

        guard let pb else { return }
        let ci = CIImage(cvPixelBuffer: pb)
        guard let cg = ciContext.createCGImage(ci, from: ci.extent) else { return }
        let image = UIImage(cgImage: cg)
        delegate?.cameraViewController(self, didCapturePeakFrame: image)
    }

    // MARK: - Motion / Orientation

    private let motionManager = CMMotionManager()
    private var deviceIsTooFlat = false

    // MARK: - Simulator Video Feed

    #if targetEnvironment(simulator)
    private var videoPlayer: AVPlayer?
    private var videoPlayerLayer: AVPlayerLayer?
    private var videoDisplayLink: CADisplayLink?
    private var videoOutput: AVPlayerItemVideoOutput?

    private func setupVideoFeed() {
        guard let url = Bundle.main.url(forResource: "test_camera_feed", withExtension: "mp4")
                ?? Bundle.main.url(forResource: "test_camera_feed", withExtension: "MP4") else {
            debugLog("[CameraVC] No test_camera_feed.mp4 found in bundle — simulator camera won't work")
            return
        }

        let outputSettings: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        let output = AVPlayerItemVideoOutput(pixelBufferAttributes: outputSettings)
        self.videoOutput = output

        let item = AVPlayerItem(url: url)
        item.add(output)

        let player = AVPlayer(playerItem: item)
        self.videoPlayer = player

        let playerLayer = AVPlayerLayer(player: player)
        playerLayer.videoGravity = .resizeAspectFill
        playerLayer.frame = view.bounds
        view.layer.addSublayer(playerLayer)
        self.videoPlayerLayer = playerLayer

        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main
        ) { [weak self] _ in
            self?.videoPlayer?.seek(to: .zero)
            self?.videoPlayer?.play()
        }
    }

    private func startVideoFeed() {
        videoPlayer?.play()
        let link = CADisplayLink(target: self, selector: #selector(readVideoFrame))
        link.preferredFrameRateRange = CAFrameRateRange(minimum: 24, maximum: 30)
        link.add(to: .main, forMode: .common)
        self.videoDisplayLink = link
    }

    private func stopVideoFeed() {
        videoDisplayLink?.invalidate()
        videoDisplayLink = nil
        videoPlayer?.pause()
    }

    /// Simulates squat rep angles since Vision pose detection model is missing on simulator.
    /// Oscillates between 160° (standing) and 70° (bottom) on a ~3-second cycle.
    private var simStartTime: Date?

    @objc private func readVideoFrame() {
        guard let output = videoOutput else { return }
        let time = videoPlayer?.currentTime() ?? .zero
        guard output.hasNewPixelBuffer(forItemTime: time) else { return }
        guard let pixelBuffer = output.copyPixelBuffer(forItemTime: time, itemTimeForDisplay: nil) else { return }

        // Cache pixel buffer for peak contraction snapshot
        pixelBufferLock.lock()
        latestPixelBuffer = pixelBuffer
        pixelBufferLock.unlock()

        // Simulate pose detection with synthetic angle data (Vision model unavailable on simulator)
        if simStartTime == nil { simStartTime = Date() }
        let elapsed = Date().timeIntervalSince(simStartTime!)

        // Sine wave: 3-second rep cycle. Standing=160°, bottom=70°.
        let mid = 115.0
        let amp = 45.0
        let angle = mid + amp * cos(elapsed * 2.0 * .pi / 3.0)
        let confidence = 0.85

        // Build a fake pose for the overlay (center of frame)
        let fakePose = DetectedPose(
            joints: [
                .nose: CGPoint(x: 0.5, y: 0.15),
                .neck: CGPoint(x: 0.5, y: 0.22),
                .leftShoulder: CGPoint(x: 0.42, y: 0.25),
                .rightShoulder: CGPoint(x: 0.58, y: 0.25),
                .leftHip: CGPoint(x: 0.44, y: 0.48),
                .rightHip: CGPoint(x: 0.56, y: 0.48),
                .leftKnee: CGPoint(x: 0.43, y: 0.68),
                .rightKnee: CGPoint(x: 0.57, y: 0.68),
                .leftAnkle: CGPoint(x: 0.43, y: 0.88),
                .rightAnkle: CGPoint(x: 0.57, y: 0.88),
            ],
            confidence: Float(confidence)
        )

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.poseOverlayView?.pose = fakePose
            self.delegate?.cameraViewController(self, didDetectPose: fakePose)
            self.delegate?.cameraViewController(self, didDetectAngle: angle, confidence: confidence)
        }
    }
    #endif

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        #if targetEnvironment(simulator)
        setupVideoFeed()
        #else
        setupCamera()
        #endif
        setupOverlay()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        #if targetEnvironment(simulator)
        startVideoFeed()
        #else
        startSession()
        startMotionUpdates()
        #endif
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        #if targetEnvironment(simulator)
        stopVideoFeed()
        #else
        stopSession()
        motionManager.stopDeviceMotionUpdates()
        #endif
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        #if targetEnvironment(simulator)
        videoPlayerLayer?.frame = view.bounds
        #else
        previewLayer?.frame = view.bounds
        #endif
        poseOverlayView?.frame = view.bounds
    }

    // MARK: - Setup

    private func setupCamera() {
        let session = AVCaptureSession()
        session.sessionPreset = .high

        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) else {
            debugLog("[CameraVC] No front camera available")
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

            if let connection = output.connection(with: .video) {
                if connection.isVideoRotationAngleSupported(90) {
                    connection.videoRotationAngle = 90
                }
                if connection.isVideoMirroringSupported {
                    connection.isVideoMirrored = true
                }
            }

            let preview = AVCaptureVideoPreviewLayer(session: session)
            preview.videoGravity = .resizeAspectFill
            preview.frame = view.bounds
            view.layer.addSublayer(preview)

            self.captureSession = session
            self.previewLayer = preview

        } catch {
            debugLog("[CameraVC] Error setting up camera: \(error)")
        }
    }

    private func setupOverlay() {
        let overlay = PoseOverlayView()
        overlay.frame = view.bounds
        overlay.backgroundColor = .clear
        overlay.isUserInteractionEnabled = false
        overlay.exerciseType = exerciseType
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

    private func startMotionUpdates() {
        guard motionManager.isDeviceMotionAvailable else { return }
        motionManager.deviceMotionUpdateInterval = 0.1
        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let self, let gravity = motion?.gravity else { return }
            self.updateOrientationFromGravity(gravity)
        }
    }

    private func updateOrientationFromGravity(_ gravity: CMAcceleration) {
        let tooFlat = abs(gravity.z) > 0.65

        if tooFlat != deviceIsTooFlat {
            deviceIsTooFlat = tooFlat
            delegate?.cameraViewController(self, didChangeTooFlat: tooFlat)
        }
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

extension CameraViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard !deviceIsTooFlat else { return }

        // Cache latest pixel buffer so we can snapshot at peak contraction
        if let pb = CMSampleBufferGetImageBuffer(sampleBuffer) {
            pixelBufferLock.lock()
            latestPixelBuffer = pb
            pixelBufferLock.unlock()
        }

        poseDetector.processFrame(sampleBuffer)
    }
}

// MARK: - PoseDetectorDelegate

extension CameraViewController: PoseDetectorDelegate {
    func poseDetector(_ detector: PoseDetector, didDetectPose pose: DetectedPose) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.poseOverlayView?.pose = pose
            self.poseOverlayView?.currentAngle = Double(self.poseDetector.averageConfidence > 0.3 ? pose.confidence : 0)
            self.delegate?.cameraViewController(self, didDetectPose: pose)
        }
    }

    func poseDetector(_ detector: PoseDetector, didCalculateAngle angle: Double, confidence: Double) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.poseOverlayView?.measuredAngle = angle
            self.delegate?.cameraViewController(self, didDetectAngle: angle, confidence: confidence)
        }
    }

    func poseDetectorDidLoseTracking(_ detector: PoseDetector) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.poseOverlayView?.pose = nil
            self.delegate?.cameraViewControllerDidLoseTracking(self)
        }
    }

    func poseDetector(_ detector: PoseDetector, didChangeConfidenceState isLow: Bool) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.delegate?.cameraViewController(self, didChangeLowConfidence: isLow)
        }
    }
}

// MARK: - Pose Overlay View

/// Draws the detected pose skeleton with exercise-aware joint highlighting,
/// angle arc at the tracked vertex, and threshold markers.
final class PoseOverlayView: UIView {

    var pose: DetectedPose? {
        didSet { setNeedsDisplay() }
    }

    /// Currently selected exercise type — determines which joints to highlight
    var exerciseType: ExerciseType = .squat {
        didSet { setNeedsDisplay() }
    }

    /// Current measured angle at the vertex joint (degrees)
    var measuredAngle: Double = 0 {
        didSet { setNeedsDisplay() }
    }

    /// Current angle value (used for confidence indicator, not drawing; kept for API)
    var currentAngle: Double = 0

    // MARK: - Constants

    /// Joint connections to draw as lines
    private let connections: [(VNHumanBodyPoseObservation.JointName, VNHumanBodyPoseObservation.JointName)] = [
        (.neck, .root),
        (.neck, .leftShoulder),
        (.neck, .rightShoulder),
        (.leftShoulder, .leftElbow),
        (.leftElbow, .leftWrist),
        (.rightShoulder, .rightElbow),
        (.rightElbow, .rightWrist),
        (.root, .leftHip),
        (.root, .rightHip),
        (.leftHip, .leftKnee),
        (.leftKnee, .leftAnkle),
        (.rightHip, .rightKnee),
        (.rightKnee, .rightAnkle),
    ]

    private let trackedJointRadius: CGFloat = 10
    private let otherJointRadius: CGFloat = 4
    private let trackedLineWidth: CGFloat = 6
    private let otherLineWidth: CGFloat = 2

    // Colors
    private let trackedColor = UIColor(red: 0.2, green: 0.9, blue: 0.4, alpha: 1.0)    // Bright green
    private let dimColor = UIColor(white: 0.7, alpha: 0.3)                                // Dim gray
    private let coralColor = UIColor(red: 1.0, green: 0.35, blue: 0.42, alpha: 1.0)

    // MARK: - Drawing

    override func draw(_ rect: CGRect) {
        guard let pose = pose, let ctx = UIGraphicsGetCurrentContext() else { return }

        ctx.setLineCap(.round)
        ctx.setLineJoin(.round)

        let config = exerciseType.jointConfiguration
        let trackedJoints = trackedJointSet(for: config)
        let trackedPairs = trackedConnectionPairs(for: config)

        // --- Draw connections ---
        // Non-tracked connections first (below)
        ctx.setStrokeColor(dimColor.cgColor)
        ctx.setLineWidth(otherLineWidth)

        for (j1, j2) in connections {
            if trackedPairs.contains(where: { ($0.0 == j1 && $0.1 == j2) || ($0.0 == j2 && $0.1 == j1) }) {
                continue // skip tracked connections — draw them on top
            }
            guard let p1 = pose.joint(j1), let p2 = pose.joint(j2) else { continue }
            ctx.move(to: viewPoint(p1))
            ctx.addLine(to: viewPoint(p2))
        }
        ctx.strokePath()

        // Tracked connections (on top, green, thick)
        ctx.setStrokeColor(trackedColor.cgColor)
        ctx.setLineWidth(trackedLineWidth)

        for (j1, j2) in trackedPairs {
            guard let p1 = pose.joint(j1), let p2 = pose.joint(j2) else { continue }
            ctx.move(to: viewPoint(p1))
            ctx.addLine(to: viewPoint(p2))
        }
        ctx.strokePath()

        // --- Draw joints ---
        // Non-tracked joints (small, dim)
        for (name, point) in pose.joints {
            if trackedJoints.contains(name) { continue }
            let vp = viewPoint(point)
            let r = otherJointRadius
            let dotRect = CGRect(x: vp.x - r, y: vp.y - r, width: r * 2, height: r * 2)
            ctx.setFillColor(dimColor.cgColor)
            ctx.fillEllipse(in: dotRect)
        }

        // Tracked joints (large, green, with glow)
        for name in trackedJoints {
            guard let point = pose.joint(name) else { continue }
            let vp = viewPoint(point)
            let r = trackedJointRadius

            // Glow effect
            ctx.saveGState()
            ctx.setShadow(offset: .zero, blur: 8, color: trackedColor.withAlphaComponent(0.6).cgColor)
            let dotRect = CGRect(x: vp.x - r, y: vp.y - r, width: r * 2, height: r * 2)
            ctx.setFillColor(trackedColor.cgColor)
            ctx.fillEllipse(in: dotRect)
            ctx.restoreGState()

            // White center
            let innerR = r * 0.5
            let innerRect = CGRect(x: vp.x - innerR, y: vp.y - innerR, width: innerR * 2, height: innerR * 2)
            ctx.setFillColor(UIColor.white.cgColor)
            ctx.fillEllipse(in: innerRect)
        }

        // --- Angle arc at vertex joint ---
        drawAngleArc(ctx: ctx, config: config, pose: pose)

        // --- Threshold markers ---
        drawThresholdMarkers(ctx: ctx, config: config, pose: pose)
    }

    // MARK: - Angle Arc

    private func drawAngleArc(ctx: CGContext, config: JointConfiguration, pose: DetectedPose) {
        // Need all 3 joints to draw the arc
        guard let p1 = pose.joint(config.joint1),
              let vertex = pose.joint(config.joint2),
              let p3 = pose.joint(config.joint3) else { return }

        let vp1 = viewPoint(p1)
        let vpVertex = viewPoint(vertex)
        let vp3 = viewPoint(p3)

        // Compute angles of each limb relative to the vertex
        let angle1 = atan2(vp1.y - vpVertex.y, vp1.x - vpVertex.x)
        let angle3 = atan2(vp3.y - vpVertex.y, vp3.x - vpVertex.x)

        // Determine the sweep angles (always draw the shorter arc)
        var startAngle = angle1
        var endAngle = angle3

        // Normalize so we draw the acute/obtuse arc (not the reflex arc)
        var diff = endAngle - startAngle
        if diff > .pi { diff -= 2 * .pi }
        if diff < -.pi { diff += 2 * .pi }
        let clockwise = diff < 0

        // Color based on angle zone
        let arcColor: UIColor
        let downT = config.downThreshold
        let upT = config.upThreshold
        let angle = measuredAngle

        if angle <= downT {
            arcColor = coralColor             // At bottom (down zone)
        } else if angle >= upT {
            arcColor = trackedColor           // At top (up zone)
        } else {
            arcColor = UIColor.systemYellow   // Transitioning
        }

        let arcRadius: CGFloat = 25

        ctx.saveGState()
        ctx.setStrokeColor(arcColor.withAlphaComponent(0.8).cgColor)
        ctx.setLineWidth(3)
        ctx.addArc(center: vpVertex, radius: arcRadius,
                   startAngle: startAngle, endAngle: endAngle, clockwise: clockwise)
        ctx.strokePath()
        ctx.restoreGState()
    }

    // MARK: - Threshold Markers

    private func drawThresholdMarkers(ctx: CGContext, config: JointConfiguration, pose: DetectedPose) {
        guard let p1 = pose.joint(config.joint1),
              let vertex = pose.joint(config.joint2),
              let p3 = pose.joint(config.joint3) else { return }

        let vpVertex = viewPoint(vertex)
        let vp1 = viewPoint(p1)

        // Reference angle (limb1 direction from vertex)
        let refAngle = atan2(vp1.y - vpVertex.y, vp1.x - vpVertex.x)

        let markerLength: CGFloat = 20
        let markerOffset: CGFloat = 30  // distance from vertex

        // Draw threshold marker at a specific angle value
        func drawMarker(thresholdDegrees: Double, label: String, color: UIColor) {
            let thresholdRad = thresholdDegrees * .pi / 180

            // The marker direction is refAngle + threshold (approximately)
            let markerAngle = refAngle + CGFloat(thresholdRad)

            let startX = vpVertex.x + cos(markerAngle) * markerOffset
            let startY = vpVertex.y + sin(markerAngle) * markerOffset
            let endX = vpVertex.x + cos(markerAngle) * (markerOffset + markerLength)
            let endY = vpVertex.y + sin(markerAngle) * (markerOffset + markerLength)

            ctx.saveGState()
            ctx.setStrokeColor(color.withAlphaComponent(0.5).cgColor)
            ctx.setLineWidth(1.5)
            ctx.setLineDash(phase: 0, lengths: [4, 4])
            ctx.move(to: CGPoint(x: startX, y: startY))
            ctx.addLine(to: CGPoint(x: endX, y: endY))
            ctx.strokePath()
            ctx.restoreGState()
        }

        drawMarker(thresholdDegrees: config.downThreshold, label: "bottom", color: coralColor)
        drawMarker(thresholdDegrees: config.upThreshold, label: "top", color: trackedColor)
    }

    // MARK: - Helpers

    /// Set of joints that are part of the tracked triple (primary + mirrored)
    private func trackedJointSet(for config: JointConfiguration) -> Set<VNHumanBodyPoseObservation.JointName> {
        var set: Set<VNHumanBodyPoseObservation.JointName> = [config.joint1, config.joint2, config.joint3]
        // Add mirrored joints too
        let mirror: [(VNHumanBodyPoseObservation.JointName)] = [config.joint1, config.joint2, config.joint3]
        for joint in mirror {
            if let m = mirrorJoint(joint) {
                set.insert(m)
            }
        }
        return set
    }

    /// Connection pairs for the tracked joints
    private func trackedConnectionPairs(for config: JointConfiguration) -> [(VNHumanBodyPoseObservation.JointName, VNHumanBodyPoseObservation.JointName)] {
        var pairs: [(VNHumanBodyPoseObservation.JointName, VNHumanBodyPoseObservation.JointName)] = [
            (config.joint1, config.joint2),
            (config.joint2, config.joint3)
        ]
        // Add mirrored pairs
        if let m1 = mirrorJoint(config.joint1),
           let m2 = mirrorJoint(config.joint2),
           let m3 = mirrorJoint(config.joint3) {
            pairs.append((m1, m2))
            pairs.append((m2, m3))
        }
        return pairs
    }

    private func mirrorJoint(_ joint: VNHumanBodyPoseObservation.JointName) -> VNHumanBodyPoseObservation.JointName? {
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

    /// Convert normalized Vision coordinates to view coordinates
    private func viewPoint(_ point: CGPoint) -> CGPoint {
        CGPoint(
            x: point.x * bounds.width,
            y: (1 - point.y) * bounds.height
        )
    }
}
