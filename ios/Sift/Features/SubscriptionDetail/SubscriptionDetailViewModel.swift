import Foundation
import Observation

struct ChargeHistoryPoint: Identifiable, Equatable {
    let id: String
    let amount: Money
    let date: Date
}

@MainActor
@Observable
final class SubscriptionDetailViewModel {
    private let repositories: RepositoryContainer
    private let refresher: any SubscriptionRefreshing
    private let referenceDateProvider: () -> Date
    let subscriptionID: String

    var isLoading = false
    var isRefreshing = false
    var hasLoaded = false
    var errorMessage: String?
    var subscription: Subscription?
    var chargeHistory: [ChargeHistoryPoint] = []
    var paymentMeta = "Payment method unavailable"

    init(
        subscriptionID: String,
        repositories: RepositoryContainer,
        refresher: any SubscriptionRefreshing = NoopSubscriptionRefreshService(),
        referenceDateProvider: @escaping () -> Date = { Date() }
    ) {
        self.subscriptionID = subscriptionID
        self.repositories = repositories
        self.refresher = refresher
        self.referenceDateProvider = referenceDateProvider
    }

    var isEmpty: Bool {
        hasLoaded && subscription == nil && errorMessage == nil
    }

    var title: String {
        subscription?.name ?? "Subscription"
    }

    var monthlyCost: Money {
        subscription?.monthlyEquivalent ?? .zeroUSD
    }

    var annualCost: Money {
        monthlyCost.multiplied(by: 12)
    }

    var nextChargeText: String {
        guard let nextRenewal = subscription?.nextRenewal else {
            return "None"
        }

        return nextRenewal.formatted(.dateTime.month(.abbreviated).day())
    }

    var lastOpenedText: String {
        guard let lastUsed = subscription?.lastUsed else {
            return "Not seen"
        }

        return lastUsed.formatted(.dateTime.month(.abbreviated).day())
    }

    var cadenceText: String {
        subscription?.cadence.displayName ?? "Unknown"
    }

    var maxChargeAmount: Money {
        chargeHistory.map(\.amount).max() ?? .zeroUSD
    }

    func load() {
        isLoading = !hasLoaded
        defer {
            isLoading = false
            hasLoaded = true
        }

        do {
            guard let subscription = try repositories.subscriptions.subscription(id: subscriptionID) else {
                subscription = nil
                chargeHistory = []
                paymentMeta = "Payment method unavailable"
                errorMessage = nil
                return
            }

            self.subscription = subscription
            chargeHistory = try makeChargeHistory(for: subscription)
            paymentMeta = try makePaymentMeta(for: subscription)
            errorMessage = nil
        } catch {
            errorMessage = userFacingMessage(for: error)
        }
    }

    func refresh() async {
        isRefreshing = true
        defer { isRefreshing = false }

        do {
            _ = try await refresher.refresh(referenceDate: referenceDateProvider())
            load()
        } catch {
            errorMessage = userFacingMessage(for: error)
        }
    }

    private func makeChargeHistory(for subscription: Subscription) throws -> [ChargeHistoryPoint] {
        try repositories.transactions.all()
            .filter { $0.merchantKey == subscription.merchantKey }
            .sorted { $0.date < $1.date }
            .suffix(8)
            .map {
                ChargeHistoryPoint(
                    id: $0.id,
                    amount: $0.amount,
                    date: $0.date
                )
            }
    }

    private func makePaymentMeta(for subscription: Subscription) throws -> String {
        let latestTransaction = try repositories.transactions.all()
            .filter { $0.merchantKey == subscription.merchantKey }
            .max { $0.date < $1.date }

        guard let accountID = latestTransaction?.accountID else {
            return "\(subscription.amount.formatted()) · \(subscription.cadence.displayName)"
        }

        let account = try repositories.accounts.all()
            .first { $0.id == accountID }

        guard let account else {
            return "\(subscription.amount.formatted()) · \(subscription.cadence.displayName)"
        }

        return "\(account.institutionName) · \(account.mask)"
    }

    private func userFacingMessage(for error: Error) -> String {
        if let siftError = error as? SiftError {
            return siftError.errorDescription ?? "Something went wrong."
        }

        return error.localizedDescription
    }
}
