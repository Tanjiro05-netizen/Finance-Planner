import Foundation
@testable import Sift
import Testing

struct SafeToSpendCalculatorTests {
    private let today = Date(timeIntervalSince1970: 1_720_000_000)

    private func input(
        balance: Money?,
        debits: [Money] = [],
        credits: [Money] = [],
        nextIncome: Date? = nil,
        recentDaily: Money = .zeroUSD
    ) -> SafeToSpendInput {
        SafeToSpendInput(
            currentBalance: balance,
            upcomingDebits: debits,
            upcomingCredits: credits,
            recentDailySpend: recentDaily,
            today: today,
            nextExpectedIncomeDate: nextIncome
        )
    }

    @Test func unavailableWithoutBalance() {
        #expect(SafeToSpendCalculator.calculate(input: input(balance: nil)) == .unavailable(.noBalanceData))
    }

    @Test func dividesNetEvenlyUntilNextIncome() {
        let payday = today.addingTimeInterval(10 * 86400)
        let outcome = SafeToSpendCalculator.calculate(input: input(
            balance: .usd(100_000),
            debits: [.usd(20000)],
            nextIncome: payday
        ))
        guard case let .available(result) = outcome else {
            Issue.record("Expected available outcome")
            return
        }
        // (100000 - 20000) / 10 days = 8000/day
        #expect(result.dailyAmount == .usd(8000))
        #expect(result.daysRemaining == 10)
        #expect(result.isOverspent == false)
        #expect(result.usedFallbackWindow == false)
        #expect(result.horizonEndDate == payday)
    }

    @Test func upcomingCreditsIncreaseAvailableSpend() {
        let payday = today.addingTimeInterval(10 * 86400)
        let outcome = SafeToSpendCalculator.calculate(input: input(
            balance: .usd(100_000),
            debits: [.usd(20000)],
            credits: [.usd(10000)],
            nextIncome: payday
        ))
        guard case let .available(result) = outcome else {
            Issue.record("Expected available outcome")
            return
        }
        // (100000 - 20000 + 10000) / 10 = 9000/day
        #expect(result.dailyAmount == .usd(9000))
    }

    @Test func fallsBackToThirtyDayWindowWithoutIncome() {
        let outcome = SafeToSpendCalculator.calculate(input: input(balance: .usd(60000)))
        guard case let .available(result) = outcome else {
            Issue.record("Expected available outcome")
            return
        }
        #expect(result.usedFallbackWindow)
        #expect(result.daysRemaining == SafeToSpendCalculator.fallbackWindowDays)
        #expect(result.dailyAmount == .usd(2000))
    }

    @Test func overspentReturnsNegativeDailyAndZeroDays() {
        let payday = today.addingTimeInterval(10 * 86400)
        let outcome = SafeToSpendCalculator.calculate(input: input(
            balance: .usd(5000),
            debits: [.usd(30000)],
            nextIncome: payday
        ))
        guard case let .available(result) = outcome else {
            Issue.record("Expected available outcome")
            return
        }
        #expect(result.isOverspent)
        #expect(result.daysRemaining == 0)
        #expect(result.dailyAmount.amountMinor < 0)
    }

    @Test func horizonOnTodayDoesNotDivideByZero() {
        let outcome = SafeToSpendCalculator.calculate(input: input(
            balance: .usd(10000),
            nextIncome: today
        ))
        guard case let .available(result) = outcome else {
            Issue.record("Expected available outcome")
            return
        }
        // Guarded to at least 1 day, so 10000/1.
        #expect(result.dailyAmount == .usd(10000))
    }

    @Test func recentDailySpendPassesThrough() {
        let outcome = SafeToSpendCalculator.calculate(input: input(
            balance: .usd(60000),
            recentDaily: .usd(1234)
        ))
        guard case let .available(result) = outcome else {
            Issue.record("Expected available outcome")
            return
        }
        #expect(result.recentDailySpend == .usd(1234))
    }
}
