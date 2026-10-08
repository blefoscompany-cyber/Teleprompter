import XCTest
import AVFoundation
import UIKit
@testable import Teleprompter

final class OrientationAndPermissionTests: XCTestCase {
    func testManualOrientationModesHaveDistinctSupportedMasksAndCaptureMappings() {
        XCTAssertEqual(OrientationMode.automatic.mask, .allButUpsideDown)
        XCTAssertEqual(OrientationMode.portrait.mask, .portrait)
        XCTAssertEqual(OrientationMode.landscapeLeft.mask, .landscapeLeft)
        XCTAssertEqual(OrientationMode.landscapeRight.mask, .landscapeRight)
        XCTAssertEqual(OrientationMode.landscapeLeft.orientation?.captureOrientation, .landscapeLeft)
        XCTAssertEqual(OrientationMode.landscapeRight.orientation?.captureOrientation, .landscapeRight)
        XCTAssertEqual(OrientationMode.portrait.orientation?.captureOrientation, .portrait)
    }
    @MainActor func testTakeLocksBothLandscapeSidesAndUnlocksWithoutUsingDeviceOrientation() {
        let controller = OrientationController()
        controller.observe(.landscapeLeft)
        XCTAssertEqual(controller.snapshot(), .landscapeLeft)
        controller.lockForTake(.landscapeLeft)
        XCTAssertEqual(controller.supportedOrientations, .landscapeLeft)
        controller.select(.portrait)
        XCTAssertEqual(controller.mode, .automatic)
        controller.lockForTake(.landscapeRight)
        XCTAssertEqual(controller.supportedOrientations, .landscapeRight)
        controller.lockForTake(nil)
        XCTAssertEqual(controller.supportedOrientations, .allButUpsideDown)
    }
    @MainActor func testUnknownAndFaceUpCannotReplaceTheLastInterfaceOrientation() {
        let controller = OrientationController()
        controller.observe(.landscapeRight)
        controller.observe(.unknown)
        XCTAssertEqual(controller.snapshot(), .landscapeRight)
    }
    func testAuthorizedMicrophoneIsNeverLabelledPermissionOffDuringSetupOrInterruption() {
        XCTAssertEqual(MicrophoneStatus.resolve(authorization: .authorized, hasInput: true, sessionRunning: true, interrupted: false), .ready)
        XCTAssertEqual(MicrophoneStatus.resolve(authorization: .authorized, hasInput: false, sessionRunning: false, interrupted: false), .starting)
        XCTAssertEqual(MicrophoneStatus.resolve(authorization: .authorized, hasInput: true, sessionRunning: true, interrupted: true), .interrupted)
        XCTAssertEqual(MicrophoneStatus.resolve(authorization: .authorized, hasInput: true, sessionRunning: true, interrupted: false), .ready)
    }
    func testPermissionOffRequiresActualDeniedOrRestrictedAuthorization() {
        for status: AVAuthorizationStatus in [.denied, .restricted] {
            XCTAssertEqual(MicrophoneStatus.resolve(authorization: status, hasInput: true, sessionRunning: true, interrupted: false), .denied)
        }
        XCTAssertEqual(MicrophoneStatus.resolve(authorization: .notDetermined, hasInput: false, sessionRunning: false, interrupted: false), .permissionNeeded)
    }
    func testPermissionExplanationClearsWhenBothPermissionsAreGranted() {
        XCTAssertNil(PermissionManager.explanation(camera: .authorized, microphone: .authorized))
        XCTAssertTrue(PermissionManager.explanation(camera: .denied, microphone: .authorized)?.hasPrefix("Camera") == true)
        XCTAssertTrue(PermissionManager.explanation(camera: .authorized, microphone: .denied)?.hasPrefix("Microphone") == true)
    }
}
