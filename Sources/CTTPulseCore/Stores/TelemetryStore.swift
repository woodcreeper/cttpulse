import Combine
import Foundation

@MainActor
public final class TelemetryStore: ObservableObject {
    @Published public private(set) var isConfigured: Bool
    @Published public private(set) var isRefreshing = false
    @Published public private(set) var isLoadingLocations = false
    @Published public private(set) var userEmail: String?
    @Published public private(set) var projects: [TelemetryProject] = []
    @Published public private(set) var allDevices: [TelemetryDevice] = []
    @Published public private(set) var devices: [TelemetryDevice] = []
    @Published public private(set) var allCheckIns: [TelemetryCheckIn] = []
    @Published public private(set) var checkIns: [TelemetryCheckIn] = []
    @Published public private(set) var locationsByIMEI: [String: [TelemetryLocation]] = [:]
    @Published public private(set) var locationSourcesByIMEI: [String: TelemetryLocationSource] = [:]
    @Published public private(set) var locationErrorsByIMEI: [String: String] = [:]
    @Published public private(set) var batteryReadingsByIMEI: [String: TelemetryBatteryReading] = [:]
    @Published public var selectedCheckInID: String?
    @Published public private(set) var lastRefresh: Date?
    @Published public private(set) var lastError: String?
    @Published public private(set) var lastRefreshSummary = "Not refreshed yet"
    @Published public private(set) var pulseID = UUID()
    @Published public private(set) var latestNewCount = 0
    @Published public private(set) var latestNotificationBatch: TelemetryNotificationBatch?

    private let apiClient: any CTTAPIProviding
    private let tokenStore: KeychainTokenStore
    private let lastSeenStore: LastSeenConnectionStore
    private let filterStore: TelemetryFilterStore
    private let nowProvider: @MainActor () -> Date
    private var pollingTask: Task<Void, Never>?
    private var locationFetchAtByIMEI: [String: Date] = [:]
    private var batteryFetchAtByIMEI: [String: Date] = [:]
    private var loadingLocationIMEIs: Set<String> = []

    private let locationCacheTTL: TimeInterval = 5 * 60
    private let batteryCacheTTL: TimeInterval = 30 * 60
    private let recentLocationWindow: TimeInterval = 24 * 60 * 60
    private let historicalLocationWindow: TimeInterval = 30 * 24 * 60 * 60
    private let historicalLocationLookAhead: TimeInterval = 6 * 60 * 60
    private let freshCheckInAlertWindow: TimeInterval = 30 * 60

    init(
        apiClient: any CTTAPIProviding,
        tokenStore: KeychainTokenStore,
        lastSeenStore: LastSeenConnectionStore = LastSeenConnectionStore(),
        filterStore: TelemetryFilterStore = TelemetryFilterStore(),
        nowProvider: @escaping @MainActor () -> Date = { Date() },
        initiallyConfigured: Bool? = nil
    ) {
        self.apiClient = apiClient
        self.tokenStore = tokenStore
        self.lastSeenStore = lastSeenStore
        self.filterStore = filterStore
        self.nowProvider = nowProvider
        self.isConfigured = initiallyConfigured ?? tokenStore.hasToken()
    }

    deinit {
        pollingTask?.cancel()
    }

    public var selectedCheckIn: TelemetryCheckIn? {
        guard let selectedCheckInID else { return checkIns.first }
        return checkIns.first { $0.id == selectedCheckInID } ?? checkIns.first
    }

    public var latestCheckIn: TelemetryCheckIn? {
        checkIns.first
    }

    public var filterSummary: String {
        guard !allDevices.isEmpty else { return "No devices loaded" }
        return "Showing \(devices.count) of \(allDevices.count) devices"
    }

    public func devices(in projectID: String) -> [TelemetryDevice] {
        allDevices.filter { $0.projectID == projectID }
    }

