import Foundation
import Observation

enum DashboardTrendDirection: Equatable {
    case up
    case down
    case neutral
}

struct DashboardTrend: Equatable {
    let text: String
    let direction: DashboardTrendDirection
}

struct DashboardTimelineMark: Identifiable, Equatable {
    let id: String
    let position: Double
    let day: Int
    let isNext: Bool
}

@MainActor
@Observable
final class HomeViewModel {
    private let repositories: RepositoryContainer
    private let refresher: any SubscriptionRefreshing
    private let featureFlags: SiftFeatureFlags
    private let referenceDateProvider: () -> Date
    private var nudgeDismissedSubscriptionIDs = Set<String>()

    var isLoading = false
    var isRefreshing = false
    var hasLoaded = false
    var errorMessage: String?
    var monthlyTotal = Money.zeroUSD
    var potentialSavings = Money.zeroUSD
    var subscriptionCount = 0
    var renewThisWeekCount = 0
    var upcomingRenewals: [Subscription] = []
    var unusedNudge: Subscription?
    var timelineMarks: [DashboardTimelineMark] = []
    var timelineMonthLabel = ""
    var trend = DashboardTrend(text: "No change", direction: .neutral)
    var safeToSpend: SafeToSpendOutcome?
    /// Budgets that are spending ahead of pace, surfaced as a nudge on Home.
    var overPaceBudgets: [BudgetRowModel] = []

    init(
        repositories: RepositoryContainer,
        refresher: any SubscriptionRefreshing,
        featureFlags: SiftFeatureFlags = .launchDefault,
        referenceDateProvider: @escaping () -> Date = { Date() }
    ) {
        self.repositories = repositories
        self.refresher = refresher
        self.featureFlags = featureFlags
        self.referenceDateProvider = referenceDateProvider
    }

    var showsSafeToSpend: Bool {
        featureFlags.ledgerEnabled
    }

    var showsBudgetNudge: Bool {
        featureFlags.budgetsEnabled && !overPaceBudgets.isEmpty
    }

    var isEmpty: Bool {
        hasLoaded && subscriptionCount == 0 && errorMessage == nil
    }

    var greeting: String {
        let hour = Calendar.current.component(.hour, from: referenceDateProvider())

        switch hour {
        case 0 ..< 12:
            return "Good morning"
        case 12 ..< 17:
            return "Good afternoon"
        default:
            return "Good evening"
        }
    }

    var dateLabel: String {
        referenceDateProvider()
            .formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
            .uppercased()
    }

    var summaryText: String {
        "Across \(subscriptionCount) subscriptions · \(renewThisWeekCount) renew this week"
    }

    func load() {
        loadContent(showLoading: !hasLoaded)
    }

    func refresh() async {
        isRefreshing = true
        defer { isRefreshing = false }

        do {
            _ = try await refresher.refresh(referenceDate: referenceDateProvider())
            loadContent(showLoading: false)
        } catch {
            errorMessage = userFacingMessage(for: error)
        }
    }

    func dismissNudge() {
        guard let unusedNudge else {
            return
        }

        nudgeDismissedSubscriptionIDs.insert(unusedNudge.id)
        self.unusedNudge = nil
    }

    private func loadContent(showLoading: Bool) {
        if showLoading {
            isLoading = true
        }

        defer {
            isLoading = false
            hasLoaded = true
        }

        do {
            let subscriptions = try repositories.subscriptions.all()
                .filter { $0.status != .cancelled }

            monthlyTotal = try repositories.subscriptions.monthlyTotal()
            potentialSavings = try repositories.subscriptions.potentialSavings(
                referenceDate: referenceDateProvider(),
                staleAfterDays: 60
            )
            subscriptionCount = subscriptions.count
            renewThisWeekCount = countRenewalsThisWeek(in: subscriptions)
            upcomingRenewals = try repositories.subscriptions.upcomingRenewals(limit: 3)
            unusedNudge = try repositories.subscriptions.unused(
                referenceDate: referenceDateProvider(),
                staleAfterDays: 60
            )
            .first { !nudgeDismissedSubscriptionIDs.contains($0.id) }
            trend = try monthlyTrend(from: subscriptions)

            let timeline = makeTimeline(from: subscriptions)
            timelineMarks = timeline.marks
            timelineMonthLabel = timeline.monthLabel
            safeToSpend = showsSafeToSpend ? try computeSafeToSpend() : nil
            overPaceBudgets = featureFlags.budgetsEnabled ? try computeOverPaceBudgets() : []
            errorMessage = nil
        } catch {
            errorMessage = userFacingMessage(for: error)
        }
    }

