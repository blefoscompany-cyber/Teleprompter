import AVFoundation
import Combine
import UIKit
import OSLog

enum RecordingPhase: Equatable {
    case idle, preparing, recording, finishing
    var isBusy: Bool { self != .idle }
}

// Every capture mutation and delegate event is serialized on sessionQueue.
// Published properties are only changed through publish(), on the main queue.
final class CameraManager: NSObject, ObservableObject, AVCaptureFileOutputRecordingDelegate {
    let session = AVCaptureSession()
    @Published private(set) var isReady = false
    @Published private(set) var isConfiguring = false
    @Published private(set) var phase: RecordingPhase = .idle
    @Published private(set) var formatLabel = "Camera not started"
    @Published private(set) var selectedSide: CameraSide = .front
    @Published private(set) var startedAt: Date?
    @Published private(set) var lockedOrientation: UIInterfaceOrientation?
    @Published private(set) var warning: String?
    @Published private(set) var microphoneStatus: MicrophoneStatus = .permissionNeeded
    @Published var message: String?
    var onRecordingFinished: ((URL) -> Void)?

    private let sessionQueue = DispatchQueue(label: "local.teleprompter.capture", qos: .userInitiated)
    private let output = AVCaptureMovieFileOutput()
    private var videoInput: AVCaptureDeviceInput?
    private var audioInput: AVCaptureDeviceInput?
    private var configured = false
    private var wantsRunning = false
    private var queuePhase: RecordingPhase = .idle
    private var side: CameraSide = .front
    private var quality: RecordingQuality = .preferred4K60
    private var observers: [NSObjectProtocol] = []
    private var monitor: DispatchSourceTimer?
    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid
    private var currentURL: URL?
    private var formatWarning: String?
    private var interruptionWarning: String?
    private var safetyWarning: String?
    private var audioActive = false
    private let log = Logger(subsystem: "local.teleprompter.camera", category: "capture")

    override init() {
        super.init()
        let center = NotificationCenter.default
        observers.append(center.addObserver(forName: .AVCaptureSessionRuntimeError, object: session, queue: nil) { [weak self] note in
            let error = note.userInfo?[AVCaptureSessionErrorKey] as? AVError
            self?.sessionQueue.async { self?.handleRuntimeError(error) }
        })
        observers.append(center.addObserver(forName: .AVCaptureSessionWasInterrupted, object: session, queue: nil) { [weak self] _ in
            self?.sessionQueue.async {
                guard let self else { return }
                self.publish {
                    $0.isReady = false
                }
                self.interruptionWarning = "Camera interrupted by iOS. Any completed recording will be kept. Return when the camera is available."
                self.publishWarnings()
                self.publishMicrophoneStatus(interrupted: true)
                self.stopOnQueue()
            }
        })
        observers.append(center.addObserver(forName: .AVCaptureSessionInterruptionEnded, object: session, queue: nil) { [weak self] _ in
            self?.sessionQueue.async { self?.resumeOnQueue() }
        })
        observers.append(center.addObserver(forName: AVAudioSession.interruptionNotification, object: nil, queue: nil) { [weak self] note in
            let raw = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
            self?.sessionQueue.async {
                guard let self else { return }
                if raw == AVAudioSession.InterruptionType.began.rawValue {
                    self.audioActive = false
                    self.interruptionWarning = "Audio interrupted by iOS. Recording is stopping so the file can be saved. Wait for audio to reconnect before another take."
                    self.publishWarnings()
                    self.publishMicrophoneStatus(interrupted: true)
                    self.stopOnQueue()
                } else {
                    self.resumeOnQueue()
                }
            }
        })
        observers.append(center.addObserver(forName: ProcessInfo.thermalStateDidChangeNotification, object: nil, queue: nil) { [weak self] _ in
            self?.sessionQueue.async { self?.checkSafety() }
        })
    }

