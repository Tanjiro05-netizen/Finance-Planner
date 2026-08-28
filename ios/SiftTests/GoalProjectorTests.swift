import Foundation
@testable import Sift
import Testing

struct GoalProjectorTests {
    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        Calendar.utc.date(from: DateComponents(year: year, month: month, day: day, hour: 12)) ?? Date()
    }

    private func goal(
        target: Int = 300_000,
        targetDate: Date? = nil,
        monthly: Int? = nil
    ) -> Goal {
        Goal(
            id: "goal-1",
            userID: SeedData.defaultUserID,
            name: "Emergency fund",
            targetAmount: .usd(target),
            targetDate: targetDate,
            monthlyContribution: monthly.map { Money.usd($0) },
            createdAt: date(2026, 1, 1)
        )
    }

    private func contribution(_ cents: Int, day: Int = 1, month: Int = 1) -> GoalContribution {
        GoalContribution(
            id: "c-\(month)-\(day)-\(cents)",
            userID: SeedData.defaultUserID,
            goalID: "goal-1",
            amount: .usd(cents),
            date: date(2026, month, day)
        )
    }

    @Test func savedIsTheSignedSumSoWithdrawalsReduceProgress() {
        let saved = GoalProjector.saved(from: [
            contribution(25000, month: 1),
            contribution(25000, month: 2),
            contribution(-10000, month: 3),
        ])

        #expect(saved == .usd(40000))
    }

    @Test func savedIsZeroForNoContributions() {
        #expect(GoalProjector.saved(from: []) == .zeroUSD)
    }

    @Test func monthsRemainingIncludesTheCurrentMonth() {
        // June to December inclusive is seven months, not six. Excluding the current month
        // would double the final month's required contribution.
        let months = GoalProjector.monthsRemaining(to: date(2026, 12, 1), from: date(2026, 6, 29))

        #expect(months == 7)
    }

    @Test func monthsRemainingIsAtLeastOneWithinTheTargetMonth() {
        let months = GoalProjector.monthsRemaining(to: date(2026, 6, 30), from: date(2026, 6, 1))

        #expect(months == 1)
    }

    @Test func requiredMonthlyContributionSplitsTheGapEvenly() {
        let required = GoalProjector.requiredMonthlyContribution(
            target: .usd(300_000),
            saved: .usd(125_000),
            monthsRemaining: 7
        )

        #expect(required == .usd(25000))
    }

    @Test func requiredMonthlyContributionIsZeroOnceTheTargetIsMet() {
        let required = GoalProjector.requiredMonthlyContribution(
            target: .usd(100_000),
            saved: .usd(120_000),
            monthsRemaining: 3
        )

        #expect(required == .zeroUSD)
    }

    @Test func projectedCompletionRoundsPartialMonthsUp() throws {
        let completion = try #require(GoalProjector.projectedCompletion(
            target: .usd(100_000),
            saved: .usd(0),
            monthlyContribution: .usd(30000),
            from: date(2026, 1, 1)
        ))

        // 100000 / 30000 = 3.33 months, so it completes in the fourth.
        #expect(completion == date(2026, 5, 1))
    }

    @Test func projectedCompletionIsNilWithoutAContribution() {
        // Zero contribution never converges; nil is honest where a number would be infinity.
        #expect(GoalProjector.projectedCompletion(
            target: .usd(100_000),
            saved: .usd(0),
            monthlyContribution: .zeroUSD,
            from: date(2026, 1, 1)
        ) == nil)
    }

    @Test func reachedWhenSavedMeetsTheTarget() {
        let outcome = GoalProjector.outcome(
            goal: goal(target: 100_000, targetDate: date(2026, 12, 1), monthly: 25000),
            contributions: [contribution(110_000)],
            referenceDate: date(2026, 6, 29)
        )

        #expect(outcome == .reached(saved: .usd(110_000), surplus: .usd(10000)))
        #expect(outcome.isReached)
    }

    @Test func overdueWhenTheTargetDateHasPassed() {
        // The genuine gap in every app researched: a naive (target - saved) / months
        // divides by zero or goes negative here.
        let outcome = GoalProjector.outcome(
            goal: goal(target: 100_000, targetDate: date(2026, 3, 1), monthly: 25000),
            contributions: [contribution(40000)],
            referenceDate: date(2026, 6, 29)
        )

        #expect(outcome == .overdue(saved: .usd(40000), remaining: .usd(60000), monthsPast: 3))
    }

    @Test func insufficientDataWithNeitherDateNorContribution() {
        let outcome = GoalProjector.outcome(
            goal: goal(target: 100_000),
            contributions: [contribution(10000)],
            referenceDate: date(2026, 6, 29)
        )

        #expect(outcome == .insufficientData(
            saved: .usd(10000),
            remaining: .usd(90000),
            missing: .targetDateAndContribution
        ))
    }

    @Test func insufficientDataWithADateButNoContribution() {
        let outcome = GoalProjector.outcome(
            goal: goal(target: 100_000, targetDate: date(2026, 12, 1)),
            contributions: [contribution(10000)],
            referenceDate: date(2026, 6, 29)
        )

        #expect(outcome == .insufficientData(
            saved: .usd(10000),
            remaining: .usd(90000),
            missing: .targetDateOrContribution
        ))
    }

    @Test func zeroContributionIsTreatedAsNoContribution() {
        let outcome = GoalProjector.outcome(
            goal: goal(target: 100_000, targetDate: date(2026, 12, 1), monthly: 0),
            contributions: [],
            referenceDate: date(2026, 6, 29)
        )

        if case .insufficientData = outcome {
            // expected
        } else {
            Issue.record("Expected insufficientData for a zero contribution, got \(outcome)")
        }
    }

    @Test func contributionWithoutADateStillProjectsCompletion() throws {
        let outcome = GoalProjector.outcome(
            goal: goal(target: 100_000, monthly: 25000),
            contributions: [contribution(50000)],
            referenceDate: date(2026, 6, 29)
        )

        guard case let .onTrack(saved, remaining, requiredMonthly, completion) = outcome else {
            Issue.record("Expected onTrack, got \(outcome)")
            return
        }

        #expect(saved == .usd(50000))
        #expect(remaining == .usd(50000))
        #expect(requiredMonthly == .usd(25000))
        _ = try #require(completion)
    }

    @Test func behindWhenThePlannedContributionFallsShort() {
        // $1750 to go over 7 months needs $250/mo; $150 leaves a $100 monthly shortfall.
        let outcome = GoalProjector.outcome(
            goal: goal(target: 300_000, targetDate: date(2026, 12, 1), monthly: 15000),
            contributions: [contribution(125_000)],
            referenceDate: date(2026, 6, 29)
        )

        #expect(outcome == .behind(
            saved: .usd(125_000),
            remaining: .usd(175_000),
            requiredMonthly: .usd(25000),
            shortfallPerMonth: .usd(10000)
        ))
    }

    @Test func aheadWhenThePlannedContributionExceedsWhatIsNeeded() {
        let outcome = GoalProjector.outcome(
            goal: goal(target: 300_000, targetDate: date(2026, 12, 1), monthly: 40000),
            contributions: [contribution(125_000)],
            referenceDate: date(2026, 6, 29)
        )

        #expect(outcome == .ahead(
            saved: .usd(125_000),
            remaining: .usd(175_000),
            requiredMonthly: .usd(25000),
            surplusPerMonth: .usd(15000)
        ))
    }

    @Test func onTrackWhenPlannedExactlyMatchesRequired() {
        let outcome = GoalProjector.outcome(
            goal: goal(target: 300_000, targetDate: date(2026, 12, 1), monthly: 25000),
            contributions: [contribution(125_000)],
            referenceDate: date(2026, 6, 29)
        )

        if case .onTrack = outcome {
            // expected
        } else {
            Issue.record("Expected onTrack, got \(outcome)")
        }
    }

    @Test func aWithdrawalCanPushAnOnTrackGoalBehind() {
        let contributions = [contribution(125_000, month: 1), contribution(-50000, month: 5)]

        let outcome = GoalProjector.outcome(
            goal: goal(target: 300_000, targetDate: date(2026, 12, 1), monthly: 25000),
            contributions: contributions,
            referenceDate: date(2026, 6, 29)
        )

        // $750 saved, $2250 to go over 7 months is ~$321/mo against a $250 plan.
        guard case let .behind(saved, _, _, shortfall) = outcome else {
            Issue.record("Expected behind after the withdrawal, got \(outcome)")
            return
        }

        #expect(saved == .usd(75000))
        #expect(shortfall.amountMinor > 0)
    }

    @Test func fractionCompleteIsClampedAndHandlesAZeroTarget() {
        #expect(GoalProjector.fractionComplete(target: .usd(10000), saved: .usd(2500)) == 0.25)
        #expect(GoalProjector.fractionComplete(target: .usd(10000), saved: .usd(20000)) == 1)
        #expect(GoalProjector.fractionComplete(target: .usd(10000), saved: .usd(-500)) == 0)
        #expect(GoalProjector.fractionComplete(target: .zeroUSD, saved: .usd(100)) == 1)
        #expect(GoalProjector.fractionComplete(target: .zeroUSD, saved: .zeroUSD) == 0)
    }
}
