import Foundation
import LocalAuthentication
import Security

public enum KeychainTokenStoreError: LocalizedError, Equatable {
    case unexpectedStatus(OSStatus)
    case invalidData

    public var errorDescription: String? {
        switch self {
        case let .unexpectedStatus(status):
            let message = SecCopyErrorMessageString(status, nil) as String? ?? "OSStatus \(status)"
            return "Could not access the CTT Pulse token in Keychain: \(message). Re-enter the token in Settings."
        case .invalidData:
            return "The stored CTT Pulse token is unreadable. Re-enter the token in Settings."
        }
    }
}

public final class KeychainTokenStore: @unchecked Sendable {
    public static let defaultService = "com.celltracktech.CTTPulse.ctt.v1"
    private static let defaultLegacyServices = [
        "com.davidlapuma.CTTPulse.ctt.v1",
        "com.davidlapuma.TelemetryIsland.ctt.v2",
        "com.davidlapuma.TelemetryIsland.ctt"
    ]

    private let service: String
    private let account: String
    private let legacyServices: [String]

    public init(
        service: String = KeychainTokenStore.defaultService,
        account: String = "personal-access-token",
        legacyServices: [String]? = nil
    ) {
        self.service = service
        self.account = account
        self.legacyServices = legacyServices ?? (service == Self.defaultService ? Self.defaultLegacyServices : [])
    }

    public func loadToken() throws -> String? {
        do {
            if let token = try readToken(service: service, allowInteraction: false) {
                return token
            }
        } catch {
            if shouldRetryWithUserInteraction(error),
               let token = try readToken(service: service, allowInteraction: true) {
                return token
            }

            throw error
        }

        for legacyService in legacyServices {
            guard let token = try? readToken(service: legacyService, allowInteraction: false), !token.isEmpty else {
                continue
            }

            try? saveToken(token)
            return token
        }

        for legacyService in legacyServices {
            guard let token = try? readToken(service: legacyService, allowInteraction: true), !token.isEmpty else {
                continue
            }

            try? saveToken(token)
            return token
        }

        return nil
    }

    public func saveToken(_ token: String) throws {
        let data = Data(token.utf8)
        let query = baseQuery()

        let deleteStatus = SecItemDelete(query as CFDictionary)
        guard deleteStatus == errSecSuccess || deleteStatus == errSecItemNotFound else {
            throw KeychainTokenStoreError.unexpectedStatus(deleteStatus)
        }

        var addQuery = baseQuery()
        addQuery[kSecValueData as String] = data
        addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly

        let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
        guard addStatus == errSecSuccess else {
            throw KeychainTokenStoreError.unexpectedStatus(addStatus)
        }
    }

    public func deleteToken() throws {
        var firstUnexpectedStatus: OSStatus?

        for serviceName in [service] + legacyServices {
            let status = SecItemDelete(baseQuery(service: serviceName) as CFDictionary)
            if status != errSecSuccess, status != errSecItemNotFound, firstUnexpectedStatus == nil {
                firstUnexpectedStatus = status
            }
        }

        if let firstUnexpectedStatus {
            throw KeychainTokenStoreError.unexpectedStatus(firstUnexpectedStatus)
        }
    }

    public func hasToken() -> Bool {
        (try? loadToken())?.isEmpty == false
    }

    private func readToken(service: String, allowInteraction: Bool) throws -> String? {
        var query = baseQuery(service: service)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        if !allowInteraction {
            let context = LAContext()
            context.interactionNotAllowed = true
            query[kSecUseAuthenticationContext as String] = context
        }

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        if status == errSecItemNotFound {
            return nil
        }

        guard status == errSecSuccess else {
            throw KeychainTokenStoreError.unexpectedStatus(status)
        }

        guard
            let data = result as? Data,
            let token = String(data: data, encoding: .utf8)
        else {
            throw KeychainTokenStoreError.invalidData
        }

        return token
    }

    private func shouldRetryWithUserInteraction(_ error: Error) -> Bool {
        guard case let KeychainTokenStoreError.unexpectedStatus(status) = error else {
            return false
        }

        return status == errSecInteractionNotAllowed || status == errSecAuthFailed
    }

    private func baseQuery(service: String? = nil) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service ?? self.service,
            kSecAttrAccount as String: account
        ]
    }
}
