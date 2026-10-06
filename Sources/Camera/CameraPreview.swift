import SwiftUI
import AVFoundation

struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession
    let mirrored: Bool
    var orientationChanged: (UIInterfaceOrientation) -> Void

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspect
        view.orientationChanged = orientationChanged
        view.mirrored = mirrored
        return view
    }
    func updateUIView(_ view: PreviewView, context: Context) {
        view.orientationChanged = orientationChanged
        view.mirrored = mirrored
        view.setNeedsLayout()
    }
    static func dismantleUIView(_ view: PreviewView, coordinator: ()) {
        view.previewLayer.session = nil
    }
}

final class PreviewView: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
    var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    var orientationChanged: ((UIInterfaceOrientation) -> Void)?
    var mirrored = false
    private var lastOrientation: UIInterfaceOrientation?

    override func layoutSubviews() {
        super.layoutSubviews()
        // Interface orientation avoids device-orientation reversal and face-up ambiguity.
        guard let orientation = window?.windowScene?.interfaceOrientation, orientation != .unknown else { return }
        if let connection = previewLayer.connection {
            if connection.isVideoOrientationSupported { connection.videoOrientation = orientation.captureOrientation }
            if connection.isVideoMirroringSupported {
                connection.automaticallyAdjustsVideoMirroring = false
                connection.isVideoMirrored = mirrored
            }
        }
        if orientation != lastOrientation {
            lastOrientation = orientation
            DispatchQueue.main.async { [weak self] in self?.orientationChanged?(orientation) }
        }
    }
}
