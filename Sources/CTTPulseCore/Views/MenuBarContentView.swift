import SwiftUI

public struct MenuBarContentView: View {
    @ObservedObject private var store: TelemetryStore
    @EnvironmentObject private var coordinator: AppCoordinator

    public init(store: TelemetryStore) {
        self.store = store
    }

    public var body: some View {
        VStack(alignment: .leading) {
            if let latest = store.latestCheckIn {
                Text(latest.displayName)
                Text("Checked in \(TelemetryDateFormatter.relative(latest.connectionAt))")
                    .foregroundStyle(.secondary)
            } else {
                Text("CTT Pulse")
                Text(store.isConfigured ? "No check-ins loaded" : "Token required")
                    .foregroundStyle(.secondary)
            }

            Divider()

            Button {
                coordinator.showMainWindow()
            } label: {
                Label("Open Telemetry", systemImage: "list.bullet.rectangle")
            }

            Button {
                coordinator.showSettingsWindow()
            } label: {
                Label("Settings", systemImage: "gearshape")
            }

            Button {
                coordinator.refreshNow()
            } label: {
                Label(store.isRefreshing ? "Refreshing" : "Refresh Now", systemImage: "arrow.clockwise")
            }
            .disabled(store.isRefreshing || !store.isConfigured)

            Button {
                coordinator.toggleIsland()
            } label: {
                Label(coordinator.islandState.isVisible ? "Hide Island" : "Show Island", systemImage: "capsule")
            }

            Divider()

            Button {
                store.disconnect()
            } label: {
                Label("Disconnect Token", systemImage: "key.slash")
            }
            .disabled(!store.isConfigured)

            Button {
                NSApp.terminate(nil)
            } label: {
                Label("Quit", systemImage: "power")
            }
        }
    }
}
