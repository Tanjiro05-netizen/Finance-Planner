import Foundation

/// Estimates a person's recent day-to-day discretionary spend rate — everyday debits that
/// aren't already accounted for as recurring subscriptions or bills. Used as a context
/// figure next to the safe-to-spend headline ("you've been averaging $Y/day recently").
enum DiscretionarySpendEstimator {
    static func dailyRate(
        recentTransactions: [Transaction],
        knownRecurringMerchantKeys: Set<MerchantKey>,
        window: DateInterval,
        calendar: Calendar = .utc
    ) -> Money {
        let discretionary = recentTransactions.filter { transaction in
            transaction.direction == .debit
                && !transaction.pending
                && !knownRecurringMerchantKeys.contains(transaction.merchantKey)
                && window.contains(transaction.date)
        }

        guard !discretionary.isEmpty else {
            return .zeroUSD
        }

        let currency = discretionary[0].amount.currency
        let total = (try? Money.sum(discretionary.map(\.amount), currency: currency))
            ?? Money(amountMinor: 0, currency: currency)

        let days = calendar.dateComponents([.day], from: window.start, to: window.end).day ?? 1
        return total.divided(by: max(1, days))
    }
}
