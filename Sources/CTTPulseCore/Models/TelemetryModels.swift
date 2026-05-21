import CoreLocation
import Foundation

public struct TelemetryProject: Identifiable, Hashable {
    public let id: String
    public let name: String
    public let description: String?
}

public struct TelemetryDevice: Identifiable, Hashable {
    public let id: String
    public let projectID: String
    public let projectName: String
    public let imei: String
    public let deviceType: String
    public let alias: String?
    public let deviceName: String?
    public let latestConnectionAt: Date?
    public let latestLocationAt: Date?
    public let latestBatteryV: Double?

    public var displayName: String {
        if let alias, !alias.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return alias
        }

        if let deviceName, !deviceName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return deviceName
        }

        if !deviceType.isEmpty {
            return "\(deviceType) \(imei.suffix(4))"
        }

        return imei
    }
}

public struct TelemetryCheckIn: Identifiable, Hashable {
    public enum Kind: String, Hashable {
        case connection
        case location
    }

    public let id: String
    public let projectID: String
    public let projectName: String
    public let imei: String
    public let displayName: String
    public let deviceType: String
    public let kind: Kind
    public let connectionAt: Date
    public let latestLocationAt: Date?
    public let latestBatteryV: Double?
    public let isNew: Bool

    public var eventLabel: String {
        switch kind {
        case .connection:
            "Connected"
        case .location:
            "Location"
        }
    }
}

public struct TelemetryLocation: Identifiable, Hashable {
    public let id: String
    public let imei: String
    public let fixAt: Date
    public let type: String
    public let latitude: Double
    public let longitude: Double
    public let altitudeM: Double?
    public let groundSpeedKnts: Double?
    public let uncertaintyM: Double?

    public var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    public var isGPSFix: Bool {
        ["gps", "fast_gps", "assisted_gps"].contains(type)
    }

    public var isCellLocateFix: Bool {
        type == "cell_locate"
    }

    public var fixTypeLabel: String {
        switch type {
        case "gps", "fast_gps", "assisted_gps":
            "GPS"
        case "cell_locate":
            "Cell Locate"
        case "argos":
            "Argos"
        case "iridium":
            "Iridium"
        default:
            type
                .split(separator: "_")
                .map { $0.capitalized }
                .joined(separator: " ")
        }
    }

    public var shortFixTypeLabel: String {
        isCellLocateFix ? "Cell" : fixTypeLabel
    }
}

public enum TelemetryLocationSource: Hashable {
    case recent24h
    case lastKnown(referenceAt: Date)
}

public struct TelemetryBatteryReading: Hashable {
    public let voltage: Double
    public let readAt: Date
}

public enum RefreshReason: Equatable {
    case launch
    case manual
    case scheduled
}
