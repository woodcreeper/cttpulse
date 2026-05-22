# Direct Distribution

This document covers the fast-track customer beta path for CTT Pulse: a Developer ID signed, notarized macOS DMG hosted by CTT instead of distributed through the Mac App Store.

Use this path for early customer testing and feedback. Keep the App Store path in `docs/APP_STORE.md` for the later public listing/TestFlight workflow.

## What Customers Get

- A standard `.dmg` download.
- A `CTT Pulse.app` bundle they drag into `/Applications`.
- Gatekeeper trust through Developer ID signing and Apple notarization.
- First-run setup inside the app: API access, project selection, device selection, and notification preferences.

Customers do not need Xcode, Swift, or a developer account.

## Signing Model

Direct distribution uses:

- Bundle ID: `com.celltracktech.CTTPulse`
- Team ID: `62QT5L9L6J`
- Signing identity: `Developer ID Application: Cellular Tracking Technologies LLC (62QT5L9L6J)`
- Export options: `Config/DeveloperID/ExportOptions.plist`
- Notary profile: `cttpulse-notary` in the local Keychain

The app remains sandboxed and keeps outbound network access for the CTT API and MapKit.

## Required CTT Developer Account Access

The release Mac must have Xcode signed into an Apple Developer account that can access the CTT organization team:

- Entity name: `Cellular Tracking Technologies LLC`
- Team ID: `62QT5L9L6J`
- Required access: Certificates, Identifiers & Profiles access for Developer ID signing

If Apple Developer shows "Access Unavailable" for Certificates, Identifiers & Profiles, the Account Holder or an Admin must grant the release account enough access before packaging can succeed. For the current CTT organization, the Account Holder shown by Apple is Casey Halverson.

After access is granted, add the work Apple Account in Xcode:

1. Open Xcode.
2. Open Xcode -> Settings -> Accounts.
3. Add or select `david.lapuma@celltracktech.com`.
4. Confirm the `Cellular Tracking Technologies LLC` team appears.
5. Let Xcode download or create managed signing assets for the team.

The packaging script uses Xcode automatic signing and will fail fast if Xcode cannot access Team ID `62QT5L9L6J`.

## One-Time Notary Setup

The packaging script requires a local `notarytool` Keychain profile. Do not put Apple ID passwords, app-specific passwords, API keys, or `.p8` files in the repository.

Create an Apple app-specific password:

1. Open [account.apple.com](https://account.apple.com/).
2. Go to Sign-In and Security.
3. Create an app-specific password named `CTT Pulse Notary`.
4. Keep the generated password visible only long enough to enter it into the local command below.

Then run this in Terminal, not in chat:

```bash
xcrun notarytool store-credentials "cttpulse-notary" \
  --apple-id "YOUR_APPLE_ID_EMAIL" \
  --team-id "62QT5L9L6J"
```

`notarytool` prompts securely for the app-specific password and validates the credentials before saving them to Keychain.

Verify setup:

```bash
./script/developer_id_preflight.sh
```

## Build A Release DMG

Run:

```bash
./script/package_developer_id.sh
```

The script:

1. runs `swift test`,
2. archives the Xcode target,
3. exports a Developer ID signed app,
4. verifies the signing authority and Team ID,
5. creates a DMG with `CTT Pulse.app` and an `/Applications` shortcut,
6. submits the DMG to Apple notarization,
7. staples the notarization ticket,
8. validates the stapled DMG with Gatekeeper,
9. writes a SHA-256 checksum next to the DMG.

Output lands in:

```text
build/DeveloperID/
```

The release artifact is named like:

```text
CTT Pulse-0.1.0+1.dmg
CTT Pulse-0.1.0+1.dmg.sha256
```

## Diagnostic Packaging Only

For local packaging diagnostics, this command produces a signed but unnotarized DMG:

```bash
./script/package_developer_id.sh --skip-notarization
```

Do not publish that DMG. Gatekeeper will reject it as unnotarized Developer ID software.

## Website Release Checklist

Before posting a DMG publicly:

- Run `swift test`.
- Run `./script/developer_id_preflight.sh`.
- Run `./script/package_developer_id.sh`.
- Install the stapled DMG on a clean Mac user account.
- Confirm first-run API setup succeeds.
- Confirm Keychain token persistence after quit/relaunch.
- Confirm CTT network calls, MapKit, notifications, and outside-click dismissal work in the sandboxed build.
- Confirm no screenshot, release note, file name, or metadata exposes customer credentials, private project names, device aliases, animal names, or precise active field locations.

Recommended website fields:

- App name: `CTT Pulse`
- Version and build
- Release date
- macOS requirement
- DMG download link
- SHA-256 checksum
- Short release notes
- Support contact
- Privacy policy link

## Customer Install Instructions

1. Download the DMG from CTT.
2. Open the DMG.
3. Drag `CTT Pulse.app` into Applications.
4. Launch CTT Pulse.
5. Enter CTT API access in Settings.
6. Choose projects/devices in Filters.
7. Choose in-app and macOS notification preferences.

If macOS asks for notification permission, allow it only if external macOS notifications are desired. In-app island alerts work without Notification Center permission.
