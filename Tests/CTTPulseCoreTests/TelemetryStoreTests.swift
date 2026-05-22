import Foundation
import Testing
@testable import CTTPulseCore

@MainActor
@Suite("Telemetry store")
struct TelemetryStoreTests {
    @Test("First poll seeds without alert, changed connection alerts once")
    func detectsNewCheckInsAfterInitialSeed() async {
        let suiteName = "TelemetryStoreTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)

        let api = FakeAPI()
        let tokenStore = KeychainTokenStore(service: "TelemetryStoreTests.\(UUID().uuidString)")
        let store = TelemetryStore(
            apiClient: api,
            tokenStore: tokenStore,
            lastSeenStore: LastSeenConnectionStore(defaults: defaults),
            filterStore: TelemetryFilterStore(defaults: defaults),
            nowProvider: { Self.testNow },
            initiallyConfigured: true
        )

        api.devices = [
            ProjectDeviceDTO(
                imei: "352753094012345",
                deviceType: "flicker_gps_gen2",
                alias: "Tern 12",
                latestConnectionAt: "2026-05-20T12:00:00Z",
                latestLocationAt: "2026-05-20T11:58:00Z",
                latestBatteryV: 3.9
            )
        ]

        await store.refresh(reason: .launch)

        #expect(store.checkIns.count == 1)
        #expect(store.latestNewCount == 0)
        #expect(store.latestNotificationBatch == nil)
        #expect(store.checkIns[0].isNew == false)
        #expect(store.checkIns[0].kind == .connection)

        api.devices = [
            ProjectDeviceDTO(
                imei: "352753094012345",
                deviceType: "flicker_gps_gen2",
                alias: "Tern 12",
                latestConnectionAt: "2026-05-20T12:15:00Z",
                latestLocationAt: "2026-05-20T12:14:00Z",
                latestBatteryV: 3.88
            )
        ]

        await store.refresh(reason: .scheduled)

        #expect(store.latestNewCount == 1)
        #expect(store.latestNotificationBatch?.events.map(\.kind) == [.checkIn])
        #expect(store.latestNotificationBatch?.events.first?.title == "Tern 12 checked in")
        #expect(store.checkIns[0].isNew == true)
        #expect(store.checkIns[0].connectionAt == TelemetryDateFormatter.parseISO8601("2026-05-20T12:15:00Z"))

        await store.refresh(reason: .scheduled)

        #expect(store.latestNewCount == 0)
        #expect(store.latestNotificationBatch == nil)
        #expect(store.checkIns[0].isNew == false)
    }

    @Test("Devices with location but no connection still display")
    func displaysLocationOnlyDevices() async {
        let suiteName = "TelemetryStoreTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)

        let api = FakeAPI()
        let tokenStore = KeychainTokenStore(service: "TelemetryStoreTests.\(UUID().uuidString)")
        let store = TelemetryStore(
            apiClient: api,
            tokenStore: tokenStore,
            lastSeenStore: LastSeenConnectionStore(defaults: defaults),
            filterStore: TelemetryFilterStore(defaults: defaults),
            nowProvider: { Self.testNow },
            initiallyConfigured: true
        )

        api.devices = [
            ProjectDeviceDTO(
                imei: "352753094012345",
                deviceType: "flicker_gps_gen2",
                alias: "Tern 12",
                latestConnectionAt: nil,
                latestLocationAt: "2026-05-20T12:14:00Z",
                latestBatteryV: 3.88
            )
        ]

        await store.refresh(reason: .launch)

        #expect(store.devices.count == 1)
        #expect(store.checkIns.count == 1)
        #expect(store.checkIns[0].kind == .location)
        #expect(store.latestNewCount == 0)
    }

