import SwiftUI

enum CameraSide: String, CaseIterable, Codable, Identifiable {
    case front, rear
    var id: String { rawValue }
    var title: String { self == .front ? "Front" : "Rear" }
    func mirrorsRecording(enabled: Bool) -> Bool { self == .front && enabled }
}

@MainActor
final class AppSettings: ObservableObject {
    @Published var script: String { didSet { defaults.set(script, forKey: "script") } }
    @Published var fontSize: Double { didSet { persist() } }
    @Published var speed: Double { didSet { persist() } }
    @Published var width: Double { didSet { persist() } }
    @Published var verticalPosition: Double { didSet { persist() } }
    @Published var textOpacity: Double { didSet { persist() } }
    @Published var backgroundOpacity: Double { didSet { persist() } }
    @Published var camera: CameraSide { didSet { persist() } }
    @Published var quality: RecordingQuality { didSet { persist() } }
    @Published var mirrorRecordedVideo: Bool { didSet { persist() } }
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        script = defaults.string(forKey: "script") ?? ""
        let stored = defaults.dictionary(forKey: "settings") ?? [:]
        func number(_ key: String, _ fallback: Double, _ range: ClosedRange<Double>) -> Double {
            guard let value = stored[key] as? Double, value.isFinite else { return fallback }
            return min(range.upperBound, max(range.lowerBound, value))
        }
        fontSize = number("fontSize", 32, 18...64)
        speed = number("speed", 35, 5...140)
        width = number("width", 0.85, 0.35...1)
        verticalPosition = number("position", 0, 0...1)
        textOpacity = number("textOpacity", 1, 0.4...1)
        backgroundOpacity = number("backgroundOpacity", 0.45, 0...0.85)
        camera = CameraSide(rawValue: stored["camera"] as? String ?? "") ?? .front
        mirrorRecordedVideo = stored["mirrorRecordedVideo"] as? Bool ?? true
        quality = RecordingQuality(rawValue: stored["quality"] as? String ?? "") ?? .preferred4K60
    }
    private func persist() {
        defaults.set(["fontSize": fontSize, "speed": speed, "width": width,
                      "position": verticalPosition, "textOpacity": textOpacity,
                      "backgroundOpacity": backgroundOpacity, "camera": camera.rawValue,
                      "quality": quality.rawValue, "mirrorRecordedVideo": mirrorRecordedVideo] as [String: Any], forKey: "settings")
    }
}