    public func isProjectIncluded(_ project: TelemetryProject) -> Bool {
        let projectDevices = devices(in: project.id)
        guard !projectDevices.isEmpty else { return false }
        return projectDevices.allSatisfy { filterStore.includes($0) }
    }

    public func isProjectPartiallyIncluded(_ project: TelemetryProject) -> Bool {
        let projectDevices = devices(in: project.id)
        guard !projectDevices.isEmpty else { return false }
        let selectedCount = projectDevices.filter { filterStore.includes($0) }.count
        return selectedCount > 0 && selectedCount < projectDevices.count
    }

    public func isDeviceIncluded(_ device: TelemetryDevice) -> Bool {
        filterStore.includes(device)
    }

    public func setProjectIncluded(_ project: TelemetryProject, isIncluded: Bool) {
        filterStore.setProject(project.id, isIncluded: isIncluded, devices: allDevices)
        applyFilters()
    }

    public func setDeviceIncluded(_ device: TelemetryDevice, isIncluded: Bool) {
        filterStore.setDevice(device.id, isIncluded: isIncluded)
        applyFilters()
    }

    public func selectAllFilters() {
        filterStore.selectAll(devices: allDevices)
        applyFilters()
    }

    public func selectNoFilters() {
        filterStore.selectNone()
        applyFilters()
    }

    public func configureToken(_ token: String) async {
        let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            lastError = "Paste a CTT Personal Access Token."
            return
        }

