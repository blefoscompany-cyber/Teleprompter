# Engineer operating rules

The owner is not a programmer. Complete implementation and diagnosis autonomously; give exactly one next manual action at a time. No Mac, paid services, Apple developer membership, secrets, or backend may be required. Do not declare V1 complete until GitHub build, IPA installation, and physical iPhone QA have evidence.

- Swift/SwiftUI, native AVFoundation/Photos; iOS 17 minimum, iPhone only. No runtime third-party dependencies.
- Maintain `project.yml`; generated Xcode projects and Info.plist are not the source of truth.
- Capture configuration/start/stop and file-output state belong on CameraManager's serial queue. UI publication belongs on the main thread. Do not start/stop sessions from SwiftUI's main thread.
- Use actual dimensions and supported frame-rate ranges, set activeFormat and both active frame durations. Never label a preset or an upscaled format as 4K60.
- Keep movie recording separate from the UI; never composite the script into the output.
- Never add maximum recording duration. Only OS restrictions/storage/critical temperature can end a take.
- Do not remove a recording until Photos confirms success. Preserve interrupted and failed-save files and provide retry/export.
- Camera/quality changes are idle-only. Capture orientation is frozen at start; preview orientation comes from UIWindowScene.interfaceOrientation.
- Never commit personal scripts, recordings, credentials, private keys or profiles. Keep generated user data out of fixtures and logs. Do not log script content.
- Make clear milestone commits. Diagnose real compiler failures from their logs and rerun the workflow when connected.
- Run relevant unit tests on GitHub's simulator, a physical-iPhone unsigned build and IPA validation. On Linux/Windows run available syntax/config/script checks and document their limitations.
- Update `docs/VERIFICATION.md` with evidence. Don't turn untested checklist items into claims.
- Keep public standard macOS CI, short artifact retention and no paid resources. Do not add GitHub secrets or a signing/exportArchive workflow.

For changes use README beginner instructions. Avoid repeated questions about routine engineering choices. Publishing the repository/build is authorized by the owner's request; don't request signing credentials. Retained file deletion, if ever added, needs an explicit user-facing confirmation.
