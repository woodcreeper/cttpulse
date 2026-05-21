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
