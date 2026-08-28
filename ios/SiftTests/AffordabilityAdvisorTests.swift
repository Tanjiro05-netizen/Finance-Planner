import Foundation
@testable import Sift
import Testing

struct AffordabilityAdvisorTests {
    private let today = Date(timeIntervalSince1970: 1_720_000_000)

    private func safeToSpend(netAvailable: Int, usedFallback: Bool = false) -> SafeToSpendOutcome {
        .available(SafeToSpendResult(
            dailyAmount: .usd(netAvailable / 10),
            netAvailable: .usd(netAvailable),
            horizonEndDate: today.addingTimeInterval(10 * 86400),
            daysRemaining: 10,
            isOverspent: false,
            usedFallbackWindow: usedFallback,
            recentDailySpend: .usd(2000)
        ))
    }

    private func progress(budgeted: Int, spent: Int) -> BudgetProgress {
        let cycle = BudgetPeriodCalculator.cycle(for: .monthly, containing: today)
        let remaining = Money.usd(budgeted - spent)
        return BudgetProgress(
            baseAmount: .usd(budgeted),
            rolloverCarry: .zeroUSD,
            budgeted: .usd(budgeted),
            spent: .usd(spent),
            remaining: remaining,
            fractionUsed: budgeted > 0 ? min(Double(spent) / Double(budgeted), 1) : 1,
            isOverspent: remaining.amountMinor < 0,
            projectedSpend: .usd(spent),
            pace: remaining.amountMinor < 0 ? .over : .onTrack,
            cycle: cycle
        )
    }

    @Test func comfortableWhenPurchaseLeavesPlentyOfRoom() {
        let assessment = AffordabilityAdvisor.assess(amount: .usd(2000), safeToSpend: safeToSpend(netAvailable: 50000))

        #expect(assessment.verdict == .comfortable)
        #expect(assessment.remainingAfter == .usd(48000))
        #expect(assessment.reasons.isEmpty == false)
    }

    @Test func tightWhenPurchaseLeavesOnlyAThinRemainder() {
        // Leaves 10% of the pool, under the 20% tight threshold.
        let assessment = AffordabilityAdvisor.assess(amount: .usd(45000), safeToSpend: safeToSpend(netAvailable: 50000))

        #expect(assessment.verdict == .tight)
        #expect(assessment.reasons.contains { $0.id == "thin-pool" })
    }

    @Test func notAdvisableWhenPurchaseExceedsThePool() {
        let assessment = AffordabilityAdvisor.assess(amount: .usd(60000), safeToSpend: safeToSpend(netAvailable: 50000))

        #expect(assessment.verdict == .notAdvisable)
        #expect(assessment.remainingAfter == .usd(-10000))
        #expect(assessment.reasons.contains { $0.id == "over-pool" })
    }

    @Test func withoutBalanceTheVerdictIsTightAndSaysWhy() {
        let assessment = AffordabilityAdvisor.assess(amount: .usd(2000), safeToSpend: .unavailable(.noBalanceData))

        #expect(assessment.verdict == .tight)
        #expect(assessment.remainingAfter == nil)
        #expect(assessment.reasons.contains { $0.id == "no-balance" })
    }

    @Test func budgetRemainderIsReportedAlongsideTheCashVerdict() {
        let assessment = AffordabilityAdvisor.assess(
            amount: .usd(2000),
            safeToSpend: safeToSpend(netAvailable: 50000),
            budgetProgress: progress(budgeted: 10000, spent: 3000)
        )

        #expect(assessment.verdict == .comfortable)
        #expect(assessment.budgetRemainingAfter == .usd(5000))
        #expect(assessment.reasons.contains { $0.id == "budget-ok" })
    }

    @Test func breachingTheBudgetDowngradesAComfortableCashVerdict() {
        let assessment = AffordabilityAdvisor.assess(
            amount: .usd(9000),
            safeToSpend: safeToSpend(netAvailable: 500_000),
            budgetProgress: progress(budgeted: 10000, spent: 3000)
        )

        #expect(assessment.verdict == .tight)
        #expect(assessment.budgetRemainingAfter == .usd(-2000))
        #expect(assessment.reasons.contains { $0.id == "budget-over" })
    }

    @Test func alreadyOverspentBudgetIsNotAdvisableEvenWithCashAvailable() {
        let assessment = AffordabilityAdvisor.assess(
            amount: .usd(500),
            safeToSpend: safeToSpend(netAvailable: 500_000),
            budgetProgress: progress(budgeted: 10000, spent: 12000)
        )

        #expect(assessment.verdict == .notAdvisable)
        #expect(assessment.reasons.contains { $0.id == "budget-already-over" })
    }

    @Test func theWorstSignalWinsRatherThanTheLast() {
        // Cash says not advisable, budget says fine — the answer must stay not advisable.
        let assessment = AffordabilityAdvisor.assess(
            amount: .usd(60000),
            safeToSpend: safeToSpend(netAvailable: 50000),
            budgetProgress: progress(budgeted: 100_000, spent: 0)
        )

        #expect(assessment.verdict == .notAdvisable)
    }

    @Test func horizonPhraseReflectsWhetherIncomeWasDetected() {
        let withIncome = AffordabilityAdvisor.assess(amount: .usd(100), safeToSpend: safeToSpend(netAvailable: 50000))
        let fallback = AffordabilityAdvisor.assess(
            amount: .usd(100),
            safeToSpend: safeToSpend(netAvailable: 50000, usedFallback: true)
        )

        #expect(withIncome.reasons.contains { $0.text.contains("next income") })
        #expect(fallback.reasons.contains { $0.text.contains("end of the month") })
    }
}
