import Foundation
@testable import Sift
import Testing

struct BudgetProgressCalculatorTests {
    private let categoryID = "cat-groceries"

    private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 12) -> Date {
        Calendar.utc.date(from: DateComponents(year: year, month: month, day: day, hour: hour)) ?? Date()
    }

    private func budget(
        amount: Int,
        period: BudgetPeriod = .monthly,
        rollover: Bool = false
    ) -> Budget {
        Budget(
            id: "budget-1",
            userID: SeedData.defaultUserID,
            categoryID: categoryID,
            amount: .usd(amount),
            period: period,
            rolloverEnabled: rollover,
            startDate: date(2026, 1, 1)
        )
    }

    private func transaction(
        id: String,
        cents: Int,
        day: Int,
        month: Int = 6,
        category: String? = "cat-groceries",
        direction: TransactionDirection = .debit,
        pending: Bool = false
    ) -> Transaction {
        Transaction(
            id: id,
            userID: SeedData.defaultUserID,
            accountID: SeedData.ID.checking,
            merchantRaw: "Corner Grocery",
            merchantKey: MerchantKey("Corner Grocery"),
            amount: .usd(cents),
            date: date(2026, month, day),
            pending: pending,
            direction: direction,
            categoryID: category
        )
    }

    @Test func spentSumsMatchingDebitsInThePeriod() {
        let progress = BudgetProgressCalculator.progress(
            budget: budget(amount: 40000),
            transactions: [
                transaction(id: "a", cents: 6247, day: 5),
                transaction(id: "b", cents: 5488, day: 19),
            ],
            referenceDate: date(2026, 6, 29)
        )

        #expect(progress.spent == .usd(11735))
        #expect(progress.budgeted == .usd(40000))
        #expect(progress.remaining == .usd(28265))
        #expect(progress.isOverspent == false)
    }

    @Test func spentExcludesCreditsPendingOtherCategoriesAndOtherPeriods() {
        let progress = BudgetProgressCalculator.progress(
            budget: budget(amount: 40000),
            transactions: [
                transaction(id: "counted", cents: 1000, day: 5),
                transaction(id: "credit", cents: 9999, day: 6, direction: .credit),
                transaction(id: "pending", cents: 9999, day: 7, pending: true),
                transaction(id: "other-category", cents: 9999, day: 8, category: "cat-dining"),
                transaction(id: "uncategorised", cents: 9999, day: 9, category: nil),
                transaction(id: "last-month", cents: 9999, day: 9, month: 5),
            ],
            referenceDate: date(2026, 6, 29)
        )

        #expect(progress.spent == .usd(1000))
    }

    @Test func overspendingReportsNegativeRemainder() {
        let progress = BudgetProgressCalculator.progress(
            budget: budget(amount: 5000),
            transactions: [transaction(id: "a", cents: 6000, day: 5)],
            referenceDate: date(2026, 6, 29)
        )

        #expect(progress.isOverspent)
        #expect(progress.remaining == .usd(-1000))
        #expect(progress.pace == .over)
        // Clamped for drawing, so the bar can't overflow its track.
        #expect(progress.fractionUsed == 1)
    }

    @Test func projectionExtrapolatesSpendAcrossTheWholeCycle() {
        // Half the month gone, $100 spent, so the month should project to about $200.
        let progress = BudgetProgressCalculator.progress(
            budget: budget(amount: 40000),
            transactions: [transaction(id: "a", cents: 10000, day: 5)],
            referenceDate: date(2026, 6, 15)
        )

        #expect(progress.cycle.elapsedDays == 15)
        #expect(progress.projectedSpend == .usd(20000))
    }

    @Test func paceIsUnderWhenSpendTrailsTheCycle() {
        let progress = BudgetProgressCalculator.progress(
            budget: budget(amount: 40000),
            transactions: [transaction(id: "a", cents: 1000, day: 2)],
            referenceDate: date(2026, 6, 29)
        )

        #expect(progress.pace == .under)
    }

    @Test func paceIsOverWhenSpendOutrunsTheCycle() {
        // Two days in, nearly the whole allowance gone.
        let progress = BudgetProgressCalculator.progress(
            budget: budget(amount: 10000),
            transactions: [transaction(id: "a", cents: 9000, day: 1)],
            referenceDate: date(2026, 6, 2)
        )

        #expect(progress.pace == .over)
        #expect(progress.isOverspent == false)
    }

    @Test func rolloverCarryAddsToTheAllowanceOnlyWhenEnabled() {
        let enabled = BudgetProgressCalculator.progress(
            budget: budget(amount: 10000, rollover: true),
            transactions: [],
            referenceDate: date(2026, 6, 15),
            rolloverCarry: .usd(2500)
        )
        let disabled = BudgetProgressCalculator.progress(
            budget: budget(amount: 10000, rollover: false),
            transactions: [],
            referenceDate: date(2026, 6, 15),
            rolloverCarry: .usd(2500)
        )

        #expect(enabled.budgeted == .usd(12500))
        #expect(enabled.rolloverCarry == .usd(2500))
        #expect(disabled.budgeted == .usd(10000))
        #expect(disabled.rolloverCarry == .zeroUSD)
    }

    @Test func rolloverCarryIsTheUnspentRemainderFlooredAtZero() {
        let previous = BudgetPeriodCalculator.previousCycle(for: .monthly, containing: date(2026, 6, 15))
        let underspent = BudgetProgressCalculator.rolloverCarry(
            budget: budget(amount: 10000, rollover: true),
            previousCycleTransactions: [transaction(id: "a", cents: 4000, day: 10, month: 5)],
            previousCycle: previous
        )
        let overspent = BudgetProgressCalculator.rolloverCarry(
            budget: budget(amount: 10000, rollover: true),
            previousCycleTransactions: [transaction(id: "b", cents: 14000, day: 10, month: 5)],
            previousCycle: previous
        )

        #expect(underspent == .usd(6000))
        // A bad month must not compound into the next one as a negative allowance.
        #expect(overspent == .zeroUSD)
    }

    @Test func zeroBudgetWithSpendReadsAsFullyUsed() {
        let progress = BudgetProgressCalculator.progress(
            budget: budget(amount: 0),
            transactions: [transaction(id: "a", cents: 500, day: 5)],
            referenceDate: date(2026, 6, 29)
        )

        #expect(progress.fractionUsed == 1)
        #expect(progress.isOverspent)
    }

    @Test func emptyLedgerIsZeroSpendNotAnError() {
        let progress = BudgetProgressCalculator.progress(
            budget: budget(amount: 10000),
            transactions: [],
            referenceDate: date(2026, 6, 29)
        )

        #expect(progress.spent == .zeroUSD)
        #expect(progress.fractionUsed == 0)
        #expect(progress.pace == .under)
    }
}
