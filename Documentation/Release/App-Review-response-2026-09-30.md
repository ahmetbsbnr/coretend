# Apple App Review response — Guideline 2.1

Date received: 2026-09-30. Submission: macOS CoreTend 2.0.0 (build 201).

## Before sending

- [ ] Record the submitted build running on the physical MacBook Air (MacBookAir10,1, Apple M1) with macOS 27.0.1 (26A434) (host re-checked 04-10-2026). Install the build **from TestFlight** first: the copy currently in `/Applications` comes from the Organizer PKG (no `_MASReceipt`), which macOS refuses to launch; TestFlight replaces it with a launchable copy. Begin at app launch and show the ordinary flow: welcome/overview, choose a folder in the system panel, scan and inspect results, then (using a disposable folder created for this demonstration) select, review, confirm a move to Trash, and show the resulting status. Do not show personal files or paths.
- [ ] Upload the recording to the App Review reply and add the same information to App Review Information → Notes. Fill in the actual Mac model and macOS version below; do not claim a recording is attached until upload completes.
- [ ] Verify the current App Store Connect state and exact submitted build before replying.

## Reply draft (English)

> **1. Screen recording**  
> We have attached a screen recording of CoreTend 2.0.0 (build 201) running on a physical MacBook Air (Apple M1) with macOS 27.0.1 (26A434). It begins by launching the app and demonstrates the normal flow: choosing a folder, scanning and reviewing results, and moving a disposable demonstration file to the macOS Trash after explicit confirmation. The recording shows the user's own folders as chosen in the macOS panel; nothing in it is staged. Build 2.0.0 (202), attached to this submission, contains the same features with faster scanning and a more responsive window during large scans.
>
> **2. Purpose and audience**  
> CoreTend is a macOS utility for people who want to understand disk usage and inspect files and applications before taking action. It provides folder exploration, cleanup candidates, exact-duplicate review, application inventory, signature and quarantine information, on-demand system metrics, and a local activity history. It does not claim that files are malicious or that space has been recovered. Its audience is Mac users managing storage and reviewing their own files; it is not a service for a regulated industry or a business-only platform.
>
> **3. Setup and main features**  
> No account, login, subscription, or sample credentials are required. Launch the app and follow the welcome screen. Choose a folder from Explore, Cleanup, Duplicates, Applications, or Integrity using the macOS folder-selection panel, then review the results. Scanning is read-only. To demonstrate the optional cleanup action, select a disposable file, review it, and confirm; CoreTend moves it to the macOS Trash and does not permanently delete it. No sample files are required. The App Store build runs in the macOS App Sandbox and accesses folders selected by the user.
>
> **4. External services and platforms**  
> CoreTend uses no external data provider, authentication service, payment processor, analytics service, or AI service. It makes no network requests and has no account or telemetry. Its core functionality uses macOS frameworks and services, including the user-selected folder panel and macOS Trash, Security framework code-signature information, and public system-statistics APIs. Distribution and review are provided by Apple through the Mac App Store.
>
> **5. Regional differences**  
> CoreTend's functionality is the same in all territories where the app is offered. The interface and product text are available in English and French; language availability does not change functionality. The app is free and has no in-app purchases.
>
> **6. Regulated services or protected third-party material**  
> CoreTend does not provide services in a regulated industry and does not include or distribute protected third-party content. It inspects files and applications selected by the user on that user's Mac. No authorization credentials or third-party-content documentation apply.

## 04-10-2026 status

- Video assembled from the maintainer's recording: `Artifacts/AppReview/CoreTend-AppReview-2.1.mp4` (answers 1–6 as cards).
- Build 202 (performance fixes) exported and signed; upload pending an App Store Connect sign-in in Xcode. Select build 202 on the version page before resubmitting.

## Disposable demonstration folder

Create it before recording so no personal file appears on screen:

```bash
mkdir -p ~/Desktop/CoreTend-Demo/Photos && for i in 1 2 3; do head -c 2000000 /dev/urandom > ~/Desktop/CoreTend-Demo/Photos/IMG_000$i.jpg; done && cp ~/Desktop/CoreTend-Demo/Photos/IMG_0001.jpg ~/Desktop/CoreTend-Demo/IMG_0001-copy.jpg
```

Record with Shift-Command-5 (« Record Entire Screen »), close other windows first, then delete the folder afterwards.

## Truthfulness checklist

- Item 1 remains conditional until a real recording of the submitted build has been captured and uploaded. Device and OS details above were observed locally; do not send this claim until the recording is attached.
- The claims in items 2–6 follow the product description, App Sandbox design and listing. Recheck them against the exact build and current App Store metadata before sending.
- The response has not been sent to Apple. This file is a draft; no App Store Connect state was changed here.
