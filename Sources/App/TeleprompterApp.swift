import SwiftUI

@main
struct TeleprompterApp: App {
    @StateObject private var settings = AppSettings()
    var body: some Scene {
        WindowGroup {
            MainCameraView()
                .environmentObject(settings)
                .preferredColorScheme(.dark)
        }
    }
}
