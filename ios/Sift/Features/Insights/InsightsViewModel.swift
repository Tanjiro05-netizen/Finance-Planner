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
    private let narrator: any InsightNarrating

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
    var insightNotes: [InsightNote] = []
    var isNarrating = false
    /// Separate from `errorMessage`: narration failing must never take the deterministic
    /// figures down with it.
    var narrationMessage: String?

    init(
        repositories: RepositoryContainer,
        detectionService: any DetectionServing,
        refresher: any SubscriptionRefreshing,
        referenceDateProvider: @escaping () -> Date = { Date() },
        featureFlags: SiftFeatureFlags = .launchDefault,
        narrator: any InsightNarrating = MockInsightNarrator()
    ) {
        self.repositories = repositories
        self.detectionService = detectionService
        self.refresher = refresher
        self.referenceDateProvider = referenceDateProvider
        self.featureFlags = featureFlags
        self.narrator = narrator
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

    /// Gated on the flag *and* on the model actually being usable. On CI, in the Simulator
    /// without Apple Intelligence, and on ineligible hardware this is false, and Insights
    /// renders exactly as it did before Phase 5.
    var showsNarration: Bool {
        featureFlags.insightNarrationEnabled && narrator.availability().isAvailable
    }

    /// Shown in place of the notes when the flag is on but the model can't run — this is an
    /// ordinary state, not an error.
    var narrationUnavailableMessage: String? {
        guard featureFlags.insightNarrationEnabled else {
            return nil
        }

        return narrator.availability().unavailableMessage
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

    /// Builds the fact sheet and asks the narrator to phrase it.
    ///
    /// Kept out of `loadContent` and awaited separately so the deterministic figures render
    /// immediately: generation takes seconds, and the numbers should never wait on prose.
    func narrateInsights() async {
        guard showsNarration, !isNarrating else {
            return
        }

        isNarrating = true
        defer { isNarrating = false }

        let facts: InsightFacts
        do {
            facts = try buildFacts()
        } catch {
            narrationMessage = InsightNarrationFailure.unknown.message
            return
        }

        guard !facts.isEmpty else {
            insightNotes = []
            narrationMessage = nil
            return
        }

        do {
            insightNotes = try await narrator.narrate(facts: facts)
            narrationMessage = nil
        } catch let failure as InsightNarrationFailure {
            insightNotes = []
            narrationMessage = failure.message
        } catch {
            insightNotes = []
            narrationMessage = InsightNarrationFailure.unknown.message
        }
    }

    /// Assembles aggregates the deterministic layer already computed. Nothing here reads a
    /// merchant name or an individual charge — see `InsightFacts`.
    private func buildFacts() throws -> InsightFacts {
        let today = referenceDateProvider()

        var safeToSpend: SafeToSpendResult?
        if case let .available(result) = try SafeToSpendProvider.outcome(repositories: repositories, today: today) {
            safeToSpend = result
        }

        // Bound before the call rather than inlined: swiftformat's `hoistTry` requires `try`
        // at the start of an expression, not buried in an argument.
        let budgets = try budgetFacts(today: today)
        let goals = try goalFacts(today: today)

        return InsightPromptBuilder.facts(
            safeToSpend: safeToSpend,
            comparison: spendComparison,
            movers: topMovers,
            budgets: budgets,
            goals: goals
        )
    }

    private func budgetFacts(today: Date) throws -> [BudgetFactInput] {
        guard featureFlags.budgetsEnabled else {
            return []
        }

        let budgets = try repositories.budgets.all().filter { $0.status == .active }
        guard !budgets.isEmpty else {
            return []
        }

        let categoryNames = try Dictionary(
            repositories.categories.all().map { ($0.id, $0.name) },
            uniquingKeysWith: { first, _ in first }
        )
        let cycles = budgets.map { BudgetPeriodCalculator.cycle(for: $0.period, containing: today) }
        let earliest = cycles.map(\.interval.start).min() ?? today
        let transactions = try repositories.transactions.transactions(from: earliest, to: today)

        return budgets.map { budget in
            BudgetFactInput(
                categoryName: categoryNames[budget.categoryID] ?? "Uncategorized",
                progress: BudgetProgressCalculator.progress(
                    budget: budget,
                    transactions: transactions,
                    referenceDate: today
                )
            )
        }
    }

    private func goalFacts(today: Date) throws -> [GoalFactInput] {
        guard featureFlags.goalsEnabled else {
            return []
        }

        return try repositories.goals.all()
            .filter { $0.status != .archived }
            .map { goal in
                let contributions = try repositories.goals.contributions(forGoal: goal.id)
                return GoalFactInput(
                    name: goal.name,
                    targetAmount: goal.targetAmount,
                    outcome: GoalProjector.outcome(
                        goal: goal,
                        contributions: contributions,
                        referenceDate: today
                    )
                )
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
