import AppKit
import MapKit
import SwiftUI

struct DetailView: View {
    @ObservedObject var store: TelemetryStore
    let checkIn: TelemetryCheckIn

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                mapCard
                metadataCard
            }
            .padding(24)
        }
        .navigationTitle(checkIn.displayName)
        .task(id: checkIn.id) {
            await store.loadLocations(for: checkIn)
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 18) {
            VStack(alignment: .leading, spacing: 8) {
                Text(checkIn.displayName)
                    .font(.largeTitle.weight(.bold))
                    .lineLimit(1)

                Text(checkIn.projectName)
                    .font(.title3)
                    .foregroundStyle(.secondary)

                HStack(spacing: 12) {
                    Label("\(checkIn.eventLabel) \(TelemetryDateFormatter.relative(checkIn.connectionAt))", systemImage: "clock")
                    Label(BatteryFormatter.string(store.batteryVoltage(for: checkIn)), systemImage: "battery.75percent")
                    Label(checkIn.deviceType, systemImage: "tag")
                }
                .font(.callout)
                .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 8) {
                Button {
                    Task { await store.loadLocations(for: checkIn, force: true) }
                } label: {
                    Label(store.isLoadingLocations ? "Loading" : "Refresh Map", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.glass)
                .disabled(store.isLoadingLocations)

                if let latest = store.locations(for: checkIn).first {
                    Button {
                        openInMaps(latest)
                    } label: {
                        Label("Open in Maps", systemImage: "map")
                    }
                    .buttonStyle(.glass)
                }
            }
        }
    }

    private var mapCard: some View {
        let locations = store.locations(for: checkIn)
        let locationError = store.locationError(for: checkIn)
        let subtitle = store.locationSubtitle(for: checkIn)
        let shape = RoundedRectangle(cornerRadius: 22, style: .continuous)

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Latest Locations")
                        .font(.headline)

                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(locationError == nil ? AnyShapeStyle(.secondary) : AnyShapeStyle(.orange))
                }

                Spacer()

                Text(locationCountLabel(locations))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            TelemetryMapView(locations: locations)
                .frame(height: 340)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .padding(16)
        .background(.thinMaterial, in: shape)
        .glassEffect(.regular, in: shape)
        .overlay {
            shape.strokeBorder(.white.opacity(0.14), lineWidth: 1)
        }
    }

    private var metadataCard: some View {
        let shape = RoundedRectangle(cornerRadius: 22, style: .continuous)

        return Grid(alignment: .leading, horizontalSpacing: 18, verticalSpacing: 12) {
            GridRow {
                Text("IMEI")
                    .foregroundStyle(.secondary)
                Text(checkIn.imei)
                    .textSelection(.enabled)
            }

            GridRow {
                Text("Event")
                    .foregroundStyle(.secondary)
                Text("\(checkIn.eventLabel) at \(checkIn.connectionAt.formatted(date: .abbreviated, time: .standard))")
            }

            GridRow {
                Text("Latest Location")
                    .foregroundStyle(.secondary)
                Text(latestLocationMetadata)
            }

            GridRow {
                Text("Battery")
                    .foregroundStyle(.secondary)
                Text(BatteryFormatter.string(store.batteryVoltage(for: checkIn)))
            }
        }
        .font(.callout)
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial, in: shape)
        .glassEffect(.regular, in: shape)
        .overlay {
            shape.strokeBorder(.white.opacity(0.14), lineWidth: 1)
        }
    }

    private func openInMaps(_ location: TelemetryLocation) {
        var components = URLComponents(string: "https://maps.apple.com/")
        components?.queryItems = [
            URLQueryItem(name: "ll", value: "\(location.latitude),\(location.longitude)"),
            URLQueryItem(name: "q", value: checkIn.displayName)
        ]

        if let url = components?.url {
            NSWorkspace.shared.open(url)
        }
    }

    private func locationCountLabel(_ locations: [TelemetryLocation]) -> String {
        guard let primary = locations.first else {
            return "0 points"
        }

        return "\(locations.count) points - latest \(primary.fixTypeLabel)"
    }

    private var latestLocationMetadata: String {
        if let latest = store.locations(for: checkIn).first {
            return "\(latest.fixTypeLabel) at \(latest.fixAt.formatted(date: .abbreviated, time: .standard))"
        }

        if let latestLocationAt = checkIn.latestLocationAt {
            return latestLocationAt.formatted(date: .abbreviated, time: .standard)
        }

        return "No location timestamp"
    }
}
