import Foundation
@testable import Sift
import Testing

struct TransactionClassifierTests {
    private func makeTransaction(
        id: String,
        accountID: String = "acct-1",
        merchantKey: MerchantKey = MerchantKey("Corner Market"),
        amount: Money = .usd(1000),
        date: Date,
        direction: TransactionDirection = .debit
    ) -> Transaction {
        Transaction(
            id: id,
            userID: SeedData.defaultUserID,
            accountID: accountID,
            merchantRaw: merchantKey.rawValue,
            merchantKey: merchantKey,
            amount: amount,
            date: date,
            direction: direction,
            source: .financeKit
        )
    }

    @Test func defaultKindForDirection() {
        #expect(TransactionClassifier.kind(for: .debit) == .purchase)
        #expect(TransactionClassifier.kind(for: .credit) == .income)
    }

    @Test func refineOnlyTouchesIncomeCredits() {
        #expect(TransactionClassifier.refine(
            kind: .purchase,
            direction: .debit,
            merchantKey: MerchantKey("Corner Market"),
            accountID: "acct-1",
            amount: .usd(1000),
            date: Date(timeIntervalSince1970: 1_800_000_000),
            priorDebits: []
        ) == .purchase)

        #expect(TransactionClassifier.refine(
            kind: .subscriptionCharge,
            direction: .credit,
            merchantKey: MerchantKey("Corner Market"),
            accountID: "acct-1",
            amount: .usd(1000),
            date: Date(timeIntervalSince1970: 1_800_000_000),
            priorDebits: []
        ) == .subscriptionCharge)
    }

    @Test func refineUpgradesMatchingCreditToRefund() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let priorDebit = makeTransaction(id: "d1", amount: .usd(1000), date: now.addingTimeInterval(-5 * 86400))

        let kind = TransactionClassifier.refine(
            kind: .income,
            direction: .credit,
            merchantKey: MerchantKey("Corner Market"),
            accountID: "acct-1",
            amount: .usd(1000),
            date: now,
            priorDebits: [priorDebit]
        )

        #expect(kind == .refund)
    }

    @Test func refineLeavesUnmatchedCreditAsIncome() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let differentMerchant = makeTransaction(
            id: "d1",
            merchantKey: MerchantKey("Other Shop"),
            amount: .usd(1000),
            date: now.addingTimeInterval(-5 * 86400)
        )
        let differentAccount = makeTransaction(
            id: "d2",
            accountID: "acct-2",
            amount: .usd(1000),
            date: now.addingTimeInterval(-5 * 86400)
        )
        let smallerDebit = makeTransaction(id: "d3", amount: .usd(500), date: now.addingTimeInterval(-5 * 86400))
        let tooOld = makeTransaction(id: "d4", amount: .usd(1000), date: now.addingTimeInterval(-200 * 86400))

        let kind = TransactionClassifier.refine(
            kind: .income,
            direction: .credit,
            merchantKey: MerchantKey("Corner Market"),
            accountID: "acct-1",
            amount: .usd(1000),
            date: now,
            priorDebits: [differentMerchant, differentAccount, smallerDebit, tooOld]
        )

        #expect(kind == .income)
    }

    @Test func refineMatchesRefundForLesserAmountThanOriginalDebit() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let priorDebit = makeTransaction(id: "d1", amount: .usd(1000), date: now.addingTimeInterval(-5 * 86400))

        let kind = TransactionClassifier.refine(
            kind: .income,
            direction: .credit,
            merchantKey: MerchantKey("Corner Market"),
            accountID: "acct-1",
            amount: .usd(400),
            date: now,
            priorDebits: [priorDebit]
        )

        #expect(kind == .refund)
    }
}
