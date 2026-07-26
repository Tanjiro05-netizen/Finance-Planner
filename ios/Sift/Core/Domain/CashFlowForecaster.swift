import Foundation

enum CashFlowEventKind: Equatable {
    case subscriptionCharge
    case billCharge
    case income
}

/// A single expected money movement on a future date.
struct CashFlowEvent: Identifiable, Equatable {
    let id: String
    let date: Date
    let label: String
    /// Unsigned magnitude; sign is carried by `direction`, matching `Money`'s convention.
    let amount: Money
    let direction: TransactionDirection
    let kind: CashFlowEventKind
}

/// The projected balance at a point in time along the forecast.
struct CashFlowProjectionPoint: Identifiable, Equatable {
    var id: Date {
        date
    }

    let date: Date
    let projectedBalance: Money
}

struct CashFlowForecast: Equatable {
    let points: [CashFlowProjectionPoint]
    let events: [CashFlowEvent]
    let startingBalance: Money
    let endingBalance: Money
    let lowestPoint: CashFlowProjectionPoint
}

/// Walks a starting balance forward through known upcoming charges and deposits to project
/// the running balance across a window. A step function — the balance only moves on the
/// discrete days money actually comes in or out, which is what the chart renders.
enum CashFlowForecaster {
    static let defaultWindowDays = 30

    static func project(
        startingBalance: Money,
        events: [CashFlowEvent],
        from startDate: Date,
        windowDays: Int = defaultWindowDays,
        calendar: Calendar = .utc
    ) -> CashFlowForecast {
        let windowEnd = calendar.date(byAdding: .day, value: windowDays, to: startDate) ?? startDate

        // Only future events inside the window affect the projection; occurrences that
        // fall between an item's last charge and today have already happened.
        let inWindow = events
            .filter { $0.date > startDate && $0.date <= windowEnd }
            .sorted { $0.date < $1.date }

        let startPoint = CashFlowProjectionPoint(date: startDate, projectedBalance: startingBalance)
        var points: [CashFlowProjectionPoint] = [startPoint]

        // Collapse events that land on the same calendar day into a single balance step.
        let byDay = Dictionary(grouping: inWindow) { calendar.startOfDay(for: $0.date) }
        var runningBalance = startingBalance

        for day in byDay.keys.sorted() {
            let dayEvents = byDay[day] ?? []
            for event in dayEvents {
                switch event.direction {
                case .credit:
                    runningBalance = runningBalance + event.amount
                case .debit:
                    runningBalance = runningBalance - event.amount
                }
            }
            points.append(CashFlowProjectionPoint(date: day, projectedBalance: runningBalance))
        }

        // Hold the final balance flat to the end of the window so the line spans it.
        if let last = points.last, last.date < windowEnd {
            points.append(CashFlowProjectionPoint(date: windowEnd, projectedBalance: runningBalance))
        }

        let lowest = points.min { $0.projectedBalance < $1.projectedBalance } ?? startPoint

        return CashFlowForecast(
            points: points,
            events: inWindow,
            startingBalance: startingBalance,
            endingBalance: runningBalance,
            lowestPoint: lowest
        )
    }
}
