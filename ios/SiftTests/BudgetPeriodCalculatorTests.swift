import Foundation
@testable import Sift
import Testing

struct BudgetPeriodCalculatorTests {
    private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 12) -> Date {
        Calendar.utc.date(from: DateComponents(year: year, month: month, day: day, hour: hour)) ?? Date()
    }

    @Test func monthlyCycleSpansTheCalendarMonth() {
        let cycle = BudgetPeriodCalculator.cycle(for: .monthly, containing: date(2026, 6, 15))

        #expect(cycle.start == date(2026, 6, 1, hour: 0))
        #expect(cycle.end == date(2026, 7, 1, hour: 0))
        #expect(cycle.totalDays == 30)
    }

    @Test func elapsedDaysCountsTheFirstDayAsOne() {
        // Day one must not read as zero elapsed, or the pace baseline is zero and every
        // budget looks overspent the moment a cycle starts.
        let cycle = BudgetPeriodCalculator.cycle(for: .monthly, containing: date(2026, 6, 1))

        #expect(cycle.elapsedDays == 1)
        #expect(cycle.fractionElapsed > 0)
    }

    @Test func elapsedDaysIsClampedToTheCycleLength() {
        let cycle = BudgetPeriodCalculator.cycle(for: .monthly, containing: date(2026, 6, 30, hour: 23))

        #expect(cycle.elapsedDays == cycle.totalDays)
        #expect(cycle.fractionElapsed == 1)
    }

    @Test func weeklyCycleIsSevenDays() {
        let cycle = BudgetPeriodCalculator.cycle(for: .weekly, containing: date(2026, 6, 17))

        #expect(cycle.totalDays == 7)
        #expect(cycle.interval.contains(date(2026, 6, 17)))
    }

    @Test func previousMonthlyCycleIsTheMonthBefore() {
        let previous = BudgetPeriodCalculator.previousCycle(for: .monthly, containing: date(2026, 6, 15))

        #expect(previous.start == date(2026, 5, 1, hour: 0))
        #expect(previous.end == date(2026, 6, 1, hour: 0))
    }

    @Test func previousCycleDoesNotOverlapTheCurrentOne() {
        let current = BudgetPeriodCalculator.cycle(for: .weekly, containing: date(2026, 6, 17))
        let previous = BudgetPeriodCalculator.previousCycle(for: .weekly, containing: date(2026, 6, 17))

        #expect(previous.end <= current.start)
        #expect(previous.totalDays == 7)
    }

    @Test func februaryCycleTracksTheShorterMonth() {
        let cycle = BudgetPeriodCalculator.cycle(for: .monthly, containing: date(2026, 2, 10))

        #expect(cycle.totalDays == 28)
    }
}
