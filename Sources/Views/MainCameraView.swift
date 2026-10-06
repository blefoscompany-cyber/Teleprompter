import SwiftUI

struct MainCameraView: View {
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var camera = CameraManager()
    @StateObject private var prompter = TeleprompterController()
    @StateObject private var recordings = RecordingStore()
    @State private var sheet: Sheet?
    @State private var orientation: UIInterfaceOrientation = .portrait
    @State private var permissionExplanation: String?
    @State private var isAuthorizing = false
    @State private var alertMessage: String?
    private enum Sheet: String, Identifiable {
        case script, settings, recordings
        var id: String { rawValue }
    }

    var body: some View {
        GeometryReader { geometry in
            let landscape = geometry.size.width > geometry.size.height
            VStack(spacing: 8) {
                topBar
                ZStack {
                    Color.black
                    CameraPreview(session: camera.session, mirrored: camera.selectedSide == .front) {
                        orientation = $0
                    }
                    if !settings.script.isEmpty {
                        GeometryReader { area in
                            let height = area.size.height * (landscape ? 0.7 : 0.43)
                            TeleprompterView(script: settings.script, fontSize: settings.fontSize,
                                            speed: settings.speed, textOpacity: settings.textOpacity,
                                            controller: prompter)
                                .background(.black.opacity(settings.backgroundOpacity))
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                                .frame(width: area.size.width * settings.width, height: height)
                                .position(x: area.size.width / 2,
                                          y: height / 2 + (area.size.height - height) * settings.verticalPosition)
                        }
                    }
                    if let explanation = permissionExplanation {
                        cameraHelp(explanation)
                    } else if !camera.isReady && !camera.phase.isBusy {
                        cameraHelp(camera.isConfiguring || isAuthorizing ? "Starting camera…" : "Camera is not ready. Tap Retry camera.")
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .layoutPriority(1)
                if let warning = camera.warning {
                    Text(warning).font(.caption).foregroundStyle(.yellow).lineLimit(landscape ? 2 : 3)
                }
                if !recordings.saving.isEmpty {
                    Label("Saving to Photos…", systemImage: "arrow.down.circle").font(.caption)
                } else if let confirmation = recordings.confirmation {
                    Text(confirmation).font(.caption).foregroundStyle(.green).lineLimit(2)
                }
                bottomBar
            }
            .padding(landscape ? 8 : 12)
        }
        .background(Color.black)
        .task {
            camera.onRecordingFinished = { url in recordings.accept(url) }
            if let message = recordings.message { alertMessage = message; recordings.message = nil }
            await authorizeAndActivate()
        }
        .onChange(of: scenePhase) { _, value in
            if value == .active {
                Task { await authorizeAndActivate() }
                recordings.reload()
            } else if value == .background {
                prompter.pause()
                camera.deactivate()
            } else {
                prompter.pause()
            }
            updateScreenAwake()
        }
        .onChange(of: settings.camera) { _, _ in activateIfForeground() }
        .onChange(of: settings.quality) { _, _ in activateIfForeground() }
        .onChange(of: camera.phase) { _, phase in
            if phase == .idle { prompter.pause() }
            updateScreenAwake()
        }
        .onChange(of: prompter.isPlaying) { _, _ in updateScreenAwake() }
        .onChange(of: camera.message) { _, value in
            if let value { alertMessage = value; camera.message = nil }
        }
        .onChange(of: recordings.message) { _, value in
            if let value { alertMessage = value; recordings.message = nil }
        }
        .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
        .sheet(item: $sheet) { current in
            switch current {
            case .script: ScriptEditorView().environmentObject(settings)
            case .settings: SettingsView(cameraBusy: camera.phase.isBusy).environmentObject(settings)
            case .recordings: KeptRecordingsView(store: recordings)
            }
        }
        .alert("Teleprompter", isPresented: Binding(get: { alertMessage != nil }, set: { if !$0 { alertMessage = nil } })) {
            Button("OK") { alertMessage = nil }
            Button("Open Settings") { openSystemSettings() }
        } message: { Text(alertMessage ?? "") }
    }

    private var topBar: some View {
        HStack(spacing: 12) {
            Button {
                settings.camera = settings.camera == .front ? .rear : .front
            } label: {
                Label(camera.selectedSide.title, systemImage: "arrow.triangle.2.circlepath.camera")
                    .frame(minHeight: 44)
            }
            .disabled(camera.phase.isBusy || camera.isConfiguring || isAuthorizing)
            .accessibilityLabel("Switch camera. Currently \(camera.selectedSide.title)")
            Spacer(minLength: 4)
            VStack(alignment: .trailing, spacing: 2) {
                Text(camera.formatLabel).font(.caption).lineLimit(1).minimumScaleFactor(0.7)
                Text((camera.lockedOrientation ?? orientation).displayName + (camera.phase.isBusy ? " · locked for this take" : ""))
                    .font(.caption2).foregroundStyle(.secondary)
            }
        }
        .foregroundStyle(.white)
    }

    private var bottomBar: some View {
        HStack(spacing: 12) {
            Button { prompter.pause(); sheet = .script } label: {
                Image(systemName: "doc.text").frame(width: 44, height: 48)
            }
            .disabled(camera.phase.isBusy)
            .accessibilityLabel("Edit script")
            Button { prompter.toggle() } label: {
                Image(systemName: prompter.isPlaying ? "pause.fill" : "play.fill").frame(width: 44, height: 48)
            }
            .disabled(settings.script.isEmpty)
            .accessibilityLabel(prompter.isPlaying ? "Pause scrolling" : "Play scrolling")
            Button { prompter.restart() } label: {
                Image(systemName: "backward.end.fill").frame(width: 44, height: 48)
            }
            .accessibilityLabel("Restart script")
            Spacer(minLength: 0)
            VStack(spacing: 2) {
                Button {
                    if camera.phase == .recording || camera.phase == .preparing { camera.stop() }
                    else if let directory = recordings.directory {
                        camera.record(orientation: orientation, directory: directory)
                    }
                } label: {
                    ZStack {
                        Circle().stroke(.white, lineWidth: 3).frame(width: 52, height: 52)
                        if camera.phase.isBusy {
                            RoundedRectangle(cornerRadius: 5).fill(.red).frame(width: 24, height: 24)
                        } else {
                            Circle().fill(.red).frame(width: 42, height: 42)
                        }
                    }
                }
                .disabled(camera.phase == .finishing || (!camera.phase.isBusy && (!camera.isReady || recordings.directory == nil)))
                .accessibilityLabel(camera.phase.isBusy ? "Stop recording" : "Record video")
                RecordingClock(startedAt: camera.startedAt, phase: camera.phase)
            }
            Spacer(minLength: 0)
            if !recordings.pending.isEmpty {
                Button { prompter.pause(); sheet = .recordings } label: {
                    Image(systemName: "tray.full").frame(width: 44, height: 48)
                }
                .disabled(camera.phase.isBusy)
                .accessibilityLabel("Kept videos: \(recordings.pending.count)")
            }
            Button { prompter.pause(); sheet = .settings } label: {
                Image(systemName: "slider.horizontal.3").frame(width: 44, height: 48)
            }
            .accessibilityLabel("Teleprompter settings")
        }
        .font(.title3)
        .foregroundStyle(.white)
    }

    private func cameraHelp(_ text: String) -> some View {
        VStack(spacing: 12) {
            Text(text).multilineTextAlignment(.center)
            if !camera.isConfiguring && !isAuthorizing {
                Button("Retry camera") { Task { await authorizeAndActivate() } }.buttonStyle(.borderedProminent)
                if permissionExplanation != nil { Button("Open Settings") { openSystemSettings() }.buttonStyle(.bordered) }
            }
        }
        .padding(24)
        .background(.black.opacity(0.85), in: RoundedRectangle(cornerRadius: 16))
        .padding()
    }
    @MainActor private func authorizeAndActivate() async {
        guard !isAuthorizing else { return }
        if camera.phase.isBusy {
            // Restore the desired foreground state even if a backgrounded take
            // is still finalizing. The capture queue resumes after finalization.
            activateIfForeground()
            return
        }
        isAuthorizing = true
        defer { isAuthorizing = false }
        permissionExplanation = await PermissionManager.capturePermissions()
        // Photos is add-only. Denial doesn't block capture; files remain recoverable.
        if permissionExplanation == nil {
            _ = await PermissionManager.requestPhotos()
            activateIfForeground()
        }
    }
    private func activateIfForeground() {
        guard scenePhase == .active, permissionExplanation == nil else { return }
        camera.activate(side: settings.camera, quality: settings.quality)
    }
    private func updateScreenAwake() {
        UIApplication.shared.isIdleTimerDisabled = scenePhase == .active && (camera.phase.isBusy || prompter.isPlaying)
    }
    private func openSystemSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
    }
}

private struct RecordingClock: View {
    let startedAt: Date?
    let phase: RecordingPhase
    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            Text(label(at: context.date)).font(.caption.monospacedDigit()).foregroundStyle(.white)
        }
        .accessibilityLabel("Recording time")
    }
    private func label(at date: Date) -> String {
        if phase == .preparing { return "Starting…" }
        if phase == .finishing { return "Finishing…" }
        guard let startedAt else { return "Record" }
        let seconds = max(0, Int(date.timeIntervalSince(startedAt)))
        return String(format: "%02d:%02d:%02d", seconds / 3600, (seconds / 60) % 60, seconds % 60)
    }
}
