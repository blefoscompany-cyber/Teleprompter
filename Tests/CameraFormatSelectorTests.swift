import XCTest
@testable import Teleprompter

final class CameraFormatSelectorTests: XCTestCase {
    private func format(_ index: Int, _ width: Int, _ height: Int, _ range: ClosedRange<Double>,
                        preferred: Bool = true) -> CameraFormatDescriptor {
        CameraFormatDescriptor(index: index, width: width, height: height,
                               frameRateRanges: [range], preferredPixelFormat: preferred)
    }
    func testChoosesTrue4K60RatherThanAnotherResolutionAt60() {
        let choice = CameraFormatSelector.select(from: [format(0, 1920, 1080, 1...120),
            format(1, 3840, 2160, 1...30), format(2, 3840, 2160, 1...60)], quality: .preferred4K60)
        XCTAssertEqual(choice, CameraFormatChoice(index: 2, width: 3840, height: 2160, fps: 60, isFallback: false))
    }
    func testNeverClaims60ForA30FPSFormat() {
        let choice = CameraFormatSelector.select(from: [format(4, 3840, 2160, 1...30)], quality: .preferred4K60)
        XCTAssertEqual(choice?.fps, 30)
        XCTAssertEqual(choice?.isFallback, true)
    }
    func testFallsBackTo1080When4KIsAbsent() {
        let choice = CameraFormatSelector.select(from: [format(2, 1920, 1080, 30...60)], quality: .preferred4K60)
        XCTAssertEqual(choice?.width, 1920)
        XCTAssertEqual(choice?.fps, 60)
        XCTAssertEqual(choice?.isFallback, true)
    }
    func testLowerQualityRequestDoesNotIncreaseResolutionOrFrameRate() {
        let choice = CameraFormatSelector.select(from: [format(0, 3840, 2160, 1...60),
            format(1, 1920, 1080, 1...60)], quality: .fullHD30)
        XCTAssertEqual(choice?.index, 1)
        XCTAssertEqual(choice?.fps, 30)
        XCTAssertEqual(choice?.isFallback, false)
    }
    func testSupportsMultipleDisjointFrameRateRanges() {
        let descriptor = CameraFormatDescriptor(index: 7, width: 3840, height: 2160,
            frameRateRanges: [24...30, 60...60], preferredPixelFormat: true)
        XCTAssertEqual(CameraFormatSelector.select(from: [descriptor], quality: .preferred4K60)?.fps, 60)
    }
    func testRejectsNear60WhenExact60IsNotSupported() {
        let choice = CameraFormatSelector.select(from: [format(0, 3840, 2160, 1...59.94)], quality: .preferred4K60)
        XCTAssertEqual(choice?.fps, 30)
        XCTAssertEqual(choice?.isFallback, true)
    }
    func testHandlesNoUsableFormats() {
        XCTAssertNil(CameraFormatSelector.select(from: [], quality: .preferred4K60))
        XCTAssertNil(CameraFormatSelector.select(from: [format(0, 7680, 4320, 1...30)], quality: .preferred4K60))
        XCTAssertNil(CameraFormatSelector.select(from: [format(0, 1280, 720, 120...240)], quality: .preferred4K60))
    }
    func testHandlesUnusualCameraWithoutHardCodedIndex() {
        let choice = CameraFormatSelector.select(from: [format(19, 1440, 1080, 12...24)], quality: .preferred4K60)
        XCTAssertEqual(choice?.index, 19)
        XCTAssertEqual(choice?.fps, 24)
        XCTAssertEqual(choice?.isFallback, true)
    }
    func testPrefersNativeFullRangePixelFormatForEqualCapabilities() {
        let choice = CameraFormatSelector.select(from: [format(0, 3840, 2160, 1...60, preferred: false),
            format(1, 3840, 2160, 1...60)], quality: .preferred4K60)
        XCTAssertEqual(choice?.index, 1)
    }
}
