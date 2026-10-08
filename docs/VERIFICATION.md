# Verification status

The project is implemented, but **V1 is not complete until the real build, installation and device acceptance tests pass**.

## Available environment

Development here is Linux. It has no Xcode, Apple SDK, Swift compiler, or physical iPhone access. This is compatible with maintaining source from Windows, but local grammar/config checks do not establish iOS compilation or runtime behavior.

## Evidence

- Native app source, project definition, macOS CI, unit tests, packaging scripts, beginner guide and device QA checklist are present.
- Swift source grammar has been parsed with Tree-sitter; this checks syntax, not types or Apple API compilation.
- **PASS:** all 20 Swift files (16 application, 4 test files) parse without grammar errors using Tree-sitter. This is not type checking or Apple SDK compilation.
- **PASS:** all Python build scripts parse; the IPA packaging shell script passes `bash -n`.
- **PASS:** project/workflow YAML parses; signing is disabled, the workflow uses the standard `macos-15` runner, its token has read-only contents access, and manual dispatch is enabled.
- **PASS:** asset-catalog JSON and the 1024 × 1024 opaque RGB app icon are valid.
- **PASS:** nine Python utility tests cover expected IPA container structure, rejection of simulator/missing-executable/missing-permission/missing-orientation/signing-material fixtures, and simulator discovery/failure handling. These use container fixtures, not a compiled iOS app.
- **PASS:** `git diff --check`; ignore rules protect movie files, personal-script folders, signing files, generated projects, generated Info.plist, and build/IPA artifacts.
- **REVIEWED:** capture mutations and delegate work are serialized; published state runs on main; foreground-return during finalization and reconfiguration after media-service resets were corrected; layout-driven text padding handles rotation; file deletion is conditional on a successful Photos transaction.

These local checks have now been followed by real Xcode compilation, simulator XCTest execution, and verification of the compiled IPA, as recorded below. The owner subsequently confirmed basic V1 recording on iPhone 16. Full acceptance and the version 1.1 fixes remain pending device testing.

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

- **Owner-confirmed V1:** AltStore installation, launch on iPhone 16, camera video with microphone audio, and successful saving to Photos.
- **Camera/microphone, genuine output 4K60, Photos saving, overlay exclusion, all orientations, interruption recovery and long recordings: REQUIRES REAL-DEVICE VERIFICATION.**

Use [QA.md](QA.md) for acceptance. Do not mark device gates complete based on successful compilation, unit tests, or IPA structure alone. Install through AltStore Classic, then begin with a private ten-second recording before long-take testing.

## Version 1.1 targeted fixes — 8 October 2026

### Causes found in source

- Scrolling calculated its endpoint without the bottom scroll inset and treated unfinished layout as the end. The corrected geometry includes adjusted top/bottom insets, adds a full viewport of trailing scroll space, waits for valid/stable layout, and preserves Play through resizing. Native UIKit tests verify movement and pause/resume, not just controller flags. A weak display-link proxy remains in use.
- Orientation relied on incidental preview layout updates and lacked explicit scene geometry requests or a landscape control layout. The app now observes actual scene transitions (including 180-degree turns), shares that orientation with preview and recording, provides public-API manual portrait/landscape scene requests, and locks the actual starting orientation during a take. Automatic rotation can be blocked by Portrait Orientation Lock; manual requests report failure instead of pretending the scene rotated. Physical playback and lock behavior require device verification.
- Audio setup/interruption warnings could be confused with permission denial or remain stale after recovery. Current authorization is now separate from audio setup/session readiness; a granted permission is not labelled disabled and successful recovery clears stale interruption warnings. The existing microphone input and native movie output are preserved.

The bundle identifier `local.teleprompter.camera`, script/settings keys, local recordings directory, format selector and native Photos saving are unchanged. There are no new dependencies, services or recording limits. The version fields are explicitly wired into XcodeGen's generated Info.plist; an initial successful build caught by independent artifact inspection still carried default version 1.0, so that metadata was corrected before distribution.

### Device gate

**REQUIRES REAL-DEVICE VERIFICATION:** version 1.1 in-place AltStore update/data retention, both landscape sides and saved 16:9 playback, short/medium/long automatic scrolling, manual orientation with lock on/off, microphone status and interruption recovery. Existing camera/4K60/Photos and long-take checks must also be repeated where indicated in QA.md. Simulator tests do not establish camera hardware behavior.

