# App Store Distribution

This document tracks what CTT Pulse needs before it can ship through the Mac App Store.

Official Apple references:

- [Distributing your app for beta testing and releases](https://developer.apple.com/documentation/xcode/distributing-your-app-for-beta-testing-and-releases)
- [Uploading apps to App Store Connect](https://developer.apple.com/help/app-store-connect/manage-builds/upload-builds/)
- [App Sandbox entitlement](https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.security.app-sandbox)
- [App privacy details](https://developer.apple.com/app-store/app-privacy-details/)
- [Privacy manifest files](https://developer.apple.com/documentation/bundleresources/privacy_manifest_files)

## Current State

The repo currently builds a local development app from SwiftPM:

```bash
./script/build_and_run.sh
```

That script stages:

```text
dist/CTT Pulse.app
```

This is useful for development and manual QA, but it is not yet a Mac App Store archive. The local bundle is ad-hoc signed and does not include an App Store provisioning profile or Team ID.

## Added App Store Prep

The repo includes these distribution prep files:

- `Config/AppStore/CTTPulse.entitlements`
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
3. Final bundle identifier, likely `com.celltracktech.CTTPulse` or another organization-owned ID.
4. Mac App Store signing certificate/provisioning profile.
5. A real Xcode app target/archive workflow.
6. App icon asset set.
7. App category, version, build number, copyright, and support URLs.
8. Privacy policy URL and completed App Store privacy questionnaire.
9. Screenshots for supported Mac display sizes.
10. Review of App Sandbox compatibility.

## Xcode Project Work

The current SwiftPM package is clean for development, but App Store release should be driven by an Xcode app target so Xcode can archive, sign, validate, and upload the app.

Recommended structure:

```text
CTTPulse.xcodeproj
  CTTPulse macOS app target
    Bundle ID: organization-owned final ID
    Sources: Sources/CTTPulseApp + Sources/CTTPulseCore
    Resources: Resources/PrivacyInfo.xcprivacy + app icon assets
    Entitlements: Config/AppStore/CTTPulse.entitlements
    Signing: automatic, Apple Developer team
```

Keep the SwiftPM package as the source of truth for tests and fast local development. The Xcode project should be the release wrapper around the same source files.

## App Review Risks To Validate

- The notch-adjacent floating panel should be described as a menu bar/notch companion, not as iOS Dynamic Island.
- The app must remain useful on Macs without a notch.
- Sandbox behavior must be tested with Keychain storage, CTT network calls, MapKit, notifications, and the outside-click monitor.
- App Store metadata must not include customer credentials, PATs, screenshots with sensitive telemetry, or private project names.

## First Submission Checklist

Before uploading the first build:

```bash
swift test
./script/build_and_run.sh --verify
./script/app_store_preflight.sh --strict
```

Then archive and upload from Xcode using Product -> Archive once the Xcode project, signing team, bundle ID, and App Store Connect app record are ready.
