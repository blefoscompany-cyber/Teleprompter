import SwiftUI

@main
struct TeleprompterApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @StateObject private var settings = AppSettings()
    @StateObject private var orientation = OrientationController.shared
    var body: some Scene {
        WindowGroup {
            MainCameraView()
                .environmentObject(settings)
                .environmentObject(orientation)
                .preferredColorScheme(.dark)
        }
    }
}
