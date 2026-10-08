# iPhone 16 QA — REQUIRES REAL-DEVICE VERIFICATION

The owner confirmed V1 installs and launches on iPhone 16 and records video with microphone audio into Photos. Other physical-device checkboxes remain unmarked until tested; repeat recording checks on version 1.1. The verified GitHub build checks at the bottom are marked with evidence in [VERIFICATION.md](VERIFICATION.md). Start with a ten-second take. Complete the short tests before trying long recordings. Keep example scripts and videos private. Record iOS version, displayed format, front/rear camera, and each result in your private notes.

## Camera

- [ ] Front camera preview works.
- [ ] Rear wide-camera preview works.
- [ ] Camera switches while idle.
- [ ] Camera/quality controls are disabled during starting, recording and finishing.
- [ ] Exact 3840 × 2160 · 60 FPS is selected when supported, separately for front and rear.
- [ ] Select 1080p30 and check the selected label changes; then select 4K60 again.
- [ ] Fallback notice and usable supported format appear on a camera/device without 4K60 (cannot force absent hardware on iPhone 16; simulator tests cover policy only).
- [ ] Close/reopen and Retry camera restore capture after interruption.

## Recording

- [ ] Record starts and red square appears.
- [ ] Elapsed recording time advances.
- [ ] Immediate Stop during starting does not hang.
- [ ] Repeated Record/Stop taps do not create overlapping takes or a crash.
- [ ] Stop finalizes and the app confirms saving.
- [ ] Finished video appears in Photos.
- [ ] Voice/audio exists and stays synchronized with picture.
- [ ] Teleprompter text, background and controls are absent from saved video.
- [ ] Saved video's actual dimensions/FPS match the selected configuration. Inspect a privately exported file using MediaInfo on Windows or an equivalent local tool; the status label alone is not output evidence. Allow for container-reported fractional/average frame-rate measurement and report discrepancies to Codex.
- [ ] Front preview is mirrored; saved front video is unmirrored.
- [ ] Two or more successive takes work without relaunching.

## Teleprompter

- [ ] Paste, edit, clear (with confirmation), and reopen a script.
- [ ] Long script (at least several thousand words) lays out and scrolls smoothly while recording.
- [ ] Play moves visible text upward for a one-line script, a medium script and a long script in portrait and landscape.
- [ ] The final line can move completely through the readable region before Play pauses.
- [ ] Idle rotation, font/width changes and temporary layout resizing do not stop Play prematurely; the reading position is retained where the new layout permits.
- [ ] Pause leaves the same reading position.
- [ ] Resume continues from that position.
- [ ] Restart returns to the beginning.
- [ ] Reaching the end pauses the script, and does not stop the video recording.
- [ ] Speed adjustment changes reading pace.
- [ ] Font adjustment improves readability without a crash.
- [ ] Width adjustment works in both orientations.
- [ ] Vertical position moves the region up/down and persists.
- [ ] Text/background opacity work over bright and dark scenes.
- [ ] Manual scrolling pauses automation; Play resumes from the manually selected position.
- [ ] Script/settings remain after force-quitting and reopening.
- [ ] Recording and scrolling prevent automatic screen sleep while the app is active.

## Orientation — test all six camera/orientation combinations

- [ ] Front: portrait UI and saved playback upright.
- [ ] Front: landscape left UI and saved playback upright.
- [ ] Front: landscape right UI and saved playback upright.
- [ ] Rear: portrait UI and saved playback upright.
- [ ] Rear: landscape left UI and saved playback upright.
- [ ] Rear: landscape right UI and saved playback upright.
- [ ] Automatic rotation with Portrait Orientation Lock OFF: both landscape sides show upright text, accessible side controls, and the correct status.
- [ ] With Portrait Orientation Lock ON: automatic mode stays portrait and explains the likely lock; test the manual Landscape left/right menu. If iOS refuses, the error explains unlock/retry and does not claim a rotation succeeded.
- [ ] Manual Portrait/left/right choices rotate the actual interface and preview before Record can be pressed.
- [ ] Inspect exported landscape files: 3840×2160 or 1920×1080 (selected mode), upright 16:9 playback, with both cameras and both landscape sides.
- [ ] A 180-degree idle turn between landscape sides updates preview/status even though the view size is unchanged.
- [ ] Accidental rotation during a take: file orientation remains the starting orientation. No crash or new orientation halfway through; keep the phone fixed for normal use.
- [ ] Face-up/down orientation does not overwrite the last usable interface orientation.

## Permissions, interruptions, saving and recovery

- [ ] Deny Camera: human-readable instructions; no crash. Allow it later and Retry camera works.
- [ ] Granted microphone permission + active preview shows Microphone ready, and saved audio still exists.
- [ ] During audio interruption the status distinguishes interruption from denied permission; after recovery the stale warning clears.
- [ ] Deny Microphone: clear explanation; no silent video-only take starts. Re-enable it in Settings and retry: the denied message clears.
- [ ] Deny Photos/add access: recording finalizes and remains under Kept videos.
- [ ] Restore Photos access, Save to Photos succeeds, local retained file is removed.
- [ ] Export a retained recording to Files and play the exported copy.
- [ ] Relaunch with a retained recording: it is still listed and save/export work.
- [ ] Lock/background during a take: recording stops, file finalizes/retains, capture can resume on returning.
- [ ] Incoming call or audio interruption during a take: useful message and finalized/retained file; capture works afterward.
- [ ] Connect/disconnect an audio accessory before recording; selected microphone audio is present. Report incompatible accessories.
- [ ] Very low storage: new recording is refused clearly; OS out-of-space error does not silently discard the file.
- [ ] Observe normal/serious thermal warnings if they occur naturally; minor heat does not arbitrarily stop a take. Do not deliberately overheat the phone.
- [ ] An incomplete/unplayable file is retained with an explanation, not deleted or falsely reported as saved.

## Long recordings — physical device only, no timed CI camera tests

Keep the phone powered/charged as appropriate, stable and ventilated, with enough storage. Prefer a short 4K60 check first; perform long takes in the format you actually intend to use. Inspect playback near the beginning, middle and end for audio sync and verify duration in Photos.

- [ ] Five minutes.
- [ ] Ten minutes.
- [ ] Twenty minutes.
- [ ] Thirty minutes.
- [ ] Longer take if needed; no artificial duration limit.

## Windows build and installation

- [x] GitHub workflow is green and its logs identify stable Xcode/SDK.
- [x] Unit tests pass and physical `iphoneos` Release build succeeds with signing off.
- [x] Artifact contains `Teleprompter.ipa`, itself containing `Payload/Teleprompter.app`.
- [ ] AltServer installs AltStore using the free Apple ID.
- [x] Owner confirmed AltStore signs and installs the V1 IPA.
- [x] Owner confirmed V1 launches on iPhone 16.
- [ ] AltStore refresh renews both app expiry dates without paying.
- [ ] Updating the IPA preserves script/settings (same bundle identifier/signing account).

V1 completion requires build/install evidence and the core camera/recording/overlay/orientation tests above. An untested long-duration claim must remain explicitly unverified.
