# CTT Pulse

A native macOS 26 SwiftUI app that creates a Perch-inspired, top-center notch companion for CTT wildlife telemetry check-ins.

This is a macOS app, not an iOS Dynamic Island or ActivityKit app. The island is a custom AppKit-backed floating panel positioned near the screen notch/menu bar and rendered with SwiftUI liquid-glass-style surfaces.

## What It Does

- Polls the CTT customer API for wildlife telemetry device check-ins.
- Shows a compact notch-adjacent island that stays out of the way until hovered, clicked, or triggered by fresh check-ins.
- Opens into a small translucent telemetry pane with the latest selected check-in, a scrollable recent list, and a mini map.
- Provides a main detail window with a recent check-in sidebar, selected device metadata, and a larger MapKit map.
- Lets the user choose which CTT projects/devices are included in the app and alerts.
- Lets the user choose whether alerts appear in the CTT Pulse island, macOS Notification Center, or both.
- Stores the CTT Personal Access Token in Keychain.
- Detects fresh check-ins without replaying stale alerts on launch.

## Current Feature Set

### Island Behavior

- Hidden/idle by default so it does not block menu bar or browser UI.
- Top-center hover hotspot gives a subtle glass shimmer near the notch.
- Click opens the island pane.
- Click outside or use the close control to hide the expanded pane.
- Recent list is clickable and scrollable.
- Selecting a row updates the island header and mini map.
- Fresh selected/new check-ins can pulse the island edge.

### Notifications

- In-app alerts appear as a compact island pulse near the notch.
- By default, in-app alerts auto-hide after 12 seconds.
- A setting can keep in-app alerts visible until the island is closed.
- Optional macOS notifications use Notification Center banners outside the app.
- Notification events can be enabled separately for fresh tag check-ins and newly discovered monitored tags.
- macOS controls external banner style and persistence through System Settings.

### CTT Data Loading

- Authenticates with:

```http
Authorization: Bearer <token>
```

- Calls `GET /v1/me` to validate the token and load account identity.
- Calls `GET /v1/projects?limit=1000` with pagination.
- Calls `GET /v1/projects/{projectId}/devices?limit=1000` with pagination.
- Uses `latestConnectionAt` from project devices as the canonical check-in signal.
- Polls every 15 minutes.
- First successful poll seeds local state without firing popup alerts.
- Later poll cycles alert only for selected devices with fresh connection changes.
- Fresh alert cutoff is currently 30 minutes, so old check-ins do not create stale popups.

### Project And Device Filters

- Settings includes an account/token view and a filters view.
- Filters load all accessible CTT projects and devices for the token.
- The user can include/exclude whole projects or individual devices.
- The main app, island recent list, and alert logic only use included devices.
- Hidden devices still update their last-seen timestamps in the background so re-enabling a device does not replay old alerts.

### Maps And Location Points

- The app loads location records on demand for the selected/recent detail view, not for every device on every poll.
- The first query asks for the last 24 hours.
- If a stale device has no valid last-24-hour coordinates, the app falls back to a historical "last known" query around the last location/connection time.
- Up to 10 valid points are displayed.
- GPS-like fixes (`gps`, `fast_gps`, `assisted_gps`) are labeled `GPS` and drawn green.
- `cell_locate` fixes are labeled `Cell Locate` and drawn orange.
- For last-known fallback, GPS is preferred as the primary/latest point when a GPS fix exists in the latest connection window.
- If the latest connection only has a cell-locate fix, that fix is shown as the primary point.
- Clicking a map point opens a popover with fix type, fix time, latitude, and longitude.
- The larger detail map includes an external Apple Maps link for the latest displayed point.

### Battery

- Uses `latestBatteryV` from project device summaries when present.
- If the project summary battery is null, the app fetches recent sensor records for the selected device and uses the latest `battery_v`.
- Sensor battery is loaded on demand for selected devices to avoid unnecessary API pressure.

### Persistence

- Personal Access Token: Keychain only.
- Last-seen device connection timestamps: local UserDefaults.
- Project/device filter selections: local UserDefaults.
- API tokens are not stored in plain UserDefaults, source files, logs, or URLs.

## Requirements

- macOS 26 or newer.
- Swift 6.2 toolchain.
- CTT Personal Access Token with access to one or more projects.

The app is intentionally dependency-light and currently uses only Apple frameworks plus the Swift standard toolchain.

## Documentation

