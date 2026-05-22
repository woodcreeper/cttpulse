import Foundation

public enum CTTAPIClientError: LocalizedError, Equatable {
    case missingToken
    case invalidURL
    case invalidResponse
    case server(status: Int, code: CTTErrorCode, message: String, requestID: String)
    case http(status: Int)
    case decoding(String)

    public var errorDescription: String? {
        switch self {
        case .missingToken:
            "Add a CTT Personal Access Token in settings."
        case .invalidURL:
            "Could not build the CTT API request URL."
        case .invalidResponse:
            "The CTT API returned a non-HTTP response."
        case let .server(_, code, message, _):
            switch code {
            case .unauthorized:
                "The CTT token was rejected. Save a fresh Personal Access Token."
            case .forbidden:
                "This CTT token does not have access to that resource."
            case .notFound:
                "CTT could not find that record."
            case .rateLimited:
                "CTT rate limit reached. Waiting briefly before trying again."
            case .serviceUnavailable:
                "CTT is temporarily unavailable. Try again shortly."
            default:
                "\(code.rawValue): \(message)"
            }
        case let .http(status):
            "The CTT API returned HTTP \(status)."
        case let .decoding(message):
            "Could not decode the CTT API response: \(message)"
        }
    }
}

protocol CTTAPIProviding: Sendable {
    func fetchMe() async throws -> UserDTO
    func fetchProjects() async throws -> [ProjectDTO]
    func fetchDevices(projectID: String) async throws -> [ProjectDeviceDTO]
    func fetchDevice(imei: String) async throws -> DeviceDetailDTO
    func fetchLocations(imei: String, start: Date, end: Date) async throws -> [LocationRecordDTO]
    func fetchSensors(imei: String, start: Date, end: Date) async throws -> [SensorRecordDTO]
}

public final class CTTAPIClient: CTTAPIProviding, @unchecked Sendable {
    private let baseURL: URL
    private let tokenStore: KeychainTokenStore
    private let session: URLSession
    private let requestThrottle = CTTRequestThrottle()

    public init(
        baseURL: URL = URL(string: "https://us-central1-ctt-data-portal.cloudfunctions.net/customerApi")!,
        tokenStore: KeychainTokenStore,
        session: URLSession = .shared
    ) {
        self.baseURL = baseURL
        self.tokenStore = tokenStore
        self.session = session
    }

    func fetchMe() async throws -> UserDTO {
        let envelope: DataEnvelope<UserDTO> = try await send(path: "/v1/me")
        return envelope.data
    }

    func fetchProjects() async throws -> [ProjectDTO] {
        try await fetchPaginated(path: "/v1/projects")
    }

    func fetchDevices(projectID: String) async throws -> [ProjectDeviceDTO] {
        try await fetchPaginated(path: "/v1/projects/\(projectID)/devices")
    }

    func fetchDevice(imei: String) async throws -> DeviceDetailDTO {
        let envelope: DataEnvelope<DeviceDetailDTO> = try await send(path: "/v1/devices/\(imei)")
        return envelope.data
    }

    func fetchLocations(imei: String, start: Date, end: Date) async throws -> [LocationRecordDTO] {
        try await fetchPaginated(
            path: "/v1/devices/\(imei)/locations",
            queryItems: [
                URLQueryItem(name: "start", value: TelemetryDateFormatter.apiString(from: start)),
                URLQueryItem(name: "end", value: TelemetryDateFormatter.apiString(from: end))
            ]
        )
    }

    func fetchSensors(imei: String, start: Date, end: Date) async throws -> [SensorRecordDTO] {
        try await fetchPaginated(
            path: "/v1/devices/\(imei)/sensors",
            queryItems: [
                URLQueryItem(name: "start", value: TelemetryDateFormatter.apiString(from: start)),
                URLQueryItem(name: "end", value: TelemetryDateFormatter.apiString(from: end))
            ]
        )
    }

    private func fetchPaginated<T: Decodable>(
        path: String,
        queryItems: [URLQueryItem] = []
    ) async throws -> [T] {
        var items: [T] = []
        var cursor: String?
        var hasMore = true

        while hasMore {
            var pageQuery = queryItems
            pageQuery.append(URLQueryItem(name: "limit", value: "1000"))

            if let cursor {
                pageQuery.append(URLQueryItem(name: "cursor", value: cursor))
            }

            let envelope: ListEnvelope<T> = try await send(path: path, queryItems: pageQuery)
            items.append(contentsOf: envelope.data)
            hasMore = envelope.pagination.hasMore
            cursor = envelope.pagination.nextCursor

            if hasMore, cursor == nil {
                break
            }
        }

        return items
    }

    private func send<T: Decodable>(
        path: String,
        queryItems: [URLQueryItem] = []
    ) async throws -> T {
        let token = try tokenStore.loadToken()
        guard let token, !token.isEmpty else {
            throw CTTAPIClientError.missingToken
        }

        var request = URLRequest(url: try makeURL(path: path, queryItems: queryItems))
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let data: Data
        let response: URLResponse

        do {
            try await requestThrottle.wait()
            (data, response) = try await session.data(for: request)
        } catch {
            throw error
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw CTTAPIClientError.invalidResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            if let envelope = try? JSONDecoder().decode(ErrorEnvelope.self, from: data) {
                throw CTTAPIClientError.server(
                    status: httpResponse.statusCode,
                    code: envelope.error.code,
                    message: envelope.error.message,
                    requestID: envelope.error.requestId
                )
            }

            throw CTTAPIClientError.http(status: httpResponse.statusCode)
        }

        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw CTTAPIClientError.decoding(error.localizedDescription)
        }
    }

    private func makeURL(path: String, queryItems: [URLQueryItem]) throws -> URL {
        var url = baseURL
        let components = path.split(separator: "/").map(String.init)

        for component in components {
            url.append(path: component)
        }

        guard var urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            throw CTTAPIClientError.invalidURL
        }

        if !queryItems.isEmpty {
            urlComponents.queryItems = queryItems
        }

        guard let finalURL = urlComponents.url else {
            throw CTTAPIClientError.invalidURL
        }

        return finalURL
    }
}

private actor CTTRequestThrottle {
    private let clock = ContinuousClock()
    private let minimumInterval: Duration
    private var nextRequestAt: ContinuousClock.Instant?

    init(minimumInterval: Duration = .milliseconds(1_100)) {
        self.minimumInterval = minimumInterval
    }

    func wait() async throws {
        let now = clock.now

        if let nextRequestAt, nextRequestAt > now {
            try await clock.sleep(until: nextRequestAt)
        }

        nextRequestAt = clock.now.advanced(by: minimumInterval)
    }
}
