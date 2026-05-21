import SwiftUI

public struct SettingsView: View {
    @ObservedObject private var store: TelemetryStore
    @State private var token = ""

    public init(store: TelemetryStore) {
        self.store = store
    }

    public var body: some View {
        TabView {
            accountPane
                .tabItem {
                    Label("Account", systemImage: "key")
                }

            filtersPane
                .tabItem {
                    Label("Filters", systemImage: "line.3.horizontal.decrease.circle")
                }
        }
        .padding(.horizontal, 22)
        .padding(.top, 48)
        .padding(.bottom, 18)
        .frame(width: 760, height: 620)
        .background(.ultraThinMaterial)
    }

    private var accountPane: some View {
        VStack(alignment: .leading, spacing: 16) {
            header

            tokenCard

            statusCard

            Text(store.lastRefreshSummary)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if let error = store.lastError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(.top, 8)
    }

    private var filtersPane: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Projects & Devices")
                        .font(.title2.weight(.bold))

                    Text(store.filterSummary)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    store.selectAllFilters()
                } label: {
                    Label("Select All", systemImage: "checkmark.circle")
                }
                .buttonStyle(.glass)

                Button {
                    store.selectNoFilters()
                } label: {
                    Label("Clear", systemImage: "circle")
                }
                .buttonStyle(.glass)
            }

            if store.projects.isEmpty {
                ContentUnavailableView {
                    Label("No Projects Loaded", systemImage: "folder.badge.questionmark")
                } description: {
                    Text(store.lastRefreshSummary)
                }
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(store.projects) { project in
                            ProjectFilterSection(store: store, project: project)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding(.top, 8)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("CTT Pulse Settings")
                .font(.title2.weight(.bold))

            Text("CTT API polling runs every 15 minutes. Tokens stay in this app's Keychain item.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
    }

    private var tokenCard: some View {
        let shape = RoundedRectangle(cornerRadius: 20, style: .continuous)

        return VStack(alignment: .leading, spacing: 10) {
            Text("Personal Access Token")
                .font(.headline)

            SecureField("ctt_pat...", text: $token)
                .textFieldStyle(.roundedBorder)

            HStack(spacing: 10) {
                Button {
                    Task { await store.configureToken(token) }
                } label: {
                    Label(store.isRefreshing ? "Saving" : "Save Token", systemImage: "key")
                }
                .buttonStyle(.glassProminent)
                .disabled(store.isRefreshing || token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                Button(role: .destructive) {
                    store.disconnect()
                    token = ""
                } label: {
                    Label("Disconnect", systemImage: "key.slash")
                }
                .buttonStyle(.glass)
                .disabled(!store.isConfigured)
            }
        }
        .padding(14)
        .background(.thinMaterial, in: shape)
        .glassEffect(.regular, in: shape)
        .overlay {
            shape.strokeBorder(.white.opacity(0.14), lineWidth: 1)
        }
    }

    private var statusCard: some View {
        let shape = RoundedRectangle(cornerRadius: 20, style: .continuous)

        return Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 7) {
            GridRow {
                Text("Status").foregroundStyle(.secondary)
                Text(store.isConfigured ? "Connected" : "Not connected")
            }
            GridRow {
                Text("Account").foregroundStyle(.secondary)
                Text(store.userEmail ?? "Unknown")
            }
            GridRow {
                Text("Poll interval").foregroundStyle(.secondary)
                Text("15 minutes")
            }
            GridRow {
                Text("Projects").foregroundStyle(.secondary)
                Text("\(store.projects.count)")
            }
            GridRow {
                Text("Devices").foregroundStyle(.secondary)
                Text("\(store.devices.count) selected / \(store.allDevices.count) total")
            }
            GridRow {
                Text("Records").foregroundStyle(.secondary)
                Text("\(store.checkIns.count) selected / \(store.allCheckIns.count) total")
            }
        }
        .font(.callout)
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial, in: shape)
        .glassEffect(.regular, in: shape)
        .overlay {
            shape.strokeBorder(.white.opacity(0.14), lineWidth: 1)
        }
    }
}

private struct ProjectFilterSection: View {
    @ObservedObject var store: TelemetryStore
    let project: TelemetryProject

    private var devices: [TelemetryDevice] {
        store.devices(in: project.id)
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)

        VStack(alignment: .leading, spacing: 8) {
            Toggle(isOn: projectBinding) {
                HStack(spacing: 8) {
                    Text(project.name)
                        .font(.headline)
                        .lineLimit(1)

                    if store.isProjectPartiallyIncluded(project) {
                        Text("Partial")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Text("\(selectedCount) of \(devices.count)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .toggleStyle(.checkbox)

            Divider()
                .opacity(0.35)

            if devices.isEmpty {
                Text("No devices loaded")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                LazyVStack(alignment: .leading, spacing: 5) {
                    ForEach(devices) { device in
                        Toggle(isOn: deviceBinding(device)) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(device.displayName)
                                    .lineLimit(1)
                                Text("\(device.deviceType) - \(device.imei)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                        .toggleStyle(.checkbox)
                    }
                }
                .padding(.leading, 18)
            }
        }
        .padding(14)
        .background(.thinMaterial, in: shape)
        .glassEffect(.regular, in: shape)
        .overlay {
            shape.strokeBorder(.white.opacity(0.12), lineWidth: 1)
        }
    }

    private var selectedCount: Int {
        devices.filter { store.isDeviceIncluded($0) }.count
    }

    private var projectBinding: Binding<Bool> {
        Binding(
            get: { store.isProjectIncluded(project) },
            set: { store.setProjectIncluded(project, isIncluded: $0) }
        )
    }

    private func deviceBinding(_ device: TelemetryDevice) -> Binding<Bool> {
        Binding(
            get: { store.isDeviceIncluded(device) },
            set: { store.setDeviceIncluded(device, isIncluded: $0) }
        )
    }
}
