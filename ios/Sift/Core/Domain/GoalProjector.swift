import Foundation

/// Which of the two optional inputs a goal is missing. Rather than fabricate a projection
/// from one data point, the UI names what it still needs.
enum GoalMissingInput: String, Equatable {
    case targetDateAndContribution
    case targetDateOrContribution
}

/// Where a goal stands. Every case carries the figures the UI needs, so views do no arithmetic.
enum GoalOutcome: Equatable {
    /// Saved has met or passed the target.
    case reached(saved: Money, surplus: Money)
    /// The target date has passed without the target being met.
    case overdue(saved: Money, remaining: Money, monthsPast: Int)
    /// Not enough inputs to project anything honest.
    case insufficientData(saved: Money, remaining: Money, missing: GoalMissingInput)
    /// The planned contribution covers what's required.
    case onTrack(saved: Money, remaining: Money, requiredMonthly: Money, projectedCompletion: Date?)
    /// The planned contribution falls short of what's required by the target date.
    case behind(saved: Money, remaining: Money, requiredMonthly: Money, shortfallPerMonth: Money)
    /// The planned contribution exceeds what's required.
    case ahead(saved: Money, remaining: Money, requiredMonthly: Money, surplusPerMonth: Money)

    /// Amount contributed so far, net of withdrawals — available on every case because the
    /// UI leads with progress made rather than the gap remaining.
    var saved: Money {
        switch self {
        case let .reached(saved, _),
             let .overdue(saved, _, _),
             let .insufficientData(saved, _, _),
             let .onTrack(saved, _, _, _),
             let .behind(saved, _, _, _),
             let .ahead(saved, _, _, _):
            saved
        }
    }

    var isReached: Bool {
        if case .reached = self {
            return true
        }
        return false
    }
}

/// Projects savings goals. Pure, deterministic, and deliberately *recompute-from-today*: the
/// required monthly contribution is re-derived from the current balance every time rather than
/// compared against a stored schedule. That makes it self-healing — a withdrawal or a skipped
/// month simply raises the next requirement, with no stored baseline to drift or migrate.
///
/// Zero-interest throughout. The app holds no rate data, and goal horizons are short enough
/// that compounding would be false precision.
enum GoalProjector {
    /// Net of withdrawals: contributions are signed, so a negative entry reduces progress.
    static func saved(from contributions: [GoalContribution]) -> Money {
        guard let currency = contributions.first?.amount.currency else {
            return .zeroUSD
        }

        return (try? Money.sum(contributions.map(\.amount), currency: currency))
            ?? Money(amountMinor: 0, currency: currency)
    }

    /// Whole months from `referenceDate` to `targetDate`, **including the current month**, and
    /// never less than 1.
    ///
    /// Counting the current month is the convention YNAB uses (`goal_months_to_budget`).
    /// Excluding it makes the final month's requirement double, because the money would be
    /// due in a month the calculation says has already gone.
    static func monthsRemaining(to targetDate: Date, from referenceDate: Date, calendar: Calendar = .utc) -> Int {
        let start = calendar.dateInterval(of: .month, for: referenceDate)?.start ?? referenceDate
        let end = calendar.dateInterval(of: .month, for: targetDate)?.start ?? targetDate
        let months = calendar.dateComponents([.month], from: start, to: end).month ?? 0
        return max(1, months + 1)
    }

    /// Whole months the target date is in the past, 0 when it isn't.
    static func monthsOverdue(targetDate: Date, referenceDate: Date, calendar: Calendar = .utc) -> Int {
        let start = calendar.dateInterval(of: .month, for: targetDate)?.start ?? targetDate
        let end = calendar.dateInterval(of: .month, for: referenceDate)?.start ?? referenceDate
        return max(0, calendar.dateComponents([.month], from: start, to: end).month ?? 0)
    }

