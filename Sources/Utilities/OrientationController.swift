import SwiftUI
import UIKit

enum OrientationMode: String, CaseIterable, Identifiable {
    case automatic, portrait, landscapeLeft, landscapeRight
    var id: String { rawValue }
    var title: String {
        switch self {
        case .automatic: return "Automatic rotation"
        case .portrait: return "Portrait"
        case .landscapeLeft: return "Landscape left"
        case .landscapeRight: return "Landscape right"
        }
    }
    var orientation: UIInterfaceOrientation? {
        switch self {
        case .automatic: return nil
        case .portrait: return .portrait
        case .landscapeLeft: return .landscapeLeft
        case .landscapeRight: return .landscapeRight
        }
    }
    var mask: UIInterfaceOrientationMask { orientation?.interfaceMask ?? .allButUpsideDown }
}

extension UIInterfaceOrientation {
    var interfaceMask: UIInterfaceOrientationMask {
        switch self {
        case .landscapeLeft: return .landscapeLeft
        case .landscapeRight: return .landscapeRight
        default: return .portrait
        }
    }
}

@MainActor
final class OrientationController: ObservableObject {
    static let shared = OrientationController()
    @Published private(set) var mode: OrientationMode = .automatic
    @Published private(set) var interfaceOrientation: UIInterfaceOrientation = .portrait
    @Published private(set) var isTransitioning = false
    @Published private(set) var hint: String?
    @Published var message: String?
    private var takeOrientation: UIInterfaceOrientation?
    private weak var scene: UIWindowScene?
    private var deviceObserver: NSObjectProtocol?
    private var requestID = UUID()
    var supportedOrientations: UIInterfaceOrientationMask { takeOrientation?.interfaceMask ?? mode.mask }

    init() {
        UIDevice.current.beginGeneratingDeviceOrientationNotifications()
        deviceObserver = NotificationCenter.default.addObserver(forName: UIDevice.orientationDidChangeNotification,
            object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in self?.deviceOrientationChanged() }
            }
    }
    deinit {
        if let deviceObserver { NotificationCenter.default.removeObserver(deviceObserver) }
    }
    func attach(_ scene: UIWindowScene) { self.scene = scene; observe(scene.interfaceOrientation) }
    func observe(_ orientation: UIInterfaceOrientation) {
        guard orientation == .portrait || orientation.isLandscape else { return }
        if interfaceOrientation != orientation { interfaceOrientation = orientation }
        if isTransitioning && (mode.orientation == nil || mode.orientation == orientation) { isTransitioning = false }
        updateHint()
    }
    func snapshot() -> UIInterfaceOrientation {
        if let actual = scene?.interfaceOrientation, actual == .portrait || actual.isLandscape { return actual }
        return interfaceOrientation
    }
    func select(_ mode: OrientationMode) {
        guard takeOrientation == nil else { return }
        self.mode = mode
        message = nil
        updateSupportedOrientations()
        if mode == .automatic {
            requestID = UUID()
            isTransitioning = false
            UIViewController.attemptRotationToDeviceOrientation()
            updateHint()
            return
        }
        guard let scene else {
            self.mode = .automatic
            message = "The camera screen is not attached yet. Close the menu and try the orientation again."
            return
        }
        let ticket = UUID()
        requestID = ticket
        isTransitioning = true
        // Rotate the actual scene using the public iOS API, not just UI drawings.
        scene.requestGeometryUpdate(.iOS(interfaceOrientations: mode.mask)) { [weak self] _ in
            Task { @MainActor in self?.requestFailed(ticket) }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            guard let self, self.requestID == ticket else { return }
            self.observe(scene.interfaceOrientation)
            if self.isTransitioning { self.requestFailed(ticket) }
        }
    }
    func lockForTake(_ orientation: UIInterfaceOrientation?) {
        takeOrientation = orientation
        updateSupportedOrientations()
        updateHint()
    }
    private func requestFailed(_ ticket: UUID) {
        guard requestID == ticket, isTransitioning else { return }
        isTransitioning = false
        mode = .automatic
        updateSupportedOrientations()
        message = "iOS did not allow that rotation. Turn off Portrait Orientation Lock in Control Center, close any open sheet, then choose Landscape again. The orientation shown at the top is the actual recording orientation."
        updateHint()
    }
    private func updateSupportedOrientations() {
        var controller = scene?.windows.first(where: { $0.isKeyWindow })?.rootViewController
        while let current = controller {
            current.setNeedsUpdateOfSupportedInterfaceOrientations()
            controller = current.presentedViewController
        }
    }
    private func updateHint() {
        let text: String? = takeOrientation == nil && mode == .automatic &&
            UIDevice.current.orientation.isLandscape && !interfaceOrientation.isLandscape
            ? "Still portrait? Turn off Portrait Orientation Lock, or choose Landscape in the rotation menu." : nil
        if hint != text { hint = text }
    }
    private func deviceOrientationChanged() {
        updateHint()
        // Read the actual scene AFTER UIKit rotates. This also catches a turn
        // between landscape sides without assuming physical/device directions.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self, let scene = self.scene else { return }
            self.observe(scene.interfaceOrientation)
        }
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        OrientationController.shared.supportedOrientations
    }
}

// Transition completion also catches 180-degree turns, which keep the same size.
struct SceneOrientationObserver: UIViewControllerRepresentable {
    let controller: OrientationController
    func makeUIViewController(context: Context) -> ObserverViewController {
        let view = ObserverViewController()
        view.orientationController = controller
        return view
    }
    func updateUIViewController(_ view: ObserverViewController, context: Context) { view.report() }
    final class ObserverViewController: UIViewController {
        weak var orientationController: OrientationController?
        override func loadView() { view = UIView(); view.isUserInteractionEnabled = false; view.backgroundColor = .clear }
        override func viewDidAppear(_ animated: Bool) { super.viewDidAppear(animated); report() }
        override func viewDidLayoutSubviews() { super.viewDidLayoutSubviews(); report() }
        override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
            super.viewWillTransition(to: size, with: coordinator)
            coordinator.animate(alongsideTransition: nil) { [weak self] _ in self?.report() }
        }
        func report() {
            guard let scene = view.window?.windowScene else { return }
            DispatchQueue.main.async { [weak self] in self?.orientationController?.attach(scene) }
        }
    }
}
