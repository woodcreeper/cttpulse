import SwiftUI

public struct CTTPulseView: View {
    @ObservedObject private var store: TelemetryStore
    @ObservedObject private var state: IslandPanelState
    private let actions: IslandActions

    @State private var isPulsing = false
    @State private var hoverGlow = false
    @State private var selectedIslandCheckInID: String?

    public init(store: TelemetryStore, state: IslandPanelState, actions: IslandActions) {
        self.store = store
        self.state = state
        self.actions = actions
    }

    public var body: some View {
        GlassEffectContainer(spacing: 10) {
            Group {
                if state.isHoverPreview {
                    hoverRim
                        .transition(.scale(scale: 0.92).combined(with: .opacity))
                } else if state.isExpanded {
                    expandedIsland
                        .transition(.scale(scale: 0.96).combined(with: .opacity))
                } else {
                    compactIsland
                        .transition(.scale(scale: 0.96).combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.28, dampingFraction: 0.82), value: state.isExpanded)
            .animation(.spring(response: 0.24, dampingFraction: 0.86), value: state.isHoverPreview)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onChange(of: store.pulseID) {
            pulse()
        }
        .onChange(of: state.isHoverPreview) { _, isHoverPreview in
            if isHoverPreview {
                startHoverGlow()
            } else {
                stopHoverGlow()
            }
        }
        .onChange(of: state.isExpanded) { _, isExpanded in
            if isExpanded {
                selectDefaultIslandCheckInIfNeeded()
            }
        }
        .onChange(of: checkInIDs) {
            selectDefaultIslandCheckInIfNeeded()
        }
        .task(id: islandLocationTaskID) {
            guard state.isExpanded, let selected = selectedIslandCheckIn else { return }
            await store.loadLocations(for: selected)
        }
    }

    private var hoverRim: some View {
        Button {
            state.show(expanded: true)
        } label: {
            Capsule()
                .fill(.white.opacity(hoverGlow ? 0.16 : 0.06))
                .frame(width: hoverGlow ? 154 : 132, height: hoverGlow ? 12 : 8)
                .glassEffect(.regular.interactive(), in: Capsule())
                .shadow(color: .cyan.opacity(hoverGlow ? 0.20 : 0), radius: hoverGlow ? 12 : 0)
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .offset(y: 34)
        .frame(width: 220, height: 70, alignment: .top)
        .help("Open CTT Pulse")
    }

    private var compactIsland: some View {
        Button {
            state.show(expanded: true)
        } label: {
            HStack(spacing: 10) {
                statusDot

                VStack(alignment: .leading, spacing: 1) {
                    Text(compactTitle)
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(1)

                    Text(compactSubtitle)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 4)

                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .frame(width: 286, height: 50)
            .contentShape(Capsule())
            .glassEffect(.regular.interactive(), in: Capsule())
            .overlay(pulseOverlay(shape: Capsule()))
        }
        .buttonStyle(.plain)
        .offset(y: 34)
        .frame(width: 310, height: 86, alignment: .top)
    }

    private var expandedIsland: some View {
        let paneShape = RoundedRectangle(cornerRadius: 28, style: .continuous)

        return ZStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 12) {
                paneHeader

                latestModule
                    .frame(height: 86)

                HStack(spacing: 10) {
                    recentModule
                        .frame(maxWidth: .infinity)

                    mapModule
                        .frame(width: 124)
                }
                .frame(height: 122)
            }
            .padding(12)
            .frame(width: 392, height: 284)
            .glassEffect(.regular.interactive(), in: paneShape)
            .overlay {
                paneShape
                    .strokeBorder(.white.opacity(0.12), lineWidth: 1)
            }
            .overlay(pulseOverlay(shape: paneShape))
            .offset(y: 34)
        }
        .frame(width: 430, height: 330, alignment: .top)
    }

    private var paneHeader: some View {
        HStack(spacing: 10) {
            statusDot

            VStack(alignment: .leading, spacing: 1) {
                Text("CTT Pulse")
                    .font(.system(size: 15, weight: .semibold))
                Text(headerSubtitle)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            controlsModule
        }
    }

    private var latestModule: some View {
        IslandModule {
            HStack(alignment: .center, spacing: 12) {
                if let selected = selectedIslandCheckIn {
                    VStack(alignment: .leading, spacing: 5) {
                        Label(selected.id == store.latestCheckIn?.id ? "Latest" : "Selected", systemImage: "antenna.radiowaves.left.and.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)

                        Text(selected.displayName)
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .lineLimit(1)

                        Text(selected.projectName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 6)

                    VStack(alignment: .trailing, spacing: 5) {
                        Text(TelemetryDateFormatter.relative(selected.connectionAt))
                        Text(BatteryFormatter.string(store.batteryVoltage(for: selected)))
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                } else {
                    VStack(alignment: .leading, spacing: 5) {
                        Label("Latest", systemImage: "antenna.radiowaves.left.and.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)

                        Text(store.isConfigured ? "No check-ins yet" : "Connect CTT")
                            .font(.headline)
                        Text(store.isConfigured ? "Waiting for API data" : "Add a PAT in settings")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var recentModule: some View {
        IslandModule {
            VStack(alignment: .leading, spacing: 7) {
                Text("Latest")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                if store.checkIns.isEmpty {
                    Text("Nothing loaded")
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(.secondary)
                } else {
                    ScrollView(.vertical) {
                        LazyVStack(alignment: .leading, spacing: 4) {
                            ForEach(store.checkIns) { checkIn in
                                recentRow(for: checkIn)
                            }
                        }
                    }
                    .scrollIndicators(.never)
                }
            }
        }
    }

    private var mapModule: some View {
        IslandModule {
            Group {
                if let selected = selectedIslandCheckIn, !store.locations(for: selected).isEmpty {
                    miniMap(for: selected)
                } else {
                    noMapContent
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func miniMap(for checkIn: TelemetryCheckIn) -> some View {
        let locations = store.locations(for: checkIn)

        return ZStack(alignment: .bottomLeading) {
            TelemetryMapView(locations: locations)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text("\(locations[0].shortFixTypeLabel) - \(locations.count) pts")
                    .font(.caption2.weight(.bold))
                Text(mapAgeLabel(for: checkIn, locations: locations))
                    .font(.caption2.weight(.medium))
                    .lineLimit(1)
            }
            .padding(.horizontal, 7)
            .padding(.vertical, 5)
            .background(.ultraThinMaterial, in: Capsule())
            .padding(6)
        }
        .overlay(alignment: .topTrailing) {
            Button {
                Task {
                    await store.loadLocations(for: checkIn)
                    actions.openMain()
                }
            } label: {
                Image(systemName: "arrow.up.forward")
            }
            .buttonStyle(.glass)
            .controlSize(.mini)
            .padding(6)
            .help("Open map detail")
        }
    }

    private var noMapContent: some View {
        VStack(spacing: 9) {
            Image(systemName: store.isLoadingLocations ? "hourglass" : "map")
                .font(.system(size: 24, weight: .semibold))

            if store.isLoadingLocations {
                Text("Loading")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            } else if let selected = selectedIslandCheckIn, let error = store.locationError(for: selected) {
                Text(error)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            } else {
                Text("No fix")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            Button {
                if let selected = selectedIslandCheckIn {
                    Task {
                        await store.loadLocations(for: selected)
                        actions.openMain()
                    }
                } else {
                    actions.openMain()
                }
            } label: {
                Label("Map", systemImage: "location")
                    .labelStyle(.titleAndIcon)
            }
            .buttonStyle(.glass)
            .controlSize(.small)
        }
    }

    private var controlsModule: some View {
        HStack(spacing: 6) {
            Button {
                actions.refresh()
            } label: {
                Image(systemName: store.isRefreshing ? "hourglass" : "arrow.clockwise")
            }
            .buttonStyle(.glass)
            .controlSize(.small)
            .disabled(store.isRefreshing || !store.isConfigured)
            .help("Refresh")

            Button {
                actions.openMain()
            } label: {
                Image(systemName: "rectangle.and.text.magnifyingglass")
            }
            .buttonStyle(.glass)
            .controlSize(.small)
            .help("Open telemetry")

            Button {
                state.hide()
            } label: {
                Image(systemName: "xmark")
            }
            .buttonStyle(.glass)
            .controlSize(.small)
            .help("Hide")
        }
    }

    private var statusDot: some View {
        Circle()
            .fill(store.latestNewCount > 0 ? .green : store.isConfigured ? .cyan : .orange)
            .frame(width: 9, height: 9)
            .shadow(color: store.latestNewCount > 0 ? .green : .clear, radius: 8)
    }

    private var compactTitle: String {
        if let latest = store.latestCheckIn {
            return latest.displayName
        }

        return state.isHoverPreview ? "CTT Pulse" : store.isConfigured ? "CTT Pulse" : "CTT token needed"
    }

    private var compactSubtitle: String {
        if state.isHoverPreview {
            return "Click to open telemetry"
        }

        if let latest = store.latestCheckIn {
            return "Checked in \(TelemetryDateFormatter.relative(latest.connectionAt))"
        }

        return store.isConfigured ? "Waiting for check-ins" : "Open settings"
    }

    private var headerSubtitle: String {
        if store.checkIns.isEmpty {
            return store.isConfigured ? "Waiting for CTT data" : "PAT required"
        }

        return "\(store.checkIns.count) monitored devices"
    }

    private var islandLocationTaskID: String {
        "\(state.isExpanded)-\(selectedIslandCheckIn?.id ?? "none")"
    }

    private var checkInIDs: [String] {
        store.checkIns.map(\.id)
    }

    private var selectedIslandCheckIn: TelemetryCheckIn? {
        if
            let selectedIslandCheckInID,
            let selected = store.checkIns.first(where: { $0.id == selectedIslandCheckInID })
        {
            return selected
        }

        return store.latestCheckIn
    }

    private func recentRow(for checkIn: TelemetryCheckIn) -> some View {
        let isSelected = selectedIslandCheckIn?.id == checkIn.id

        return Button {
            selectedIslandCheckInID = checkIn.id
            Task { await store.loadLocations(for: checkIn) }
        } label: {
            HStack(spacing: 8) {
                Circle()
                    .fill(checkIn.isNew ? .green : isSelected ? .cyan : .secondary.opacity(0.55))
                    .frame(width: 6, height: 6)

                VStack(alignment: .leading, spacing: 1) {
                    Text(checkIn.displayName)
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                    Text(TelemetryDateFormatter.relative(checkIn.connectionAt))
                        .font(.caption2.weight(isSelected ? .semibold : .regular))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .background(isSelected ? .white.opacity(0.12) : .clear, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func selectDefaultIslandCheckInIfNeeded() {
        guard
            selectedIslandCheckInID == nil || !store.checkIns.contains(where: { $0.id == selectedIslandCheckInID })
        else {
            return
        }

        selectedIslandCheckInID = store.latestCheckIn?.id
    }

    private func mapAgeLabel(for checkIn: TelemetryCheckIn, locations: [TelemetryLocation]) -> String {
        if case .lastKnown = store.locationSource(for: checkIn) {
            return "last known"
        }

        guard let latest = locations.first else { return "no fix" }
        return TelemetryDateFormatter.relative(latest.fixAt)
    }

    private func pulse() {
        guard store.latestNewCount > 0 else { return }

        withAnimation(.easeOut(duration: 0.16)) {
            isPulsing = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation(.easeOut(duration: 0.5)) {
                isPulsing = false
            }
        }
    }

    private func pulseOverlay<S: Shape>(shape: S) -> some View {
        shape
            .stroke(.green.opacity(isPulsing ? 0.95 : 0), lineWidth: isPulsing ? 3 : 0)
            .shadow(color: .green.opacity(isPulsing ? 0.9 : 0), radius: isPulsing ? 18 : 0)
    }

    private func startHoverGlow() {
        hoverGlow = false

        withAnimation(.easeInOut(duration: 0.78).repeatForever(autoreverses: true)) {
            hoverGlow = true
        }
    }

    private func stopHoverGlow() {
        withAnimation(.easeOut(duration: 0.18)) {
            hoverGlow = false
        }
    }
}

private struct IslandModule<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 20, style: .continuous)

        content
            .padding(12)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .glassEffect(.regular, in: shape)
            .overlay {
                shape
                    .strokeBorder(.white.opacity(0.08), lineWidth: 1)
            }
    }
}
