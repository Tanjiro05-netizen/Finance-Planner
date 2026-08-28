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
        let names = try Set(repositories.categories.all().map(\.name))
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

/// Narration is a separate pass over the same loaded figures, so it gets its own suite.
@MainActor
struct InsightsNarrationTests {
    private static var referenceDate: Date {
        SeedData.referenceDate
    }

    private func makeViewModel(
        narrator: any InsightNarrating,
        flags: SiftFeatureFlags = SiftFeatureFlags(
            budgetsEnabled: true,
            goalsEnabled: true,
            insightNarrationEnabled: true
        ),
        repositories: RepositoryContainer = .mock()
    ) -> InsightsViewModel {
        InsightsViewModel(
            repositories: repositories,
            detectionService: MockDetectionService(),
            refresher: NoopSubscriptionRefreshService(),
            referenceDateProvider: { Self.referenceDate },
            featureFlags: flags,
            narrator: narrator
        )
    }

    @Test func narrationStaysOffUntilTheFlagIsOn() async {
        let viewModel = makeViewModel(
            narrator: MockInsightNarrator(),
            flags: SiftFeatureFlags(budgetsEnabled: true, goalsEnabled: true)
        )

        await viewModel.load()
        await viewModel.narrateInsights()

        #expect(viewModel.showsNarration == false)
        #expect(viewModel.narrationUnavailableMessage == nil)
        #expect(viewModel.insightNotes.isEmpty)
    }

    @Test func anUnavailableModelExplainsItselfWithoutErroring() async {
        let narrator = MockInsightNarrator(availabilityResult: .unavailable(.appleIntelligenceNotEnabled))
        let viewModel = makeViewModel(narrator: narrator)

        await viewModel.load()
        await viewModel.narrateInsights()

        #expect(viewModel.showsNarration == false)
        #expect(viewModel.narrationUnavailableMessage == InsightUnavailableReason.appleIntelligenceNotEnabled.message)
        #expect(viewModel.insightNotes.isEmpty)
        // The deterministic half is untouched by the model being unavailable.
        #expect(viewModel.errorMessage == nil)
        #expect(viewModel.showsSpendReports)
    }

    @Test func availableModelProducesNotes() async {
        let viewModel = makeViewModel(narrator: MockInsightNarrator())

        await viewModel.load()
        await viewModel.narrateInsights()

        #expect(viewModel.showsNarration)
        #expect(viewModel.insightNotes.isEmpty == false)
        #expect(viewModel.narrationMessage == nil)
        #expect(viewModel.isNarrating == false)
    }

    @Test func aNarrationFailureLeavesTheFiguresIntact() async {
        let narrator = MockInsightNarrator(failure: .rateLimited)
        let viewModel = makeViewModel(narrator: narrator)

        await viewModel.load()
        await viewModel.narrateInsights()

        #expect(viewModel.insightNotes.isEmpty)
        #expect(viewModel.narrationMessage == InsightNarrationFailure.rateLimited.message)
        // The whole point of keeping narrationMessage separate from errorMessage.
        #expect(viewModel.errorMessage == nil)
        #expect(viewModel.monthlySpend.isEmpty == false)
        #expect(viewModel.spendComparison != nil)
    }

    @Test func theNarratorOnlyEverSeesAggregates() async throws {
        let repositories = RepositoryContainer.mock()
        let narrator = MockInsightNarrator()
        let viewModel = makeViewModel(narrator: narrator, repositories: repositories)

        await viewModel.load()
        await viewModel.narrateInsights()

        let facts = try #require(narrator.recorder.lastFacts)
        #expect(facts.isEmpty == false)

        // No merchant string from the ledger may appear anywhere in the prompt. This is the
        // privacy guarantee, asserted against the real seeded ledger rather than a fixture.
        let prompt = InsightPromptBuilder.promptText(for: facts)
        for transaction in try repositories.transactions.all() {
            #expect(prompt.contains(transaction.merchantRaw) == false)
        }
    }

    @Test func factsCarryBudgetsAndGoalsWhenThoseFlagsAreOn() async throws {
        let narrator = MockInsightNarrator()
        let viewModel = makeViewModel(narrator: narrator)

        await viewModel.load()
        await viewModel.narrateInsights()

        let facts = try #require(narrator.recorder.lastFacts)
        #expect(facts.lines.contains { $0.label.contains("budget") })
        #expect(facts.lines.contains { $0.label.hasPrefix("Goal:") })
    }

    @Test func budgetsAndGoalsAreOmittedWhenTheirFlagsAreOff() async throws {
        let narrator = MockInsightNarrator()
        let viewModel = makeViewModel(
            narrator: narrator,
            flags: SiftFeatureFlags(insightNarrationEnabled: true)
        )

        await viewModel.load()
        await viewModel.narrateInsights()

        let facts = try #require(narrator.recorder.lastFacts)
        #expect(facts.lines.contains { $0.label.contains("budget") } == false)
        #expect(facts.lines.contains { $0.label.hasPrefix("Goal:") } == false)
    }

    @Test func anEmptyStoreNarratesNothingRatherThanFailing() async {
        let viewModel = makeViewModel(narrator: MockInsightNarrator(), repositories: .emptyMock())

        await viewModel.load()
        await viewModel.narrateInsights()

        #expect(viewModel.insightNotes.isEmpty)
        #expect(viewModel.narrationMessage == nil)
    }
}
