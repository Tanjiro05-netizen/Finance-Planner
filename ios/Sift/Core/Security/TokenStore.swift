import Foundation
import Security

protocol TokenStoring: Sendable {
    func readToken() throws -> String?
    func saveToken(_ token: String) throws
    func deleteToken() throws
}

final class KeychainTokenStore: TokenStoring, @unchecked Sendable {
    private let service: String
    private let account: String

    init(service: String = "com.sift.app.auth", account: String = "jwt") {
        self.service = service
        self.account = account
    }

    func readToken() throws -> String? {
        var query = baseQuery()
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        if status == errSecItemNotFound {
            return nil
        }

        guard status == errSecSuccess else {
            throw SiftError.keychain("Unable to read the stored session.")
        }

        guard
            let data = result as? Data,
            let token = String(data: data, encoding: .utf8)
        else {
            throw SiftError.keychain("The stored session could not be decoded.")
        }

        return token
    }

    func saveToken(_ token: String) throws {
        let data = Data(token.utf8)
        var query = baseQuery()

        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ]

        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)

        if updateStatus == errSecSuccess {
            return
        }

        guard updateStatus == errSecItemNotFound else {
            throw SiftError.keychain("Unable to update the stored session.")
        }

        query.merge(attributes) { _, new in new }
        let addStatus = SecItemAdd(query as CFDictionary, nil)

        guard addStatus == errSecSuccess else {
            throw SiftError.keychain("Unable to save the session securely.")
        }
    }

    func deleteToken() throws {
        let status = SecItemDelete(baseQuery() as CFDictionary)

        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw SiftError.keychain("Unable to delete the stored session.")
        }
    }

    private func baseQuery() -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }
}

final class InMemoryTokenStore: TokenStoring, @unchecked Sendable {
    private let lock = NSLock()
    private var token: String?

    init(token: String? = nil) {
        self.token = token
    }

    func readToken() throws -> String? {
        lock.withLock { token }
    }

    func saveToken(_ token: String) throws {
        lock.withLock {
            self.token = token
        }
    }

    func deleteToken() throws {
        lock.withLock {
            token = nil
        }
    }
}

private extension NSLock {
    func withLock<Value>(_ body: () throws -> Value) rethrows -> Value {
        lock()
        defer { unlock() }
        return try body()
    }
}

/// Device-owner authentication used to gate access to balances and transactions.
protocol BiometricAuthenticating: Sendable {
    /// Whether Face ID, Touch ID, or a device passcode can be evaluated.
    func canAuthenticate() -> Bool
    /// Prompts the person; succeeds via biometrics or the device passcode fallback.
    func authenticate(reason: String) async -> Bool
}

struct MockBiometricAuthenticator: BiometricAuthenticating {
    var available = true
    var succeeds = true

    func canAuthenticate() -> Bool {
        available
    }

    func authenticate(reason _: String) async -> Bool {
        succeeds
    }
}

/// Persisted preference for requiring authentication when Sift opens. Defaults on.
struct AppLockPreference: Sendable {
    private let defaults: UserDefaults
    private let key = "sift.appLock.enabled"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var isEnabled: Bool {
        get { defaults.object(forKey: key) as? Bool ?? true }
        nonmutating set { defaults.set(newValue, forKey: key) }
    }
}