    @Test("Device location not found is scoped to detail view")
    func scopesLocationNotFoundAwayFromGlobalError() async {
        let suiteName = "TelemetryStoreTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)

        let api = FakeAPI()
        api.locationError = CTTAPIClientError.server(
            status: 404,
            code: .notFound,
            message: "Device not found",
            requestID: "request_1"
        )
        let tokenStore = KeychainTokenStore(service: "TelemetryStoreTests.\(UUID().uuidString)")
        let store = TelemetryStore(
            apiClient: api,
            tokenStore: tokenStore,
            lastSeenStore: LastSeenConnectionStore(defaults: defaults),
            filterStore: TelemetryFilterStore(defaults: defaults),
            nowProvider: { Self.testNow },
            initiallyConfigured: true
        )

        api.devices = [
            ProjectDeviceDTO(
                imei: "352753094012345",
                deviceType: "flicker_gps_gen2",
                alias: "Tern 12",
                latestConnectionAt: "2026-05-20T12:00:00Z",
                latestLocationAt: "2026-05-20T11:58:00Z",
                latestBatteryV: 3.9
            )
        ]

        await store.refresh(reason: .launch)
        await store.loadLocations(for: store.checkIns[0])

        #expect(store.lastError == nil)
        #expect(store.locations(for: store.checkIns[0]).isEmpty)
        #expect(store.locationError(for: store.checkIns[0]) == "CTT did not return a location stream or latest location snapshot for this device.")
    }

    @Test("Device location not found falls back to latest device snapshot")
    func locationNotFoundFallsBackToLatestDeviceSnapshot() async {
        let suiteName = "TelemetryStoreTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)

        let api = FakeAPI()
        api.locationError = CTTAPIClientError.server(
            status: 404,
            code: .notFound,
            message: "Device not found",
            requestID: "request_snapshot"
        )
        api.deviceDetail = DeviceDetailDTO(
            imei: "352753094012345",
            deviceType: "flicker",
            deviceName: nil,
            latestLocation: DeviceLatestLocationDTO(
                timeUtc: "2026-05-20T12:00:00Z",
                type: "cell_locate",
                lat: 50.0134843,
                lon: -97.7692219,
                altM: 294
            ),
            latestSensor: DeviceLatestSensorDTO(
                timeUtc: "2026-05-20T12:00:00Z",
                batteryMv: 4080
            )
        )
        let tokenStore = KeychainTokenStore(service: "TelemetryStoreTests.\(UUID().uuidString)")
        let store = TelemetryStore(
            apiClient: api,
            tokenStore: tokenStore,
            lastSeenStore: LastSeenConnectionStore(defaults: defaults),
            filterStore: TelemetryFilterStore(defaults: defaults),
            nowProvider: { Self.testNow },
            initiallyConfigured: true
        )

        api.devices = [
            ProjectDeviceDTO(
                imei: "352753094012345",
                deviceType: "flicker",
                alias: "Cason 40",
                latestConnectionAt: "2026-05-20T12:00:00Z",
                latestLocationAt: nil,
                latestBatteryV: nil
            )
        ]

        await store.refresh(reason: .launch)
        await store.loadLocations(for: store.checkIns[0])

        let locations = store.locations(for: store.checkIns[0])
        #expect(locations.count == 1)
        #expect(locations[0].type == "cell_locate")
        #expect(locations[0].coordinateLabel == "50.013484, -97.769222")
        #expect(store.locationError(for: store.checkIns[0]) == nil)
        #expect(store.batteryVoltage(for: store.checkIns[0]) == 4.08)
    }

    @Test("Rate limited location errors use friendly detail copy")
    func rateLimitedLocationErrorIsFriendly() async {
        let suiteName = "TelemetryStoreTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)

        let api = FakeAPI()
        api.locationError = CTTAPIClientError.server(
            status: 429,
            code: .rateLimited,
            message: "Rate limit exceeded",
            requestID: "request_2"
        )
        let tokenStore = KeychainTokenStore(service: "TelemetryStoreTests.\(UUID().uuidString)")
        let store = TelemetryStore(
            apiClient: api,
            tokenStore: tokenStore,
            lastSeenStore: LastSeenConnectionStore(defaults: defaults),
            filterStore: TelemetryFilterStore(defaults: defaults),
            nowProvider: { Self.testNow },
            initiallyConfigured: true
        )

        api.devices = [Self.deviceDTO()]

        await store.refresh(reason: .launch)
        await store.loadLocations(for: store.checkIns[0])

        #expect(store.lastError == nil)
        #expect(store.locationError(for: store.checkIns[0]) == "CTT rate limit reached. Waiting briefly before trying again.")
    }

