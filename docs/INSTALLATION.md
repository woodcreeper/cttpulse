# Installation

CTT Pulse supports source-based installation for developers and Developer ID signed/notarized DMG releases for non-developer customers.

## Requirements

- macOS 26 or newer.
- Xcode 26 or newer, or a Swift 6.2-compatible command line toolchain.
- A CTT Data Portal Personal Access Token.
- Network access to the CTT customer API.

## Install From Source

Clone the repository:

```bash
git clone https://github.com/woodcreeper/cttpulse.git
cd cttpulse
```

Build and launch:

```bash
./script/build_and_run.sh
```

The script:

1. stops any currently running `CTTPulse` process,
2. runs `swift build --product CTTPulse`,
3. stages a development app bundle at `dist/CTT Pulse.app`,
4. launches the app as a menu-bar/accessory app.

To verify the app launched:

```bash
./script/build_and_run.sh --verify
```

## First Run

1. Launch the app.
2. Open the CTT Pulse menu bar item or move the pointer to the notch/top-center hotspot and click the island.
3. Open Settings.
4. Paste your CTT Personal Access Token.
5. Save the token.
6. Open the Filters tab.
7. Select the projects and devices you want visible and alertable.

The token is stored in the macOS Keychain. It is not written to the repository, UserDefaults, logs, or URLs.

If you previously used a development build named Telemetry Island, CTT Pulse will try to migrate that older Keychain token into the stable CTT Pulse Keychain service on launch. If macOS cannot read the old item silently, it may show a one-time Keychain access dialog. Choose Allow or Always Allow to let CTT Pulse copy the token. If macOS denies access to the old item, save the PAT once in CTT Pulse Settings and future launches should reuse it.

## Updating

Pull the latest source and relaunch:

```bash
git pull
./script/build_and_run.sh
```

## Uninstalling A Development Build

Quit CTT Pulse from the menu bar item, then remove the development bundle:

```bash
rm -rf dist
```

To remove the stored CTT token, use Settings -> Disconnect before deleting the app. That removes the app's Keychain token item.

## Distribution Status

This repository supports Developer ID distribution for double-click customer installs.

For manual releases, use Xcode:

1. Open `CTT Pulse.xcodeproj`.
2. Choose Product -> Archive.
3. In Organizer, choose Distribute App.
4. Export a Developer ID signed/notarized app.
5. Package the exported app as a DMG.

The repo also has an optional command-line packaging workflow for future automation:

```bash
./script/developer_id_preflight.sh
./script/package_developer_id.sh
```

See [Direct Distribution](DIRECT_DISTRIBUTION.md) for Xcode Organizer release steps, optional CLI packaging, website posting, and customer install instructions.

Optional auto-update is not implemented yet.
