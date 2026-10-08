import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.dismiss) private var dismiss
    let cameraBusy: Bool
    var body: some View {
        NavigationStack {
            Form {
                Section("Teleprompter") {
                    adjustment("Text size", value: $settings.fontSize, range: 18...64, suffix: "pt")
                    adjustment("Scroll speed", value: $settings.speed, range: 5...140, suffix: "pt/s")
                    adjustment("Width", value: $settings.width, range: 0.35...1, percentage: true)
                    adjustment("Vertical position · top to bottom", value: $settings.verticalPosition, range: 0...1, percentage: true)
                    adjustment("Text opacity", value: $settings.textOpacity, range: 0.4...1, percentage: true)
                    adjustment("Background opacity", value: $settings.backgroundOpacity, range: 0...0.85, percentage: true)
                    Text("Move the text toward the lens. Swipe the script to scroll manually; this pauses automatic scrolling. Tap Play to resume.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Section("Camera · change before recording") {
                    Picker("Camera", selection: $settings.camera) {
                        ForEach(CameraSide.allCases) { Text($0.title).tag($0) }
                    }
                    Picker("Preferred quality", selection: $settings.quality) {
                        ForEach(RecordingQuality.allCases) { Text($0.title).tag($0) }
                    }
                    Toggle("Mirror Recorded Video", isOn: $settings.mirrorRecordedVideo)
                    Text("Applies only to saved front-camera video. The front preview stays mirrored; rear recordings stay non-mirrored. Changes apply to the next take.")
                        .font(.caption).foregroundStyle(.secondary)
                    Text("The main screen shows the format actually selected. 4K60 uses more storage and can heat the phone. 1080p30 is a practical fallback for long takes.")
                        .font(.caption).foregroundStyle(.secondary)
                }.disabled(cameraBusy)
                Section("Orientation") {
                    Text("Turn your iPhone before Record, or choose Landscape left/right from the rotation menu on the camera screen. Automatic rotation respects Portrait Orientation Lock; turn it off in Control Center if the screen stays upright. Manual modes request an actual iOS scene rotation. If iOS refuses, the app explains how to retry. Preview and video use the actual orientation shown, which stays fixed during the take. Landscape 4K/1080p/720p videos are 16:9.")
                        .font(.callout)
                }
            }
            .navigationTitle("Settings")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }
    private func adjustment(_ title: String, value: Binding<Double>, range: ClosedRange<Double>,
                            suffix: String = "", percentage: Bool = false) -> some View {
        VStack(alignment: .leading) {
            HStack {
                Text(title)
                Spacer()
                Text(percentage ? "\(Int(value.wrappedValue * 100))%" : "\(Int(value.wrappedValue)) \(suffix)")
                    .foregroundStyle(.secondary).monospacedDigit()
            }
            Slider(value: value, in: range).accessibilityLabel(title)
        }
    }
}