    /// What must be set aside each month to close the gap by the target date.
    static func requiredMonthlyContribution(target: Money, saved: Money, monthsRemaining: Int) -> Money {
        let remaining = target - saved
        guard remaining.amountMinor > 0 else {
            return Money(amountMinor: 0, currency: target.currency)
        }

        return remaining.divided(by: max(1, monthsRemaining))
    }

    /// When the goal completes at the given contribution rate, or nil when it never would.
    static func projectedCompletion(
        target: Money,
        saved: Money,
        monthlyContribution: Money,
        from referenceDate: Date,
        calendar: Calendar = .utc
    ) -> Date? {
        let remaining = target - saved
        guard remaining.amountMinor > 0 else {
            return referenceDate
        }

        // A zero or negative rate never converges; returning nil is the honest answer, where
        // dividing would produce an infinity the UI would have to special-case anyway.
        guard monthlyContribution.amountMinor > 0 else {
            return nil
        }

        let months = Int(ceil(Double(remaining.amountMinor) / Double(monthlyContribution.amountMinor)))
        return calendar.date(byAdding: .month, value: months, to: referenceDate)
    }

    static func outcome(
        goal: Goal,
        contributions: [GoalContribution],
        referenceDate: Date,
        calendar: Calendar = .utc
    ) -> GoalOutcome {
        let saved = saved(from: contributions)
        let remaining = goal.targetAmount - saved

        if remaining.amountMinor <= 0 {
            let surplus = Money(amountMinor: abs(remaining.amountMinor), currency: remaining.currency)
            return .reached(saved: saved, surplus: surplus)
        }

        let planned = goal.monthlyContribution

        guard let targetDate = goal.targetDate else {
            // No date: a contribution alone still yields a completion estimate, which is the
            // "derive the third value" behaviour. With neither, there's nothing to say.
            guard let planned, planned.amountMinor > 0 else {
                return .insufficientData(saved: saved, remaining: remaining, missing: .targetDateAndContribution)
            }

            return .onTrack(
                saved: saved,
                remaining: remaining,
                requiredMonthly: planned,
                projectedCompletion: projectedCompletion(
                    target: goal.targetAmount,
                    saved: saved,
                    monthlyContribution: planned,
                    from: referenceDate,
                    calendar: calendar
                )
            )
        }

        let overdueMonths = monthsOverdue(targetDate: targetDate, referenceDate: referenceDate, calendar: calendar)
        if overdueMonths > 0 {
            return .overdue(saved: saved, remaining: remaining, monthsPast: overdueMonths)
        }

        let months = monthsRemaining(to: targetDate, from: referenceDate, calendar: calendar)
        let required = requiredMonthlyContribution(target: goal.targetAmount, saved: saved, monthsRemaining: months)

        // A date with no contribution is not a failure — the required figure is exactly the
        // answer to "how much would I need to save?", so surface it as the plan.
        guard let planned, planned.amountMinor > 0 else {
            return .insufficientData(saved: saved, remaining: remaining, missing: .targetDateOrContribution)
        }

        if planned.amountMinor < required.amountMinor {
            return .behind(
                saved: saved,
                remaining: remaining,
                requiredMonthly: required,
                shortfallPerMonth: required - planned
            )
        }

        if planned.amountMinor > required.amountMinor {
            return .ahead(
                saved: saved,
                remaining: remaining,
                requiredMonthly: required,
                surplusPerMonth: planned - required
            )
        }

        return .onTrack(
            saved: saved,
            remaining: remaining,
            requiredMonthly: required,
            projectedCompletion: projectedCompletion(
                target: goal.targetAmount,
                saved: saved,
                monthlyContribution: planned,
                from: referenceDate,
                calendar: calendar
            )
        )
    }

    /// Progress for drawing, clamped to 0...1.
    static func fractionComplete(target: Money, saved: Money) -> Double {
        guard target.amountMinor > 0 else {
            return saved.amountMinor > 0 ? 1 : 0
        }

        return min(max(Double(saved.amountMinor) / Double(target.amountMinor), 0), 1)
    }
}
