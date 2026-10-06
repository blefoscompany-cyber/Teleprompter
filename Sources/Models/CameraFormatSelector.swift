import Foundation

enum RecordingQuality: String, CaseIterable, Codable, Identifiable {
    case preferred4K60, fourK30, fullHD60, fullHD30
    var id: String { rawValue }
    var title: String {
        switch self {
        case .preferred4K60: return "4K / 60 FPS (preferred)"
        case .fourK30: return "4K / 30 FPS"
        case .fullHD60: return "1080p / 60 FPS"
        case .fullHD30: return "1080p / 30 FPS"
        }
    }
    var target: (width: Int, height: Int, fps: Int) {
        switch self {
        case .preferred4K60: return (3840, 2160, 60)
        case .fourK30: return (3840, 2160, 30)
        case .fullHD60: return (1920, 1080, 60)
        case .fullHD30: return (1920, 1080, 30)
        }
    }
}

// Independent of AVFoundation so fallback policy can be tested without a camera.
struct CameraFormatDescriptor {
    let index: Int
    let width: Int
    let height: Int
    let frameRateRanges: [ClosedRange<Double>]
    let preferredPixelFormat: Bool
    func supports(_ fps: Int) -> Bool {
        frameRateRanges.contains { $0.contains(Double(fps)) }
    }
}

struct CameraFormatChoice: Equatable {
    let index: Int
    let width: Int
    let height: Int
    let fps: Int
    let isFallback: Bool
    var label: String { "\(width) × \(height) · \(fps) FPS" }
}

enum CameraFormatSelector {
    static func select(from formats: [CameraFormatDescriptor], quality: RecordingQuality) -> CameraFormatChoice? {
        let target = quality.target
        // Favor resolution before frame rate for the default 4K request.
        let preferences = [(target.width, target.height, target.fps),
                           (3840, 2160, 30), (1920, 1080, 60), (1920, 1080, 30),
                           (1280, 720, 30)]
        for (width, height, fps) in preferences {
            // A lower-quality request must never silently select a higher resolution/FPS.
            guard width <= target.width, height <= target.height, fps <= target.fps else { continue }
            let candidates = formats.filter { $0.width == width && $0.height == height && $0.supports(fps) }
            if let format = candidates.sorted(by: prefer).first {
                return choice(format, fps: fps, target: target)
            }
        }
        // Last resort: arbitrary supported dimensions/rates, still bounded by the request.
        let candidates: [(CameraFormatDescriptor, Int)] = formats.compactMap { format in
            guard format.width > 0, format.height > 0,
                  format.width <= target.width, format.height <= target.height else { return nil }
            let maxFPS = format.frameRateRanges.map { min($0.upperBound, Double(target.fps)) }
                .filter { $0 >= 1 }.max() ?? 0
            let fps = Int(maxFPS.rounded(.down))
            return fps > 0 && format.supports(fps) ? (format, fps) : nil
        }
        let best = candidates.sorted { lhs, rhs in
            let leftArea = lhs.0.width * lhs.0.height
            let rightArea = rhs.0.width * rhs.0.height
            if leftArea != rightArea { return leftArea > rightArea }
            if lhs.1 != rhs.1 { return lhs.1 > rhs.1 }
            return prefer(lhs.0, rhs.0)
        }.first
        return best.map { choice($0.0, fps: $0.1, target: target) }
    }
    private static func prefer(_ lhs: CameraFormatDescriptor, _ rhs: CameraFormatDescriptor) -> Bool {
        if lhs.preferredPixelFormat != rhs.preferredPixelFormat { return lhs.preferredPixelFormat }
        return lhs.index < rhs.index
    }
    private static func choice(_ format: CameraFormatDescriptor, fps: Int,
                               target: (width: Int, height: Int, fps: Int)) -> CameraFormatChoice {
        CameraFormatChoice(index: format.index, width: format.width, height: format.height, fps: fps,
                           isFallback: format.width != target.width || format.height != target.height || fps != target.fps)
    }
}
