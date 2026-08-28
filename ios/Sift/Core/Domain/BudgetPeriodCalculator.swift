import Foundation

/// One budget cycle, plus where "now" sits inside it.
struct BudgetCycle: Equatable {
    let interval: DateInterval
    /// Whole days in the cycle, always at least 1 so callers can divide safely.
    let totalDays: Int
    /// Days elapsed including today, clamped to `1...totalDays`.
    let elapsedDays: Int

    var start: Date {
        interval.start
    }

    var end: Date {
        interval.end
    }

    /// How far through the cycle we are, 0...1. Used as the even-burn baseline that
    /// spending is compared against to decide pace.
    var fractionElapsed: Double {
        Double(elapsedDays) / Double(totalDays)
    }
}

/// Resolves which budget cycle a date falls in. Kept separate from progress math so the
/// calendar reasoning has exactly one home — budgets, rollover, and any future
/// period-based feature all derive their windows from here.
enum BudgetPeriodCalculator {
    /// The cycle containing `referenceDate`, aligned to the calendar (weeks start on the
    /// calendar's first weekday, months on the 1st) rather than to the budget's start date.
    /// People think in "this month", not "the month since I created this budget".
    static func cycle(
        for period: BudgetPeriod,
        containing referenceDate: Date,
        calendar: Calendar = .utc
    ) -> BudgetCycle {
        let interval = calendar.dateInterval(of: period.calendarComponent, for: referenceDate)
            ?? fallbackInterval(for: period, containing: referenceDate, calendar: calendar)

        return makeCycle(interval: interval, referenceDate: referenceDate, calendar: calendar)
    }

    /// The cycle immediately before the one containing `referenceDate`. Rollover needs this
    /// to know what was left unspent last time.
    static func previousCycle(
        for period: BudgetPeriod,
        containing referenceDate: Date,
        calendar: Calendar = .utc
    ) -> BudgetCycle {
        let current = cycle(for: period, containing: referenceDate, calendar: calendar)
        let anchor = calendar.date(byAdding: .day, value: -1, to: current.start) ?? current.start
        return cycle(for: period, containing: anchor, calendar: calendar)
    }

    private static func makeCycle(interval: DateInterval, referenceDate: Date, calendar: Calendar) -> BudgetCycle {
        let totalDays = max(1, calendar.dateComponents([.day], from: interval.start, to: interval.end).day ?? 1)
        let rawElapsed = calendar.dateComponents([.day], from: interval.start, to: referenceDate).day ?? 0
        // +1 so the first day of a cycle counts as one day elapsed rather than zero, which
        // would make the pace baseline zero and every cycle look overspent on day one.
        let elapsed = min(max(rawElapsed + 1, 1), totalDays)

        return BudgetCycle(interval: interval, totalDays: totalDays, elapsedDays: elapsed)
    }

    /// `Calendar.dateInterval(of:for:)` is optional; this keeps the calculator total rather
    /// than forcing every caller to handle a nil that should never occur for these units.
    private static func fallbackInterval(
        for period: BudgetPeriod,
        containing referenceDate: Date,
        calendar: Calendar
    ) -> DateInterval {
        let start = calendar.startOfDay(for: referenceDate)
        let length = period == .weekly ? 7 : 30
        let end = calendar.date(byAdding: .day, value: length, to: start) ?? start
        return DateInterval(start: start, end: end)
    }
}
