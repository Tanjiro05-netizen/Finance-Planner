import Foundation
@testable import Sift
import Testing

struct DiscretionarySpendEstimatorTests {
    private let end = Date(timeIntervalSince1970: 1_720_000_000)
    private var start: Date { end.addingTimeInterval(-10 * 86400) }
    private var window: DateInterval { DateInterval(start: start, end: end) }

    private func txn(
        id: String,
        merchant: String,
        amount: Int,
        daysBeforeEnd: Int,
        direction: TransactionDirection = .debit,
        pending: Bool = false
    ) -> Transaction {
        Transaction(
            id: id,
            userID: SeedData.defaultUserID,
            accountID: "acct-1",
            merchantRaw: merchant,
            merchantKey: MerchantKey(merchant),
            amount: .usd(amount),
            date: end.addingTimeInterval(TimeInterval(-daysBeforeEnd * 86400)),
            pending: pending,
            direction: direction
        )
    }

    @Test func averagesDiscretionaryDebitsOverWindow() {
        let transactions = [
            txn(id: "a", merchant: "GROCERY", amount: 5_000, daysBeforeEnd: 2),
            txn(id: "b", merchant: "COFFEE", amount: 5_000, daysBeforeEnd: 5),
        ]
        // 10000 total / 10 days = 1000/day
        let rate = DiscretionarySpendEstimator.dailyRate(
            recentTransactions: transactions,
            knownRecurringMerchantKeys: [],
            window: window
        )
        #expect(rate == .usd(1_000))
    }

    @Test func excludesRecurringCreditsAndPendingAndOutOfWindow() {
        let transactions = [
            txn(id: "spend", merchant: "GROCERY", amount: 10_000, daysBeforeEnd: 2),
            txn(id: "sub", merchant: "NETFLIX", amount: 1_500, daysBeforeEnd: 3),
            txn(id: "income", merchant: "PAYROLL", amount: 200_000, daysBeforeEnd: 1, direction: .credit),
            txn(id: "pending", merchant: "GROCERY", amount: 9_999, daysBeforeEnd: 1, pending: true),
            txn(id: "old", merchant: "GROCERY", amount: 9_999, daysBeforeEnd: 40),
        ]
        let rate = DiscretionarySpendEstimator.dailyRate(
            recentTransactions: transactions,
            knownRecurringMerchantKeys: [MerchantKey("NETFLIX")],
            window: window
        )
        // Only the $100 grocery spend counts: 10000 / 10 days = 1000/day
        #expect(rate == .usd(1_000))
    }

    @Test func zeroWhenNoDiscretionarySpend() {
        #expect(DiscretionarySpendEstimator.dailyRate(
            recentTransactions: [],
            knownRecurringMerchantKeys: [],
            window: window
        ) == .zeroUSD)
    }
}
