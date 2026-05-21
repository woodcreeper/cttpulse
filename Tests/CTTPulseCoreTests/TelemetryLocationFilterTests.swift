import Foundation
import Testing
@testable import CTTPulseCore

@Suite("Telemetry location filtering")
struct TelemetryLocationFilterTests {
    @Test("Keeps newest valid points from the last 24 hours")
    func keepsNewestValidPoints() {
        let now = Date(timeIntervalSince1970: 1_800_000)
        let recent = Int64(now.addingTimeInterval(-60).timeIntervalSince1970 * 1000)
        let older = Int64(now.addingTimeInterval(-120).timeIntervalSince1970 * 1000)
        let stale = Int64(now.addingTimeInterval(-25 * 60 * 60).timeIntervalSince1970 * 1000)

        let records = [
            LocationRecordDTO(fixAt: older, type: "gps", lat: 40.1, lon: -73.1, altM: nil, groundSpeedKnts: nil, cog: nil, hdop: nil, pdop: nil, vdop: nil, satCount: nil, timeToFix: nil, navMode: nil, errorFlag: nil, reason: nil, uncertaintyM: nil),
            LocationRecordDTO(fixAt: recent, type: "gps", lat: 40.2, lon: -73.2, altM: nil, groundSpeedKnts: nil, cog: nil, hdop: nil, pdop: nil, vdop: nil, satCount: nil, timeToFix: nil, navMode: nil, errorFlag: nil, reason: nil, uncertaintyM: nil),
            LocationRecordDTO(fixAt: stale, type: "gps", lat: 40.3, lon: -73.3, altM: nil, groundSpeedKnts: nil, cog: nil, hdop: nil, pdop: nil, vdop: nil, satCount: nil, timeToFix: nil, navMode: nil, errorFlag: nil, reason: nil, uncertaintyM: nil),
            LocationRecordDTO(fixAt: recent + 1, type: "gps", lat: nil, lon: -73.4, altM: nil, groundSpeedKnts: nil, cog: nil, hdop: nil, pdop: nil, vdop: nil, satCount: nil, timeToFix: nil, navMode: nil, errorFlag: nil, reason: nil, uncertaintyM: nil),
            LocationRecordDTO(fixAt: recent + 2, type: "gps", lat: 91.0, lon: -73.5, altM: nil, groundSpeedKnts: nil, cog: nil, hdop: nil, pdop: nil, vdop: nil, satCount: nil, timeToFix: nil, navMode: nil, errorFlag: nil, reason: nil, uncertaintyM: nil)
        ]

        let locations = TelemetryLocationFilter.latestValidLocations(
            records,
            imei: "352753094012345",
            now: now,
            window: 24 * 60 * 60,
            limit: 10
        )

        #expect(locations.map(\.latitude) == [40.2, 40.1])
    }

