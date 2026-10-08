import AVFoundation
import Photos

enum PermissionManager {
    static func capturePermissions() async -> String? {
        _ = await request(.video)
        if AVCaptureDevice.authorizationStatus(for: .video) == .authorized { _ = await request(.audio) }
        // Re-read after the permission sheets, instead of retaining a stale result.
        return currentCaptureExplanation()
    }
    static func currentCaptureExplanation() -> String? {
        explanation(camera: AVCaptureDevice.authorizationStatus(for: .video),
                    microphone: AVCaptureDevice.authorizationStatus(for: .audio))
    }
    static func explanation(camera: AVAuthorizationStatus, microphone: AVAuthorizationStatus) -> String? {
        if camera != .authorized {
            return "Camera access is not allowed yet. Open Settings → Teleprompter and allow Camera to see the preview and record."
        }
        if microphone != .authorized {
            return "Microphone access is not allowed yet. Open Settings → Teleprompter and allow Microphone to record your voice."
        }
        return nil
    }
    private static func request(_ type: AVMediaType) async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: type) {
        case .authorized: return true
        case .notDetermined: return await AVCaptureDevice.requestAccess(for: type)
        default: return false
        }
    }
    static func requestPhotos() async -> Bool {
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        return status == .authorized || status == .limited
    }
}
