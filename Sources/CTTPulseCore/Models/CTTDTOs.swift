import Foundation

struct PaginationEnvelope: Decodable, Equatable {
    let nextCursor: String?
    let hasMore: Bool
}

struct ListEnvelope<T: Decodable>: Decodable {
    let data: [T]
    let pagination: PaginationEnvelope
}

struct DataEnvelope<T: Decodable>: Decodable {
    let data: T
}

struct ErrorEnvelope: Decodable, Equatable {
    struct Body: Decodable, Equatable {
        let code: CTTErrorCode
        let message: String
        let requestId: String
    }

    let error: Body
}

public enum CTTErrorCode: String, Decodable, Equatable, Sendable {
    case unauthorized
    case forbidden
    case notFound = "not_found"
    case rateLimited = "rate_limited"
    case invalidRequest = "invalid_request"
    case methodNotAllowed = "method_not_allowed"
    case serviceUnavailable = "service_unavailable"
    case `internal`
}

struct UserDTO: Decodable, Equatable {
    let userId: String
    let email: String?
    let displayName: String?
    let role: String
    let projectCount: Int
    let tokenId: String
}

struct ProjectDTO: Decodable, Equatable {
    let projectId: String
    let name: String
    let description: String?
    let ownerId: String
    let createdAt: String?
    let updatedAt: String?
}

struct ProjectDeviceDTO: Decodable, Equatable {
    let imei: String
    let deviceType: String
    let alias: String?
    let latestConnectionAt: String?
    let latestLocationAt: String?
    let latestBatteryV: Double?
}

struct DeviceDetailDTO: Decodable, Equatable {
    let imei: String
    let deviceType: String
    let deviceName: String?
    let latestLocation: DeviceLatestLocationDTO?
    let latestSensor: DeviceLatestSensorDTO?
}

struct DeviceLatestLocationDTO: Decodable, Equatable {
    let timeUtc: String?
    let fixAt: Int64?
    let type: String
    let lat: Double?
    let lon: Double?
    let altM: Double?
    let groundSpeedKnts: Double?
    let uncertaintyM: Double?

    init(
        timeUtc: String?,
        fixAt: Int64? = nil,
        type: String,
        lat: Double?,
        lon: Double?,
        altM: Double? = nil,
        groundSpeedKnts: Double? = nil,
        uncertaintyM: Double? = nil
    ) {
        self.timeUtc = timeUtc
        self.fixAt = fixAt
        self.type = type
        self.lat = lat
        self.lon = lon
        self.altM = altM
        self.groundSpeedKnts = groundSpeedKnts
        self.uncertaintyM = uncertaintyM
    }

    enum CodingKeys: String, CodingKey {
        case timeUtc
        case fixAt
        case type
        case lat
        case lon
        case altM
        case groundSpeedKnts
        case uncertaintyM
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        timeUtc = container.decodeLenientStringIfPresent(.timeUtc)
        fixAt = container.decodeLenientInt64IfPresent(.fixAt)
        type = container.decodeLenientStringIfPresent(.type) ?? "unknown"
        lat = container.decodeLenientDoubleIfPresent(.lat)
        lon = container.decodeLenientDoubleIfPresent(.lon)
        altM = container.decodeLenientDoubleIfPresent(.altM)
        groundSpeedKnts = container.decodeLenientDoubleIfPresent(.groundSpeedKnts)
        uncertaintyM = container.decodeLenientDoubleIfPresent(.uncertaintyM)
    }

    var fixDate: Date? {
        if let timeUtc, let date = TelemetryDateFormatter.parseISO8601(timeUtc) {
            return date
        }

        if let fixAt {
            return Date(timeIntervalSince1970: TimeInterval(fixAt) / 1000)
        }

        return nil
    }
}

struct DeviceLatestSensorDTO: Decodable, Equatable {
    let timeUtc: String?
    let time: String?
    let batteryV: Double?
    let batteryMv: Double?

    init(
        timeUtc: String?,
        time: String? = nil,
        batteryV: Double? = nil,
        batteryMv: Double? = nil
    ) {
        self.timeUtc = timeUtc
        self.time = time
        self.batteryV = batteryV
        self.batteryMv = batteryMv
    }

    enum CodingKeys: String, CodingKey {
        case timeUtc
        case time
        case batteryV
        case batteryMv
        case battery_v
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        timeUtc = container.decodeLenientStringIfPresent(.timeUtc)
        time = container.decodeLenientStringIfPresent(.time)
        batteryV = container.decodeLenientDoubleIfPresent(.batteryV)
            ?? container.decodeLenientDoubleIfPresent(.battery_v)
        batteryMv = container.decodeLenientDoubleIfPresent(.batteryMv)
    }

    var readDate: Date? {
        if let timeUtc, let date = TelemetryDateFormatter.parseISO8601(timeUtc) {
            return date
        }

        if let time, let date = TelemetryDateFormatter.parseISO8601(time) {
            return date
        }

        return nil
    }

    var voltage: Double? {
        if let batteryV {
            return batteryV
        }

        if let batteryMv {
            return batteryMv / 1000
        }

        return nil
    }
}

struct LocationRecordDTO: Decodable, Equatable {
    let fixAt: Int64
    let type: String
    let lat: Double?
    let lon: Double?
    let altM: Double?
    let groundSpeedKnts: Double?
    let cog: Double?
    let hdop: Double?
    let pdop: Double?
    let vdop: Double?
    let satCount: Int?
    let timeToFix: Int?
    let navMode: Int?
    let errorFlag: Int?
    let reason: Int?
    let uncertaintyM: Double?
}

struct SensorRecordDTO: Decodable, Equatable {
    let imei: String
    let time: String
    let source: String
    let reason: Int?
    let batteryV: Double?
    let solarMv: Int?
    let solarMa: Int?
    let tempC: Double?
    let activity: Int?
    let actCumulative: Int?
    let actX: Int?
    let actY: Int?
    let actZ: Int?
    let polarAct: Int?

    enum CodingKeys: String, CodingKey {
        case imei
        case time
        case source
        case reason
        case batteryV = "battery_v"
        case solarMv
        case solarMa
        case tempC
        case activity
        case actCumulative
        case actX
        case actY
        case actZ
        case polarAct
    }
}

private extension KeyedDecodingContainer {
    func decodeLenientStringIfPresent(_ key: Key) -> String? {
        if let value = try? decodeIfPresent(String.self, forKey: key) {
            return value
        }

        if let value = try? decodeIfPresent(Int.self, forKey: key) {
            return String(value)
        }

        if let value = try? decodeIfPresent(Double.self, forKey: key) {
            return String(value)
        }

        return nil
    }

    func decodeLenientDoubleIfPresent(_ key: Key) -> Double? {
        if let value = try? decodeIfPresent(Double.self, forKey: key) {
            return value
        }

        if let value = try? decodeIfPresent(Int.self, forKey: key) {
            return Double(value)
        }

        if let value = try? decodeIfPresent(String.self, forKey: key) {
            return Double(value)
        }

        return nil
    }

    func decodeLenientInt64IfPresent(_ key: Key) -> Int64? {
        if let value = try? decodeIfPresent(Int64.self, forKey: key) {
            return value
        }

        if let value = try? decodeIfPresent(Int.self, forKey: key) {
            return Int64(value)
        }

        if let value = try? decodeIfPresent(Double.self, forKey: key) {
            return Int64(value)
        }

        if let value = try? decodeIfPresent(String.self, forKey: key) {
            return Int64(value)
        }

        return nil
    }
}
