# Settings

CTT Pulse has two main settings areas: account/token setup and project/device filters.

## Account

The Account section is where the user connects the app to CTT.

Fields and actions:

- Personal Access Token: secure text field for the CTT PAT.
- Save Token: stores the token in Keychain and immediately refreshes CTT data.
- Disconnect: deletes the stored token, clears loaded projects/devices/check-ins, clears filters, and returns the app to an unconfigured state.

Status shown after connection:

- account email,
- poll interval,
- loaded project count,
- loaded device count,
- visible record count,
- latest refresh/error summary.

## Filters

The Filters section controls what appears in the app and which devices can trigger alerts.

Behavior:

- All accessible devices are selected by default after the first load.
- Projects can be selected/deselected as groups.
- Individual devices can be selected/deselected.
- The island, main window, and alerts only use selected devices.
- Hidden devices are still observed internally for last-seen timestamp updates, preventing old alerts from replaying if a device is re-enabled later.

The island header count is based on the filtered monitoring list. It does not count every accessible project/device on the token. It also should not be read as "fresh alerts right now"; it is the number of selected monitored devices with a latest known record. The island's Latest list is sorted by each selected device's latest known check-in time.

Use cases:

- monitor only active field deployments,
- hide test devices,
- hide archived projects,
- focus the island on one species/project during a field season.

## Alerts

Alerts are based on `latestConnectionAt`, not only GPS fixes. This matters because a tag can connect and transmit without a GPS fix.

The app alerts only when:

- the device is selected in Filters,
- a previous successful refresh has seeded local state,
- `latestConnectionAt` advances,
- the new connection is fresh enough to matter.

The current fresh-alert window is 30 minutes. Older connection changes are loaded into the UI but do not create popup/pulse alerts.

## Maps

Maps are loaded on demand for the selected device to limit API usage.

The app first checks the last 24 hours. If no valid coordinates exist and the device is stale, it searches a historical last-known window near the most relevant recent connection/location timestamp.

Point types:

- GPS: green, most accurate.
- Cell Locate: orange, less accurate, used when no GPS fix exists in the latest connection window.
- Other fix types: cyan.

Clicking a map point shows:

- fix type,
- fix time,
- latitude,
- longitude.

## Battery

Battery display uses the best available source:

1. `latestBatteryV` from the project-device summary.
2. If missing, latest selected-device sensor `battery_v`.

Sensor battery lookup is on demand so the app does not poll sensor history for every device every 15 minutes.
