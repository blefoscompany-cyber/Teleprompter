import XCTest
@testable import Teleprompter

final class AppSettingsTests: XCTestCase {
    @MainActor
    func testScriptAndSettingsSurviveRecreation() {
        let suite = "TeleprompterTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let first = AppSettings(defaults: defaults)
        first.script = "Test script\nSecond paragraph"
        first.speed = 72
        first.verticalPosition = 0.8
        first.camera = .rear
        first.quality = .fullHD30
        let reopened = AppSettings(defaults: defaults)
        XCTAssertEqual(reopened.script, first.script)
        XCTAssertEqual(reopened.speed, 72)
        XCTAssertEqual(reopened.verticalPosition, 0.8)
        XCTAssertEqual(reopened.camera, .rear)
        XCTAssertEqual(reopened.quality, .fullHD30)
    }
    @MainActor
    func testInvalidStoredValuesAreClampedOrDefaulted() {
        let suite = "TeleprompterTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(["fontSize": 10000.0, "position": -2.0, "camera": "unavailable", "quality": "unknown"], forKey: "settings")
        let settings = AppSettings(defaults: defaults)
        XCTAssertEqual(settings.fontSize, 64)
        XCTAssertEqual(settings.verticalPosition, 0)
        XCTAssertEqual(settings.camera, .front)
        XCTAssertEqual(settings.quality, .preferred4K60)
    }
    @MainActor
    func testMirrorDefaultsOnForExistingSettingsAndPersistsBothChoices() {
        let suite = "TeleprompterTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set("Existing private script", forKey: "script")
        defaults.set(["speed": 72.0, "camera": "rear", "quality": "fullHD30"], forKey: "settings")
        let settings = AppSettings(defaults: defaults)
        XCTAssertTrue(settings.mirrorRecordedVideo)
        settings.mirrorRecordedVideo = false
        let reopened = AppSettings(defaults: defaults)
        XCTAssertFalse(reopened.mirrorRecordedVideo)
        XCTAssertEqual(reopened.script, "Existing private script")
        XCTAssertEqual(reopened.speed, 72)
        XCTAssertEqual(reopened.camera, .rear)
        XCTAssertEqual(reopened.quality, .fullHD30)
        reopened.mirrorRecordedVideo = true
        XCTAssertTrue(AppSettings(defaults: defaults).mirrorRecordedVideo)
    }

    @MainActor
    func testNewInstallationDefaultsToMirroredFrontRecording() {
        let suite = "TeleprompterTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let settings = AppSettings(defaults: defaults)
        XCTAssertEqual(settings.camera, .front)
        XCTAssertTrue(settings.mirrorRecordedVideo)
    }

    func testRecordingMirrorPolicyAlwaysExcludesRearCamera() {
        XCTAssertTrue(CameraSide.front.mirrorsRecording(enabled: true))
        XCTAssertFalse(CameraSide.front.mirrorsRecording(enabled: false))
        XCTAssertFalse(CameraSide.rear.mirrorsRecording(enabled: true))
        XCTAssertFalse(CameraSide.rear.mirrorsRecording(enabled: false))
    }

}
