import Foundation

final class TelemetryFilterStore {
    private let defaults: UserDefaults
    private let configuredKey = "ctt.filters.configured"
    private let selectedDeviceIDsKey = "ctt.filters.selectedDeviceIDs"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var hasConfiguredFilters: Bool {
        defaults.bool(forKey: configuredKey)
    }

    var selectedDeviceIDs: Set<String> {
        Set(defaults.stringArray(forKey: selectedDeviceIDsKey) ?? [])
    }

    func prepareDefaults(devices: [TelemetryDevice]) {
        if hasConfiguredFilters {
            pruneUnavailableDevices(devices)
            return
        }

        guard !devices.isEmpty else { return }

        saveSelectedDeviceIDs(Set(devices.map(\.id)), markConfigured: true)
    }

    func includes(_ device: TelemetryDevice) -> Bool {
        selectedDeviceIDs.contains(device.id)
    }

    func includesDeviceID(_ deviceID: String) -> Bool {
        selectedDeviceIDs.contains(deviceID)
    }

    func setDevice(_ deviceID: String, isIncluded: Bool) {
        var selected = selectedDeviceIDs

        if isIncluded {
            selected.insert(deviceID)
        } else {
            selected.remove(deviceID)
        }

        saveSelectedDeviceIDs(selected, markConfigured: true)
    }

    func setProject(_ projectID: String, isIncluded: Bool, devices: [TelemetryDevice]) {
        var selected = selectedDeviceIDs
        let projectDeviceIDs = devices
            .filter { $0.projectID == projectID }
            .map(\.id)

        if isIncluded {
            selected.formUnion(projectDeviceIDs)
        } else {
            selected.subtract(projectDeviceIDs)
        }

        saveSelectedDeviceIDs(selected, markConfigured: true)
    }

    func selectAll(devices: [TelemetryDevice]) {
        saveSelectedDeviceIDs(Set(devices.map(\.id)), markConfigured: true)
    }

    func selectNone() {
        saveSelectedDeviceIDs([], markConfigured: true)
    }

    func clear() {
        defaults.removeObject(forKey: configuredKey)
        defaults.removeObject(forKey: selectedDeviceIDsKey)
    }

    private func pruneUnavailableDevices(_ devices: [TelemetryDevice]) {
        let available = Set(devices.map(\.id))
        let pruned = selectedDeviceIDs.intersection(available)
        saveSelectedDeviceIDs(pruned, markConfigured: true)
    }

    private func saveSelectedDeviceIDs(_ selectedDeviceIDs: Set<String>, markConfigured: Bool) {
        defaults.set(Array(selectedDeviceIDs).sorted(), forKey: selectedDeviceIDsKey)

        if markConfigured {
            defaults.set(true, forKey: configuredKey)
        }
    }
}
