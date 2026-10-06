"""Check an actual IPA after packaging. This does not test signing/installability."""
import plistlib
import sys
import zipfile

def verify(path):
    with zipfile.ZipFile(path) as archive:
        assert archive.testzip() is None, "IPA contains a corrupt entry"
        names = set(archive.namelist())
        prefix = "Payload/Teleprompter.app/"
        assert all(name.startswith("Payload/") for name in names), "Unexpected top-level entry"
        info = plistlib.loads(archive.read(prefix + "Info.plist"))
        assert info["CFBundleSupportedPlatforms"] == ["iPhoneOS"], "A simulator app cannot be installed on iPhone"
        assert info["UIDeviceFamily"] == [1], "Expected an iPhone application"
        assert prefix + info["CFBundleExecutable"] in names, "Missing executable"
        for key in ("NSCameraUsageDescription", "NSMicrophoneUsageDescription", "NSPhotoLibraryAddUsageDescription"):
            assert info.get(key), f"Missing permission explanation: {key}"
        orientations = set(info["UISupportedInterfaceOrientations"])
        assert {"UIInterfaceOrientationPortrait", "UIInterfaceOrientationLandscapeLeft",
                "UIInterfaceOrientationLandscapeRight"} <= orientations, "Missing supported orientation"
        assert not any(name.endswith("embedded.mobileprovision") for name in names), "Unexpected provisioning profile"
        assert not any("/_CodeSignature/" in name for name in names), "Expected unsigned app for AltStore"
        print("IPA verified: physical-iPhone app in Payload/Teleprompter.app. AltStore must sign it before installation.")

if __name__ == "__main__":
    verify(sys.argv[1])
