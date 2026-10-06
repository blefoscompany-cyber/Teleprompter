"""Container/runner utility tests, not an iOS build or simulated camera test."""
import contextlib
import io
import json
from pathlib import Path
import plistlib
import subprocess
import sys
import tempfile
import unittest
import zipfile

from verify_ipa import verify


class PackagingChecks(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.ipa = Path(self.temp.name) / "fixture.ipa"
        self.info = {
            "CFBundleSupportedPlatforms": ["iPhoneOS"],
            "CFBundleExecutable": "Teleprompter",
            "UIDeviceFamily": [1],
            "NSCameraUsageDescription": "Camera permission fixture",
            "NSMicrophoneUsageDescription": "Microphone permission fixture",
            "NSPhotoLibraryAddUsageDescription": "Photos permission fixture",
            "UISupportedInterfaceOrientations": ["UIInterfaceOrientationPortrait",
                "UIInterfaceOrientationLandscapeLeft", "UIInterfaceOrientationLandscapeRight"],
        }

    def package(self, executable=True, extra=None):
        prefix = "Payload/Teleprompter.app/"
        with zipfile.ZipFile(self.ipa, "w") as archive:
            archive.writestr(prefix + "Info.plist", plistlib.dumps(self.info))
            if executable:
                archive.writestr(prefix + "Teleprompter", b"Packaging test fixture, NOT an app binary.")
            if extra:
                archive.writestr(extra, b"fixture")

    def test_accepts_expected_container(self):
        self.package()
        with contextlib.redirect_stdout(io.StringIO()):
            verify(self.ipa)

    def test_rejects_simulator_app(self):
        self.info["CFBundleSupportedPlatforms"] = ["iPhoneSimulator"]
        self.package()
        with self.assertRaisesRegex(AssertionError, "simulator"):
            verify(self.ipa)

    def test_rejects_missing_executable(self):
        self.package(executable=False)
        with self.assertRaisesRegex(AssertionError, "Missing executable"):
            verify(self.ipa)

    def test_rejects_missing_microphone_permission(self):
        del self.info["NSMicrophoneUsageDescription"]
        self.package()
        with self.assertRaisesRegex(AssertionError, "Missing permission"):
            verify(self.ipa)

    def test_rejects_missing_landscape_support(self):
        self.info["UISupportedInterfaceOrientations"] = ["UIInterfaceOrientationPortrait"]
        self.package()
        with self.assertRaisesRegex(AssertionError, "Missing supported orientation"):
            verify(self.ipa)

    def test_rejects_embedded_profile(self):
        self.package(extra="Payload/Teleprompter.app/embedded.mobileprovision")
        with self.assertRaisesRegex(AssertionError, "provisioning profile"):
            verify(self.ipa)

    def test_rejects_signing_material(self):
        self.package(extra="Payload/Teleprompter.app/_CodeSignature/CodeResources")
        with self.assertRaisesRegex(AssertionError, "unsigned app"):
            verify(self.ipa)


class SimulatorChecks(unittest.TestCase):
    def run_catalog(self, catalog):
        with tempfile.TemporaryDirectory() as temp:
            path = Path(temp) / "simulators.json"
            path.write_text(json.dumps(catalog), encoding="utf-8")
            return subprocess.run([sys.executable, str(Path(__file__).with_name("select_simulator.py")),
                str(path)], capture_output=True, text=True)

    def test_selects_available_iphone_on_latest_runtime(self):
        result = self.run_catalog({"devices": {
            "com.apple.CoreSimulator.SimRuntime.iOS-18-4": [
                {"name": "iPhone 16", "udid": "old", "isAvailable": True}],
            "com.apple.CoreSimulator.SimRuntime.iOS-26-0": [
                {"name": "iPad Pro", "udid": "ipad", "isAvailable": True},
                {"name": "iPhone 16", "udid": "unavailable", "isAvailable": False},
                {"name": "iPhone 17", "udid": "latest", "isAvailable": True}],
        }})
        self.assertEqual(result.returncode, 0)
        self.assertEqual(result.stdout.strip(), "latest")

    def test_missing_iphone_explains_failure(self):
        result = self.run_catalog({"devices": {}})
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("No available iPhone simulator", result.stderr)


if __name__ == "__main__":
    unittest.main()
