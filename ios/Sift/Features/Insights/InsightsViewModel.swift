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
    var monthlySpend: [MonthlySpendPoint] = []
    var spendComparison: SpendComparison?
    var topMovers: [CategoryMover] = []

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

    /// Deliberately subscription-derived only. The spending reports have their own
    /// `showsSpendReports` gate, and folding them in here would change what the existing
    /// "no savings surfaced yet" empty state means.
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

    /// Reports only earn their space once there's real spend behind them — three empty
    /// charts is worse than no charts.
    var showsSpendReports: Bool {
        monthlySpend.contains { $0.total.amountMinor > 0 }
    }

    var maxMonthlySpend: Money {
        monthlySpend.map(\.total).max() ?? .zeroUSD
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
            try loadSpendReports()
            errorMessage = nil
        } catch {
            errorMessage = userFacingMessage(for: error)
        }
    }

    /// One ledger read covering the widest window the reports need, then every aggregation
    /// happens in memory — the same shape as `BudgetsViewModel.buildRows()`, and the reason
    /// six months of trend costs one query rather than six.
    private func loadSpendReports() throws {
        let today = referenceDateProvider()
        let calendar = Calendar.utc
        let currentMonth = calendar.dateInterval(of: .month, for: today)
            ?? DateInterval(start: today, end: today)
        let windowStart = calendar.date(
            byAdding: .month,
            value: -(SpendReportBuilder.defaultMonths - 1),
            to: currentMonth.start
        ) ?? currentMonth.start

        let transactions = try repositories.transactions.transactions(from: windowStart, to: currentMonth.end)

        // Names come from the category store rather than `TransactionRepository.byCategory`,
        // whose mock hands back the raw id as the display name.
        let categoryNames = try Dictionary(
            repositories.categories.all().map { ($0.id, $0.name) },
            uniquingKeysWith: { first, _ in first }
        )

        monthlySpend = SpendReportBuilder.monthlyTotals(
            transactions: transactions,
            endingAt: today,
            calendar: calendar
        )

        let comparison = SpendReportBuilder.comparison(
            transactions: transactions,
            referenceDate: today,
            categoryNames: categoryNames,
            calendar: calendar
        )
        spendComparison = comparison
        topMovers = SpendReportBuilder.topMovers(comparison: comparison)
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
