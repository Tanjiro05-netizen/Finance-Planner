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
        #expect(SiftFeatureFlags.current().ledgerEnabled == false)
        #expect(SiftFeatureFlags.launchDefault.ledgerEnabled == false)
        #expect(SiftFeatureFlags.current().budgetsEnabled == false)
        #expect(SiftFeatureFlags.launchDefault.budgetsEnabled == false)
        #expect(SiftFeatureFlags.current().goalsEnabled == false)
        #expect(SiftFeatureFlags.launchDefault.goalsEnabled == false)
    }

    @Test func goalStatusRoundTripsRawValues() {
        #expect(GoalStatus.allCases.map(\.rawValue) == ["active", "reached", "archived"])

        for status in GoalStatus.allCases {
            #expect(GoalStatus(rawValue: status.rawValue) == status)
        }
    }

    @Test func featureFlagsDefaultEachParameterIndependently() {
        // The defaulted init is what keeps adding a flag from breaking every call site.
        #expect(SiftFeatureFlags(budgetsEnabled: true).budgetsEnabled)
        #expect(SiftFeatureFlags(budgetsEnabled: true).ledgerEnabled == false)
        #expect(SiftFeatureFlags(ledgerEnabled: true).budgetsEnabled == false)
    }

    @Test func budgetEnumsRoundTripRawValues() {
        #expect(BudgetStatus.allCases.map(\.rawValue) == ["active", "archived"])
        #expect(BudgetPace.allCases.map(\.rawValue) == ["under", "onTrack", "over"])

        for period in BudgetPeriod.allCases {
            #expect(BudgetPeriod(rawValue: period.rawValue) == period)
            #expect(period.displayName.isEmpty == false)
            #expect(period.shortLabel == period.shortLabel.uppercased())
        }
    }

    @Test func budgetPeriodMapsToItsCalendarUnit() {
        #expect(BudgetPeriod.weekly.calendarComponent == .weekOfYear)
        #expect(BudgetPeriod.monthly.calendarComponent == .month)
    }

    @Test func editableAmountTextRoundTripsThroughDecimal() {
        // The text field form must parse back, unlike formatted() which adds a symbol
        // and thousands separators.
        for minor in [0, 5, 999, 100_000, -2500] {
            let money = Money.usd(minor)
            let parsed = Decimal(string: money.editableAmountText)
            #expect(parsed != nil)
        }

        #expect(Money.usd(123_456).editableAmountText == "1234.56")
        #expect(Money.usd(5).editableAmountText == "0.05")
    }

    // MARK: - Transaction enums

    @Test func transactionDirectionCasesRoundTripRawValues() {
        #expect(TransactionDirection(rawValue: "debit") == .debit)
        #expect(TransactionDirection(rawValue: "credit") == .credit)
        #expect(TransactionDirection.allCases.map(\.rawValue) == ["debit", "credit"])
    }

    @Test func transactionKindCasesRoundTripRawValues() {
        let expected: [TransactionKind] = [.purchase, .subscriptionCharge, .refund, .income, .transfer, .other]
        #expect(TransactionKind.allCases == expected)
        for kind in expected {
            #expect(TransactionKind(rawValue: kind.rawValue) == kind)
        }
    }

    @Test func transactionSourceCasesRoundTripRawValues() {
        let expected: [TransactionSource] = [.financeKit, .plaid, .manual]
        #expect(TransactionSource.allCases == expected)
        for source in expected {
            #expect(TransactionSource(rawValue: source.rawValue) == source)
        }
    }

    // MARK: - TransactionCategoryGroup

    @Test func transactionCategoryGroupTotalSumsAmounts() {
        let group = TransactionCategoryGroup(
            categoryID: "cat-streaming",
            categoryName: "Streaming",
            transactions: [
                makeTransaction(id: "t1", amount: .usd(999)),
                makeTransaction(id: "t2", amount: .usd(501)),
            ]
        )

        #expect(group.total == .usd(1500))
    }

    @Test func transactionCategoryGroupTotalIsZeroForEmptyGroup() {
        let group = TransactionCategoryGroup(categoryID: nil, categoryName: "Empty", transactions: [])
        #expect(group.total == .zeroUSD)
    }

    private func makeTransaction(id: String, amount: Money) -> Transaction {
        Transaction(
            id: id,
            userID: SeedData.defaultUserID,
            accountID: "acct-1",
            merchantRaw: id,
            merchantKey: MerchantKey(id),
            amount: amount,
            date: SeedData.referenceDate
        )
    }

    // MARK: - Cadence

    @Test func displayNameAndShortLabelCoverEveryCadence() {
        let expectations: [(Cadence, String, String)] = [
            (.weekly, "Weekly", "WEEKLY"),
            (.biweekly, "Every 2 weeks", "BIWEEKLY"),
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

    @Test func biweeklyMonthlyEquivalentUsesTwentySixPaymentsPerYear() {
        // $1000 biweekly => 1000 * 26 / 12 = 2166.67 -> rounds to 216_667 minor units.
        #expect(Cadence.biweekly.monthlyEquivalent(for: .usd(100_000)) == .usd(216_667))
    }

    @Test func biweeklyDetectionConstants() {
        #expect(Cadence.biweekly.detectionTargetDays == 14)
        #expect(Cadence.biweekly.detectionToleranceDays == 12 ... 16)
    }

    @Test func recurringIncomeAndBillStatusRoundTrip() {
        #expect(RecurringIncomeStatus.allCases == [.active, .stopped])
        #expect(BillStatus(rawValue: "stopped") == .stopped)
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
