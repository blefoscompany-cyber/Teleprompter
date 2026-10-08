import SwiftUI

struct MainCameraView: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var orientation: OrientationController
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var camera = CameraManager()
    @StateObject private var prompter = TeleprompterController()
    @StateObject private var recordings = RecordingStore()
    @State private var sheet: Sheet?
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
            let layout = landscape ? AnyLayout(HStackLayout(spacing: 8)) : AnyLayout(VStackLayout(spacing: 8))
            VStack(spacing: 8) {
                topBar
                // AnyLayout preserves the preview/text-view identity and reading
                // offset when rearranging from a bottom bar to a landscape rail.
                layout {
                    cameraCanvas(landscape: landscape)
                    if landscape { landscapeControls } else { bottomBar }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                if let warning = camera.warning ?? orientation.hint {
                    Text(warning).font(.caption).foregroundStyle(.yellow).lineLimit(landscape ? 2 : 3)
                }
                if !recordings.saving.isEmpty {
                    Label("Saving to Photos…", systemImage: "arrow.down.circle").font(.caption)
                } else if let confirmation = recordings.confirmation {
                    Text(confirmation).font(.caption).foregroundStyle(.green).lineLimit(2)
                }
            }
            .padding(landscape ? 8 : 12)
        }
        .background(Color.black)
        .background(SceneOrientationObserver(controller: orientation).allowsHitTesting(false))
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
        .onChange(of: camera.lockedOrientation) { _, value in orientation.lockForTake(value) }
        .onChange(of: camera.isReady) { _, ready in
            if ready { permissionExplanation = PermissionManager.currentCaptureExplanation() }
        }
        .onChange(of: orientation.message) { _, value in
            if let value { alertMessage = value; orientation.message = nil }
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
            Menu {
                ForEach(OrientationMode.allCases) { mode in
                    Button(mode.title) { orientation.select(mode) }
                }
            } label: {
                Image(systemName: "rotate.right").frame(width: 44, height: 44)
            }
            .disabled(camera.phase.isBusy || orientation.isTransitioning)
            .accessibilityLabel("Recording orientation. \(orientation.mode.title)")
            Spacer(minLength: 4)
            VStack(alignment: .trailing, spacing: 2) {
                Text(camera.formatLabel).font(.caption).lineLimit(1).minimumScaleFactor(0.7)
                Text((camera.lockedOrientation ?? orientation.interfaceOrientation).displayName + (camera.phase.isBusy ? " · locked for this take" : ""))
                    .font(.caption2).foregroundStyle(.secondary)
                Label(camera.microphoneStatus.text, systemImage: camera.microphoneStatus == .ready ? "mic.fill" : "mic")
                    .font(.caption2).foregroundStyle(camera.microphoneStatus == .ready ? Color.green : Color.secondary)
            }
        }
        .foregroundStyle(.white)
    }

    private var bottomBar: some View {
        HStack(spacing: 12) {
            scriptButton
            playButton
            restartButton
            Spacer(minLength: 0)
            recordControl
            Spacer(minLength: 0)
            keptVideosButton
            settingsButton
        }
        .font(.title3)
        .foregroundStyle(.white)
    }

    private var recordControl: some View {
            VStack(spacing: 2) {
                Button {
                    if camera.phase == .recording || camera.phase == .preparing { camera.stop() }
                    else if let directory = recordings.directory {
                        camera.record(orientation: orientation.snapshot(), directory: directory,
                                      mirrorRecordedVideo: settings.mirrorRecordedVideo)
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
                .disabled(camera.phase == .finishing || (!camera.phase.isBusy && (!camera.isReady || recordings.directory == nil || orientation.isTransitioning)))
                .accessibilityLabel(camera.phase.isBusy ? "Stop recording" : "Record video")
                RecordingClock(startedAt: camera.startedAt, phase: camera.phase)
            }
    }

    @ViewBuilder private var keptVideosButton: some View {
            if !recordings.pending.isEmpty {
                Button { prompter.pause(); sheet = .recordings } label: {
                    Image(systemName: "tray.full").frame(width: 44, height: 48)
                }
                .disabled(camera.phase.isBusy)
                .accessibilityLabel("Kept videos: \(recordings.pending.count)")
            }
    }
    private var settingsButton: some View {
            Button { prompter.pause(); sheet = .settings } label: {
                Image(systemName: "slider.horizontal.3").frame(width: 44, height: 48)
            }
            .accessibilityLabel("Teleprompter settings")
    }

    private var scriptButton: some View {
        Button { prompter.pause(); sheet = .script } label: { Image(systemName: "doc.text").frame(width: 44, height: 44) }
            .disabled(camera.phase.isBusy).accessibilityLabel("Edit script")
    }
    private var playButton: some View {
        Button { prompter.toggle() } label: {
            Image(systemName: prompter.isPlaying ? "pause.fill" : "play.fill").frame(width: 44, height: 44)
        }.disabled(settings.script.isEmpty).accessibilityLabel(prompter.isPlaying ? "Pause scrolling" : "Play scrolling")
    }
    private var restartButton: some View {
        Button { prompter.restart() } label: { Image(systemName: "backward.end.fill").frame(width: 44, height: 44) }
            .accessibilityLabel("Restart script")
    }
    private var landscapeControls: some View {
        VStack(spacing: 8) {
            recordControl
            HStack(spacing: 4) { playButton; restartButton }
            HStack(spacing: 4) { scriptButton; settingsButton }
            keptVideosButton
        }
        .frame(width: 96).font(.title3).foregroundStyle(.white)
    }
    private func cameraCanvas(landscape: Bool) -> some View {
        ZStack {
            Color.black
            CameraPreview(session: camera.session, mirrored: camera.selectedSide == .front,
                          orientation: camera.lockedOrientation ?? orientation.interfaceOrientation)
            if !settings.script.isEmpty {
                GeometryReader { area in
                    let height = area.size.height * (landscape ? 0.85 : 0.43)
                    TeleprompterView(script: settings.script, fontSize: settings.fontSize,
                                    speed: settings.speed, textOpacity: settings.textOpacity, controller: prompter)
                        .background(.black.opacity(settings.backgroundOpacity))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .frame(width: area.size.width * settings.width, height: height)
                        .position(x: area.size.width / 2,
                                  y: height / 2 + (area.size.height - height) * settings.verticalPosition)
                }
            }
            if let explanation = permissionExplanation { cameraHelp(explanation) }
            else if !camera.isReady && !camera.phase.isBusy {
                cameraHelp(camera.isConfiguring || isAuthorizing ? "Starting camera…" : "Camera is not ready. Tap Retry camera.")
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .frame(maxWidth: .infinity, maxHeight: .infinity).layoutPriority(1)
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