    @Test("Limits to ten points")
    func limitsToTenPoints() {
        let now = Date(timeIntervalSince1970: 1_800_000)
        let records = (0..<15).map { index in
            LocationRecordDTO(
                fixAt: Int64(now.addingTimeInterval(TimeInterval(-index * 60)).timeIntervalSince1970 * 1000),
                type: "gps",
                lat: 41.0 + Double(index) / 100,
                lon: -72.0,
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

        let locations = TelemetryLocationFilter.latestValidLocations(records, imei: "352753094012345", now: now)

        #expect(locations.count == 10)
        #expect(locations.first?.latitude == 41.0)
    }

    @Test("Can filter older explicit windows for last known locations")
    func filtersExplicitHistoricalWindow() {
        let windowStart = TelemetryDateFormatter.parseISO8601("2026-04-20T00:00:00Z")!
        let windowEnd = TelemetryDateFormatter.parseISO8601("2026-04-21T00:00:00Z")!
        let included = Int64(TelemetryDateFormatter.parseISO8601("2026-04-20T12:00:00Z")!.timeIntervalSince1970 * 1000)
        let excluded = Int64(TelemetryDateFormatter.parseISO8601("2026-04-19T23:59:00Z")!.timeIntervalSince1970 * 1000)

        let records = [
            LocationRecordDTO(fixAt: excluded, type: "gps", lat: 39.9, lon: -72.9, altM: nil, groundSpeedKnts: nil, cog: nil, hdop: nil, pdop: nil, vdop: nil, satCount: nil, timeToFix: nil, navMode: nil, errorFlag: nil, reason: nil, uncertaintyM: nil),
            LocationRecordDTO(fixAt: included, type: "gps", lat: 40.4, lon: -73.4, altM: nil, groundSpeedKnts: nil, cog: nil, hdop: nil, pdop: nil, vdop: nil, satCount: nil, timeToFix: nil, navMode: nil, errorFlag: nil, reason: nil, uncertaintyM: nil)
        ]

        let locations = TelemetryLocationFilter.latestValidLocations(
            records,
            imei: "352753094012345",
            start: windowStart,
            end: windowEnd
        )

        #expect(locations.map(\.latitude) == [40.4])
    }

    @Test("Last known locations prefer GPS over newer cell locate fixes in the latest connection")
    func lastKnownPrefersGPSInLatestConnection() {
        let reference = TelemetryDateFormatter.parseISO8601("2026-05-17T12:00:00Z")!
        let start = TelemetryDateFormatter.parseISO8601("2026-05-16T00:00:00Z")!
        let end = TelemetryDateFormatter.parseISO8601("2026-05-17T18:00:00Z")!
        let gpsFix = Int64(TelemetryDateFormatter.parseISO8601("2026-05-17T11:55:00Z")!.timeIntervalSince1970 * 1000)
        let cellFix = Int64(TelemetryDateFormatter.parseISO8601("2026-05-17T12:02:00Z")!.timeIntervalSince1970 * 1000)

        let records = [
            LocationRecordDTO(fixAt: cellFix, type: "cell_locate", lat: 40.1, lon: -73.1, altM: nil, groundSpeedKnts: nil, cog: nil, hdop: nil, pdop: nil, vdop: nil, satCount: nil, timeToFix: nil, navMode: nil, errorFlag: nil, reason: nil, uncertaintyM: 1000),
            LocationRecordDTO(fixAt: gpsFix, type: "gps", lat: 40.2, lon: -73.2, altM: nil, groundSpeedKnts: nil, cog: nil, hdop: nil, pdop: nil, vdop: nil, satCount: nil, timeToFix: nil, navMode: nil, errorFlag: nil, reason: nil, uncertaintyM: nil)
        ]

        let locations = TelemetryLocationFilter.lastKnownLocations(
            records,
            imei: "352753094012345",
            start: start,
            end: end,
            reference: reference
        )

        #expect(locations.first?.type == "gps")
        #expect(locations.map(\.type) == ["gps", "cell_locate"])
    }

    @Test("Last known locations use cell locate when no GPS was transmitted")
    func lastKnownUsesCellLocateWithoutGPS() {
        let reference = TelemetryDateFormatter.parseISO8601("2026-05-17T12:00:00Z")!
        let start = TelemetryDateFormatter.parseISO8601("2026-05-16T00:00:00Z")!
        let end = TelemetryDateFormatter.parseISO8601("2026-05-17T18:00:00Z")!
        let cellFix = Int64(TelemetryDateFormatter.parseISO8601("2026-05-17T12:02:00Z")!.timeIntervalSince1970 * 1000)

        let records = [
            LocationRecordDTO(fixAt: cellFix, type: "cell_locate", lat: 40.1, lon: -73.1, altM: nil, groundSpeedKnts: nil, cog: nil, hdop: nil, pdop: nil, vdop: nil, satCount: nil, timeToFix: nil, navMode: nil, errorFlag: nil, reason: nil, uncertaintyM: 1000)
        ]

        let locations = TelemetryLocationFilter.lastKnownLocations(
            records,
            imei: "352753094012345",
            start: start,
            end: end,
            reference: reference
        )

        #expect(locations.first?.type == "cell_locate")
        #expect(locations.first?.fixTypeLabel == "Cell Locate")
    }
}