- [Installation](docs/INSTALLATION.md)
- [Settings](docs/SETTINGS.md)
- [Architecture](docs/ARCHITECTURE.md)
- [App Store Distribution](docs/APP_STORE.md)
- [Security](SECURITY.md)

## Run

```bash
./script/build_and_run.sh
```

The script builds the Swift package, stages `dist/CTT Pulse.app`, and launches it as a menu-bar/accessory app.

The App Store/Xcode target can be built with:

```bash
xcodebuild -scheme "CTT Pulse" -configuration Debug -destination 'platform=macOS' build
```

Other useful modes:

```bash
./script/build_and_run.sh --verify
./script/build_and_run.sh --logs
./script/build_and_run.sh --telemetry
./script/build_and_run.sh --debug
```

## Setup

1. Launch the app.
2. Open the menu bar item or click the island.
3. Add your CTT Personal Access Token in Settings.
4. Open Settings -> Filters.
5. Select the projects/devices you want visible and alertable.

The token is stored in the app's Keychain item. If Keychain access fails, disconnect and save the token again.

For a full source-install walkthrough, see [Installation](docs/INSTALLATION.md). For token, filter, alert, map, and battery behavior, see [Settings](docs/SETTINGS.md).

## Verification

```bash
swift test
./script/build_and_run.sh --verify
```

Current test coverage includes:

- CTT JSON decoding for project device summaries, sensor battery records, and error envelopes.
- First-poll seeding without alerts.
- Fresh check-in detection.
- Stale alert suppression.
- Project/device filtering.
- Location filtering for valid coordinates, 24-hour windows, explicit historical windows, and max 10 points.
- Last-known location fallback.
- GPS-vs-cell-locate primary point selection.
- Sensor battery fallback.

## Repository Layout

```text
Sources/CTTPulseApp/
  CTTPulseApp.swift       App entry point

Sources/CTTPulseCore/App/
  AppCoordinator.swift           Owns app-wide stores, windows, island controller
  IslandPanelController.swift    AppKit floating panel for the notch island
  NotchHoverMonitor.swift        Pointer hotspot monitoring
  MainWindowController.swift     Main detail window bridge
  SettingsWindowController.swift Settings window bridge

Sources/CTTPulseCore/Services/
  CTTAPIClient.swift             URLSession API client and pagination
  KeychainTokenStore.swift       Secure token storage
  MacNotificationCenter.swift    Notification Center delivery bridge

Sources/CTTPulseCore/Stores/
  TelemetryStore.swift           Polling, normalization, alerts, locations, battery fallback
  TelemetryFilterStore.swift     Persisted project/device inclusion filters
  LastSeenConnectionStore.swift  Persisted last-seen check-in timestamps
  NotificationPreferencesStore.swift Persisted alert display and event preferences

Sources/CTTPulseCore/Views/
  CTTPulseView.swift      Compact/expanded notch island UI
  ContentView.swift              Main split/detail window
  DetailView.swift               Device detail and large map
  TelemetryMapView.swift         MapKit annotations and point popovers
  SettingsView.swift             Token/account/filter settings
  SetupView.swift                First-run token prompt

Sources/CTTPulseCore/Support/
  TelemetryDateFormatter.swift   API/display date helpers
  TelemetryLocationFilter.swift  Location validation, ordering, GPS preference
  BatteryFormatter.swift         Battery display formatting
  NotchGeometry.swift            Screen/notch positioning helpers

Tests/CTTPulseCoreTests/
  CTTDecodingTests.swift
  NotificationPreferencesStoreTests.swift
  TelemetryLocationFilterTests.swift
  TelemetryStoreTests.swift
```

## Packaging Status

The project currently builds and runs locally from SwiftPM. The script stages a development `.app` bundle in `dist/`, which is intentionally ignored by git.

Not yet completed:

- Developer ID signing.
- Hardened runtime configuration.
- Notarization.
- Installer or DMG packaging.
- Mac App Store Xcode archive/sign/upload workflow.
- Auto-update mechanism.

Those are the next steps before distributing this to other Mac users.

## Roadmap

- Schedule-aware polling: derive expected check-in times from CTT config/instruction data, then poll shortly after scheduled transmissions in addition to the baseline 15-minute cadence.
- Packaged installer for non-developer users.
- Optional onboarding wizard for token, project selection, and device selection.
- More device metadata in the detail view.
- More explicit stale/missing-unit classification beyond "latest check-in."
- User-configurable alert windows and polling intervals.
