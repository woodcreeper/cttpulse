# CTT Pulse Architecture

CTT Pulse is a SwiftPM macOS app split into a tiny executable target and a reusable `CTTPulseCore` library target. The app is intentionally lean: SwiftUI for UI/state, AppKit only where macOS window/panel behavior requires it, URLSession/Codable for networking, Keychain for secrets, UserDefaults for local non-secret preferences.

## High-Level Flow

```text
CTTPulseApp
  -> AppCoordinator
    -> KeychainTokenStore
    -> CTTAPIClient
    -> LastSeenConnectionStore
    -> TelemetryFilterStore
    -> NotificationPreferencesStore
    -> TelemetryStore
    -> MacNotificationCenter
    -> IslandPanelController
    -> MainWindowController / SettingsWindowController
```

`AppCoordinator` is the composition root. It owns the shared stores and controllers, starts polling, and routes island/menu/settings/main-window actions. It also routes notification batches from `TelemetryStore` into the configured in-app island behavior and optional macOS Notification Center delivery.

## API Flow

The app uses the CTT customer API at:

```text
https://us-central1-ctt-data-portal.cloudfunctions.net/customerApi
```

Authentication uses a Personal Access Token sent as a bearer token. The PAT is loaded from Keychain at request time by `CTTAPIClient`.

Refresh sequence:

1. `GET /v1/me`
2. `GET /v1/projects?limit=1000`
3. `GET /v1/projects/{projectId}/devices?limit=1000` for each project
4. Normalize into `TelemetryProject`, `TelemetryDevice`, and `TelemetryCheckIn`
5. Apply persisted project/device filters
6. Compare `latestConnectionAt` against `LastSeenConnectionStore`
7. Emit notification events only for selected devices whose new connection is fresh, or newly discovered selected devices after the initial seed

Location sequence is on demand:

1. Fetch selected device locations for the last 24 hours.
2. Validate lat/lon and sort newest first.
3. If no valid recent points exist for a stale device, fetch a historical window around the latest location timestamp or latest connection timestamp.
4. For last-known historical displays, promote GPS-like fixes over cell-locate fixes when both were transmitted in the latest connection window.

Battery sequence is also on demand:

1. Use project device `latestBatteryV` when present.
2. If it is missing for the selected device, fetch `/v1/devices/{imei}/sensors` and use the newest non-null `battery_v`.

## Alert Semantics

`latestConnectionAt` is the canonical check-in signal. `latestLocationAt` is not used to fire check-in alerts because a device can connect without a GPS fix, and the user primarily wants connection awareness.

The first successful refresh seeds `LastSeenConnectionStore` without alerting. Later refreshes can emit a check-in notification when:

- the device is included by filters,
- the app has already seeded local state,
- `latestConnectionAt` is newer than the stored timestamp,
- the connection is within the fresh alert window.

The fresh alert window is currently 30 minutes. This prevents stale historical records from surfacing as new popups.

New selected devices discovered after the initial seed emit a separate "new tag added" notification event. This is distinct from a normal fresh check-in, so users can turn either event class on or off.

`NotificationPreferencesStore` persists display and event preferences in UserDefaults. The current display routes are:

- in-app island pulse, auto-hidden after 12 seconds by default;
- persistent in-app island pulse until dismissed;
- optional macOS Notification Center banner through `MacNotificationCenter`.

If both display routes are enabled, the same notification event is shown in both places. If both event types are disabled, refresh still updates app state but emits no user-facing notification.

## Filtering

`TelemetryFilterStore` stores selected device IDs. Device IDs are project-scoped using:

```text
{projectId}|{imei}
```

This avoids collisions if the same IMEI appears in multiple accessible projects with different aliases.

Default behavior after loading projects/devices is inclusive: all accessible devices are selected unless the user changes filters. Hiding a device removes it from visible app state and alert eligibility, but refresh still updates last-seen timestamps for hidden devices so stale alerts do not replay later.

## Island Window

The island is an AppKit floating panel driven by `IslandPanelController`. Product and store copy should describe it as a macOS menu bar/notch companion or top-center companion, not as an iOS feature.

Key behavior:

- borderless/nonactivating panel,
- fixed frame to avoid left/right shifting,
- positioned around the primary screen notch when available, or top center of the visible menu bar area on Macs without a notch,
- joins normal Spaces,
- avoids full-screen auxiliary behavior,
- expands/collapses through SwiftUI state.

`NotchHoverMonitor` watches a top-center hotspot and asks `IslandPanelState` to show a hover preview. The hover preview is visual only; the user still clicks to expand the island.

The menu bar item, settings window, and main detail window are independent access paths, so the app remains usable on non-notched Macs and when the user never interacts with the hover hotspot.

## Map Semantics

`TelemetryMapView` displays `TelemetryLocation` annotations with type-aware styling:

- GPS-like fixes: green
- cell-locate fixes: orange
- other known/unknown fixes: cyan

Clicking a map point opens a popover with:

- fix type,
- fix time,
- latitude,
- longitude.

The first location in the array is treated as the primary/latest displayed point. For normal 24-hour views this is the newest valid coordinate. For historical last-known views this is the best fix from the latest connection window, preferring GPS over cell locate.

## Local Persistence

Secrets:

- CTT PAT is stored only in Keychain by `KeychainTokenStore`.

Non-secrets:

- last-seen connection timestamps live in UserDefaults through `LastSeenConnectionStore`;
- filter selections live in UserDefaults through `TelemetryFilterStore`.
- notification display and event preferences live in UserDefaults through `NotificationPreferencesStore`.

Generated artifacts:

- `.build/` and `dist/` are ignored by git.
- `dist/CTT Pulse.app` is development output from `script/build_and_run.sh`.

## Testing Strategy

The test suite focuses on behavior that would otherwise regress silently:

- JSON decoding for CTT envelopes and DTOs.
- Fresh/stale check-in detection.
- First-poll seeding.
- Filtered device visibility and alert suppression.
- Notification event kind classification.
- Notification preference persistence and event filtering.
- Location coordinate validation.
- 24-hour and historical location windows.
- GPS-vs-cell-locate primary point selection.
- Location API error handling.
- Sensor battery fallback.

Run:

```bash
swift test
```

## Distribution Readiness

The current app is ready for local development/testing. To distribute it broadly, the next engineering work is signing and packaging:

1. Configure Developer ID signing.
2. Add hardened runtime entitlements.
3. Build a release `.app`.
4. Notarize with Apple.
5. Package as a DMG or installer.
6. Decide whether to add auto-update.