    deinit {
        observers.forEach { NotificationCenter.default.removeObserver($0) }
        monitor?.cancel()
    }

    func activate(side: CameraSide, quality: RecordingQuality) {
        sessionQueue.async {
            self.wantsRunning = true
            guard self.queuePhase == .idle else { return }
            do {
                try self.configure(side: side, quality: quality)
                self.resumeOnQueue()
            } catch {
                self.report(error, explanation: "Camera setup failed. Try another camera or choose 1080p / 30 FPS in Settings, then tap Retry camera.")
            }
        }
    }

    func deactivate() {
        sessionQueue.async {
            self.wantsRunning = false
            self.publish { $0.isReady = false }
            if self.queuePhase.isBusy {
                self.stopOnQueue()
                // Keep the session alive until didFinishRecording finalizes the file.
            } else {
                self.suspendOnQueue()
            }
        }
    }

    private func configure(side requestedSide: CameraSide, quality requestedQuality: RecordingQuality, force: Bool = false) throws {
        guard force || !configured || side != requestedSide || quality != requestedQuality else { return }
        publish { $0.isConfiguring = true; $0.isReady = false }
        publishMicrophoneStatus()
        defer { publish { $0.isConfiguring = false } }
        guard AVCaptureDevice.authorizationStatus(for: .video) == .authorized,
              AVCaptureDevice.authorizationStatus(for: .audio) == .authorized else {
            throw CaptureFailure(PermissionManager.currentCaptureExplanation() ?? "Capture permissions changed. Tap Retry camera.")
        }
        let position: AVCaptureDevice.Position = requestedSide == .front ? .front : .back
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position) else {
            throw CaptureFailure("This camera is unavailable on your device. Try the other camera.")
        }
        let newVideo = try AVCaptureDeviceInput(device: device)
        let newAudio: AVCaptureDeviceInput
        if let audioInput { newAudio = audioInput }
        else {
            guard let microphone = AVCaptureDevice.default(for: .audio) else {
                throw CaptureFailure("No microphone is available. Disconnect audio accessories and try again.")
            }
            newAudio = try AVCaptureDeviceInput(device: microphone)
        }
        let formats = device.formats.enumerated().map { index, format in
            let dimensions = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
            let subtype = CMFormatDescriptionGetMediaSubType(format.formatDescription)
            return CameraFormatDescriptor(index: index, width: Int(dimensions.width), height: Int(dimensions.height),
                frameRateRanges: format.videoSupportedFrameRateRanges.map { $0.minFrameRate...$0.maxFrameRate },
                preferredPixelFormat: subtype == kCVPixelFormatType_420YpCbCr8BiPlanarFullRange)
        }
        guard let choice = CameraFormatSelector.select(from: formats, quality: requestedQuality) else {
            throw CaptureFailure("No compatible recording format was found. Try another camera or a lower quality.")
        }

