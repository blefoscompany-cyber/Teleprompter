# Teleprompter Camera

A personal iPhone camera app: read a scrolling script over the live preview while recording camera video and microphone audio. The script and buttons do **not** appear in the saved video. There is no backend, account, tracking, watermark, paid API, or recording-duration timer.

**Current status: GitHub/Xcode compilation, all 11 app tests, and unsigned IPA packaging have passed. The downloaded IPA has been verified. AltStore installation and real iPhone testing are next; V1 is not yet certified complete.** Open the [successful build and IPA artifact](https://github.com/blefoscompany-cyber/Teleprompter/actions/runs/37650602886). See [verification status](docs/VERIFICATION.md) and [iPhone checklist](docs/QA.md).

## What you need — no Mac

- Windows 10/11 PC, iPhone 16, Apple ID, and GitHub account.
- Free **AltStore Classic** and **AltServer for Windows**. AltStore PAL is a different product and is not this workflow.
- A USB cable to set up the phone. The iPad is not needed.
- Internet to build/download the app and renew Apple's signing. Camera recording and scripts work offline after installation, while signing remains valid.

The app requests an exact **3840 × 2160 at 60 FPS** camera format. It uses supported frame-rate ranges, not a generic “high quality” preset. If that combination is unavailable, the screen shows the actual selected format and a fallback notice. Native HEVC recording is preferred to reduce storage use. The rear wide camera and front camera are supported; additional rear lenses and mid-recording switching are outside V1.

### Staying at ₹0 / $0

Use a **public source repository** and the standard GitHub-hosted macOS runner in this project. Standard GitHub-hosted runners are free for public repositories under GitHub's current policy. A private repository has included usage quotas; macOS can consume those quickly. Do not choose a paid larger runner, add a payment method for extra builds, or enable paid usage. This project uploads small app artifacts for seven days and diagnostic logs for three days. Delete old artifacts if GitHub reports a storage quota; don't buy storage.

Only application source goes to GitHub. Your scripts and recordings stay on the iPhone. Never upload scripts, personal videos, Apple credentials, certificates, or provisioning profiles. The build uses no GitHub secrets or Apple signing account. Apple's free signing normally lasts **seven days**, and limits the number of installed apps/App IDs. AltStore counts toward those limits. Service rules and supported Windows components may change; official links below are the reference if an installer screen differs.

## Use the app

1. On first launch, allow **Camera**, **Microphone**, and adding videos to **Photos** when iOS asks. Photos permission is only for adding videos; the app doesn't browse your library.
2. Tap the **document icon** at the bottom. Paste your script into the editor by touching and holding in the text area, then choosing **Paste**. Tap **Done**. Edits save automatically. The first installation starts with an empty script.
3. Tap the camera button at the top to choose **Front** or **Rear**. Do this before recording.
4. Hold the phone upright for Reels or horizontally for YouTube. If it won't rotate, open Control Center and turn off the padlock-with-circular-arrow **Portrait Orientation Lock**. Check the on-screen orientation before recording.
5. Tap the **sliders icon**. Set text size, speed, width, vertical position, and opacity. Position **0% is at the top**, 100% at the bottom. Place the reading area near the physical lens; in landscape the front lens is at a side of the phone, so center placement will not align perfectly with it. Tap **Done**.
6. Tap the **red circle** to record. Then tap **Play** to scroll your script. These are independent controls; you can rehearse scrolling without recording.
7. **Pause** freezes the script; **Play** resumes. Swiping the text scrolls manually and pauses automatic scrolling. The **back-to-start icon** returns the script to its beginning.
8. Tap the **red square** to stop. Wait for **Video saved to Photos**. Open Apple's Photos app to watch the result.

Keep the phone in its starting orientation throughout the take. The file's orientation is fixed when you press Record. The front preview is mirrored to help frame yourself; the saved front video is not mirrored. The preview fits the video frame without cropping it, so black bars can appear around it.

There is no app duration limit. Long 4K60 takes use substantial storage and battery, and can heat the phone. The app warns about low storage/serious heat, refuses to start below 500 MB free, and lets AVFoundation stop near its storage reserve. Critical heat stops a take to protect the phone and preserve its file. Normal/minor heat does not stop recording. Incoming calls, locking the screen, switching away from the app, or iOS camera restrictions may end a take; this is a foreground camera app.

### If saving fails

The completed `.mov` stays in the app's **Documents/Recordings** folder until Photos reports success. A **tray icon** appears for kept videos. Open it and tap **Save to Photos** after fixing permission/storage, or **Export** to copy the file to Files or another destination you select. Kept videos are listed again after reopening the app. Do not delete/reinstall the app while it contains videos you need. A file interrupted before AVFoundation could finalize it may be unplayable; the app retains it but cannot promise recovery. File Sharing is enabled for copying the Recordings folder with Apple's Windows device software. Recordings are excluded from the app's device backup.

## Project folders

| Path | Purpose |
| --- | --- |
| `Sources/App` | App entry point |
| `Sources/Camera` | Capture session, format setup, audio/video output, preview, interruptions |
| `Sources/Teleprompter` | Native scrolling text and play/pause/restart |
| `Sources/Views` | Camera screen, settings, editor, retained recordings |
| `Sources/Models` | Locally saved settings and testable format selection |
| `Sources/Utilities` | Permissions and safe Photos saving |
| `Tests` | Format fallback and settings persistence tests |
| `project.yml` | XcodeGen project definition; maintained on Windows |
| `Resources` | Generated Info.plist and app resources |
| `.github/workflows/build-ios.yml` | macOS tests, iPhone build, unsigned IPA artifact |
| `scripts` | Simulator selection and IPA packaging/checks |
| `docs` | QA, engineering notes, and verification status |

An `.xcodeproj` and `Resources/Info.plist` are generated from `project.yml`. Don't edit the generated project to make a lasting change. No third-party packages are linked into the app. XcodeGen is only a build tool on GitHub's Mac runner.

## Tell Codex what to change

Open this project folder in Codex and describe the result in ordinary language. For example: “The text is too far from the lens in landscape,” or “Here is the failed GitHub run; please fix it.” Codex should inspect this repository, change the source/project definition, run available checks, make a clear commit, and help publish the update. You do not need to edit Swift or configure signing. [AGENTS.md](AGENTS.md) records these operating rules.

## Get the code into GitHub from Windows

The source folder is named **Teleprompter**. If Codex has already connected and pushed a repository, skip to building below. If there is no remote repository yet, use these exact steps; Codex can help you through one at a time.

1. Install [GitHub Desktop for Windows](https://desktop.github.com/download/). Open it and sign in to your GitHub account.
2. Click **File → Add local repository**. Click **Choose** and select the **Teleprompter** project folder that contains this README and `project.yml`. Click **Add repository**. If it says this isn't a Git repository, click **create a repository here**, keep the name **Teleprompter**, and create it in this folder.
3. If the Changes tab shows the imported files, enter **Import teleprompter app** in the Summary box and click **Commit to main**.
4. Click **Publish repository**. Keep the name **Teleprompter**. **Uncheck “Keep this code private”** for the free public-runner path. Click **Publish repository**. Only app source should be in the upload.
5. Click **Repository → View on GitHub**. Send the resulting browser link to Codex so it can inspect build runs and fix failures for you.

If you created an empty repository in your browser first, send its link to Codex before publishing a second repository; Codex can connect the existing one. Never paste an Apple password or a GitHub token into this chat or any project file.

After Codex makes a later change, open GitHub Desktop. If it shows uncommitted changes, Codex should commit them; otherwise click **Push origin** when available. If Codex has already pushed, no extra push is necessary. Source changes reaching `main` automatically start a build.

## Build the IPA — GitHub does the Apple compilation

1. Open your repository in your browser.
2. Click **Actions** near the top. If GitHub asks to enable workflows, enable them for this repository.
3. Click **Build iOS IPA** in the left sidebar.
4. Click **Run workflow**, keep branch **main**, then click the green **Run workflow** button.
5. A new run appears. Open it. Wait until it finishes; the first run can take several minutes.
6. A green check means tests, the unsigned physical-iPhone build, and IPA verification passed. A red cross means a failed step; send the run link to Codex. Do not pay for anything to fix a compiler failure.

The workflow uses the runner's stable installed Xcode, installs XcodeGen, generates the project, runs meaningful tests on an iPhone simulator, then builds against `iphoneos` for a generic physical iPhone. Code signing and certificate lookup are disabled. It copies the resulting app into `Payload/Teleprompter.app`, zips that folder, checks its platform, permissions and structure, then uploads the IPA.

## Download the IPA on Windows

1. Open the successful run under **Actions**.
2. Scroll to **Artifacts** at the bottom of the run summary.
3. Click **Teleprompter-IPA**. You must be signed into GitHub. Windows downloads a ZIP file.
4. In Windows File Explorer, right-click that ZIP → **Extract All** → **Extract**.
5. Inside the extracted folder is **Teleprompter.ipa**. Keep this file. It is already an IPA; don't unzip it again and don't rename the outer artifact ZIP to `.ipa`.

Artifacts expire after seven days. If the download has expired, run the workflow again. This IPA is intentionally unsigned and cannot install by tapping it directly. AltStore will sign it with your own free Apple ID.

## Install AltServer and AltStore Classic

Use the official [AltStore Classic Windows installation guide](https://faq.altstore.io/altstore-classic/how-to-install-altstore-windows) and [AltStore download site](https://altstore.io/). Screens and Apple's Windows software requirements can change. The steps below describe the Classic workflow; follow the official Windows guide if its component downloads differ.

### Windows preparation

1. Install the **iTunes and iCloud Windows components specified by the official AltStore guide**. Classic Windows setup has historically required Apple's direct-download versions rather than Microsoft Store versions. Use the links in the official guide; do not obtain installers from an unofficial mirror. If Store versions are already present, follow the guide's replacement directions and restart Windows after installation.
2. Download **AltServer for Windows** from the official site. Extract the download, run `setup.exe`, and finish the installer.
3. Open **AltServer** from the Windows Start menu. It runs in the notification area by the clock, not in a large normal window. Click the upward arrow by the clock if you don't see its diamond icon.
4. Connect the iPhone by USB. Unlock it. If the phone asks **Trust This Computer?**, tap **Trust** and enter your iPhone passcode.
5. Open iTunes (or the device-management software instructed by the official guide). Select the phone/device icon. On its Summary page, enable **Sync with this iPhone over Wi-Fi**, click **Apply**, and leave the phone connected for setup.
6. If Windows Firewall asks about AltServer, allow it on your **private/home network** so your iPhone can reach it. Do not disable the firewall.

### Install AltStore on the iPhone

1. Click the **AltServer diamond icon** in Windows' notification area.
2. Choose **Install AltStore → your iPhone's name**.
3. Enter your Apple ID and password **only in AltServer's own sign-in window**. Follow its verification prompt if one appears. Do not put these credentials in GitHub, Codex chat, or a source file. Your Apple ID is used for Apple's free signing, not for an app login in Teleprompter.
4. Wait for AltServer to report success. An **AltStore** icon should appear on the phone.
5. On the iPhone, open **Settings → General → VPN & Device Management**. Under the developer entry for your Apple ID, select it and choose **Trust**, following iOS' confirmation prompts.
6. If iOS requires **Developer Mode**, open **Settings → Privacy & Security → Developer Mode**. Enable it, restart when asked, and confirm **Turn On** after restart. This option may appear only after you attempt the first developer-app install/launch.
7. Open AltStore. Follow its Apple ID sign-in prompt for free signing. Keep AltServer running on Windows and the phone unlocked/connected during setup.

Trusting the developer identity and Developer Mode are separate iOS settings. You do not need to buy an Apple Developer membership.

## Install Teleprompter.ipa

1. Move **Teleprompter.ipa** from Windows to the phone. A no-cloud option is to use USB File Sharing in iTunes/Apple device software: select your iPhone → **File Sharing** → **AltStore** if listed → **Add File**, then select `Teleprompter.ipa`. Open the matching **On My iPhone → AltStore** folder in Files. If your installed AltStore version doesn't expose File Sharing, use the local Windows share method in the next paragraph.
2. On the iPhone, open **AltStore → My Apps**.
3. Tap **+** in the top-left. Browse to the IPA in Files and select it. Keep AltServer running on Windows; use USB or keep both devices on the same home network. Wait for signing and installation.
4. Return to the iPhone home screen and open **Teleprompter**. Allow the permissions. Start with a **10-second test recording**, stop, and check that Photos has both picture and voice with no script overlay.

**Local transfer if File Sharing isn't available:** On Windows, put just the IPA in a new folder. Right-click the folder → **Properties → Sharing → Advanced Sharing**, select **Share this folder**, give it a name such as `TeleprompterIPA`, and keep access limited to your Windows account. Note your PC name in **Settings → System → About**. On the iPhone, open **Files → Browse → … → Connect to Server**. Enter `smb://YOUR-PC-NAME`, choose **Registered User**, and sign in with the Windows account's network credentials (not its Windows Hello PIN). Open the share and copy the IPA to **On My iPhone**. Both devices must be on the same private home network. Turn off the temporary folder share after transfer. This transfer uses no cloud service, API, or hosting subscription. Ask Codex for help if Windows network credentials/sharing are unfamiliar; don't share the password in chat.

To install a later build, use the same IPA-import process and keep the same Apple ID and project bundle identifier. A normal update should retain the saved script/settings. Export kept recordings before any reinstall; **deleting the app deletes its local data**.

## Refresh before the seven days expire

1. Turn on your Windows PC and open AltServer. Keep it running in the notification area.
2. Connect the phone by USB for the most reliable refresh, or put phone and PC on the same Wi-Fi with Wi-Fi sync enabled. Unlock the phone.
3. Open **AltStore → My Apps**. Check the days remaining next to AltStore and Teleprompter.
4. Tap **Refresh All**. Wait for completion and confirm that both show renewed expiry dates.

Do this every few days, before the expiry reaches zero. Background refresh can help but isn't guaranteed; use manual refresh for reliability. If apps have already expired, use AltServer on Windows to reinstall AltStore, then refresh Teleprompter. Avoid deleting Teleprompter to fix expiry because that loses its local data. Once the app launches with valid signing, it doesn't need the PC or internet to record.

## Common problems

| What you see | What to do |
| --- | --- |
| Build has a red cross | Open the failed run and send Codex its browser link. Download **Build-Logs** if requested. Codex should diagnose and fix the code. |
| Actions has no Run workflow button | Check that you're on the repository's default `main` branch, the workflow file was uploaded, and you're signed in as an owner. Enable workflows if GitHub prompts. |
| GitHub says quota/usage limit | Keep spending disabled. Confirm public repository and standard `macos-15` runner; remove old artifacts. Send Codex the exact message. |
| No artifact yet | Wait for the full run to finish. An IPA is uploaded only after tests and compilation succeed. Expired artifacts need a new build. |
| AltServer cannot find the iPhone | Use USB, unlock and trust the computer, confirm Apple's Windows software sees the device, and restart AltServer. For Wi-Fi, check both are on the same home network and Wi-Fi sync is enabled. |
| AltStore cannot find AltServer | Start AltServer on Windows; use USB first. Check Windows Firewall's private-network permission. VPNs and isolated guest Wi-Fi can block discovery. |
| Too many apps or App IDs | Free Apple signing has app/App-ID limits; AltStore itself uses a slot. Review My Apps/App IDs in AltStore. Some identifiers must expire before new ones are available. |
| Untrusted Developer / Developer Mode required | Follow the two iPhone Settings steps above. Don't buy a membership. |
| “App integrity could not be verified” or install fails | Make sure you imported the actual extracted `.ipa` through AltStore, not the artifact ZIP. Check trust, Developer Mode, Apple sign-in, signing limits and network. Send the full error to Codex. |
| Camera/microphone permission denied | Open **Settings → Teleprompter** (or **Settings → Apps → Teleprompter** on newer iOS) and allow Camera/Microphone. Return and tap Retry camera. |
| Saved video doesn't appear in Photos | Wait for saving. Check the app's kept-videos tray, Photos permission, and storage. Retry or export; do not delete the app. |
| Resolution shows “fallback” | That exact requested format isn't available on this camera. The dimensions/FPS shown are the selected supported mode. Try the rear camera, or use 4K30/1080p. |
| Phone gets hot / runs out of space | Stop and save, let it cool, make space, and choose 1080p30 for the next long take. There is no arbitrary duration cutoff. |
| Video appears rotated or audio is missing | Keep the example private. Tell Codex the camera, orientation when Record was pressed, iOS version, displayed format, and whether rotation/accessories/calls happened during the take. |

## Send this to Codex when something fails

- For a build: **failed run link**, step name, and **Build-Logs** if asked. No Apple credentials.
- For installation: exact AltStore/AltServer error or screenshot, Windows version, iOS version, and whether USB or Wi-Fi was used.
- For camera/recording: what you tapped, front/rear camera, displayed resolution/FPS, portrait/landscape, approximate recording length, and the human-readable message. Say whether a retained file appears under Kept videos.
- For a long-take failure: available storage and whether the phone felt hot or an interruption occurred.

Never put your personal script or recording in a public issue. A screenshot of a script should be cropped/covered before sharing.

## Verification

The simulator unit tests validate format-selection policy and local persistence. They cannot prove physical camera, microphone, orientation, Photos, AltStore signing, or 30-minute recording behavior. All those items are **REQUIRES REAL-DEVICE VERIFICATION** in [the manual checklist](docs/QA.md). Codex has inspected the actual GitHub logs, corrected two build/packaging configuration errors, and verified the successful build and downloaded binary. Future build failures should be diagnosed from their actual logs.
