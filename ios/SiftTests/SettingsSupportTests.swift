import Foundation
import Testing
@testable import Sift

struct SettingsSupportTests {
    @Test func metadataBuildsVersionSummaryAndSafeFeedbackURL() throws {
        let metadata = AppSupportMetadata(
            version: "1.0",
            build: "42",
            supportEmail: "beta@sift.app"
        )

        #expect(metadata.versionSummary == "Version 1.0 (42)")

        let url = try #require(metadata.feedbackURL)
        let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
        let queryItems = Dictionary(
            uniqueKeysWithValues: (components.queryItems ?? []).map { ($0.name, $0.value ?? "") }
        )

        #expect(components.scheme == "mailto")
        #expect(components.path == "beta@sift.app")
        #expect(queryItems["subject"] == "Sift beta feedback")
        #expect(queryItems["body"]?.contains("Version 1.0 (42)") == true)
        #expect(queryItems["body"]?.contains("Please do not include") == true)
        #expect(queryItems["body"]?.localizedCaseInsensitiveContains("transaction contents") == false)
        #expect(queryItems["body"]?.localizedCaseInsensitiveContains("access_token") == false)
    }
}
