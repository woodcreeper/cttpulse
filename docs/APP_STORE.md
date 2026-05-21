# App Store Distribution

This document tracks what CTT Pulse needs before it can ship through the Mac App Store.

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

- The notch-adjacent floating panel should be described as a menu bar/notch companion, not as iOS Dynamic Island.
- The app must remain useful on Macs without a notch.
- Sandbox behavior must be tested with Keychain storage, CTT network calls, MapKit, notifications, and the outside-click monitor.
- App Store metadata must not include customer credentials, PATs, screenshots with sensitive telemetry, or private project names.

## First Submission Checklist

Before uploading the first build:

```bash
swift test
xcodebuild -scheme "CTT Pulse" -configuration Release -destination 'platform=macOS' build
./script/build_and_run.sh --verify
./script/app_store_preflight.sh --strict
```

Then archive and upload from Xcode using Product -> Archive once the App Store Connect app record, signing certificate/profile, icon, privacy details, and screenshots are ready.
