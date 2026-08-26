import AVFoundation
import Combine

enum CameraAuthState {
    case notDetermined
    case authorized
    case denied
}

@MainActor
final class CameraManager: NSObject, ObservableObject {
    @Published var authState: CameraAuthState = .notDetermined
    @Published var isRunning: Bool = false
    @Published var frameCount: Int = 0

    ///Latest frame handoff point for downstream processing (Vision, in Phase 3).
    ///Called on a background queue — never the main actor — since Vision work is CPU-bound.
    nonisolated(unsafe) var onFrame: ((CVPixelBuffer) -> Void)?

    //Only ever touched on `sessionQueue`, never on the main actor.
    nonisolated(unsafe) private let session = AVCaptureSession()
    nonisolated(unsafe) private let videoOutput = AVCaptureVideoDataOutput()
    private let sessionQueue = DispatchQueue(label: "com.posturefix.camera.session")

    //Vision face detection doesn't need to run at full camera fps — throttling
    //here cuts CPU/power draw and, combined with the throttling in AppState,
    //keeps @Published updates from flooding the menu bar item's scene updates.
    nonisolated(unsafe) private var lastProcessedAt: CFAbsoluteTime = 0
    private static let minProcessInterval: CFAbsoluteTime = 1.0 / 8.0

    override init() {
        super.init()
        refreshAuthState()
    }

    func refreshAuthState() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: authState = .authorized
        case .notDetermined: authState = .notDetermined
        default: authState = .denied
        }
    }

    func requestAccessIfNeeded() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                Task { @MainActor in
                    self.authState = granted ? .authorized : .denied
                }
            }
        case .authorized:
            authState = .authorized
        default:
            authState = .denied
        }
    }

    func start() {
        guard authState == .authorized else {
            requestAccessIfNeeded()
            return
        }
        sessionQueue.async { [weak self] in
            guard let self else { return }
            if self.session.inputs.isEmpty {
                self.configureSession()
            }
            if !self.session.isRunning {
                self.session.startRunning()
            }
            Task { @MainActor in self.isRunning = true }
        }
    }

    func stop() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            if self.session.isRunning {
                self.session.stopRunning()
            }
            Task { @MainActor in self.isRunning = false }
        }
    }

    nonisolated private func configureSession() {
        session.beginConfiguration()
        session.sessionPreset = .medium

        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front)
            ?? AVCaptureDevice.default(for: .video),
            let input = try? AVCaptureDeviceInput(device: device),
            session.canAddInput(input) else {
            session.commitConfiguration()
            return
        }
        session.addInput(input)

        videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.setSampleBufferDelegate(self, queue: sessionQueue)
        if session.canAddOutput(videoOutput) {
            session.addOutput(videoOutput)
        }

        session.commitConfiguration()
    }
}

extension CameraManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    nonisolated func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        let now = CFAbsoluteTimeGetCurrent()
        guard now - lastProcessedAt >= Self.minProcessInterval else { return }
        lastProcessedAt = now

        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        onFrame?(pixelBuffer)
        Task { @MainActor in
            self.frameCount += 1
        }
    }
}
