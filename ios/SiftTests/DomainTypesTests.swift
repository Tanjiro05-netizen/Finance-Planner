import Foundation
@testable import Sift
import Testing

struct DomainTypesTests {
    // MARK: - SiftError

    @Test func errorDescriptionsMatchEachCase() {
        #expect(SiftError.notFound("Subscription").errorDescription == "Subscription could not be found.")
        #expect(SiftError.currencyMismatch.errorDescription == "Money values must use the same currency.")
        #expect(SiftError.persistence("disk full").errorDescription == "disk full")
        #expect(SiftError.network("offline").errorDescription == "offline")
        #expect(SiftError.api(code: "bad_request", message: "nope").errorDescription == "nope")
        #expect(SiftError.unauthorized.errorDescription == "Please start a new secure session.")
        #expect(SiftError.decoding("bad json").errorDescription == "bad json")
        #expect(SiftError.keychain("locked").errorDescription == "locked")
        #expect(SiftError.cancelled("stopped").errorDescription == "stopped")
    }

    @Test func isAuthenticationExpiredIdentifiesUnauthorizedCases() {
        #expect(SiftError.unauthorized.isAuthenticationExpired)
        #expect(SiftError.api(code: "unauthorized", message: "").isAuthenticationExpired)
        #expect(SiftError.api(code: "token_expired", message: "").isAuthenticationExpired)
        #expect(!SiftError.api(code: "validation_error", message: "").isAuthenticationExpired)
        #expect(!SiftError.network("offline").isAuthenticationExpired)
    }

    @Test func isTransientIdentifiesRetryableCases() {
        #expect(SiftError.network("offline").isTransient)
        #expect(SiftError.api(code: "rate_limited", message: "").isTransient)
        #expect(SiftError.api(code: "temporarily_unavailable", message: "").isTransient)
        #expect(!SiftError.api(code: "validation_error", message: "").isTransient)
        #expect(!SiftError.unauthorized.isTransient)
    }

    // MARK: - SiftFeatureFlags

    @Test func featureFlagsDefaultToDisabledForTheTestProcess() {
        // ProcessInfo has no public initializer for injecting fake arguments/environment,
        // so this exercises the real default path: the test runner's own process has
        // neither -siftConciergeEnabled nor SIFT_CONCIERGE_ENABLED set.
        #expect(SiftFeatureFlags.current().conciergeEnabled == false)
        #expect(SiftFeatureFlags.launchDefault.conciergeEnabled == false)
    }

    // MARK: - Cadence

    @Test func displayNameAndShortLabelCoverEveryCadence() {
        let expectations: [(Cadence, String, String)] = [
            (.weekly, "Weekly", "WEEKLY"),
            (.monthly, "Monthly", "MONTHLY"),
            (.quarterly, "Quarterly", "QUARTERLY"),
            (.yearly, "Yearly", "YEARLY"),
            (.unknown, "Unknown", "UNKNOWN"),
        ]

        for (cadence, displayName, shortLabel) in expectations {
            #expect(cadence.displayName == displayName)
            #expect(cadence.shortLabel == shortLabel)
        }
    }

    @Test func unknownCadenceMonthlyEquivalentPassesAmountThrough() {
        #expect(Cadence.unknown.monthlyEquivalent(for: .usd(1234)) == .usd(1234))
    }

    // MARK: - SubscriptionCategoryGroup

    @Test func monthlyTotalExcludesCancelledSubscriptions() {
        let group = SubscriptionCategoryGroup(
            categoryID: "cat-streaming",
            categoryName: "Streaming",
            subscriptions: [
                makeSubscription(id: "sub-active", amount: .usd(999), cadence: .monthly, status: .active),
                makeSubscription(id: "sub-yearly", amount: .usd(12000), cadence: .yearly, status: .active),
                makeSubscription(id: "sub-cancelled", amount: .usd(500), cadence: .monthly, status: .cancelled),
            ]
        )

        #expect(group.monthlyTotal == .usd(999 + 1000))
    }

    @Test func monthlyTotalIsZeroForAnEmptyGroup() {
        let group = SubscriptionCategoryGroup(categoryID: nil, categoryName: "Empty", subscriptions: [])
        #expect(group.monthlyTotal == .zeroUSD)
    }

    private func makeSubscription(
        id: String,
        amount: Money,
        cadence: Cadence,
        status: SubscriptionStatus
    ) -> Subscription {
        Subscription(
            id: id,
            userID: SeedData.defaultUserID,
            name: id,
            merchantKey: MerchantKey(id),
            monogramLetter: "S",
            tileColorToken: .ink,
            amount: amount,
            cadence: cadence,
            status: status,
            detectionConfidence: 0.9,
            firstSeen: SeedData.referenceDate,
            lastCharge: SeedData.referenceDate
        )
    }
}
