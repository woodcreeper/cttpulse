# App Store Distribution

This document tracks what CTT Pulse needs before it can ship through the Mac App Store.

For the faster hosted-DMG customer beta path, see [Direct Distribution](DIRECT_DISTRIBUTION.md).

Official Apple references:

- [Distributing your app for beta testing and releases](https://developer.apple.com/documentation/xcode/distributing-your-app-for-beta-testing-and-releases)
- [Uploading apps to App Store Connect](https://developer.apple.com/help/app-store-connect/manage-builds/upload-builds/)
- [App Sandbox entitlement](https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.security.app-sandbox)
- [App privacy details](https://developer.apple.com/app-store/app-privacy-details/)
- [Privacy manifest files](https://developer.apple.com/documentation/bundleresources/privacy_manifest_files)

## Current State

The repo has two supported build paths:

- SwiftPM for fast local development and tests.
- `CTT Pulse.xcodeproj` for Xcode signing, archiving, validation, and App Store Connect upload.

The SwiftPM development app still builds with:

```bash
./script/build_and_run.sh
```

That script stages:

```text
dist/CTT Pulse.app
```

This is useful for development and manual QA, but it is not the Mac App Store archive. The local SwiftPM bundle is ad-hoc signed and does not include an App Store provisioning profile or Team ID.

The Xcode project builds the real app target with:

```bash
xcodebuild -scheme "CTT Pulse" -configuration Debug -destination 'platform=macOS' build
xcodebuild -scheme "CTT Pulse" -configuration Release -destination 'platform=macOS' build
```

## Added App Store Prep

The repo includes these distribution prep files:

- `Config/AppStore/CTTPulse.entitlements`
- `Resources/Assets.xcassets/AppIcon.appiconset`
- `Resources/CTTPulse.icns`
- `Resources/PrivacyInfo.xcprivacy`
- `Config/AppStore/ExportOptions.plist`
- `script/app_store_preflight.sh`

The entitlements enable:

- App Sandbox
- outbound network client access for the CTT API and MapKit

The privacy manifest currently declares no tracking and documents UserDefaults usage for local app preferences. App Store Connect privacy labels still need a business/legal review before submission, especially because CTT account credentials and telemetry project data flow through CTT services.

## Preflight

Build the local app and run the preflight:

```bash
./script/build_and_run.sh --verify
./script/app_store_preflight.sh
```

The preflight checks:

- bundle metadata,
- App Store entitlements file,
- copied privacy manifest,
- current signing state,
- local distribution signing identities,
- whether an Xcode project/workspace exists.

Warnings are expected until the App Store project/signing work is complete.

## Required Before App Store Upload

1. Apple Developer Program membership.
2. App Store Connect app record for CTT Pulse.
3. Final bundle identifier. The Xcode target currently uses `com.celltracktech.CTTPulse`.
4. Mac App Store signing certificate/provisioning profile.
5. Final review of the app icon and App Store marketing artwork.
6. App category, version, build number, copyright, and support URLs.
7. Privacy policy URL and completed App Store privacy questionnaire.
8. Screenshots for supported Mac display sizes.
9. Review of App Sandbox compatibility.

## Xcode Project

```text
CTT Pulse.xcodeproj
  CTT Pulse macOS app target
    Bundle ID: com.celltracktech.CTTPulse
    Sources: Sources/CTTPulseApp + Sources/CTTPulseCore
    Resources: Resources/Assets.xcassets + Resources/PrivacyInfo.xcprivacy
    Entitlements: Config/AppStore/CTTPulse.entitlements
    Signing: automatic, Apple Developer team 33XYKMGGZ7
```

Keep the SwiftPM package as the source of truth for tests and fast local development. The Xcode project is the release wrapper around the same source files.

## App Review Risks To Validate

- The top-center floating panel should be described as a macOS menu bar/notch companion. Avoid iOS-only feature names in store copy.
- The app must remain useful on Macs without a notch through the menu bar item, settings window, and main detail window.
- Sandbox behavior must be tested with Keychain storage, CTT network calls, MapKit, notifications, and the outside-click monitor.
- App Store metadata must not include customer credentials, PATs, screenshots with sensitive telemetry, or private project names.

## Store Metadata Guardrails

Store-facing text lives in `Config/AppStore/Metadata/`. Use those files as the source for App Store Connect fields unless the final business/legal review changes the copy.

Metadata rules:

- Describe CTT Pulse as a macOS menu bar/notch companion or top-center companion.
- Do not use iOS-only feature names.
- Do not include real customer credentials, API tokens, project names, device aliases, animal names, email addresses, or precise active field coordinates.
- Use only sanitized demo screenshots staged under `Config/AppStore/Screenshots/`.

The preflight script scans the metadata files and screenshot filenames for high-risk wording before upload prep.

## Sandbox QA

Before submitting a build, run or manually verify these sandbox-sensitive flows from the Xcode-built app:

- Keychain: save API access, quit, relaunch, and confirm the app reconnects without re-entering the token.
- CTT network: refresh account/projects/devices from the CTT customer API.
- MapKit: open a selected device with coordinates and confirm the map tiles and point popovers render.
- Notifications: enable macOS notifications and verify a test/fresh event appears through Notification Center.
- Outside-click monitor: open the top-center panel, click outside it, and confirm it dismisses without trapping focus.
- Non-notch access: open the app on a display without a camera notch or with the panel ignored, then confirm the menu bar item, settings window, and main detail window cover the full workflow.

## First Submission Checklist

Before uploading the first build:

```bash
swift test
xcodebuild -scheme "CTT Pulse" -configuration Release -destination 'platform=macOS' build
./script/build_and_run.sh --verify
./script/app_store_preflight.sh --strict
```

Then archive and upload from Xcode using Product -> Archive once the App Store Connect app record, signing certificate/profile, icon, privacy details, and screenshots are ready.

Command-line archive/upload path:

```bash
xcodebuild -scheme "CTT Pulse" \
  -configuration Release \
  -destination 'generic/platform=macOS' \
  -archivePath "$PWD/build/AppStore/CTT Pulse.xcarchive" \
  -allowProvisioningUpdates \
  archive

xcodebuild -exportArchive \
  -archivePath "$PWD/build/AppStore/CTT Pulse.xcarchive" \
  -exportPath "$PWD/build/AppStore/Upload" \
  -exportOptionsPlist "$PWD/Config/AppStore/ExportOptions.plist" \
  -allowProvisioningUpdates
```

The App Store Connect app record must already exist for bundle ID `com.celltracktech.CTTPulse`; otherwise export/upload fails while downloading app information.
