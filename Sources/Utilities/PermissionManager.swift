import AVFoundation
import Photos

enum PermissionManager {
    static func capturePermissions() async -> String? {
        guard await request(.video) else {
            return "Camera access is off. Open Settings → Teleprompter and allow Camera to see the preview and record."
        }
        guard await request(.audio) else {
            return "Microphone access is off. Open Settings → Teleprompter and allow Microphone to record your voice."
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