### Final build and downloaded artifact

- **PASS:** https://github.com/blefoscompany-cyber/Teleprompter/actions/runs/37739554005 — built `e76c2c0` on main using Xcode 16.4, physical iPhoneOS 18.5 SDK, signing disabled.
- **PASS:** actual job logs inspected: nine build-tool tests and 25 simulator XCTest cases, zero failures (including 14 new scrolling/orientation/microphone regression cases); Release `iphoneos` build and packaging/upload succeeded.
- **PASS:** downloaded [Teleprompter-IPA artifact](https://github.com/blefoscompany-cyber/Teleprompter/actions/runs/37739554005/artifacts/11533736569), ID `11533736569`, size `277740` bytes. Outer ZIP digest matches GitHub: `bb3951ac2742cf31da35b4f751b2374eb9df1b31dd9e6cd71a1318e6e9873152`.
- **PASS:** independent inspection confirms version **1.1**, build **2**, unchanged `local.teleprompter.camera`, iPhone family `[1]`, expected Payload structure/permission descriptions/orientations, and an unsigned arm64 physical-iOS Mach-O executable.
- IPA SHA-256: `7c32361c055dc541d0f7a8b1c89053c12429bbd10310d492f97195fb723f073a`.
- Supported older orientation APIs produce deprecation warnings; no compiler/test failure occurred. Real rotation, recording playback, Portrait Orientation Lock behavior and long takes are still physical-device gates.

Subsequent documentation-only commits do not rebuild the app; their application source/project configuration is identical to the successful build above. Update using README's in-place AltStore instructions; do not uninstall the existing app.

## Version 1.2 front-camera recording mirroring — 8 October 2026

The native movie connection now uses the locally persisted **Mirror Recorded Video** setting (default ON for new and existing installations). Only the queue-owned front camera can request mirroring; rear takes explicitly remain non-mirrored. The preference is captured when Record is pressed, automatic output mirroring is disabled, and orientation continues to be set from the same actual interface orientation before recording. Preview mirroring and the existing orientation mapping are unchanged. Unsupported requested mirroring produces an actionable error instead of silently recording the wrong appearance.

The bundle identifier, old script/settings keys, recording folder, camera format selection, audio and Photos saving are preserved. Three regression cases cover fresh-install defaults, upgrade defaults and both persisted choices without losing script/settings, and the front/rear policy matrix. Local checks: 20 Swift files parsed without grammar errors, nine Python utility tests passed, and `git diff --check` passed. These are not Apple SDK compilation checks.

**REQUIRES REAL-DEVICE VERIFICATION:** recorded mirror ON/OFF appearance for front portrait and both landscapes, rear remaining non-mirrored, unchanged preview, setting persistence, in-place update/data retention, and continued audio/Photos/4K60 operation. Check Photos and an exported movie on Windows using a private asymmetric object or printed word; the simulator cannot establish recorded appearance.

### Successful build and independent artifact inspection

- Run: https://github.com/blefoscompany-cyber/Teleprompter/actions/runs/37748599481 — built `00ccbf66cd4dae71fbd71b55aad626a705258b24` on main with Xcode 16.4 and the physical iPhoneOS SDK, signing disabled.
- Actual job logs inspected: **28 simulator XCTest cases passed**, including all three new mirror-setting regression cases; nine build-tool tests, physical-iPhone Release compilation, IPA packaging and upload passed.
- Downloaded [Teleprompter-IPA artifact](https://github.com/blefoscompany-cyber/Teleprompter/actions/runs/37748599481/artifacts/11537485355), ID `11537485355`, size `279924` bytes. Its outer ZIP digest matches GitHub: `c2a841d7b96e4844447cf7659548558f954dd353b2ec548e2ee7a901035cf1a9`.
- Independent inspection confirms **version 1.2, build 3**, unchanged `local.teleprompter.camera`, iPhone family `[1]`, expected Payload/permissions/orientations, and an unsigned arm64 physical-iOS Mach-O executable. IPA SHA-256: `1d10d5e77883b44cf53ea787f2c238fd55d1ddd1b1c1c1b90361c3102dafab08`.
- Subsequent documentation-only commits preserve the exact application source/configuration from this run. No actual front-camera recorded appearance or orientation behavior is claimed verified by these checks.
