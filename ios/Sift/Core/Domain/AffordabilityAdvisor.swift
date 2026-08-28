import Foundation

enum AffordabilityVerdict: String, Codable, CaseIterable {
    case comfortable
    case tight
    case notAdvisable

    var headline: String {
        switch self {
        case .comfortable:
            "Yes, you can afford this"
        case .tight:
            "You can, but it's tight"
        case .notAdvisable:
            "Not right now"
        }
    }

    /// Worse of two verdicts, so several checks can be combined without nested branching.
    fileprivate var severity: Int {
        switch self {
        case .comfortable:
            0
        case .tight:
            1
        case .notAdvisable:
            2
        }
    }
}

/// A single plain-language justification. The point of this feature is to explain, not to
/// hand down a verdict, so every assessment carries the reasoning that produced it.
struct AffordabilityReason: Identifiable, Equatable {
    let id: String
    let text: String
}

struct AffordabilityAssessment: Equatable {
    let amount: Money
    let verdict: AffordabilityVerdict
    let reasons: [AffordabilityReason]
    /// Safe-to-spend pool left after this purchase; nil when there's no balance to reason from.
    let remainingAfter: Money?
    /// Budget left after this purchase; nil when the category has no budget.
    let budgetRemainingAfter: Money?
}

/// Answers "can I afford this?" by combining Phase 2's safe-to-spend pool with the relevant
/// category budget. Deliberately reuses `SafeToSpendOutcome` rather than inventing a second,
/// subtly different notion of affordability — two answers to the same question is worse than none.
enum AffordabilityAdvisor {
    /// Leaving under this share of the pool intact counts as tight rather than comfortable.
    static let tightRemainderFraction = 0.2

    static func assess(
        amount: Money,
        safeToSpend: SafeToSpendOutcome,
        budgetProgress: BudgetProgress? = nil
    ) -> AffordabilityAssessment {
        var reasons: [AffordabilityReason] = []
        var verdict = AffordabilityVerdict.comfortable
        var remainingAfter: Money?

        switch safeToSpend {
        case .unavailable(.noBalanceData):
            // No balance means no honest answer from the cash side. Say so rather than
            // implying the budget alone settles it.
            verdict = .tight
            reasons.append(AffordabilityReason(
                id: "no-balance",
                text: "No account balance yet, so this only reflects your budget."
            ))

        case let .available(result):
            let after = result.netAvailable - amount
            remainingAfter = after

            if after.amountMinor < 0 {
                verdict = .notAdvisable
                let shortfall = Money(amountMinor: abs(after.amountMinor), currency: after.currency)
                reasons.append(AffordabilityReason(
                    id: "over-pool",
                    text: "This is \(shortfall.formatted()) more than you have before \(horizonPhrase(result))."
                ))
            } else if isTight(remainder: after, pool: result.netAvailable) {
                verdict = verdict.combined(with: .tight)
                reasons.append(AffordabilityReason(
                    id: "thin-pool",
                    text: "Leaves \(after.formatted()) to last until \(horizonPhrase(result))."
                ))
            } else {
                reasons.append(AffordabilityReason(
                    id: "pool-ok",
                    text: "Leaves \(after.formatted()) until \(horizonPhrase(result))."
                ))
            }
        }

        if let budgetProgress {
            let (budgetVerdict, budgetReason, after) = assessBudget(amount: amount, progress: budgetProgress)
            verdict = verdict.combined(with: budgetVerdict)
            reasons.append(budgetReason)
            return AffordabilityAssessment(
                amount: amount,
                verdict: verdict,
                reasons: reasons,
                remainingAfter: remainingAfter,
                budgetRemainingAfter: after
            )
        }

        return AffordabilityAssessment(
            amount: amount,
            verdict: verdict,
            reasons: reasons,
            remainingAfter: remainingAfter,
            budgetRemainingAfter: nil
        )
    }

    private static func assessBudget(
        amount: Money,
        progress: BudgetProgress
    ) -> (AffordabilityVerdict, AffordabilityReason, Money) {
        let after = progress.remaining - amount

        if progress.isOverspent {
            return (
                .notAdvisable,
                AffordabilityReason(id: "budget-already-over", text: "That budget is already overspent this period."),
                after
            )
        }

        if after.amountMinor < 0 {
            let overage = Money(amountMinor: abs(after.amountMinor), currency: after.currency)
            return (
                .tight,
                AffordabilityReason(id: "budget-over", text: "Puts that budget \(overage.formatted()) over for this period."),
                after
            )
        }

        return (
            .comfortable,
            AffordabilityReason(id: "budget-ok", text: "Leaves \(after.formatted()) in that budget this period."),
            after
        )
    }

    private static func isTight(remainder: Money, pool: Money) -> Bool {
        guard pool.amountMinor > 0 else {
            return true
        }

        return Double(remainder.amountMinor) / Double(pool.amountMinor) < tightRemainderFraction
    }

    private static func horizonPhrase(_ result: SafeToSpendResult) -> String {
        result.usedFallbackWindow ? "the end of the month" : "your next income"
    }
}

private extension AffordabilityVerdict {
    func combined(with other: AffordabilityVerdict) -> AffordabilityVerdict {
        severity >= other.severity ? self : other
    }
}
