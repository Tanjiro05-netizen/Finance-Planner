import Foundation

/// Pure heuristics for assigning a `TransactionKind` to a transaction. Kept framework-free
/// and side-effect-free so the refund/income logic is unit-testable in isolation.
enum TransactionClassifier {
    /// The default kind for a freshly-imported transaction, before any merchant-history
    /// refinement: a credit defaults to income, a debit to a plain purchase.
    static func kind(for direction: TransactionDirection) -> TransactionKind {
        switch direction {
        case .credit:
            .income
        case .debit:
            .purchase
        }
    }

    /// Upgrades a credit's default `.income` kind to `.refund` when it matches a recent
    /// same-merchant, same-account debit for the same or a lesser amount. Only ever
    /// refines credits that are still at their untouched default -- a manually-set or
    /// otherwise-classified kind is left alone.
    static func refine(
        kind: TransactionKind,
        direction: TransactionDirection,
        merchantKey: MerchantKey,
        accountID: String,
        amount: Money,
        date: Date,
        priorDebits: [Transaction],
        window: TimeInterval = 90 * 86400
    ) -> TransactionKind {
        guard direction == .credit, kind == .income else {
            return kind
        }

        let matches = priorDebits.contains { debit in
            debit.accountID == accountID &&
                debit.merchantKey == merchantKey &&
                debit.amount.currency == amount.currency &&
                debit.amount.amountMinor >= amount.amountMinor &&
                debit.date <= date &&
                date.timeIntervalSince(debit.date) <= window
        }

        return matches ? .refund : kind
    }
}
