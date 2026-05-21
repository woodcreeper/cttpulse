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
    private let service: String
    private let account: String

    public init(
        service: String = "com.davidlapuma.CTTPulse.ctt.v1",
        account: String = "personal-access-token"
    ) {
        self.service = service
        self.account = account
    }

    public func loadToken() throws -> String? {
        var query = baseQuery()
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        let context = LAContext()
        context.interactionNotAllowed = true
        query[kSecUseAuthenticationContext as String] = context

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
        let status = SecItemDelete(baseQuery() as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainTokenStoreError.unexpectedStatus(status)
        }
    }

    public func hasToken() -> Bool {
        (try? loadToken())?.isEmpty == false
    }

    private func baseQuery() -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }
}