        if session.isRunning { session.stopRunning() }
        configured = false
        session.beginConfiguration()
        defer { session.commitConfiguration() }
        // Prevent the session from silently replacing the manually chosen format.
        session.sessionPreset = .inputPriority
        session.automaticallyConfiguresApplicationAudioSession = false
        let oldVideo = videoInput
        if let oldVideo { session.removeInput(oldVideo) }
        guard session.canAddInput(newVideo) else {
            if let oldVideo, session.canAddInput(oldVideo) { session.addInput(oldVideo) }
            throw CaptureFailure("The selected camera cannot be connected. Try the other camera.")
        }
        session.addInput(newVideo)
        videoInput = newVideo
        if audioInput == nil {
            guard session.canAddInput(newAudio) else { throw CaptureFailure("The microphone cannot be connected. Close other camera/audio apps and retry.") }
            session.addInput(newAudio)
            audioInput = newAudio
        }
        if !session.outputs.contains(where: { $0 === output }) {
            guard session.canAddOutput(output) else { throw CaptureFailure("Video recording output could not be configured. Close and reopen the app.") }
            session.addOutput(output)
        }
        try device.lockForConfiguration()
        defer { device.unlockForConfiguration() }
        device.activeFormat = device.formats[choice.index]
        let duration = CMTime(value: 1, timescale: CMTimeScale(choice.fps))
        device.activeVideoMinFrameDuration = duration
        device.activeVideoMaxFrameDuration = duration
        device.automaticallyAdjustsVideoHDREnabled = false
        if device.activeFormat.isVideoHDRSupported { device.isVideoHDREnabled = false }
        if device.isFocusModeSupported(.continuousAutoFocus) { device.focusMode = .continuousAutoFocus }
        if device.isExposureModeSupported(.continuousAutoExposure) { device.exposureMode = .continuousAutoExposure }
        if device.isWhiteBalanceModeSupported(.continuousAutoWhiteBalance) { device.whiteBalanceMode = .continuousAutoWhiteBalance }
        if let connection = output.connection(with: .video) {
            if connection.isVideoStabilizationSupported { connection.preferredVideoStabilizationMode = .off }
            let codec: AVVideoCodecType = output.availableVideoCodecTypes.contains(.hevc) ? .hevc : .h264
            output.setOutputSettings([AVVideoCodecKey: codec], for: connection)
        }
        // No maximum duration or file size. Only storage/OS safety can end a take.
        output.maxRecordedDuration = .invalid
        output.maxRecordedFileSize = 0
        output.minFreeDiskSpaceLimit = 200 * 1024 * 1024
        side = requestedSide
        quality = requestedQuality
        configured = true
        formatWarning = choice.isFallback ? "Requested \(requestedQuality.title). This camera supports \(choice.label) in this configuration." : nil
        publishWarnings()
        publish {
            $0.selectedSide = requestedSide
            $0.formatLabel = choice.label + (choice.isFallback ? " (fallback)" : "")
        }
    }

    private func configureAudio() throws {
        audioActive = false
        let audio = AVAudioSession.sharedInstance()
        try audio.setCategory(.playAndRecord, mode: .videoRecording, options: [])
        try audio.setActive(true)
        audioActive = true
    }

    private func resumeOnQueue() {
        guard wantsRunning, configured, queuePhase == .idle, !session.isInterrupted else { return }
        publishMicrophoneStatus()
        guard AVCaptureDevice.authorizationStatus(for: .video) == .authorized,
              AVCaptureDevice.authorizationStatus(for: .audio) == .authorized else {
            let explanation = PermissionManager.currentCaptureExplanation()
            publish { $0.isReady = false; $0.message = explanation ?? "Capture permissions changed. Tap Retry camera." }
            return
        }
        do {
            try configureAudio()
            if !session.isRunning { session.startRunning() }
            let running = session.isRunning
            publish { $0.isReady = running }
            if running { interruptionWarning = nil; publishWarnings() }
            publishMicrophoneStatus()
            if !running { publish { $0.message = "The camera could not start. Close other camera apps and tap Retry camera." } }
            checkSafety()
        } catch {
            publishMicrophoneStatus()
            report(error, explanation: "Microphone permission is allowed, but iOS could not activate audio. Disconnect audio accessories, close other audio apps, and tap Retry camera.")
        }
    }

    private func suspendOnQueue() {
        if session.isRunning { session.stopRunning() }
        audioActive = false
        publishMicrophoneStatus()
        do { try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation) }
        catch { log.error("Audio deactivation failed: \(error.localizedDescription, privacy: .public)") }
    }

    // Called on the main thread with the interface orientation seen by the user.
    func record(orientation: UIInterfaceOrientation, directory: URL) {
        // Reserve an iOS background task BEFORE moving to the capture queue.
        // It only protects finalization; this is not background camera recording.
        let task = UIApplication.shared.beginBackgroundTask(withName: "Finalize recording") { [weak self] in
            self?.stop()
            self?.endBackgroundTask()
        }
        sessionQueue.async {
            guard self.queuePhase == .idle, self.wantsRunning, self.configured,
                  self.session.isRunning, !self.session.isInterrupted else {
                DispatchQueue.main.async { if task != .invalid { UIApplication.shared.endBackgroundTask(task) } }
                return
            }
            guard ProcessInfo.processInfo.thermalState != .critical else {
                self.publish { $0.message = "Your iPhone is too hot to start recording. Let it cool down and try again." }
                DispatchQueue.main.async { if task != .invalid { UIApplication.shared.endBackgroundTask(task) } }
                return
            }
            if let bytes = Self.availableStorage(at: directory), bytes < 500 * 1024 * 1024 {
                self.publish { $0.message = "Less than 500 MB is free. Make room in iPhone storage before recording, especially for 4K60." }
                DispatchQueue.main.async { if task != .invalid { UIApplication.shared.endBackgroundTask(task) } }
                return
            }
            guard let connection = self.output.connection(with: .video),
                  self.output.connection(with: .audio) != nil else {
                self.publish { $0.message = "Camera or microphone output is unavailable. Tap Retry camera before recording." }
                DispatchQueue.main.async { if task != .invalid { UIApplication.shared.endBackgroundTask(task) } }
                return
            }
            guard connection.isVideoOrientationSupported else {
                self.publish { $0.message = "The selected camera cannot orient this recording. Choose another quality or camera and retry." }
                DispatchQueue.main.async { if task != .invalid { UIApplication.shared.endBackgroundTask(task) } }
                return
            }
            connection.videoOrientation = orientation.captureOrientation
            if connection.isVideoMirroringSupported {
                connection.automaticallyAdjustsVideoMirroring = false
                connection.isVideoMirrored = false // Saved front video is natural; preview is mirrored.
            }
            let url = directory.appendingPathComponent("Take-\(UUID().uuidString).mov")
            self.currentURL = url
            self.queuePhase = .preparing
            self.publish {
                $0.backgroundTask = task
                $0.phase = .preparing
                $0.lockedOrientation = orientation
                $0.isReady = false
            }
            self.output.startRecording(to: url, recordingDelegate: self)
        }
    }

    func stop() { sessionQueue.async { self.stopOnQueue() } }

    private func stopOnQueue() {
        guard queuePhase == .recording || queuePhase == .preparing else { return }
        queuePhase = .finishing
        publish { $0.phase = .finishing }
        // startRecording becomes active asynchronously; didStart handles an early stop.
        if output.isRecording { output.stopRecording() }
    }

    func fileOutput(_ output: AVCaptureFileOutput, didStartRecordingTo fileURL: URL, from connections: [AVCaptureConnection]) {
        sessionQueue.async {
            if self.queuePhase == .finishing {
                if self.output.isRecording { self.output.stopRecording() }
                return
            }
            self.queuePhase = .recording
            self.publish { $0.phase = .recording; $0.startedAt = Date() }
            self.startSafetyMonitor()
        }
    }

    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo fileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        sessionQueue.async {
            self.monitor?.cancel()
            self.monitor = nil
            self.currentURL = nil
            self.queuePhase = .idle
            if let error {
                self.log.error("Recording ended: \(error.localizedDescription, privacy: .public)")
                let completed = (error as NSError).userInfo[AVErrorRecordingSuccessfullyFinishedKey] as? Bool ?? false
                self.publish {
                    $0.message = completed
                        ? "iOS ended this recording early. The completed video will be saved. Check storage, temperature, and interruptions before your next take."
                        : "Recording could not finish normally. The local file has been kept. Open Kept videos to retry saving or export it; an interrupted file may be incomplete."
                }
            }
            self.publish {
                $0.phase = .idle
                $0.startedAt = nil
                $0.lockedOrientation = nil
                $0.endBackgroundTask()
                $0.onRecordingFinished?(fileURL)
            }
            if self.wantsRunning { self.resumeOnQueue() }
            else { self.suspendOnQueue() }
        }
    }

    private func endBackgroundTask() {
        if backgroundTask != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTask)
            backgroundTask = .invalid
        }
    }

    private func startSafetyMonitor() {
        let timer = DispatchSource.makeTimerSource(queue: sessionQueue)
        timer.schedule(deadline: .now(), repeating: 5)
        timer.setEventHandler { [weak self] in self?.checkSafety() }
        monitor = timer
        timer.resume()
    }

    private func checkSafety() {
        switch ProcessInfo.processInfo.thermalState {
        case .serious:
            safetyWarning = "iPhone is getting hot. Recording can continue, but consider 1080p / 30 FPS for the next take."
        case .critical:
            safetyWarning = "iPhone temperature is critical. Recording is stopping so the file can be saved. Let your iPhone cool down."
            stopOnQueue()
        default: safetyWarning = nil
        }
        if let currentURL, let free = Self.availableStorage(at: currentURL.deletingLastPathComponent()), free < 1024 * 1024 * 1024 {
            if safetyWarning == nil { safetyWarning = "Less than 1 GB is free. Storage may end this take soon. Stop and save when practical." }
        }
        publishWarnings()
    }

    private func handleRuntimeError(_ error: AVError?) {
        if let error { log.error("Capture session error: \(error.localizedDescription, privacy: .public)") }
        publish { $0.isReady = false }
        if error?.code == .mediaServicesWereReset, queuePhase == .idle {
            // A media-service reset can discard the active device format.
            // Reapply the exact requested format before reporting readiness again.
            do {
                try configure(side: side, quality: quality, force: true)
                resumeOnQueue()
            } catch {
                report(error, explanation: "iOS reset the camera service. Tap Retry camera to reconnect it.")
            }
        } else {
            stopOnQueue()
            publish { $0.message = "iOS interrupted the camera. Any recording file will be kept. Close other camera apps and tap Retry camera." }
        }
    }

    static func availableStorage(at url: URL) -> Int64? {
        if let values = try? url.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey]),
           let bytes = values.volumeAvailableCapacityForImportantUsage { return bytes }
        let values = try? FileManager.default.attributesOfFileSystem(forPath: url.path)
        return (values?[.systemFreeSize] as? NSNumber)?.int64Value
    }

    private func publish(_ update: @escaping (CameraManager) -> Void) {
        DispatchQueue.main.async { update(self) }
    }
    private func publishWarnings() {
        let text = interruptionWarning ?? safetyWarning ?? formatWarning
        publish { if $0.warning != text { $0.warning = text } }
    }
    private func publishMicrophoneStatus(interrupted: Bool = false) {
        let status = MicrophoneStatus.resolve(authorization: AVCaptureDevice.authorizationStatus(for: .audio),
            hasInput: audioInput != nil, sessionRunning: session.isRunning && audioActive,
            interrupted: interrupted || session.isInterrupted)
        publish { if $0.microphoneStatus != status { $0.microphoneStatus = status } }
    }
    private func report(_ error: Error, explanation: String) {
        log.error("Camera failure: \(error.localizedDescription, privacy: .public)")
        publish { $0.isReady = false; $0.message = (error as? CaptureFailure)?.text ?? explanation }
    }
}

private struct CaptureFailure: Error { let text: String; init(_ text: String) { self.text = text } }

extension UIInterfaceOrientation {
    var captureOrientation: AVCaptureVideoOrientation {
        switch self {
        case .landscapeLeft: return .landscapeLeft
        case .landscapeRight: return .landscapeRight
        default: return .portrait
        }
    }
    var displayName: String {
        switch self {
        case .landscapeLeft: return "Landscape left · 16:9"
        case .landscapeRight: return "Landscape right · 16:9"
        default: return "Portrait"
        }
    }
}
