import Foundation

struct SafeToSpendInput {
    /// Summed spendable balance across deposit accounts; nil when no balance is known.
    let currentBalance: Money?
    /// Recurring debits (bills + subscriptions) due before the horizon.
    let upcomingDebits: [Money]
    /// Non-income credits expected before the horizon (e.g. refunds).
    let upcomingCredits: [Money]
    /// Recent average discretionary daily spend, carried through for display only.
    let recentDailySpend: Money
    let today: Date
    /// Next expected recurring income date; nil when no income was detected.
    let nextExpectedIncomeDate: Date?
    var calendar: Calendar = .utc
}

enum SafeToSpendUnavailableReason: Equatable {
    case noBalanceData
}

struct SafeToSpendResult: Equatable {
    /// Safe daily spend; negative when already over-committed before the horizon.
    let dailyAmount: Money
    let horizonEndDate: Date
    let daysRemaining: Int
    let isOverspent: Bool
    /// True when no income was detected and a fixed window was used instead.
    let usedFallbackWindow: Bool
    let recentDailySpend: Money
}

enum SafeToSpendOutcome: Equatable {
    case unavailable(SafeToSpendUnavailableReason)
    case available(SafeToSpendResult)
}

/// Turns a balance, the known money in/out before the next payday, and today's date into
/// a "safe to spend per day" figure. Pure and deterministic — the emotional hook of the
/// planner, so it never fabricates a number when it doesn't have the balance to stand on.
enum SafeToSpendCalculator {
    /// Window used only when no recurring income is detected.
    static let fallbackWindowDays = 30

    static func calculate(input: SafeToSpendInput) -> SafeToSpendOutcome {
        guard let currentBalance = input.currentBalance else {
            return .unavailable(.noBalanceData)
        }

        let usedFallbackWindow = input.nextExpectedIncomeDate == nil
        let horizonEnd = input.nextExpectedIncomeDate
            ?? input.calendar.date(byAdding: .day, value: fallbackWindowDays, to: input.today)
            ?? input.today

        let currency = currentBalance.currency
        let debits = (try? Money.sum(input.upcomingDebits, currency: currency)) ?? Money(amountMinor: 0, currency: currency)
        let credits = (try? Money.sum(input.upcomingCredits, currency: currency)) ?? Money(amountMinor: 0, currency: currency)
        let netAvailable = currentBalance - debits + credits

        let rawDays = input.calendar.dateComponents([.day], from: input.today, to: horizonEnd).day ?? 1
        let daysUntilHorizon = max(1, rawDays)
        let isOverspent = netAvailable.amountMinor < 0

        return .available(SafeToSpendResult(
            dailyAmount: netAvailable.divided(by: daysUntilHorizon),
            horizonEndDate: horizonEnd,
            daysRemaining: isOverspent ? 0 : daysUntilHorizon,
            isOverspent: isOverspent,
            usedFallbackWindow: usedFallbackWindow,
            recentDailySpend: input.recentDailySpend
        ))
    }
}
