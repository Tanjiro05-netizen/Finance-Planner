import Foundation
@testable import Sift
import Testing

struct CashFlowForecasterTests {
    private let today = Date(timeIntervalSince1970: 1_720_000_000)

    private func event(
        id: String,
        daysFromToday: Int,
        amount: Int,
        direction: TransactionDirection,
        kind: CashFlowEventKind = .subscriptionCharge
    ) -> CashFlowEvent {
        CashFlowEvent(
            id: id,
            date: today.addingTimeInterval(TimeInterval(daysFromToday * 86400)),
            label: id,
            amount: .usd(amount),
            direction: direction,
            kind: kind
        )
    }

    @Test func emptyWindowKeepsBalanceFlat() {
        let forecast = CashFlowForecaster.project(startingBalance: .usd(100_000), events: [], from: today)
        #expect(forecast.startingBalance == .usd(100_000))
        #expect(forecast.endingBalance == .usd(100_000))
        #expect(forecast.points.count == 2)
        #expect(forecast.points.first?.projectedBalance == .usd(100_000))
        #expect(forecast.points.last?.projectedBalance == .usd(100_000))
    }

    @Test func debitLowersBalanceAndSetsLowestPoint() {
        let forecast = CashFlowForecaster.project(
            startingBalance: .usd(100_000),
            events: [event(id: "rent", daysFromToday: 5, amount: 30_000, direction: .debit)],
            from: today
        )
        #expect(forecast.endingBalance == .usd(70_000))
        #expect(forecast.lowestPoint.projectedBalance == .usd(70_000))
    }

    @Test func incomeAndBillNetCorrectly() {
        let forecast = CashFlowForecaster.project(
            startingBalance: .usd(50_000),
            events: [
                event(id: "rent", daysFromToday: 3, amount: 30_000, direction: .debit, kind: .billCharge),
                event(id: "pay", daysFromToday: 14, amount: 200_000, direction: .credit, kind: .income),
            ],
            from: today
        )
        #expect(forecast.endingBalance == .usd(50_000 - 30_000 + 200_000))
        #expect(forecast.lowestPoint.projectedBalance == .usd(20_000))
    }

    @Test func sameDayEventsCollapseToOneStep() {
        let forecast = CashFlowForecaster.project(
            startingBalance: .usd(100_000),
            events: [
                event(id: "a", daysFromToday: 5, amount: 10_000, direction: .debit),
                event(id: "b", daysFromToday: 5, amount: 5_000, direction: .debit),
            ],
            from: today
        )
        // start + one collapsed day + flat end
        #expect(forecast.points.count == 3)
        #expect(forecast.endingBalance == .usd(85_000))
    }

    @Test func pastAndBeyondWindowEventsAreExcluded() {
        let forecast = CashFlowForecaster.project(
            startingBalance: .usd(100_000),
            events: [
                event(id: "past", daysFromToday: -3, amount: 40_000, direction: .debit),
                event(id: "beyond", daysFromToday: 45, amount: 40_000, direction: .debit),
                event(id: "inside", daysFromToday: 10, amount: 20_000, direction: .debit),
            ],
            from: today,
            windowDays: 30
        )
        #expect(forecast.events.map(\.id) == ["inside"])
        #expect(forecast.endingBalance == .usd(80_000))
    }
}
