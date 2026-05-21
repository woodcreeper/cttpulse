import Foundation

final class LastSeenConnectionStore {
    private let defaults: UserDefaults
    private let timestampsKey = "ctt.lastSeenConnections"
    private let seededKey = "ctt.hasSeededConnections"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var hasSeeded: Bool {
        defaults.bool(forKey: seededKey)
    }

    func markSeeded() {
        defaults.set(true, forKey: seededKey)
    }

    func date(for key: String) -> Date? {
        guard
            let dictionary = defaults.dictionary(forKey: timestampsKey) as? [String: String],
            let rawValue = dictionary[key]
        else {
            return nil
        }

        return TelemetryDateFormatter.parseISO8601(rawValue)
    }

    func set(_ date: Date, for key: String) {
        var dictionary = defaults.dictionary(forKey: timestampsKey) as? [String: String] ?? [:]
        dictionary[key] = TelemetryDateFormatter.apiString(from: date)
        defaults.set(dictionary, forKey: timestampsKey)
    }

    func clear() {
        defaults.removeObject(forKey: timestampsKey)
        defaults.removeObject(forKey: seededKey)
    }
}
