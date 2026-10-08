import XCTest
import UIKit
@testable import Teleprompter

final class TeleprompterRegressionTests: XCTestCase {
    func testBottomScrollInsetLetsShortMediumAndLongScriptsTravelOutOfView() {
        for viewport: CGFloat in [180, 480] {
            for content: CGFloat in [48, 800, 20_000] {
                let geometry = ScrollGeometry(contentHeight: content, viewportHeight: viewport, topInset: 0, bottomInset: viewport)
                XCTAssertTrue(geometry.isReady)
                XCTAssertEqual(geometry.maximum, content)
                XCTAssertGreaterThan(geometry.advanced(from: 0, speed: 35, elapsed: 1.0 / 30), 0)
            }
        }
    }
    func testInsetsAndBounceAreAccountedFor() {
        let geometry = ScrollGeometry(contentHeight: 1000, viewportHeight: 200, topInset: 20, bottomInset: 200)
        XCTAssertEqual(geometry.minimum, -20)
        XCTAssertEqual(geometry.maximum, 1000)
        XCTAssertGreaterThan(geometry.advanced(from: -100, speed: 35, elapsed: 0.03), -20)
        XCTAssertEqual(geometry.advanced(from: 999, speed: 100, elapsed: 0.1), 1000)
    }
    func testUnfinishedLayoutIsNotAScrollEndpoint() {
        XCTAssertFalse(ScrollGeometry(contentHeight: 0, viewportHeight: 200, topInset: 0, bottomInset: 200).isReady)
        XCTAssertFalse(ScrollGeometry(contentHeight: 100, viewportHeight: 0, topInset: 0, bottomInset: 0).isReady)
    }
    func testSpeedAndElapsedTimeChangeDistanceWithoutLargeResumeJumps() {
        let geometry = ScrollGeometry(contentHeight: 1000, viewportHeight: 200, topInset: 0, bottomInset: 200)
        XCTAssertEqual(geometry.advanced(from: 50, speed: 20, elapsed: 0.05), 51)
        XCTAssertEqual(geometry.advanced(from: 50, speed: 80, elapsed: 0.05), 54)
        XCTAssertEqual(geometry.advanced(from: 50, speed: 20, elapsed: 20), 52)
    }
    @MainActor func testPlayPauseResumeRestartController() {
        let controller = TeleprompterController()
        XCTAssertFalse(controller.isPlaying)
        controller.toggle()
        XCTAssertTrue(controller.isPlaying)
        controller.pause()
        XCTAssertFalse(controller.isPlaying)
        controller.toggle()
        XCTAssertTrue(controller.isPlaying)
        controller.restart()
        XCTAssertFalse(controller.isPlaying)
        XCTAssertEqual(controller.restartToken, 1)
    }
    @MainActor func testNativeTextViewActuallyMovesAndPausePreservesItsPosition() {
        let controller = TeleprompterController()
        let coordinator = TeleprompterView.Coordinator(controller: controller)
        let view = makeTextView(lines: 30, width: 320, height: 180)
        coordinator.view = view
        coordinator.lastScript = view.text
        controller.toggle()
        coordinator.advance(timestamp: 1)
        coordinator.advance(timestamp: 1.05)
        let moved = view.contentOffset.y
        XCTAssertGreaterThan(moved, 0)
        controller.pause()
        coordinator.advance(timestamp: 1.1)
        XCTAssertEqual(view.contentOffset.y, moved)
        controller.toggle()
        coordinator.invalidateGeometry()
        coordinator.advance(timestamp: 2)
        coordinator.advance(timestamp: 2.05)
        XCTAssertGreaterThan(view.contentOffset.y, moved)
    }
    @MainActor func testShortNativeTextAndResizeDoNotImmediatelyPause() {
        let controller = TeleprompterController()
        let coordinator = TeleprompterView.Coordinator(controller: controller)
        let view = makeTextView(lines: 1, width: 320, height: 400)
        coordinator.view = view
        coordinator.lastScript = view.text
        controller.toggle()
        coordinator.advance(timestamp: 1)
        coordinator.advance(timestamp: 1.05)
        XCTAssertTrue(controller.isPlaying)
        XCTAssertGreaterThan(view.contentOffset.y, 0)
        view.frame = CGRect(x: 0, y: 0, width: 600, height: 180)
        view.setNeedsLayout()
        view.layoutIfNeeded()
        coordinator.advance(timestamp: 1.1)
        coordinator.advance(timestamp: 1.15)
        XCTAssertTrue(controller.isPlaying)
    }
    @MainActor func testZeroSizeBeforeFirstLayoutKeepsPlayRequested() {
        let controller = TeleprompterController()
        let coordinator = TeleprompterView.Coordinator(controller: controller)
        let view = UITextView(frame: .zero)
        coordinator.view = view
        coordinator.lastScript = "A short script"
        controller.toggle()
        coordinator.advance(timestamp: 1)
        coordinator.advance(timestamp: 1.05)
        XCTAssertTrue(controller.isPlaying)
    }
    @MainActor private func makeTextView(lines: Int, width: CGFloat, height: CGFloat) -> PrompterTextView {
        let view = PrompterTextView(frame: CGRect(x: 0, y: 0, width: width, height: height))
        view.font = .systemFont(ofSize: 26)
        view.textContainerInset = UIEdgeInsets(top: 18, left: 18, bottom: 18, right: 18)
        view.text = Array(repeating: "Regression test line", count: lines).joined(separator: "\n")
        view.layoutManager.ensureLayout(for: view.textContainer)
        view.setNeedsLayout()
        view.layoutIfNeeded()
        return view
    }
}
