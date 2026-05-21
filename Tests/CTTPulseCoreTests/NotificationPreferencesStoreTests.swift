import Foundation
import Testing
@testable import CTTPulseCore

@MainActor
@Suite("Notification preferences")
struct NotificationPreferencesStoreTests {
    @Test("Defaults keep in-app alerts on and macOS notifications off")
    func defaultsUseInAppOnlyAlerts() {
        let suiteName = "NotificationPreferencesStoreTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)

        let store = NotificationPreferencesStore(defaults: defaults)

        #expect(store.showInAppAlerts == true)
        #expect(store.keepInAppAlertsVisible == false)
        #expect(store.showMacOSNotifications == false)
        #expect(store.notifyOnCheckIns == true)
        #expect(store.notifyOnNewTags == true)
    }

    @Test("Preferences persist and filter notification event kinds")
    func persistsAndFiltersEvents() {
        let suiteName = "NotificationPreferencesStoreTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)

        let store = NotificationPreferencesStore(defaults: defaults)
        store.showInAppAlerts = false
        store.keepInAppAlertsVisible = true
        store.showMacOSNotifications = true
        store.notifyOnCheckIns = false
        store.notifyOnNewTags = true

        let reloadedStore = NotificationPreferencesStore(defaults: defaults)
        let checkInEvent = Self.event(kind: .checkIn)
        let newTagEvent = Self.event(kind: .newTag)

        #expect(reloadedStore.showInAppAlerts == false)
        #expect(reloadedStore.keepInAppAlertsVisible == true)
        #expect(reloadedStore.showMacOSNotifications == true)
        #expect(reloadedStore.includes(checkInEvent) == false)
        #expect(reloadedStore.includes(newTagEvent) == true)
    }

    private static func event(kind: TelemetryNotificationEvent.Kind) -> TelemetryNotificationEvent {
        TelemetryNotificationEvent(
            kind: kind,
            checkIn: TelemetryCheckIn(
                id: "project-1|connection|2026-05-20T12:15:00Z",
                projectID: "project-1",
                projectName: "Cape May Owl Project",
                imei: "352753094012345",
                displayName: "Tern 12",
                deviceType: "flicker_gps_gen2",
                kind: .connection,
                connectionAt: TelemetryDateFormatter.parseISO8601("2026-05-20T12:15:00Z")!,
                latestLocationAt: TelemetryDateFormatter.parseISO8601("2026-05-20T12:14:00Z"),
                latestBatteryV: 3.88,
                isNew: true
            )
        )
    }
}