    @Test("Location loads are cached unless forced")
    func cachesLocationLoadsUntilForced() async {
        let suiteName = "TelemetryStoreTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)

        let api = FakeAPI()
        let tokenStore = KeychainTokenStore(service: "TelemetryStoreTests.\(UUID().uuidString)")
        let store = TelemetryStore(
            apiClient: api,
            tokenStore: tokenStore,
            lastSeenStore: LastSeenConnectionStore(defaults: defaults),
            filterStore: TelemetryFilterStore(defaults: defaults),
            nowProvider: { Self.testNow },
            initiallyConfigured: true
        )

        api.devices = [Self.deviceDTO()]

        await store.refresh(reason: .launch)
        await store.loadLocations(for: store.checkIns[0])
        await store.loadLocations(for: store.checkIns[0])

        #expect(api.locationFetchCount == 1)

        await store.loadLocations(for: store.checkIns[0], force: true)

        #expect(api.locationFetchCount == 2)
    }

    @Test("Stale devices fall back to last known location windows")
    func loadsLastKnownLocationsForStaleDevices() async {
        let suiteName = "TelemetryStoreTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)

        let api = FakeAPI()
        let tokenStore = KeychainTokenStore(service: "TelemetryStoreTests.\(UUID().uuidString)")
        let store = TelemetryStore(
            apiClient: api,
            tokenStore: tokenStore,
            lastSeenStore: LastSeenConnectionStore(defaults: defaults),
            filterStore: TelemetryFilterStore(defaults: defaults),
            nowProvider: { Self.testNow },
            initiallyConfigured: true
        )

        api.devices = [
            Self.deviceDTO(
                latestConnectionAt: "2026-05-17T12:00:00Z",
                latestLocationAt: "2026-05-17T11:58:00Z"
            )
        ]
        api.locationResponses = [
            [],
            [
                Self.locationRecord(fixAt: "2026-05-17T12:02:00Z", type: "cell_locate", lat: 40.1, lon: -73.1),
                Self.locationRecord(fixAt: "2026-05-17T11:58:00Z", type: "gps", lat: 40.2, lon: -73.2)
            ]
        ]

        await store.refresh(reason: .launch)
        await store.loadLocations(for: store.checkIns[0])

        #expect(api.locationFetchCount == 2)
        #expect(api.locationRequests.count == 2)
        #expect(store.locations(for: store.checkIns[0]).map(\.latitude) == [40.2, 40.1])
        #expect(store.locations(for: store.checkIns[0]).map(\.type) == ["gps", "cell_locate"])
        #expect(store.locationSource(for: store.checkIns[0]) == .lastKnown(referenceAt: TelemetryDateFormatter.parseISO8601("2026-05-17T11:58:00Z")!))
    }

    @Test("Stale devices without latest location timestamp still search historical locations")
    func loadsHistoricalLocationsWhenLatestLocationTimestampIsMissing() async {
        let suiteName = "TelemetryStoreTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)

        let api = FakeAPI()
        let tokenStore = KeychainTokenStore(service: "TelemetryStoreTests.\(UUID().uuidString)")
        let store = TelemetryStore(
            apiClient: api,
            tokenStore: tokenStore,
            lastSeenStore: LastSeenConnectionStore(defaults: defaults),
            filterStore: TelemetryFilterStore(defaults: defaults),
            nowProvider: { Self.testNow },
            initiallyConfigured: true
        )

        api.devices = [
            Self.deviceDTO(
                latestConnectionAt: "2026-05-17T12:00:00Z",
                latestLocationAt: nil
            )
        ]
        api.locationResponses = [
            [],
            [Self.locationRecord(fixAt: "2026-05-17T10:30:00Z", lat: 40.6, lon: -73.6)]
        ]

        await store.refresh(reason: .launch)
        await store.loadLocations(for: store.checkIns[0])

        #expect(api.locationFetchCount == 2)
        #expect(store.locations(for: store.checkIns[0]).map(\.latitude) == [40.6])
        #expect(store.locationSource(for: store.checkIns[0]) == .lastKnown(referenceAt: TelemetryDateFormatter.parseISO8601("2026-05-17T10:30:00Z")!))
    }

