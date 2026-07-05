import Foundation
import SwiftData
import Testing
@testable import Sift

@MainActor
struct SeedDataTests {
    @Test func snapshotMatchesMockupTotals() throws {
        let snapshot = SeedData.snapshot()

        let total = try subscriptionMonthlyTotal(for: snapshot.subscriptions)
        let unused = unusedSubscriptions(
            from: snapshot.subscriptions,
            referenceDate: SeedData.referenceDate,
            staleAfterDays: 60
        )
        let savings = try Money.sum(unused.map(\.monthlyEquivalent))

        #expect(snapshot.subscriptions.count == 12)
        #expect(total == Money.usd(24_783))
        #expect(savings == Money.usd(14_600))
    }

    @Test func seedLoadsIntoInMemoryContainer() throws {
        let container = try SiftModelContainerFactory.makeSeededInMemoryContainer()
        let context = container.mainContext

        #expect(try context.fetchCount(FetchDescriptor<Subscription>()) == 12)
        #expect(try context.fetchCount(FetchDescriptor<LinkedAccount>()) == 2)
        #expect(try context.fetchCount(FetchDescriptor<AlertSettings>()) == 1)
    }

    @Test func releaseReadinessArtifactsExist() throws {
        let root = repositoryRoot()
        let fileManager = FileManager.default

        for path in [
            ".github/workflows/ci.yml",
            "docs/RELEASE.md",
            "docs/PRIVACY_POLICY_DRAFT.md",
            "docs/TERMS_DRAFT.md",
            "scripts/check-ios-coverage.js",
            "ios/Sift/Resources/PrivacyInfo.xcprivacy",
            "ios/Sift/Resources/Assets.xcassets/AppIcon.appiconset/Contents.json",
        ] {
            #expect(fileManager.fileExists(atPath: root.appending(path: path).path))
        }

        let privacyManifest = try String(
            contentsOf: root.appending(path: "ios/Sift/Resources/PrivacyInfo.xcprivacy"),
            encoding: .utf8
        )
        #expect(privacyManifest.contains("NSPrivacyTracking"))
        #expect(privacyManifest.contains("NSPrivacyCollectedDataTypeFinancialInfo"))
        #expect(privacyManifest.contains("NSPrivacyAccessedAPICategoryUserDefaults"))

        let releaseChecklist = try String(
            contentsOf: root.appending(path: "docs/RELEASE.md"),
            encoding: .utf8
        )
        #expect(releaseChecklist.contains("CONCIERGE_ENABLED=false"))
        #expect(releaseChecklist.contains("80%"))
    }
}

private func repositoryRoot() -> URL {
    URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
}
