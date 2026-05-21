import Foundation

@MainActor
public final class NotificationPreferencesStore: ObservableObject {
    @Published public var showInAppAlerts: Bool {
        didSet { defaults.set(showInAppAlerts, forKey: Keys.showInAppAlerts) }
    }

    @Published public var keepInAppAlertsVisible: Bool {
        didSet { defaults.set(keepInAppAlertsVisible, forKey: Keys.keepInAppAlertsVisible) }
    }

    @Published public var showMacOSNotifications: Bool {
        didSet { defaults.set(showMacOSNotifications, forKey: Keys.showMacOSNotifications) }
    }

    @Published public var notifyOnCheckIns: Bool {
        didSet { defaults.set(notifyOnCheckIns, forKey: Keys.notifyOnCheckIns) }
    }

    @Published public var notifyOnNewTags: Bool {
        didSet { defaults.set(notifyOnNewTags, forKey: Keys.notifyOnNewTags) }
    }

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.showInAppAlerts = Self.bool(for: Keys.showInAppAlerts, defaults: defaults, defaultValue: true)
        self.keepInAppAlertsVisible = Self.bool(for: Keys.keepInAppAlertsVisible, defaults: defaults, defaultValue: false)
        self.showMacOSNotifications = Self.bool(for: Keys.showMacOSNotifications, defaults: defaults, defaultValue: false)
        self.notifyOnCheckIns = Self.bool(for: Keys.notifyOnCheckIns, defaults: defaults, defaultValue: true)
        self.notifyOnNewTags = Self.bool(for: Keys.notifyOnNewTags, defaults: defaults, defaultValue: true)
    }

    public func includes(_ event: TelemetryNotificationEvent) -> Bool {
        switch event.kind {
        case .newTag:
            notifyOnNewTags
        case .checkIn:
            notifyOnCheckIns
        }
    }

    private static func bool(for key: String, defaults: UserDefaults, defaultValue: Bool) -> Bool {
        guard defaults.object(forKey: key) != nil else {
            return defaultValue
        }

        return defaults.bool(forKey: key)
    }
}

private enum Keys {
    static let showInAppAlerts = "notifications.showInAppAlerts"
    static let keepInAppAlertsVisible = "notifications.keepInAppAlertsVisible"
    static let showMacOSNotifications = "notifications.showMacOSNotifications"
    static let notifyOnCheckIns = "notifications.notifyOnCheckIns"
    static let notifyOnNewTags = "notifications.notifyOnNewTags"
}
