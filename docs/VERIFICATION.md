# Verification status

The project is implemented, but **V1 is not complete until the real build, installation and device acceptance tests pass**.

## Available environment

Development here is Linux. It has no Xcode, Apple SDK, Swift compiler, or physical iPhone access. This is compatible with maintaining source from Windows, but local grammar/config checks do not establish iOS compilation or runtime behavior.

## Evidence

- Native app source, project definition, macOS CI, unit tests, packaging scripts, beginner guide and device QA checklist are present.
- Swift source grammar has been parsed with Tree-sitter; this checks syntax, not types or Apple API compilation.
- Subsequent repository/config/packaging checks and their outcomes are recorded below as they run.

## Pending gates

- **GitHub macOS build and simulator tests: NOT RUN.** No target repository URL has been supplied; no IPA has been generated.
- **Actual IPA packaging: NOT RUN against a compiled app.** Packaging fixtures can validate script behavior but cannot prove an installable binary.
- **AltStore installation and iPhone launch: REQUIRES REAL-DEVICE VERIFICATION.**
- **Camera/microphone, genuine output 4K60, Photos saving, overlay exclusion, all orientations, interruption recovery and long recordings: REQUIRES REAL-DEVICE VERIFICATION.**

Use [QA.md](QA.md) for acceptance. When a repository is connected, Codex should push the source, inspect the first run, fix compiler failures, and update this document with the successful run URL/commit. Do not mark pending gates complete based on static review or file existence.
