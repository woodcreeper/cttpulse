import MapKit
import SwiftUI

struct TelemetryMapView: View {
    let locations: [TelemetryLocation]
    @State private var position: MapCameraPosition = .automatic
    @State private var selectedLocation: TelemetryLocation?

    var body: some View {
        Group {
            if locations.isEmpty {
                ContentUnavailableView {
                    Label("No Location Points", systemImage: "map")
                } description: {
                    Text("No valid coordinates were returned for the last 24 hours.")
                }
            } else {
                Map(position: $position) {
                    ForEach(Array(locations.enumerated()), id: \.element.id) { index, location in
                        Annotation(annotationTitle(for: location, index: index), coordinate: location.coordinate) {
                            Button {
                                selectedLocation = location
                            } label: {
                                LocationMapMarker(location: location, isPrimary: index == 0)
                            }
                            .buttonStyle(.plain)
                            .popover(isPresented: Binding(
                                get: { selectedLocation?.id == location.id },
                                set: { isPresented in
                                    if !isPresented {
                                        selectedLocation = nil
                                    }
                                }
                            )) {
                                LocationDetailPopover(location: location)
                            }
                        }
                    }
                }
                .mapStyle(.standard(elevation: .realistic))
                .onAppear {
                    position = .region(Self.region(for: locations))
                }
                .onChange(of: locations) { _, newLocations in
                    position = .region(Self.region(for: newLocations))
                }
            }
        }
    }

    private func annotationTitle(for location: TelemetryLocation, index: Int) -> String {
        if index == 0 {
            return "Latest \(location.shortFixTypeLabel)"
        }

        return location.shortFixTypeLabel
    }

    private static func region(for locations: [TelemetryLocation]) -> MKCoordinateRegion {
        guard let first = locations.first else {
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 0, longitude: 0),
                span: MKCoordinateSpan(latitudeDelta: 1, longitudeDelta: 1)
            )
        }

        let latitudes = locations.map(\.latitude)
        let longitudes = locations.map(\.longitude)
        let minLatitude = latitudes.min() ?? first.latitude
        let maxLatitude = latitudes.max() ?? first.latitude
        let minLongitude = longitudes.min() ?? first.longitude
        let maxLongitude = longitudes.max() ?? first.longitude

        let center = CLLocationCoordinate2D(
            latitude: (minLatitude + maxLatitude) / 2,
            longitude: (minLongitude + maxLongitude) / 2
        )

        let latitudeDelta = max(0.02, (maxLatitude - minLatitude) * 1.6)
        let longitudeDelta = max(0.02, (maxLongitude - minLongitude) * 1.6)

        return MKCoordinateRegion(
            center: center,
            span: MKCoordinateSpan(latitudeDelta: latitudeDelta, longitudeDelta: longitudeDelta)
        )
    }
}

private struct LocationMapMarker: View {
    let location: TelemetryLocation
    let isPrimary: Bool

    var body: some View {
        ZStack {
            Circle()
                .fill(markerColor)
                .frame(width: isPrimary ? 18 : 12, height: isPrimary ? 18 : 12)

            if isPrimary {
                Circle()
                    .stroke(.white, lineWidth: 3)
                    .frame(width: 24, height: 24)
            }
        }
        .shadow(radius: 4)
        .contentShape(Circle())
        .help("\(location.fixTypeLabel) at \(location.fixAt.formatted(date: .abbreviated, time: .standard))")
    }

    private var markerColor: Color {
        if location.isGPSFix {
            return .green
        }

        if location.isCellLocateFix {
            return .orange
        }

        return .cyan
    }
}

private struct LocationDetailPopover: View {
    let location: TelemetryLocation

    var body: some View {
        Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 8) {
            GridRow {
                Text("Fix")
                    .foregroundStyle(.secondary)
                Text(location.fixTypeLabel)
                    .fontWeight(.semibold)
            }

            GridRow {
                Text("Time")
                    .foregroundStyle(.secondary)
                Text(location.fixAt.formatted(date: .abbreviated, time: .standard))
            }

            GridRow {
                Text("Lat")
                    .foregroundStyle(.secondary)
                Text(Self.coordinateString(location.latitude))
                    .textSelection(.enabled)
            }

            GridRow {
                Text("Lon")
                    .foregroundStyle(.secondary)
                Text(Self.coordinateString(location.longitude))
                    .textSelection(.enabled)
            }
        }
        .font(.callout)
        .padding(14)
        .frame(minWidth: 240, alignment: .leading)
    }

    private static func coordinateString(_ value: Double) -> String {
        String(format: "%.6f", value)
    }
}