    @Test("Missing project battery falls back to latest sensor voltage")
    func loadsBatteryFromSensorRecordsWhenProjectSummaryIsEmpty() async {
        let suiteName = "TelemetryStoreTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)

        let api = FakeAPI()
        let tokenStore = KeychainTokenStore(service: "TelemetryStoreTests.\(UUID().uuidString)")
        let store = TelemetryStore(
            apiClient: api,
            tokenStore: tokenStore,
            lastSeenStore: LastSeenConnectionStore(defaults: defaults),
            filterStore: TelemetryFilterStore(defaults: defaults),
            nowProvider: { Self.testNow },
            initiallyConfigured: true
        )

        api.devices = [Self.deviceDTO(latestBatteryV: nil)]
        api.sensorRecords = [
            Self.sensorRecord(time: "2026-05-20T11:50:00Z", batteryV: 3.61),
            Self.sensorRecord(time: "2026-05-20T12:10:00Z", batteryV: 3.72)
        ]

        await store.refresh(reason: .launch)
        #expect(store.batteryVoltage(for: store.checkIns[0]) == nil)

        await store.loadLocations(for: store.checkIns[0])

        #expect(api.sensorFetchCount == 1)
        #expect(store.batteryVoltage(for: store.checkIns[0]) == 3.72)
    }

    @Test("Stale connection changes do not create popup alerts")
    func ignoresStaleConnectionChangesForAlerts() async {
        let suiteName = "TelemetryStoreTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)

        let api = FakeAPI()
        let tokenStore = KeychainTokenStore(service: "TelemetryStoreTests.\(UUID().uuidString)")
        let store = TelemetryStore(
            apiClient: api,
            tokenStore: tokenStore,
            lastSeenStore: LastSeenConnectionStore(defaults: defaults),
            filterStore: TelemetryFilterStore(defaults: defaults),
            nowProvider: { Self.testNow },
            initiallyConfigured: true
        )

        api.devices = [
            ProjectDeviceDTO(
                imei: "352753094012345",
                deviceType: "flicker_gps_gen2",
                alias: "Tern 12",
                latestConnectionAt: "2026-05-19T12:00:00Z",
                latestLocationAt: "2026-05-19T11:58:00Z",
                latestBatteryV: 3.9
            )
        ]

        await store.refresh(reason: .launch)

        api.devices = [
            ProjectDeviceDTO(
                imei: "352753094012345",
                deviceType: "flicker_gps_gen2",
                alias: "Tern 12",
                latestConnectionAt: "2026-05-19T16:00:00Z",
                latestLocationAt: "2026-05-19T15:58:00Z",
                latestBatteryV: 3.88
            )
        ]

        await store.refresh(reason: .scheduled)

        #expect(store.latestNewCount == 0)
        #expect(store.latestNotificationBatch == nil)
        #expect(store.checkIns[0].isNew == false)
    }

    @Test("Fresh newly discovered devices can still alert")
    func alertsForFreshNewlyDiscoveredDevices() async {
        let suiteName = "TelemetryStoreTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)

        let api = FakeAPI()
        let tokenStore = KeychainTokenStore(service: "TelemetryStoreTests.\(UUID().uuidString)")
        let store = TelemetryStore(
            apiClient: api,
            tokenStore: tokenStore,
            lastSeenStore: LastSeenConnectionStore(defaults: defaults),
            filterStore: TelemetryFilterStore(defaults: defaults),
            nowProvider: { Self.testNow },
            initiallyConfigured: true
        )

        api.devices = []
        await store.refresh(reason: .launch)

        api.devices = [Self.deviceDTO()]
        await store.refresh(reason: .scheduled)

        #expect(store.latestNewCount == 1)
        #expect(store.latestNotificationBatch?.events.map(\.kind) == [.newTag])
        #expect(store.latestNotificationBatch?.events.first?.title == "New tag added")
        #expect(store.checkIns[0].isNew == true)
    }

    @Test("Device filters hide records and suppress alerts")
    func filtersHideRecordsAndSuppressAlerts() async {
        let suiteName = "TelemetryStoreTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)

        let api = FakeAPI()
        let tokenStore = KeychainTokenStore(service: "TelemetryStoreTests.\(UUID().uuidString)")
        let store = TelemetryStore(
            apiClient: api,
            tokenStore: tokenStore,
            lastSeenStore: LastSeenConnectionStore(defaults: defaults),
            filterStore: TelemetryFilterStore(defaults: defaults),
            nowProvider: { Self.testNow },
            initiallyConfigured: true
        )

        api.devices = [
            Self.deviceDTO(imei: "352753094012345", alias: "Visible"),
            Self.deviceDTO(imei: "352753094067890", alias: "Hidden")
        ]

        await store.refresh(reason: .launch)

        let hidden = store.devices.first { $0.displayName == "Hidden" }!
        store.setDeviceIncluded(hidden, isIncluded: false)

        #expect(store.allDevices.count == 2)
        #expect(store.devices.map(\.displayName) == ["Visible"])
        #expect(store.checkIns.map(\.displayName) == ["Visible"])

        api.devices = [
            Self.deviceDTO(imei: "352753094012345", alias: "Visible"),
            Self.deviceDTO(imei: "352753094067890", alias: "Hidden", latestConnectionAt: "2026-05-20T12:15:00Z")
        ]

        await store.refresh(reason: .scheduled)

        #expect(store.latestNewCount == 0)
        #expect(store.allCheckIns.count == 2)
        #expect(store.checkIns.map(\.displayName) == ["Visible"])
    }

