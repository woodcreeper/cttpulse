import Foundation
import UserNotifications

@MainActor
final class MacNotificationCenter: NSObject, UNUserNotificationCenterDelegate {
    private let center: UNUserNotificationCenter

    override init() {
        self.center = .current()
        super.init()
        center.delegate = self
    }

    func deliver(_ events: [TelemetryNotificationEvent]) async {
        guard await requestAuthorizationIfNeeded() else { return }

        for event in events {
            let content = UNMutableNotificationContent()
            content.title = event.title
            content.body = event.body
            content.sound = .default
            content.userInfo = [
                "kind": event.kind.rawValue,
                "imei": event.checkIn.imei,
                "projectID": event.checkIn.projectID
            ]

            let request = UNNotificationRequest(
                identifier: event.id,
                content: content,
                trigger: nil
            )

            try? await center.add(request)
        }
    }

    private func requestAuthorizationIfNeeded() async -> Bool {
        let settings = await center.notificationSettings()

        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .denied:
            return false
        case .notDetermined:
            return (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) == true
        @unknown default:
            return false
        }
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }
}
