import Foundation
@testable import Sift
import Testing

@MainActor
struct CoreScreensViewModelTests {
    @Test func dashboardLoadsTotalsRenewalCountAndUnusedNudge() {
        let viewModel = HomeViewModel(
            repositories: .mock(),
            refresher: NoopSubscriptionRefreshService(),
            referenceDateProvider: { Self.referenceDate }
        )

        viewModel.load()

        #expect(viewModel.monthlyTotal == Money.usd(24783))
        #expect(viewModel.subscriptionCount == 11)
        #expect(viewModel.renewThisWeekCount == 3)
        #expect(viewModel.unusedNudge?.id == SeedData.ID.creativeCloud)
        #expect(viewModel.timelineMonthLabel == "JULY")
    }

    @Test func subscriptionsSegmentFiltersAndCounts() {
        let viewModel = SubscriptionsViewModel(
            repositories: .mock(),
            refresher: NoopSubscriptionRefreshService(),
            referenceDateProvider: { Self.referenceDate }
        )

        viewModel.load()

        #expect(viewModel.allCount == 11)
        #expect(viewModel.activeCount == 6)
        #expect(viewModel.unusedCount == 5)
        #expect(viewModel.segmentTitles == ["All 11", "Active 6", "Unused 5"])

        viewModel.selectSegment(title: "Unused 5")

        #expect(viewModel.selectedSegment == .unused)
        #expect(viewModel.filteredSubscriptions.count == 5)
        #expect(viewModel.filteredSubscriptions.allSatisfy { $0.status == .unused })
    }

    @Test func insightsLoadsSavingsCategoryTotalsAndPriceChanges() async {
        let viewModel = InsightsViewModel(
            repositories: .mock(),
            detectionService: MockDetectionService(),
            refresher: NoopSubscriptionRefreshService(),
            referenceDateProvider: { Self.referenceDate }
        )

        await viewModel.load()

        #expect(viewModel.potentialSavings == Money.usd(14600))
        #expect(viewModel.annualSavings == Money.usd(175_200))
        #expect(viewModel.categorySpend.first?.name == "Design")
        #expect(viewModel.categorySpend.first?.total == Money.usd(8436))
        #expect(viewModel.priceChangeRows.count == 1)
        #expect(viewModel.priceChangeRows.first?.subscriptionName == "Streamline+")
    }

    @Test func detailAnnualizesMonthlyAndYearlyCadences() {
        let repositories = RepositoryContainer.mock()
        let monthlyViewModel = SubscriptionDetailViewModel(
            subscriptionID: SeedData.ID.streamline,
            repositories: repositories
        )
        let yearlyViewModel = SubscriptionDetailViewModel(
            subscriptionID: SeedData.ID.notewell,
            repositories: repositories
        )

        monthlyViewModel.load()
        yearlyViewModel.load()

        #expect(monthlyViewModel.monthlyCost == Money.usd(1549))
        #expect(monthlyViewModel.annualCost == Money.usd(18588))
        #expect(yearlyViewModel.monthlyCost == Money.usd(999))
        #expect(yearlyViewModel.annualCost == Money.usd(11988))
    }

    @Test func refreshCallsSharedRefreshService() async {
        let refresher = RefreshSpy()
        let viewModel = HomeViewModel(
            repositories: .mock(),
            refresher: refresher,
            referenceDateProvider: { Self.referenceDate }
        )

        await viewModel.refresh()

        #expect(refresher.callCount == 1)
        #expect(refresher.lastReferenceDate == Self.referenceDate)
    }

    @Test func safeToSpendHiddenWhenLedgerFlagOff() {
        let viewModel = HomeViewModel(
            repositories: .mock(),
            refresher: NoopSubscriptionRefreshService(),
            featureFlags: SiftFeatureFlags(conciergeEnabled: false, ledgerEnabled: false),
            referenceDateProvider: { SeedData.referenceDate }
        )

        viewModel.load()

        #expect(viewModel.showsSafeToSpend == false)
        #expect(viewModel.safeToSpend == nil)
    }

    @Test func safeToSpendAvailableWhenLedgerFlagOn() {
        let viewModel = HomeViewModel(
            repositories: .mock(),
            refresher: NoopSubscriptionRefreshService(),
            featureFlags: SiftFeatureFlags(conciergeEnabled: false, ledgerEnabled: true),
            referenceDateProvider: { SeedData.referenceDate }
        )

        viewModel.load()

        #expect(viewModel.showsSafeToSpend)
        guard case let .available(result) = viewModel.safeToSpend else {
            Issue.record("Expected an available safe-to-spend outcome from seeded balances")
            return
        }
        // Seeded checking balance is spendable; the seeded payroll gives a real income horizon.
        #expect(result.usedFallbackWindow == false)
        #expect(result.horizonEndDate > SeedData.referenceDate)
    }

    private static var referenceDate: Date {
        Calendar.utc.date(from: DateComponents(year: 2026, month: 7, day: 1, hour: 10)) ?? Date()
    }
}

@MainActor
private final class RefreshSpy: SubscriptionRefreshing, @unchecked Sendable {
    var callCount = 0
    var lastReferenceDate: Date?

    func refresh(referenceDate: Date) async throws -> SubscriptionRefreshResult {
        callCount += 1
        lastReferenceDate = referenceDate
        return SubscriptionRefreshResult(
            synced: TransactionSyncResponse(added: 0, modified: 0, removed: 0, hasMore: false),
            importedTransactionCount: 0,
            detectionResult: .empty
        )
    }
}
