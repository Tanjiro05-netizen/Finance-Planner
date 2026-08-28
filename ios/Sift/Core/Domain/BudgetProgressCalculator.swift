import Foundation

/// Where a budget stands partway through its cycle.
struct BudgetProgress: Equatable {
    /// The budget's own allowance, before any rollover.
    let baseAmount: Money
    /// Unspent remainder carried in from the previous cycle; zero when rollover is off.
    let rolloverCarry: Money
    /// What's actually available this cycle: `baseAmount + rolloverCarry`.
    let budgeted: Money
    let spent: Money
    /// `budgeted - spent`. Negative once the budget is blown, which the UI shows as such
    /// rather than clamping to zero — hiding the overage is exactly the wrong thing here.
    let remaining: Money
    /// `spent / budgeted`, clamped to 0...1 for drawing progress bars. Read `isOverspent`
    /// rather than this to decide whether the budget was exceeded.
    let fractionUsed: Double
    let isOverspent: Bool
    /// Spend-to-date extrapolated evenly across the whole cycle.
    let projectedSpend: Money
    let pace: BudgetPace
    let cycle: BudgetCycle
}

/// Turns a budget plus the ledger into a progress reading. Pure and deterministic: actuals
/// are always derived from transactions, never stored, so a budget cannot drift out of sync
/// with the spending it measures.
enum BudgetProgressCalculator {
    /// How far ahead of or behind an even burn-down spending may drift before it stops
    /// counting as on track. Ten percentage points keeps day-to-day lumpiness from
    /// constantly flipping the label.
    static let paceTolerance = 0.1

    static func progress(
        budget: Budget,
        transactions: [Transaction],
        referenceDate: Date,
        rolloverCarry: Money = .zeroUSD,
        calendar: Calendar = .utc
    ) -> BudgetProgress {
        let cycle = BudgetPeriodCalculator.cycle(for: budget.period, containing: referenceDate, calendar: calendar)
        let carry = budget.rolloverEnabled ? rolloverCarry : .zeroUSD
        let budgeted = budget.amount + carry
        let spent = spend(in: transactions, categoryID: budget.categoryID, during: cycle.interval)

        let remaining = budgeted - spent
        let isOverspent = remaining.amountMinor < 0
        let fractionUsed = fraction(spent: spent, budgeted: budgeted)

        // Extrapolate with integer money math so the projection rounds the same way every
        // other figure in the app does.
        let projected = spent.multiplied(by: cycle.totalDays).divided(by: cycle.elapsedDays)

        return BudgetProgress(
            baseAmount: budget.amount,
            rolloverCarry: carry,
            budgeted: budgeted,
            spent: spent,
            remaining: remaining,
            fractionUsed: fractionUsed,
            isOverspent: isOverspent,
            projectedSpend: projected,
            pace: pace(fractionUsed: fractionUsed, cycle: cycle, isOverspent: isOverspent),
            cycle: cycle
        )
    }

    /// Total spend against a category in a window. Debits only, settled only — a pending
    /// charge can still vanish, and counting it would show people money they still have.
    static func spend(in transactions: [Transaction], categoryID: String, during interval: DateInterval) -> Money {
        let matching = transactions.filter { transaction in
            transaction.direction == .debit
                && !transaction.pending
                && transaction.categoryID == categoryID
                && interval.contains(transaction.date)
        }

        guard let currency = matching.first?.amount.currency else {
            return .zeroUSD
        }

        return (try? Money.sum(matching.map(\.amount), currency: currency))
            ?? Money(amountMinor: 0, currency: currency)
    }

    /// The unspent remainder of a finished cycle, floored at zero — overspending eats into
    /// the current cycle only if we let a negative carry through, and compounding a bad
    /// month into the next one is a punishment, not a budget.
    static func rolloverCarry(budget: Budget, previousCycleTransactions: [Transaction], previousCycle: BudgetCycle) -> Money {
        guard budget.rolloverEnabled else {
            return .zeroUSD
        }

        let spent = spend(in: previousCycleTransactions, categoryID: budget.categoryID, during: previousCycle.interval)
        let remainder = budget.amount - spent
        return remainder.amountMinor > 0 ? remainder : .zeroUSD
    }

    private static func fraction(spent: Money, budgeted: Money) -> Double {
        guard budgeted.amountMinor > 0 else {
            return spent.amountMinor > 0 ? 1 : 0
        }

        let raw = Double(spent.amountMinor) / Double(budgeted.amountMinor)
        return min(max(raw, 0), 1)
    }

    private static func pace(fractionUsed: Double, cycle: BudgetCycle, isOverspent: Bool) -> BudgetPace {
        if isOverspent {
            return .over
        }

        let elapsed = cycle.fractionElapsed
        if fractionUsed > elapsed + paceTolerance {
            return .over
        }
        if fractionUsed < elapsed - paceTolerance {
            return .under
        }
        return .onTrack
    }
}
