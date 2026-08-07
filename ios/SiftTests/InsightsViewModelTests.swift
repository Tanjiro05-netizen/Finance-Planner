import Foundation
@testable import Sift
import Testing

/// Covers the ledger-backed spending reports. The subscription half of Insights is exercised
/// by `CoreScreensViewModelTests`.
@MainActor
struct InsightsViewModelTests {
    private static var referenceDate: Date {
        SeedData.referenceDate
    }

    private func makeViewModel(repositories: RepositoryContainer = .mock()) -> InsightsViewModel {
        InsightsViewModel(
            repositories: repositories,
            detectionService: MockDetectionService(),
            refresher: NoopSubscriptionRefreshService(),
            referenceDateProvider: { Self.referenceDate }
        )
    }

    @Test func monthlySpendCoversTheTrailingWindowOldestFirst() async {
        let viewModel = makeViewModel()

        await viewModel.load()

        #expect(viewModel.errorMessage == nil)
        #expect(viewModel.monthlySpend.count == SpendReportBuilder.defaultMonths)

        let starts = viewModel.monthlySpend.map(\.monthStart)
        #expect(starts == starts.sorted())

        // The window ends on the reference month, not on whatever the last transaction was.
        let currentMonthStart = Calendar.utc.dateInterval(of: .month, for: Self.referenceDate)?.start
        #expect(starts.last == currentMonthStart)
    }

    @Test func monthlyTotalsMatchTheSeededLedger() async throws {
        let repositories = RepositoryContainer.mock()
        let viewModel = makeViewModel(repositories: repositories)

        await viewModel.load()

        // Derived rather than pinned: the seed is free to grow as long as the view model and
        // the builder agree about what it contains.
        let ledger = try repositories.transactions.all()
        for point in viewModel.monthlySpend {
            let interval = try #require(Calendar.utc.dateInterval(of: .month, for: point.monthStart))
            let expected = ledger
                .filter { $0.direction == .debit && !$0.pending && interval.contains($0.date) }
                .reduce(0) { $0 + $1.amount.amountMinor }
            #expect(point.total.amountMinor == expected)
        }
    }

    @Test func reportsStayHiddenWithoutALedger() async {
        let viewModel = makeViewModel(repositories: .emptyMock())

        await viewModel.load()

        #expect(viewModel.showsSpendReports == false)
        #expect(viewModel.maxMonthlySpend == .zeroUSD)
        #expect(viewModel.topMovers.isEmpty)
        // Still emits a point per month, so the absence is a deliberate gate rather than an
        // accident of empty data.
        #expect(viewModel.monthlySpend.count == SpendReportBuilder.defaultMonths)
    }

    @Test func reportsAppearOnceThereIsSpend() async {
        let viewModel = makeViewModel()

        await viewModel.load()

        #expect(viewModel.showsSpendReports)
        #expect(viewModel.maxMonthlySpend.amountMinor > 0)
    }

    @Test func theComparisonIsDayAlignedWhenTheMonthIsStillRunning() async throws {
        let viewModel = makeViewModel()

        await viewModel.load()

        let comparison = try #require(viewModel.spendComparison)
        // 29 June: 29 of 30 days elapsed, so both windows are truncated to 29 days.
        #expect(comparison.isPartialMonth)
        #expect(comparison.dayCount == 29)

        let currentDays = Calendar.utc.dateComponents(
            [.day],
            from: comparison.currentInterval.start,
            to: comparison.currentInterval.end
        ).day
        let previousDays = Calendar.utc.dateComponents(
            [.day],
            from: comparison.previousInterval.start,
            to: comparison.previousInterval.end
        ).day
        #expect(currentDays == previousDays)
    }

    @Test func comparisonCategoryNamesComeFromTheCategoryStore() async throws {
        let repositories = RepositoryContainer.mock()
        let viewModel = makeViewModel(repositories: repositories)

        await viewModel.load()

        let comparison = try #require(viewModel.spendComparison)
        let names = Set(try repositories.categories.all().map(\.name))
        let resolved = (comparison.currentByCategory + comparison.previousByCategory)
            .filter { $0.categoryID != nil }

        #expect(resolved.isEmpty == false)
        // Names, not raw ids — the mock ledger's own grouping returns ids as display names.
        #expect(resolved.allSatisfy { names.contains($0.categoryName) })
    }

    @Test func moversOnlyCarryAPercentageWhenThereWasABase() async {
        let viewModel = makeViewModel()

        await viewModel.load()

        for mover in viewModel.topMovers {
            if mover.previous.amountMinor > 0 {
                #expect(mover.fractionChange != nil)
            } else {
                #expect(mover.fractionChange == nil)
            }
        }
    }

    @Test func moversAreRankedByAbsoluteMoney() async {
        let viewModel = makeViewModel()

        await viewModel.load()

        let magnitudes = viewModel.topMovers.map { abs($0.delta.amountMinor) }
        #expect(magnitudes == magnitudes.sorted(by: >))
    }

    @Test func reportsDoNotChangeWhatEmptyInsightsMeans() async {
        // The detection service is seeded independently of the repositories, so it has to be
        // emptied explicitly for this to be a test about `isEmpty` rather than about trials.
        let viewModel = InsightsViewModel(
            repositories: .emptyMock(),
            detectionService: MockDetectionService(detections: []),
            refresher: NoopSubscriptionRefreshService(),
            referenceDateProvider: { Self.referenceDate }
        )

        await viewModel.load()

        // Six monthly points exist, all zero — and `isEmpty` stays subscription-derived
        // regardless, because the reports carry their own gate.
        #expect(viewModel.monthlySpend.isEmpty == false)
        #expect(viewModel.isEmpty)
    }
}
