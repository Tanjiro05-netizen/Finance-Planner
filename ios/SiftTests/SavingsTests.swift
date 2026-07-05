import Foundation
import Testing
@testable import Sift

@MainActor
struct SavingsTests {
    @Test func requestsTrackerSumsRealizedAnnualSavingsOncePerSubscription() throws {
        let snapshot = SeedData.snapshot()
        let requests = [
            CancellationRequest(
                id: "cancel-streamline-confirmed",
                userID: SeedData.defaultUserID,
                subscriptionID: SeedData.ID.streamline,
                method: .concierge,
                status: .confirmed,
                createdAt: SeedData.referenceDate,
                updatedAt: SeedData.referenceDate
            ),
            CancellationRequest(
                id: "cancel-streamline-duplicate",
                userID: SeedData.defaultUserID,
                subscriptionID: SeedData.ID.streamline,
                method: .guided,
                status: .cancelledByUser,
                createdAt: SeedData.referenceDate,
                updatedAt: SeedData.referenceDate
            ),
            CancellationRequest(
                id: "cancel-tonebox-requested",
                userID: SeedData.defaultUserID,
                subscriptionID: SeedData.ID.tonebox,
                method: .concierge,
                status: .requested,
                createdAt: SeedData.referenceDate,
                updatedAt: SeedData.referenceDate
            ),
            CancellationRequest(
                id: "cancel-parcel-guided",
                userID: SeedData.defaultUserID,
                subscriptionID: SeedData.ID.parcelPro,
                method: .guided,
                status: .cancelledByUser,
                createdAt: SeedData.referenceDate,
                updatedAt: SeedData.referenceDate
            ),
        ]

        let savings = try CancellationSavings.realizedAnnualSavings(
            requests: requests,
            subscriptions: snapshot.subscriptions
        )

        #expect(savings == Money.usd(28_176))
    }
}
