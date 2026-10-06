import SwiftUI

@MainActor
final class TeleprompterController: ObservableObject {
    @Published private(set) var isPlaying = false
    @Published private(set) var restartToken = 0
    func toggle() { isPlaying.toggle() }
    func pause() { isPlaying = false }
    func restart() { isPlaying = false; restartToken += 1 }
}