    private static func deviceDTO(
        imei: String = "352753094012345",
        alias: String = "Tern 12",
        latestConnectionAt: String = "2026-05-20T12:00:00Z",
        latestLocationAt: String? = "2026-05-20T11:58:00Z",
        latestBatteryV: Double? = 3.9
    ) -> ProjectDeviceDTO {
        ProjectDeviceDTO(
            imei: imei,
            deviceType: "flicker_gps_gen2",
            alias: alias,
            latestConnectionAt: latestConnectionAt,
            latestLocationAt: latestLocationAt,
            latestBatteryV: latestBatteryV
        )
    }

    private static func locationRecord(
        fixAt: String,
        type: String = "gps",
        lat: Double,
        lon: Double
    ) -> LocationRecordDTO {
        LocationRecordDTO(
            fixAt: Int64(TelemetryDateFormatter.parseISO8601(fixAt)!.timeIntervalSince1970 * 1000),
            type: type,
            lat: lat,
            lon: lon,
            altM: nil,
            groundSpeedKnts: nil,
            cog: nil,
            hdop: nil,
            pdop: nil,
            vdop: nil,
            satCount: nil,
            timeToFix: nil,
            navMode: nil,
            errorFlag: nil,
            reason: nil,
            uncertaintyM: nil
        )
    }

    private static func sensorRecord(time: String, batteryV: Double?) -> SensorRecordDTO {
        SensorRecordDTO(
            imei: "352753094012345",
            time: time,
            source: "sensor",
            reason: nil,
            batteryV: batteryV,
            solarMv: nil,
            solarMa: nil,
            tempC: nil,
            activity: nil,
            actCumulative: nil,
            actX: nil,
            actY: nil,
            actZ: nil,
            polarAct: nil
        )
    }

    private static var testNow: Date {
        TelemetryDateFormatter.parseISO8601("2026-05-20T12:20:00Z")!
    }
}

private final class FakeAPI: CTTAPIProviding, @unchecked Sendable {
    var devices: [ProjectDeviceDTO] = []
    var deviceDetail: DeviceDetailDTO?
    var locationError: Error?
    var locationResponses: [[LocationRecordDTO]] = []
    var locationRequests: [(imei: String, start: Date, end: Date)] = []
    var sensorRecords: [SensorRecordDTO] = []
    var locationFetchCount = 0
    var sensorFetchCount = 0

    func fetchMe() async throws -> UserDTO {
        UserDTO(
            userId: "user_1",
            email: "researcher@example.com",
            displayName: "Researcher",
            role: "user",
            projectCount: 1,
            tokenId: "token_1"
        )
    }

    func fetchProjects() async throws -> [ProjectDTO] {
        [
            ProjectDTO(
                projectId: "project_1",
                name: "Coastal Birds",
                description: nil,
                ownerId: "user_1",
                createdAt: nil,
                updatedAt: nil
            )
        ]
    }

    func fetchDevices(projectID: String) async throws -> [ProjectDeviceDTO] {
        devices
    }

    func fetchDevice(imei: String) async throws -> DeviceDetailDTO {
        if let deviceDetail {
            return deviceDetail
        }

        throw CTTAPIClientError.server(
            status: 404,
            code: .notFound,
            message: "Device not found",
            requestID: "fake_device_detail"
        )
    }

    func fetchLocations(imei: String, start: Date, end: Date) async throws -> [LocationRecordDTO] {
        locationFetchCount += 1
        locationRequests.append((imei: imei, start: start, end: end))

        if let locationError {
            throw locationError
        }

        if locationResponses.isEmpty {
            return []
        }

        return locationResponses.removeFirst()
    }

    func fetchSensors(imei: String, start: Date, end: Date) async throws -> [SensorRecordDTO] {
        sensorFetchCount += 1
        return sensorRecords
    }
}
