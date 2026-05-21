import Foundation

public enum TelemetryLocationFilter {
    static func latestValidLocations(
        _ records: [LocationRecordDTO],
        imei: String,
        now: Date = Date(),
        window: TimeInterval = 24 * 60 * 60,
        limit: Int = 10
    ) -> [TelemetryLocation] {
        let start = now.addingTimeInterval(-window)

        return latestValidLocations(records, imei: imei, start: start, end: now, limit: limit)
    }

    static func latestValidLocations(
        _ records: [LocationRecordDTO],
        imei: String,
        start: Date,
        end: Date,
        limit: Int = 10
    ) -> [TelemetryLocation] {
        validLocations(records, imei: imei, start: start, end: end)
            .sorted { $0.fixAt > $1.fixAt }
            .prefix(limit)
            .map { $0 }
    }

    static func lastKnownLocations(
        _ records: [LocationRecordDTO],
        imei: String,
        start: Date,
        end: Date,
        reference: Date,
        connectionWindow: TimeInterval = 6 * 60 * 60,
        limit: Int = 10
    ) -> [TelemetryLocation] {
        let locations = validLocations(records, imei: imei, start: start, end: end)
            .sorted { $0.fixAt > $1.fixAt }

        guard let primary = preferredLastKnownLocation(
            in: locations,
            reference: reference,
            connectionWindow: connectionWindow
        ) else {
            return []
        }

        return ([primary] + locations.filter { $0.id != primary.id })
            .prefix(limit)
            .map { $0 }
    }

    private static func validLocations(
        _ records: [LocationRecordDTO],
        imei: String,
        start: Date,
        end: Date
    ) -> [TelemetryLocation] {
        records.compactMap { record -> TelemetryLocation? in
            guard
                let latitude = record.lat,
                let longitude = record.lon,
                (-90...90).contains(latitude),
                (-180...180).contains(longitude)
            else {
                return nil
            }

            let fixDate = Date(timeIntervalSince1970: TimeInterval(record.fixAt) / 1000)
            guard fixDate >= start, fixDate <= end else { return nil }

            return TelemetryLocation(
                id: "\(imei)-\(record.fixAt)-\(latitude)-\(longitude)",
                imei: imei,
                fixAt: fixDate,
                type: record.type,
                latitude: latitude,
                longitude: longitude,
                altitudeM: record.altM,
                groundSpeedKnts: record.groundSpeedKnts,
                uncertaintyM: record.uncertaintyM
            )
        }
    }

    private static func preferredLastKnownLocation(
        in locations: [TelemetryLocation],
        reference: Date,
        connectionWindow: TimeInterval
    ) -> TelemetryLocation? {
        guard !locations.isEmpty else { return nil }

        let referenceCandidates = locations.filter {
            abs($0.fixAt.timeIntervalSince(reference)) <= connectionWindow
        }

        let candidates: [TelemetryLocation]
        if referenceCandidates.isEmpty, let newest = locations.first {
            candidates = locations.filter {
                newest.fixAt.timeIntervalSince($0.fixAt) <= connectionWindow
            }
        } else {
            candidates = referenceCandidates
        }

        return candidates.sorted { lhs, rhs in
            let lhsPriority = fixPriority(lhs)
            let rhsPriority = fixPriority(rhs)

            if lhsPriority != rhsPriority {
                return lhsPriority < rhsPriority
            }

            return lhs.fixAt > rhs.fixAt
        }.first
    }

    private static func fixPriority(_ location: TelemetryLocation) -> Int {
        if location.isGPSFix {
            return 0
        }

        if location.isCellLocateFix {
            return 1
        }

        return 2
    }
}
