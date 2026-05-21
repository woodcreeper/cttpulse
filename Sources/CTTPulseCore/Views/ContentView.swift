import SwiftUI

public struct ContentView: View {
    @ObservedObject private var store: TelemetryStore
    @EnvironmentObject private var coordinator: AppCoordinator

    public init(store: TelemetryStore) {
        self.store = store
    }

    public var body: some View {
        Group {
            if !store.isConfigured && store.checkIns.isEmpty {
                SetupView(store: store)
            } else {
                mainContent
            }
        }
        .frame(minWidth: 900, minHeight: 560)
        .background(.ultraThinMaterial)
    }

    private var mainContent: some View {
        NavigationSplitView {
            List(selection: $store.selectedCheckInID) {
                Section("Recent Check-ins") {
                    if store.checkIns.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("No records loaded")
                                .foregroundStyle(.secondary)

                            Text(store.lastRefreshSummary)
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                                .lineLimit(3)
                        }
                    } else {
                        ForEach(store.checkIns) { checkIn in
                            CheckInRow(checkIn: checkIn)
                                .tag(checkIn.id)
                        }
                    }
                }
            }
            .listStyle(.sidebar)
            .navigationTitle("CTT Pulse")
            .toolbar {
                ToolbarItem {
                    Button {
                        coordinator.refreshNow()
                    } label: {
                        Image(systemName: store.isRefreshing ? "hourglass" : "arrow.clockwise")
                    }
                    .disabled(store.isRefreshing || !store.isConfigured)
                    .help("Refresh")
                }

                ToolbarItem {
                    Button {
                        coordinator.showSettingsWindow()
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .help("Settings")
                }
            }
        } detail: {
            if let selected = store.selectedCheckIn {
                DetailView(store: store, checkIn: selected)
            } else {
                EmptyDetailView(store: store)
            }
        }
    }
}

private struct CheckInRow: View {
    let checkIn: TelemetryCheckIn

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: checkIn.isNew ? "dot.radiowaves.left.and.right" : "antenna.radiowaves.left.and.right")
                .foregroundStyle(checkIn.isNew ? .green : .secondary)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 3) {
                Text(checkIn.displayName)
                    .lineLimit(1)

                Text("\(checkIn.projectName) - \(TelemetryDateFormatter.relative(checkIn.connectionAt))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Text(checkIn.eventLabel)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }
}

private struct EmptyDetailView: View {
    @ObservedObject var store: TelemetryStore

    var body: some View {
        ContentUnavailableView {
            Label("No Check-ins", systemImage: "antenna.radiowaves.left.and.right.slash")
        } description: {
            Text(store.isConfigured ? store.lastRefreshSummary : "Add your CTT API token to begin.")
        }
    }
}
