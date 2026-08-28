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
            events: [event(id: "rent", daysFromToday: 5, amount: 30000, direction: .debit)],
            from: today
        )
        #expect(forecast.endingBalance == .usd(70000))
        #expect(forecast.lowestPoint.projectedBalance == .usd(70000))
    }

    @Test func incomeAndBillNetCorrectly() {
        let forecast = CashFlowForecaster.project(
            startingBalance: .usd(50000),
            events: [
                event(id: "rent", daysFromToday: 3, amount: 30000, direction: .debit, kind: .billCharge),
                event(id: "pay", daysFromToday: 14, amount: 200_000, direction: .credit, kind: .income),
            ],
            from: today
        )
        #expect(forecast.endingBalance == .usd(50000 - 30000 + 200_000))
        #expect(forecast.lowestPoint.projectedBalance == .usd(20000))
    }

    @Test func sameDayEventsCollapseToOneStep() {
        let forecast = CashFlowForecaster.project(
            startingBalance: .usd(100_000),
            events: [
                event(id: "a", daysFromToday: 5, amount: 10000, direction: .debit),
                event(id: "b", daysFromToday: 5, amount: 5000, direction: .debit),
            ],
            from: today
        )
        // start + one collapsed day + flat end
        #expect(forecast.points.count == 3)
        #expect(forecast.endingBalance == .usd(85000))
    }

    @Test func eventLaterOnTheStartDayDoesNotRepeatOrRewindThePoint() {
        // `today` is mid-morning UTC, so this event's start-of-day precedes the start point.
        // Points are identified by date, so a naive step would both duplicate an id and
        // walk the projection backwards in time.
        let laterToday = CashFlowEvent(
            id: "sameDay",
            date: today.addingTimeInterval(4 * 3600),
            label: "sameDay",
            amount: .usd(2500),
            direction: .debit,
            kind: .subscriptionCharge
        )
        let forecast = CashFlowForecaster.project(startingBalance: .usd(100_000), events: [laterToday], from: today)

        let dates = forecast.points.map(\.date)
        #expect(dates == dates.sorted())
        #expect(Set(dates).count == dates.count)
        #expect(forecast.endingBalance == .usd(97500))
    }

    @Test func pastAndBeyondWindowEventsAreExcluded() {
        let forecast = CashFlowForecaster.project(
            startingBalance: .usd(100_000),
            events: [
                event(id: "past", daysFromToday: -3, amount: 40000, direction: .debit),
                event(id: "beyond", daysFromToday: 45, amount: 40000, direction: .debit),
                event(id: "inside", daysFromToday: 10, amount: 20000, direction: .debit),
            ],
            from: today,
            windowDays: 30
        )
        #expect(forecast.events.map(\.id) == ["inside"])
        #expect(forecast.endingBalance == .usd(80000))
    }
}