        do {
            try tokenStore.saveToken(trimmed)
            lastSeenStore.clear()
            isConfigured = true
            lastError = nil
            lastRefreshSummary = "Token saved. Loading CTT telemetry..."
            await refresh(reason: .manual)
        } catch {
            lastError = error.localizedDescription
            lastRefreshSummary = error.localizedDescription
        }
    }

    public func disconnect() {
        do {
            try tokenStore.deleteToken()
        } catch {
            lastError = error.localizedDescription
        }

        lastSeenStore.clear()
        isConfigured = false
        userEmail = nil
        projects = []
        allDevices = []
        devices = []
        allCheckIns = []
        checkIns = []
        latestNotificationBatch = nil
        latestNewCount = 0
        locationsByIMEI = [:]
        locationSourcesByIMEI = [:]
        locationErrorsByIMEI = [:]
        batteryReadingsByIMEI = [:]
        locationFetchAtByIMEI = [:]
        batteryFetchAtByIMEI = [:]
        loadingLocationIMEIs = []
        filterStore.clear()
        selectedCheckInID = nil
    }

    public func startPolling() {
        guard pollingTask == nil else { return }

        pollingTask = Task { [weak self] in
            await self?.refresh(reason: .launch)

            while !Task.isCancelled {
                do {
                    try await Task.sleep(for: .seconds(15 * 60))
                } catch {
                    return
                }

                await self?.refresh(reason: .scheduled)
            }
        }
    }

    public func stopPolling() {
        pollingTask?.cancel()
        pollingTask = nil
    }

    public func refresh(reason: RefreshReason) async {
        guard isConfigured else { return }
        guard !isRefreshing else { return }

        isRefreshing = true
        lastRefreshSummary = "Checking CTT token..."
        defer { isRefreshing = false }

        do {
            let user = try await apiClient.fetchMe()
            lastRefreshSummary = "Loading projects..."
            let projectDTOs = try await apiClient.fetchProjects()
            let projects = projectDTOs.map {
                TelemetryProject(id: $0.projectId, name: $0.name, description: $0.description)
            }

            var allDevices: [TelemetryDevice] = []
            var snapshots: [DeviceSnapshot] = []
            var notificationEvents: [TelemetryNotificationEvent] = []
            let hasSeeded = lastSeenStore.hasSeeded
            let alertCutoff = nowProvider().addingTimeInterval(-freshCheckInAlertWindow)

            for project in projects {
                lastRefreshSummary = "Loading devices for \(project.name)..."
                let projectDevices = try await apiClient.fetchDevices(projectID: project.id)

                for dto in projectDevices {
                    let latestConnectionAt = TelemetryDateFormatter.parseISO8601(dto.latestConnectionAt)
                    let latestLocationAt = TelemetryDateFormatter.parseISO8601(dto.latestLocationAt)
                    let device = TelemetryDevice(
                        id: Self.deviceKey(projectID: project.id, imei: dto.imei),
                        projectID: project.id,
                        projectName: project.name,
                        imei: dto.imei,
                        deviceType: dto.deviceType,
                        alias: dto.alias,
                        deviceName: nil,
                        latestConnectionAt: latestConnectionAt,
                        latestLocationAt: latestLocationAt,
                        latestBatteryV: dto.latestBatteryV
                    )

                    allDevices.append(device)
                    snapshots.append(
                        DeviceSnapshot(
                            device: device,
                            latestConnectionAt: latestConnectionAt,
                            latestLocationAt: latestLocationAt,
                            latestBatteryV: dto.latestBatteryV
                        )
                    )
                }
            }

            let sortedProjects = projects.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            let sortedAllDevices = allDevices.sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
            filterStore.prepareDefaults(devices: sortedAllDevices)

            var latestByDevice: [String: TelemetryCheckIn] = [:]

            for snapshot in snapshots {
                let device = snapshot.device
                let latestConnectionAt = snapshot.latestConnectionAt
                let latestLocationAt = snapshot.latestLocationAt
                let key = device.id
                let eventAt: Date
                let kind: TelemetryCheckIn.Kind
                let isNew: Bool
                let notificationKind: TelemetryNotificationEvent.Kind?

                if let latestConnectionAt {
                    let previousDate = lastSeenStore.date(for: key)
                    let isSelected = filterStore.includes(device)
                    let isNewTag = isSelected && hasSeeded && previousDate == nil
                    let isFreshCheckIn = isSelected
                        && hasSeeded
                        && previousDate != nil
                        && latestConnectionAt > previousDate!
                        && latestConnectionAt >= alertCutoff
                    isNew = isNewTag || isFreshCheckIn
                    notificationKind = isNewTag ? .newTag : isFreshCheckIn ? .checkIn : nil
                    eventAt = latestConnectionAt
                    kind = .connection
                    lastSeenStore.set(latestConnectionAt, for: key)
                } else if let latestLocationAt {
                    isNew = false
                    notificationKind = nil
                    eventAt = latestLocationAt
                    kind = .location
                } else {
                    continue
                }

                let checkIn = TelemetryCheckIn(
                    id: "\(key)|\(kind.rawValue)|\(TelemetryDateFormatter.apiString(from: eventAt))",
                    projectID: device.projectID,
                    projectName: device.projectName,
                    imei: device.imei,
                    displayName: device.displayName,
                    deviceType: device.deviceType,
                    kind: kind,
                    connectionAt: eventAt,
                    latestLocationAt: latestLocationAt,
                    latestBatteryV: snapshot.latestBatteryV,
                    isNew: isNew
                )

                if let notificationKind {
                    notificationEvents.append(TelemetryNotificationEvent(kind: notificationKind, checkIn: checkIn))
                }

                if let existing = latestByDevice[key] {
                    if checkIn.connectionAt > existing.connectionAt {
                        latestByDevice[key] = checkIn
                    }
                } else {
                    latestByDevice[key] = checkIn
                }
            }

            let sortedAllCheckIns = latestByDevice.values.sorted { $0.connectionAt > $1.connectionAt }

            lastSeenStore.markSeeded()

            self.userEmail = user.email
            self.projects = sortedProjects
            self.allDevices = sortedAllDevices
            self.allCheckIns = sortedAllCheckIns
            applyFilters()
            self.lastRefresh = Date()
            self.lastError = nil
            self.lastRefreshSummary = "Loaded \(projects.count) projects, \(allDevices.count) devices. \(filterSummary)."

            latestNewCount = notificationEvents.count
            if notificationEvents.isEmpty {
                latestNotificationBatch = nil
            } else {
                latestNotificationBatch = TelemetryNotificationBatch(events: notificationEvents)
                pulseID = UUID()
            }
        } catch {
            lastError = error.localizedDescription
            lastRefreshSummary = "Refresh failed: \(error.localizedDescription)"
            if case CTTAPIClientError.missingToken = error {
                isConfigured = false
            }
        }
    }

    public func loadLocations(for checkIn: TelemetryCheckIn, force: Bool = false) async {
        guard isConfigured else { return }

        selectedCheckInID = checkIn.id

        let now = nowProvider()
        if !force, let lastFetch = locationFetchAtByIMEI[checkIn.imei], now.timeIntervalSince(lastFetch) < locationCacheTTL {
            await loadBatteryIfNeeded(for: checkIn, force: false)
            return
        }

        guard loadingLocationIMEIs.insert(checkIn.imei).inserted else { return }
        isLoadingLocations = true
        defer {
            loadingLocationIMEIs.remove(checkIn.imei)
            isLoadingLocations = !loadingLocationIMEIs.isEmpty
        }

        let end = now
        let start = end.addingTimeInterval(-recentLocationWindow)

        do {
            try Task.checkCancellation()
            let records = try await apiClient.fetchLocations(imei: checkIn.imei, start: start, end: end)
            let recentLocations = TelemetryLocationFilter.latestValidLocations(
                records,
                imei: checkIn.imei,
                start: start,
                end: end,
                limit: 10
            )

            let locations: [TelemetryLocation]
            let source: TelemetryLocationSource

            if !recentLocations.isEmpty {
                locations = recentLocations
                source = .recent24h
            } else if let fallbackReference = historicalLocationReference(for: checkIn, recentStart: start) {
                let fallbackEnd = historicalWindowEnd(reference: fallbackReference, now: end)
                let fallbackStart = fallbackEnd.addingTimeInterval(-historicalLocationWindow)
                let fallbackRecords = try await apiClient.fetchLocations(
                    imei: checkIn.imei,
                    start: fallbackStart,
                    end: fallbackEnd
                )
                locations = TelemetryLocationFilter.lastKnownLocations(
                    fallbackRecords,
                    imei: checkIn.imei,
                    start: fallbackStart,
                    end: fallbackEnd,
                    reference: checkIn.connectionAt,
                    limit: 10
                )
                source = locations.isEmpty ? .recent24h : .lastKnown(referenceAt: locations.first?.fixAt ?? fallbackReference)
            } else {
                locations = []
                source = .recent24h
            }

            locationFetchAtByIMEI[checkIn.imei] = nowProvider()
            locationsByIMEI[checkIn.imei] = locations
            locationSourcesByIMEI[checkIn.imei] = source
            locationErrorsByIMEI[checkIn.imei] = nil
        } catch is CancellationError {
            return
        } catch {
            locationFetchAtByIMEI[checkIn.imei] = nowProvider()
            locationsByIMEI[checkIn.imei] = []
            locationSourcesByIMEI[checkIn.imei] = .recent24h

            if case CTTAPIClientError.server(_, .notFound, _, _) = error {
                locationErrorsByIMEI[checkIn.imei] = "CTT did not return a location stream for this device."
            } else if case CTTAPIClientError.server(_, .rateLimited, _, _) = error {
                locationErrorsByIMEI[checkIn.imei] = "CTT rate limit reached. Waiting briefly before trying again."
            } else {
                locationErrorsByIMEI[checkIn.imei] = error.localizedDescription
            }
        }

        await loadBatteryIfNeeded(for: checkIn, force: force)
    }

    public func locations(for checkIn: TelemetryCheckIn) -> [TelemetryLocation] {
        locationsByIMEI[checkIn.imei] ?? []
    }

    public func locationSource(for checkIn: TelemetryCheckIn) -> TelemetryLocationSource? {
        locationSourcesByIMEI[checkIn.imei]
    }

    public func locationError(for checkIn: TelemetryCheckIn) -> String? {
        locationErrorsByIMEI[checkIn.imei]
    }

    public func locationSubtitle(for checkIn: TelemetryCheckIn) -> String {
        if let error = locationError(for: checkIn) {
            return error
        }

        switch locationSource(for: checkIn) {
        case let .lastKnown(referenceAt):
            return "Last known locations near \(referenceAt.formatted(date: .abbreviated, time: .shortened))"
        default:
            return "Last 24 hours, newest 10 valid points"
        }
    }

    public func batteryVoltage(for checkIn: TelemetryCheckIn) -> Double? {
        checkIn.latestBatteryV ?? batteryReadingsByIMEI[checkIn.imei]?.voltage
    }

    private static func deviceKey(projectID: String, imei: String) -> String {
        "\(projectID)|\(imei)"
    }

    private func historicalWindowEnd(reference: Date, now: Date) -> Date {
        let referenceEnd = reference.addingTimeInterval(historicalLocationLookAhead)
        return referenceEnd > now ? now : referenceEnd
    }

    private func historicalLocationReference(for checkIn: TelemetryCheckIn, recentStart: Date) -> Date? {
        if let latestLocationAt = checkIn.latestLocationAt {
            return latestLocationAt < recentStart ? latestLocationAt : nil
        }

        return checkIn.connectionAt < recentStart ? checkIn.connectionAt : nil
    }

    private func loadBatteryIfNeeded(for checkIn: TelemetryCheckIn, force: Bool) async {
        guard checkIn.latestBatteryV == nil || force else { return }

        let now = nowProvider()
        if !force, let lastFetch = batteryFetchAtByIMEI[checkIn.imei], now.timeIntervalSince(lastFetch) < batteryCacheTTL {
            return
        }

        let reference = checkIn.latestLocationAt ?? checkIn.connectionAt
        let isHistorical = reference < now.addingTimeInterval(-recentLocationWindow)
        let end = isHistorical ? historicalWindowEnd(reference: reference, now: now) : now
        let start = end.addingTimeInterval(-historicalLocationWindow)

        do {
            try Task.checkCancellation()
            let records = try await apiClient.fetchSensors(imei: checkIn.imei, start: start, end: end)
            batteryFetchAtByIMEI[checkIn.imei] = nowProvider()

            if let reading = latestBatteryReading(from: records) {
                batteryReadingsByIMEI[checkIn.imei] = reading
            }
        } catch is CancellationError {
            return
        } catch {
            batteryFetchAtByIMEI[checkIn.imei] = nowProvider()
        }
    }

    private func latestBatteryReading(from records: [SensorRecordDTO]) -> TelemetryBatteryReading? {
        records.compactMap { record -> TelemetryBatteryReading? in
            guard
                let voltage = record.batteryV,
                let readAt = TelemetryDateFormatter.parseISO8601(record.time)
            else {
                return nil
            }

            return TelemetryBatteryReading(voltage: voltage, readAt: readAt)
        }
        .sorted { $0.readAt > $1.readAt }
        .first
    }

    private func applyFilters() {
        devices = allDevices.filter { filterStore.includes($0) }
        let selectedDeviceIDs = Set(devices.map(\.id))
        allCheckIns = allCheckIns.sorted { $0.connectionAt > $1.connectionAt }
        checkIns = allCheckIns
            .filter { selectedDeviceIDs.contains(Self.deviceKey(projectID: $0.projectID, imei: $0.imei)) }
            .sorted { $0.connectionAt > $1.connectionAt }

        if selectedCheckInID == nil || !checkIns.contains(where: { $0.id == selectedCheckInID }) {
            selectedCheckInID = checkIns.first?.id
        }
    }
}

private struct DeviceSnapshot {
    let device: TelemetryDevice
    let latestConnectionAt: Date?
    let latestLocationAt: Date?
    let latestBatteryV: Double?
}
