import Foundation
@testable import Sift
import Testing

struct TokenStoreTests {
    @Test func keychainTokenStoreSavesUpdatesAndReadsBack() throws {
        let store = KeychainTokenStore(service: "com.sift.tests.\(UUID().uuidString)", account: "jwt")
        defer { try? store.deleteToken() }

        #expect(try store.readToken() == nil)

        try store.saveToken("jwt-first")
        #expect(try store.readToken() == "jwt-first")

        try store.saveToken("jwt-second")
        #expect(try store.readToken() == "jwt-second")
    }

    @Test func keychainTokenStoreDeleteIsIdempotent() throws {
        let store = KeychainTokenStore(service: "com.sift.tests.\(UUID().uuidString)", account: "jwt")

        try store.deleteToken()
        #expect(try store.readToken() == nil)

        try store.saveToken("jwt-value")
        try store.deleteToken()
        #expect(try store.readToken() == nil)
        try store.deleteToken()
    }

    @Test func inMemoryTokenStoreRoundTrips() throws {
        let store = InMemoryTokenStore()

        #expect(try store.readToken() == nil)
        try store.saveToken("jwt-1")
        #expect(try store.readToken() == "jwt-1")
        try store.saveToken("jwt-2")
        #expect(try store.readToken() == "jwt-2")
        try store.deleteToken()
        #expect(try store.readToken() == nil)
    }

    @Test func mockBiometricAuthenticatorReflectsConfiguredResult() async {
        let unavailable = MockBiometricAuthenticator(available: false, succeeds: true)
        #expect(unavailable.canAuthenticate() == false)

        let deniesAuth = MockBiometricAuthenticator(available: true, succeeds: false)
        #expect(deniesAuth.canAuthenticate())
        #expect(await deniesAuth.authenticate(reason: "test") == false)

        let grantsAuth = MockBiometricAuthenticator(available: true, succeeds: true)
        #expect(await grantsAuth.authenticate(reason: "test"))
    }

    @Test func appLockPreferenceDefaultsToOffAndPersists() throws {
        let defaults = try #require(UserDefaults(suiteName: "sift-test-\(UUID().uuidString)"))
        let preference = AppLockPreference(defaults: defaults)

        #expect(preference.isEnabled == false)
        preference.isEnabled = true
        #expect(preference.isEnabled)
        preference.isEnabled = false
        #expect(preference.isEnabled == false)
    }
}
