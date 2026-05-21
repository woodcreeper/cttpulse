import SwiftUI

struct SetupView: View {
    @ObservedObject var store: TelemetryStore
    @EnvironmentObject private var coordinator: AppCoordinator
    @State private var token = ""

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "antenna.radiowaves.left.and.right")
                .font(.system(size: 48, weight: .semibold))
                .foregroundStyle(.cyan)

            VStack(spacing: 8) {
                Text("Connect CTT Telemetry")
                    .font(.largeTitle.weight(.bold))

                Text("Paste your CTT Personal Access Token. It will be stored in Keychain.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 10) {
                SecureField("Personal Access Token", text: $token)
                    .textFieldStyle(.roundedBorder)

                HStack {
                    Button {
                        Task { await store.configureToken(token) }
                    } label: {
                        Label(store.isRefreshing ? "Connecting" : "Connect", systemImage: "key")
                    }
                    .buttonStyle(.glassProminent)
                    .disabled(store.isRefreshing || token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                    Button {
                        coordinator.showSettingsWindow()
                    } label: {
                        Label("Settings", systemImage: "gearshape")
                    }
                    .buttonStyle(.glass)
                }
            }
            .frame(maxWidth: 430)

            if let error = store.lastError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 520)
            }
        }
        .padding(40)
    }
}
