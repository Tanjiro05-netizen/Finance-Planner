import Foundation

/// Assembles `SafeToSpendInput` from the repositories and runs the calculator.
///
/// Not pure — it reads the ledger — so it deliberately sits between the repositories and
/// the pure `SafeToSpendCalculator` rather than inside it. It exists because more than one
/// screen needs the same answer (the Home hero card and the affordability check), and two
/// hand-assembled copies of this input would drift the way the two `Transaction` builders
/// did before Phase 1 consolidated them.
@MainActor
enum SafeToSpendProvider {
    /// How far back the discretionary spend average looks.
    static let discretionaryWindowDays = 30

    static func outcome(repositories: RepositoryContainer, today: Date, calendar: Calendar = .utc) throws -> SafeToSpendOutcome {
        let balance = try repositories.accounts.totalBalance()
        let nextIncome = try repositories.recurringIncome.nextExpectedIncome(after: today)
        let horizon = nextIncome?.nextExpected
            ?? calendar.date(byAdding: .day, value: SafeToSpendCalculator.fallbackWindowDays, to: today)
            ?? today

        let upcomingSubscriptions = try repositories.subscriptions.upcomingRenewals(from: today, to: horizon)
        let upcomingBills = try repositories.bills.upcomingBills(from: today, to: horizon)
        let upcomingDebits = upcomingSubscriptions.map(\.amount) + upcomingBills.map(\.amount)

        let windowStart = calendar.date(byAdding: .day, value: -discretionaryWindowDays, to: today) ?? today
        let recentTransactions = try repositories.transactions.transactions(from: windowStart, to: today)
        let subscriptionKeys = try repositories.subscriptions.all().map(\.merchantKey)
        let billKeys = try repositories.bills.all().map(\.merchantKey)
        let recurringKeys = Set(subscriptionKeys).union(billKeys)
        let dailySpend = DiscretionarySpendEstimator.dailyRate(
            recentTransactions: recentTransactions,
            knownRecurringMerchantKeys: recurringKeys,
            window: DateInterval(start: windowStart, end: today)
        )

        return SafeToSpendCalculator.calculate(input: SafeToSpendInput(
            currentBalance: balance,
            upcomingDebits: upcomingDebits,
            upcomingCredits: [],
            recentDailySpend: dailySpend,
            today: today,
            nextExpectedIncomeDate: nextIncome?.nextExpected
        ))
    }
}
