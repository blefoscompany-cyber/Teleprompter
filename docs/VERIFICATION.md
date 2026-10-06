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

These results describe repository/tooling checks only. Simulator XCTest cases are authored but have not been executed. Runtime reliability remains pending the gates below.

## Pending gates

- **GitHub macOS build and simulator tests: NOT RUN.** No target repository URL has been supplied; no IPA has been generated.
- **Actual IPA packaging: NOT RUN against a compiled app.** Packaging fixtures can validate script behavior but cannot prove an installable binary.
- **AltStore installation and iPhone launch: REQUIRES REAL-DEVICE VERIFICATION.**
- **Camera/microphone, genuine output 4K60, Photos saving, overlay exclusion, all orientations, interruption recovery and long recordings: REQUIRES REAL-DEVICE VERIFICATION.**

Use [QA.md](QA.md) for acceptance. When a repository is connected, Codex should push the source, inspect the first run, fix compiler failures, and update this document with the successful run URL/commit. Do not mark pending gates complete based on static review or file existence.
