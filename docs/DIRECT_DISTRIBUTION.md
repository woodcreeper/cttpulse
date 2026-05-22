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
- Developer ID signing
- Apple notarization
- Hardened runtime
- App Sandbox

The app remains sandboxed and keeps outbound network access for the CTT API and MapKit.

## Primary Xcode Release Flow

Use Xcode Organizer as the primary release path. This is the most reliable path for manual releases because Xcode can handle Apple-managed signing and notarization flows that do not behave the same way through `xcodebuild -exportArchive`.

1. Open `CTT Pulse.xcodeproj`.
2. Select the `CTT Pulse` scheme.
3. Choose Product -> Archive.
4. When the archive appears in Organizer, choose Distribute App.
5. Choose the direct distribution / Developer ID signed app path.
6. Let Xcode manage signing.
7. Wait for Apple notarization approval.
8. Export the signed/notarized app.
9. Package the exported `CTT Pulse.app` in a DMG before posting it for customers.

Before release, confirm Organizer signs with the intended developer team:

- Entity name: `Cellular Tracking Technologies LLC`
- Team ID: `62QT5L9L6J`

If the release is intentionally signed under a different team during testing, do not publish it as the CTT customer build.

## Package Xcode Export As A DMG

After Xcode exports a signed/notarized `CTT Pulse.app`, create a simple drag-install DMG:

```bash
mkdir -p build/ManualDMG/DMGRoot
ditto "PATH/TO/XCODE/EXPORT/CTT Pulse.app" "build/ManualDMG/DMGRoot/CTT Pulse.app"
ln -sf /Applications "build/ManualDMG/DMGRoot/Applications"
hdiutil create \
  -volname "CTT Pulse" \
  -srcfolder "build/ManualDMG/DMGRoot" \
  -ov \
  -format UDZO \
  "build/ManualDMG/CTT Pulse.dmg"
shasum -a 256 "build/ManualDMG/CTT Pulse.dmg" > "build/ManualDMG/CTT Pulse.dmg.sha256"
```

If Xcode exported a notarized app, the app inside the DMG should pass Gatekeeper. Validate on a clean Mac user account before publishing.

## Optional CLI Packaging

The repo also includes a command-line packaging script for future automation or CI. Treat it as an advanced path. It may require additional Apple Developer role/certificate setup even when the Xcode Organizer flow succeeds.

The script uses:

- Export options: `Config/DeveloperID/ExportOptions.plist`
- Notary profile: `cttpulse-notary` in the local Keychain

Do not put Apple ID passwords, app-specific passwords, API keys, or `.p8` files in the repository.

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

Build a CLI release DMG:

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

### Diagnostic Packaging Only

For local packaging diagnostics, this command produces a signed but unnotarized DMG:

```bash
./script/package_developer_id.sh --skip-notarization
```

Do not publish that DMG. Gatekeeper will reject it as unnotarized Developer ID software.

## Website Release Checklist

Before posting a DMG publicly:

- Run `swift test`.
- Create the signed/notarized app through Xcode Organizer, or run the optional CLI package script if that path is configured.
- Package the exported app as a DMG.
- Install the DMG on a clean Mac user account.
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
