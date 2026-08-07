import Foundation
import Observation

struct CategorySpend: Identifiable, Equatable {
    let id: String
    let name: String
    let total: Money
}

struct PriceChangeAlertRow: Identifiable, Equatable {
    let id: String
    let subscriptionName: String
    let detail: String
    let delta: Money
    let isIncrease: Bool
}

struct TrialEndingAlertRow: Identifiable, Equatable {
    let id: String
    let subscriptionName: String
    let detail: String
}

@MainActor
@Observable
final class InsightsViewModel {
    private let repositories: RepositoryContainer
    private let detectionService: any DetectionServing
    private let refresher: any SubscriptionRefreshing
    private let referenceDateProvider: () -> Date
    private let featureFlags: SiftFeatureFlags

    var isLoading = false
    var isRefreshing = false
    var hasLoaded = false
    var errorMessage: String?
    var potentialSavings = Money.zeroUSD
    var categorySpend: [CategorySpend] = []
    var priceChangeRows: [PriceChangeAlertRow] = []
    var trialEndingRows: [TrialEndingAlertRow] = []

    init(
        repositories: RepositoryContainer,
        detectionService: any DetectionServing,
        refresher: any SubscriptionRefreshing,
        referenceDateProvider: @escaping () -> Date = { Date() },
        featureFlags: SiftFeatureFlags = .launchDefault
    ) {
        self.repositories = repositories
        self.detectionService = detectionService
        self.refresher = refresher
        self.referenceDateProvider = referenceDateProvider
        self.featureFlags = featureFlags
    }

    /// Goals are reached from Insights, mirroring Budgets. Gated so the route stays dark
    /// until the flag is on.
    var showsGoalsEntry: Bool {
        featureFlags.goalsEnabled
    }

    var annualSavings: Money {
        potentialSavings.multiplied(by: 12)
    }

    var isEmpty: Bool {
        hasLoaded
            && potentialSavings == .zeroUSD
            && categorySpend.isEmpty
            && priceChangeRows.isEmpty
            && trialEndingRows.isEmpty
            && errorMessage == nil
    }

    var maxCategorySpend: Money {
        categorySpend.map(\.total).max() ?? .zeroUSD
    }

    func load() async {
        await loadContent(showLoading: !hasLoaded)
    }

    func refresh() async {
        isRefreshing = true
        defer { isRefreshing = false }

        do {
            _ = try await refresher.refresh(referenceDate: referenceDateProvider())
            await loadContent(showLoading: false)
        } catch {
            errorMessage = userFacingMessage(for: error)
        }
    }

    private func loadContent(showLoading: Bool) async {
        if showLoading {
            isLoading = true
        }

        defer {
            isLoading = false
            hasLoaded = true
        }

        do {
            potentialSavings = try repositories.subscriptions.potentialSavings(
                referenceDate: referenceDateProvider(),
                staleAfterDays: 60
            )
            categorySpend = try repositories.subscriptions.byCategory()
                .map {
                    CategorySpend(
                        id: $0.categoryID ?? $0.categoryName,
                        name: $0.categoryName,
                        total: $0.monthlyTotal
                    )
                }
                .filter { $0.total.amountMinor > 0 }
                .sorted { $0.total.amountMinor > $1.total.amountMinor }
            priceChangeRows = try makePriceChangeRows()
            trialEndingRows = try await makeTrialEndingRows()
            errorMessage = nil
        } catch {
            errorMessage = userFacingMessage(for: error)
        }
    }

    private func makePriceChangeRows() throws -> [PriceChangeAlertRow] {
        let subscriptions = try repositories.subscriptions.all()
        let subscriptionsByID = Dictionary(uniqueKeysWithValues: subscriptions.map { ($0.id, $0) })

        return try repositories.priceChanges.all().compactMap { change in
            guard let subscription = subscriptionsByID[change.subscriptionID] else {
                return nil
            }

            let delta = change.newAmount - change.oldAmount
            let absoluteDelta = Money(amountMinor: abs(delta.amountMinor), currency: delta.currency)
            let direction = delta.amountMinor >= 0 ? "increased" : "decreased"

            return PriceChangeAlertRow(
                id: change.id,
                subscriptionName: subscription.name,
                detail: "\(direction) by \(absoluteDelta.formatted()) on \(change.changedAt.formatted(.dateTime.month(.abbreviated).day()))",
                delta: absoluteDelta,
                isIncrease: delta.amountMinor >= 0
            )
        }
    }

    private func makeTrialEndingRows() async throws -> [TrialEndingAlertRow] {
        let detections = try await detectionService.detect()

        return detections
            .filter(\.isTrialEnding)
            .map { detection in
                let date = detection.nextRenewal?.formatted(.dateTime.month(.abbreviated).day()) ?? "soon"
                return TrialEndingAlertRow(
                    id: detection.id,
                    subscriptionName: detection.name,
                    detail: "Trial converts \(date)"
                )
            }
    }

    private func userFacingMessage(for error: Error) -> String {
        if let siftError = error as? SiftError {
            return siftError.errorDescription ?? "Something went wrong."
        }

        return error.localizedDescription
    }
}
