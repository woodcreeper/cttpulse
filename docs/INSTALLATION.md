# Installation

CTT Pulse currently supports source-based installation for macOS 26+ users with Apple's developer tools installed. Packaged, signed, notarized releases are planned but not yet available.

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

This repository is ready for local source builds. It is not yet ready as a double-click installer for non-developer users.

Before publishing packaged releases, the app still needs:

- Developer ID signing,
- hardened runtime,
- notarization,
- release bundle generation,
- DMG or installer packaging,
- optional auto-update.
