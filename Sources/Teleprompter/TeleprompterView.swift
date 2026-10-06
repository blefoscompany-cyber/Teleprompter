import SwiftUI
import UIKit

struct TeleprompterView: UIViewRepresentable {
    let script: String
    let fontSize: Double
    let speed: Double
    let textOpacity: Double
    @ObservedObject var controller: TeleprompterController

    func makeCoordinator() -> Coordinator { Coordinator(controller: controller) }
    func makeUIView(context: Context) -> UITextView {
        let view = UITextView()
        view.backgroundColor = .clear
        view.isEditable = false
        view.isSelectable = false
        view.alwaysBounceVertical = true
        view.showsVerticalScrollIndicator = true
        view.textContainer.lineFragmentPadding = 0
        view.contentInsetAdjustmentBehavior = .never
        view.delegate = context.coordinator
        view.accessibilityLabel = "Script. Swipe to scroll manually."
        context.coordinator.view = view
        return view
    }
    func updateUIView(_ view: UITextView, context: Context) {
        let coordinator = context.coordinator
        let scriptChanged = coordinator.lastScript != script
        let fontChanged = coordinator.lastFontSize != fontSize
        if scriptChanged || fontChanged {
            let paragraph = NSMutableParagraphStyle()
            paragraph.lineSpacing = 8
            let shadow = NSShadow()
            shadow.shadowColor = UIColor.black
            shadow.shadowBlurRadius = 3
            shadow.shadowOffset = CGSize(width: 0, height: 1)
            let previousOffset = view.contentOffset
            view.attributedText = NSAttributedString(string: script, attributes: [
                .font: UIFont.systemFont(ofSize: CGFloat(fontSize), weight: .semibold),
                .foregroundColor: UIColor.white,
                .paragraphStyle: paragraph,
                .shadow: shadow
            ])
            coordinator.lastScript = script
            coordinator.lastFontSize = fontSize
            view.layoutIfNeeded()
            view.setContentOffset(scriptChanged ? .zero : previousOffset, animated: false)
        }
        view.alpha = CGFloat(textOpacity)
        // Bottom space lets the final words reach the top reading region.
        view.textContainerInset = UIEdgeInsets(top: 18, left: 18, bottom: max(40, view.bounds.height - 40), right: 18)
        coordinator.speed = speed
        if coordinator.lastRestartToken != controller.restartToken {
            coordinator.lastRestartToken = controller.restartToken
            view.setContentOffset(.zero, animated: false)
        }
        coordinator.setPlaying(controller.isPlaying)
    }
    static func dismantleUIView(_ view: UITextView, coordinator: Coordinator) {
        coordinator.setPlaying(false)
        view.delegate = nil
    }

    @MainActor
    final class Coordinator: NSObject, UITextViewDelegate {
        weak var view: UITextView?
        let controller: TeleprompterController
        var speed = 35.0
        var lastScript: String?
        var lastFontSize: Double?
        var lastRestartToken = 0
        private var link: CADisplayLink?
        private var previousTimestamp: CFTimeInterval?
        private var proxy: DisplayLinkProxy?

        init(controller: TeleprompterController) { self.controller = controller }
        func setPlaying(_ playing: Bool) {
            if playing, link == nil {
                let proxy = DisplayLinkProxy()
                proxy.coordinator = self
                self.proxy = proxy
                let link = CADisplayLink(target: proxy, selector: #selector(DisplayLinkProxy.tick(_:)))
                link.preferredFrameRateRange = CAFrameRateRange(minimum: 15, maximum: 30, preferred: 30)
                link.add(to: .main, forMode: .common)
                self.link = link
                previousTimestamp = nil
            } else if !playing {
                link?.invalidate()
                link = nil
                proxy = nil
                previousTimestamp = nil
            }
        }
        func tick(_ link: CADisplayLink) {
            guard let view, !view.isDragging, !view.isDecelerating else { previousTimestamp = nil; return }
            defer { previousTimestamp = link.timestamp }
            guard let previousTimestamp else { return }
            let elapsed = min(link.timestamp - previousTimestamp, 0.1)
            let maximum = max(0, view.contentSize.height - view.bounds.height)
            let next = min(maximum, max(0, view.contentOffset.y) + speed * elapsed)
            view.setContentOffset(CGPoint(x: 0, y: next), animated: false)
            if next >= maximum {
                controller.pause()
                setPlaying(false)
            }
        }
        func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
            controller.pause()
            setPlaying(false)
        }
    }
}

@MainActor
private final class DisplayLinkProxy: NSObject {
    weak var coordinator: TeleprompterView.Coordinator?
    @objc func tick(_ link: CADisplayLink) { coordinator?.tick(link) }
}
