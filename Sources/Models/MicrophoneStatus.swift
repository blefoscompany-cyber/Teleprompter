import AVFoundation

enum MicrophoneStatus: Equatable {
    case permissionNeeded, denied, starting, interrupted, ready
    static func resolve(authorization: AVAuthorizationStatus, hasInput: Bool,
                        sessionRunning: Bool, interrupted: Bool) -> MicrophoneStatus {
        switch authorization {
        case .denied, .restricted: return .denied
        case .notDetermined: return .permissionNeeded
        case .authorized:
            if interrupted { return .interrupted }
            return hasInput && sessionRunning ? .ready : .starting
        @unknown default: return .permissionNeeded
        }
    }
    var text: String {
        switch self {
        case .permissionNeeded: return "Microphone permission needed"
        case .denied: return "Microphone permission off"
        case .starting: return "Microphone allowed · waiting for audio"
        case .interrupted: return "Audio interrupted · permission allowed"
        case .ready: return "Microphone ready"
        }
    }
}