    private func computeSafeToSpend() throws -> SafeToSpendOutcome {
        try SafeToSpendProvider.outcome(repositories: repositories, today: referenceDateProvider())
    }

    /// Reuses `BudgetsViewModel` rather than re-deriving progress here, so Home and the
    /// budgets screen can never disagree about whether a budget is over pace.
    private func computeOverPaceBudgets() throws -> [BudgetRowModel] {
        let budgets = BudgetsViewModel(repositories: repositories, referenceDateProvider: referenceDateProvider)
        budgets.load()

        if let errorMessage = budgets.errorMessage {
            throw SiftError.persistence(errorMessage)
        }

        return budgets.overPaceRows
    }

    private func countRenewalsThisWeek(in subscriptions: [Subscription]) -> Int {
        let calendar = Calendar.utc
        let start = calendar.startOfDay(for: referenceDateProvider())
        let end = calendar.date(byAdding: .day, value: 7, to: start) ?? start

        return subscriptions.count(where: { subscription in
            guard let nextRenewal = subscription.nextRenewal else {
                return false
            }

            return nextRenewal >= start && nextRenewal < end
        })
    }

    private func makeTimeline(from subscriptions: [Subscription]) -> (marks: [DashboardTimelineMark], monthLabel: String) {
        let referenceDate = referenceDateProvider()
        let calendar = Calendar.utc
        let renewalDates = subscriptions.compactMap(\.nextRenewal).sorted()
        let timelineDate = renewalDates.first(where: { $0 >= referenceDate }) ?? referenceDate
        let monthInterval = calendar.dateInterval(of: .month, for: timelineDate)
        let monthRange = calendar.range(of: .day, in: .month, for: timelineDate)
        let dayCount = monthRange?.count ?? 30
        let nextRenewalID = subscriptions
            .filter { ($0.nextRenewal ?? .distantFuture) >= referenceDate }
            .min { ($0.nextRenewal ?? .distantFuture) < ($1.nextRenewal ?? .distantFuture) }?
            .id

        let marks = subscriptions.compactMap { subscription -> DashboardTimelineMark? in
            guard
                let nextRenewal = subscription.nextRenewal,
                let monthInterval,
                monthInterval.contains(nextRenewal)
            else {
                return nil
            }

            let day = calendar.component(.day, from: nextRenewal)
            let denominator = max(dayCount - 1, 1)

            return DashboardTimelineMark(
                id: subscription.id,
                position: Double(day - 1) / Double(denominator),
                day: day,
                isNext: subscription.id == nextRenewalID
            )
        }

        let label = timelineDate.formatted(.dateTime.month(.wide)).uppercased()
        return (marks.sorted { $0.day < $1.day }, label)
    }

    private func monthlyTrend(from subscriptions: [Subscription]) throws -> DashboardTrend {
        let subscriptionsByID = Dictionary(uniqueKeysWithValues: subscriptions.map { ($0.id, $0) })
        let deltas = try repositories.priceChanges.all().compactMap { change -> Money? in
            guard let subscription = subscriptionsByID[change.subscriptionID] else {
                return nil
            }

            let oldMonthly = subscription.cadence.monthlyEquivalent(for: change.oldAmount)
            let newMonthly = subscription.cadence.monthlyEquivalent(for: change.newAmount)
            return newMonthly - oldMonthly
        }

        let delta = try Money.sum(deltas)

        if delta.amountMinor > 0 {
            return DashboardTrend(
                text: "Up \(delta.formatted())",
                direction: .up
            )
        }

        if delta.amountMinor < 0 {
            return DashboardTrend(
                text: "Down \(Money(amountMinor: abs(delta.amountMinor), currency: delta.currency).formatted())",
                direction: .down
            )
        }

        return DashboardTrend(text: "No change", direction: .neutral)
    }

    private func userFacingMessage(for error: Error) -> String {
        if let siftError = error as? SiftError {
            return siftError.errorDescription ?? "Something went wrong."
        }

        return error.localizedDescription
    }
}
