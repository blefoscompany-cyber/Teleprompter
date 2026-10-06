import SwiftUI
import Photos
import AVFoundation
import OSLog

@MainActor
final class RecordingStore: ObservableObject {
    @Published private(set) var pending: [URL] = []
    @Published private(set) var saving: Set<URL> = []
    @Published var message: String?
    @Published private(set) var confirmation: String?
    private(set) var directory: URL?
    private let log = Logger(subsystem: "local.teleprompter.camera", category: "saving")

    init() {
        do {
            let documents = try FileManager.default.url(for: .documentDirectory, in: .userDomainMask,
                                                        appropriateFor: nil, create: true)
            var folder = documents.appendingPathComponent("Recordings", isDirectory: true)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            var values = URLResourceValues()
            values.isExcludedFromBackup = true
            try folder.setResourceValues(values)
            directory = folder
            reload()
        } catch {
            log.error("Recording folder unavailable: \(error.localizedDescription, privacy: .public)")
            message = "Local recording storage could not be opened. Make room on your iPhone, then close and reopen the app."
        }
    }

    func reload() {
        guard let directory else { return }
        do {
            pending = try FileManager.default.contentsOfDirectory(at: directory,
                includingPropertiesForKeys: [.creationDateKey], options: .skipsHiddenFiles)
                .filter { $0.pathExtension.lowercased() == "mov" }
                .sorted { $0.lastPathComponent < $1.lastPathComponent }
        } catch {
            message = "Kept recordings could not be listed. They have not been deleted. Close and reopen the app."
        }
    }

    func accept(_ url: URL) {
        reload()
        guard FileManager.default.fileExists(atPath: url.path) else {
            message = "No recording file was created. Close other camera apps, choose a lower recording quality, and try again."
            return
        }
        save(url)
    }

    func save(_ url: URL) {
        guard !saving.contains(url) else { return }
        saving.insert(url)
        confirmation = nil
        Task {
            defer { saving.remove(url) }
            guard await PermissionManager.requestPhotos() else {
                message = "Photos access is off. Your video is kept in this app. Allow adding photos in Settings → Teleprompter → Photos, then open Kept videos and tap Save to Photos."
                return
            }
            do {
                let asset = AVURLAsset(url: url)
                guard try await asset.load(.isPlayable),
                      !(try await asset.loadTracks(withMediaType: .video)).isEmpty else {
                    message = "This recording file is incomplete or cannot be played. It is still kept locally; you can export it from Kept videos."
                    return
                }
                let audioMissing = try await asset.loadTracks(withMediaType: .audio).isEmpty
                try await PHPhotoLibrary.shared().performChanges {
                    PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url)
                }
                // Delete ONLY after Photos reports that its transaction succeeded.
                do { try FileManager.default.removeItem(at: url) }
                catch {
                    log.error("Saved but cleanup failed: \(error.localizedDescription, privacy: .public)")
                    message = "Video saved to Photos, but the local copy could not be removed. Keep it for now; saving it again may create a duplicate."
                }
                reload()
                confirmation = audioMissing ? "Saved to Photos, but no audio track was found. Check the microphone before the next take." : "Video saved to Photos."
            } catch {
                log.error("Photos save failed: \(error.localizedDescription, privacy: .public)")
                message = "Video could not be saved to Photos. It is kept locally. Check Photos permission and free storage, then open Kept videos to retry or export it."
            }
        }
    }
}
