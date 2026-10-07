# Verification status

The project is implemented, but **V1 is not complete until the real build, installation and device acceptance tests pass**.

## Available environment

Development here is Linux. It has no Xcode, Apple SDK, Swift compiler, or physical iPhone access. This is compatible with maintaining source from Windows, but local grammar/config checks do not establish iOS compilation or runtime behavior.

## Evidence

- Native app source, project definition, macOS CI, unit tests, packaging scripts, beginner guide and device QA checklist are present.
- Swift source grammar has been parsed with Tree-sitter; this checks syntax, not types or Apple API compilation.
- **PASS:** all 15 Swift files (13 application, 2 test files) parse without grammar errors using Tree-sitter. This is not type checking or Apple SDK compilation.
- **PASS:** all Python build scripts parse; the IPA packaging shell script passes `bash -n`.
- **PASS:** project/workflow YAML parses; signing is disabled, the workflow uses the standard `macos-15` runner, its token has read-only contents access, and manual dispatch is enabled.
- **PASS:** asset-catalog JSON and the 1024 × 1024 opaque RGB app icon are valid.
- **PASS:** nine Python utility tests cover expected IPA container structure, rejection of simulator/missing-executable/missing-permission/missing-orientation/signing-material fixtures, and simulator discovery/failure handling. These use container fixtures, not a compiled iOS app.
- **PASS:** `git diff --check`; ignore rules protect movie files, personal-script folders, signing files, generated projects, generated Info.plist, and build/IPA artifacts.
- **REVIEWED:** capture mutations and delegate work are serialized; published state runs on main; foreground-return during finalization and reconfiguration after media-service resets were corrected; layout-driven text padding handles rotation; file deletion is conditional on a successful Photos transaction.

These local checks have now been followed by real Xcode compilation, simulator XCTest execution, and verification of the compiled IPA, as recorded below. Runtime camera reliability remains pending iPhone testing.

## Successful GitHub build — 7 October 2026

- Repository: https://github.com/blefoscompany-cyber/Teleprompter
- Successful full workflow: https://github.com/blefoscompany-cyber/Teleprompter/actions/runs/37650602886
- Built commit: `1c5b8ae53c6c6bcc88d40accdefa86ad746c0057` on `main`.
- The original five committed milestones were pushed unchanged. All 32 tracked file blobs were compared with GitHub and matched. Subsequent build fixes were limited to the packaging script and application-target device-family setting; the original Swift implementation was preserved.
- **PASS:** standard GitHub-hosted `macos-15`, Xcode 16.4, iPhoneOS 18.5 SDK. No Apple signing credentials or paid developer account were used.
- **PASS:** nine Python build-tool tests and eleven simulator XCTest cases (nine format-policy tests, two settings-persistence tests), with zero failures.
- **PASS:** Release physical-iPhone build, `arm64`, deployment target iOS 17.0, signing disabled.
- **PASS:** IPA packaging, verification and artifact upload. Artifact: [Teleprompter-IPA](https://github.com/blefoscompany-cyber/Teleprompter/actions/runs/37650602886/artifacts/11495948886), ID `11495948886`, outer artifact ZIP size `237437` bytes. Artifact retention is seven days; rebuild if the download expires.
- **PASS:** downloaded artifact digest matches GitHub's `sha256:2bab03a70c0bbde11e0fead854adbb7c37fb110b0a54e495662f40e82f5798b7`.
- **PASS:** actual downloaded IPA contains `Payload/Teleprompter.app`, required permission strings and all three orientations, iPhone-only device family `[1]`, no provisioning profile or code-signature directory. Its executable was independently inspected as an unsigned `arm64` Mach-O for physical iOS (not an iOS simulator).
- IPA SHA-256: `7fa3735f9df593c94dc939cc69b1fe1439608002017af7aae6b17e6c77411faf`.

Two failed runs were diagnosed from their actual logs before the successful run:

1. [First run](https://github.com/blefoscompany-cyber/Teleprompter/actions/runs/37647986126): tests and iPhone compilation passed; `lipo -verify_arch` interpreted the trailing app path as an architecture. Fixed by supplying the executable before the verification option.
2. [Second run](https://github.com/blefoscompany-cyber/Teleprompter/actions/runs/37648989624): tests and compilation passed; the IPA check rejected the generated iPhone-and-iPad device family. XcodeGen's target default overrode the project setting. Fixed by explicitly setting `TARGETED_DEVICE_FAMILY: "1"` on the application target. The checker was kept strict.

The build reports deprecation warnings for the supported older AVFoundation orientation API and the workflow actions' Node runtime. These did not prevent compilation, testing, or IPA generation. Orientation behavior still needs the physical-device tests below.

## Pending gates

- **AltStore installation and iPhone launch: REQUIRES REAL-DEVICE VERIFICATION.**
- **Camera/microphone, genuine output 4K60, Photos saving, overlay exclusion, all orientations, interruption recovery and long recordings: REQUIRES REAL-DEVICE VERIFICATION.**

Use [QA.md](QA.md) for acceptance. Do not mark device gates complete based on successful compilation, unit tests, or IPA structure alone. Install through AltStore Classic, then begin with a private ten-second recording before long-take testing.
