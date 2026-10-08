import SwiftUI
import AVFoundation

struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession
    let mirrored: Bool
    let orientation: UIInterfaceOrientation

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspect
        view.orientation = orientation
        view.mirrored = mirrored
        return view
    }
    func updateUIView(_ view: PreviewView, context: Context) {
        view.orientation = orientation
        view.mirrored = mirrored
        view.applyConnectionOrientation()
        view.setNeedsLayout()
    }
    static func dismantleUIView(_ view: PreviewView, coordinator: ()) {
        view.previewLayer.session = nil
    }
}

final class PreviewView: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
    var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    var orientation: UIInterfaceOrientation = .portrait
    var mirrored = false

    override func layoutSubviews() {
        super.layoutSubviews()
        applyConnectionOrientation()
    }
    func applyConnectionOrientation() {
        if let connection = previewLayer.connection {
            if connection.isVideoOrientationSupported { connection.videoOrientation = orientation.captureOrientation }
            if connection.isVideoMirroringSupported {
                connection.automaticallyAdjustsVideoMirroring = false
                connection.isVideoMirrored = mirrored
            }
        }
    }
}
