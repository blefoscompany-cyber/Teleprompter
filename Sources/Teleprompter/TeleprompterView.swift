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
        let view = PrompterTextView()
        view.backgroundColor = .clear
        view.isEditable = false
        view.isSelectable = false
        view.alwaysBounceVertical = true
        view.showsVerticalScrollIndicator = true
        view.isScrollEnabled = true
        view.textContainer.lineFragmentPadding = 0
        view.textContainer.widthTracksTextView = true
        view.textContainer.heightTracksTextView = false
        view.textContainerInset = UIEdgeInsets(top: 18, left: 18, bottom: 18, right: 18)
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
            coordinator.invalidateGeometry()
            view.layoutManager.ensureLayout(for: view.textContainer)
            view.layoutIfNeeded()
            view.setContentOffset(scriptChanged ? CGPoint(x: 0, y: -view.adjustedContentInset.top) : previousOffset, animated: false)
        }
        view.alpha = CGFloat(textOpacity)
        coordinator.speed = speed
        if coordinator.lastRestartToken != controller.restartToken {
            coordinator.lastRestartToken = controller.restartToken
            coordinator.invalidateGeometry()
            view.setContentOffset(CGPoint(x: 0, y: -view.adjustedContentInset.top), animated: false)
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
        private var stableEndFrames = 0
        private var lastGeometry: ScrollGeometry?

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
                stableEndFrames = 0
            } else if !playing {
                link?.invalidate()
                link = nil
                proxy = nil
                previousTimestamp = nil
            }
        }
        func tick(_ link: CADisplayLink) {
            advance(timestamp: link.timestamp)
        }
        func advance(timestamp: CFTimeInterval) {
            guard controller.isPlaying else { return }
            guard let view, !view.isDragging, !view.isDecelerating else { previousTimestamp = nil; return }
            view.layoutIfNeeded()
            let geometry = ScrollGeometry(contentHeight: view.contentSize.height, viewportHeight: view.bounds.height,
                                          topInset: view.adjustedContentInset.top, bottomInset: view.adjustedContentInset.bottom)
            // A zero-sized or still-laying-out view is not the end of a script.
            guard geometry.isReady, !(lastScript?.isEmpty ?? true) else {
                previousTimestamp = nil
                stableEndFrames = 0
                return
            }
            if geometry != lastGeometry {
                lastGeometry = geometry
                stableEndFrames = 0
                previousTimestamp = timestamp
                return
            }
            defer { previousTimestamp = timestamp }
            guard let previousTimestamp else { return }
            let next = geometry.advanced(from: view.contentOffset.y, speed: speed, elapsed: timestamp - previousTimestamp)
            view.setContentOffset(CGPoint(x: 0, y: next), animated: false)
            stableEndFrames = next >= geometry.maximum ? stableEndFrames + 1 : 0
            if stableEndFrames >= 3 {
                controller.pause()
                setPlaying(false)
            }
        }
        func invalidateGeometry() { lastGeometry = nil; stableEndFrames = 0; previousTimestamp = nil }
        func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
            controller.pause()
            setPlaying(false)
        }
    }
}

final class PrompterTextView: UITextView {
    private var lastLayoutSize = CGSize.zero
    override func layoutSubviews() {
        // SwiftUI sets the actual bounds after updateUIView. Computing this in
        // layout also handles rotation, width/font edits and long final lines.
        // A scroll-view inset lets even one line travel fully past the top.
        let inset = UIEdgeInsets(top: 0, left: 0, bottom: max(0, bounds.height), right: 0)
        if contentInset != inset { contentInset = inset }
        super.layoutSubviews()
        if bounds.size != lastLayoutSize {
            lastLayoutSize = bounds.size
            layoutManager.ensureLayout(for: textContainer)
        }
    }
}

@MainActor
private final class DisplayLinkProxy: NSObject {
    weak var coordinator: TeleprompterView.Coordinator?
    @objc func tick(_ link: CADisplayLink) { coordinator?.tick(link) }
}
