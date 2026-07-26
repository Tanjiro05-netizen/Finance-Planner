import Foundation
import Observation

@MainActor
@Observable
final class CashFlowForecastViewModel {
    private let repositories: RepositoryContainer
    private let referenceDateProvider: () -> Date
    private let windowDays: Int

    var isLoading = false
    var hasLoaded = false
    var errorMessage: String?
    var forecast: CashFlowForecast?
    /// True when no account balance is available to project from.
    var isUnavailable = false

    init(
        repositories: RepositoryContainer,
        windowDays: Int = CashFlowForecaster.defaultWindowDays,
        referenceDateProvider: @escaping () -> Date = { Date() }
    ) {
        self.repositories = repositories
        self.windowDays = windowDays
        self.referenceDateProvider = referenceDateProvider
    }

    var isEmpty: Bool {
        hasLoaded && !isUnavailable && (forecast?.events.isEmpty ?? true)
    }

    func load() {
        if !hasLoaded {
            isLoading = true
        }
        defer {
            isLoading = false
            hasLoaded = true
        }

        do {
            guard let startingBalance = try repositories.accounts.totalBalance() else {
                isUnavailable = true
                forecast = nil
                errorMessage = nil
                return
            }

            isUnavailable = false
            let today = referenceDateProvider()
            let windowEnd = Calendar.utc.date(byAdding: .day, value: windowDays, to: today) ?? today
            let events = try buildEvents(through: windowEnd)
            forecast = CashFlowForecaster.project(
                startingBalance: startingBalance,
                events: events,
                from: today,
                windowDays: windowDays
            )
            errorMessage = nil
        } catch {
            errorMessage = userFacingMessage(for: error)
        }
    }

    private func buildEvents(through windowEnd: Date) throws -> [CashFlowEvent] {
        var events: [CashFlowEvent] = []

        for subscription in try repositories.subscriptions.all() where subscription.status != .cancelled {
            events += subscription.cadence
                .occurrences(after: subscription.lastCharge, through: windowEnd)
                .map { date in
                    CashFlowEvent(
                        id: "\(subscription.id)-\(date.timeIntervalSince1970)",
                        date: date,
                        label: subscription.name,
                        amount: subscription.amount,
                        direction: .debit,
                        kind: .subscriptionCharge
                    )
                }
        }

        for bill in try repositories.bills.all() where bill.status == .active {
            events += bill.cadence
                .occurrences(after: bill.lastCharge, through: windowEnd)
                .map { date in
                    CashFlowEvent(
                        id: "\(bill.id)-\(date.timeIntervalSince1970)",
                        date: date,
                        label: bill.name,
                        amount: bill.amount,
                        direction: .debit,
                        kind: .billCharge
                    )
                }
        }

        for income in try repositories.recurringIncome.all() where income.status == .active {
            events += income.cadence
                .occurrences(after: income.lastReceived, through: windowEnd)
                .map { date in
                    CashFlowEvent(
                        id: "\(income.id)-\(date.timeIntervalSince1970)",
                        date: date,
                        label: income.sourceName,
                        amount: income.amount,
                        direction: .credit,
                        kind: .income
                    )
                }
        }

        return events
    }

    private func userFacingMessage(for error: Error) -> String {
        if let siftError = error as? SiftError {
            return siftError.errorDescription ?? "Something went wrong."
        }
        return error.localizedDescription
    }
}
