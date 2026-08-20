import Charts
import SwiftUI

struct InsightsView: View {
    @Environment(AppModel.self) private var appModel
    @State private var viewModel: InsightsViewModel

    init(
        repositories: RepositoryContainer = .mock(),
        apiClient: any SiftAPIClient = MockSiftAPIClient(),
        detectionService: any DetectionServing = MockDetectionService(),
        incomeDetectionService: any IncomeDetectionServing = MockIncomeDetectionService(),
        notificationScheduler: any NotificationScheduling = NoopNotificationScheduler(),
        referenceDateProvider: @escaping () -> Date = { Date() },
        featureFlags: SiftFeatureFlags = .launchDefault,
        insightNarrator: any InsightNarrating = MockInsightNarrator()
    ) {
        let refresher = DefaultSubscriptionRefreshService(
            apiClient: apiClient,
            detectionService: detectionService,
            repositories: repositories,
            incomeDetectionService: incomeDetectionService,
            notificationScheduler: notificationScheduler
        )
        _viewModel = State(initialValue: InsightsViewModel(
            repositories: repositories,
            detectionService: detectionService,
            refresher: refresher,
            referenceDateProvider: referenceDateProvider,
            featureFlags: featureFlags,
            narrator: insightNarrator
        ))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xl) {
                ScreenHeader(title: "Insights")
                    .accessibilityIdentifier("insights-title")

                content
            }
            .padding(.horizontal, Spacing.screenHorizontal)
            .padding(.top, Spacing.xl)
            .padding(.bottom, 84)
        }
        .background(Palette.ground)
        .navigationTitle("Insights")
        .refreshable { await viewModel.refresh() }
        .task {
            await viewModel.load()
            // Sequenced after load, not alongside it: narration reads the comparison and
            // movers that load() produces, and the figures must not wait on generation.
            await viewModel.narrateInsights()
        }
        .onChange(of: appModel.sheet) { _, newValue in
            if newValue == nil {
                Task {
                    await viewModel.load()
                }
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading {
            InsightsLoadingView()
        } else if let errorMessage = viewModel.errorMessage {
            StateMessageCard(
                title: "Insights unavailable",
                message: errorMessage,
                systemImage: SiftIcon.warning,
                actionTitle: "Try again"
            ) {
                Task { await viewModel.load() }
            }
        } else if viewModel.isEmpty {
            StateMessageCard(
                title: "No savings surfaced yet",
                message: "Sift will show savings, category spend, and billing alerts after more activity is synced.",
                systemImage: SiftIcon.insights
            )
        } else {
            InsightsContentView(
                viewModel: viewModel,
                openSavings: { appModel.push(.savingsBreakdown, in: .insights) },
                openGoals: { appModel.push(.goals, in: .insights) },
                openBudgets: { appModel.push(.budgets, in: .insights) }
            )
        }
    }
}

private struct InsightsContentView: View {
    let viewModel: InsightsViewModel
    let openSavings: () -> Void
    let openGoals: () -> Void
    let openBudgets: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xl) {
            SavingsHeroCard(viewModel: viewModel)

            NarrationSection(
                notes: viewModel.insightNotes,
                isNarrating: viewModel.isNarrating,
                failureMessage: viewModel.narrationMessage,
                unavailableMessage: viewModel.narrationUnavailableMessage
            )

            CategorySpendCard(
                rows: viewModel.categorySpend,
                maxSpend: viewModel.maxCategorySpend
            )
            PriceChangesSection(rows: viewModel.priceChangeRows)
            TrialEndingSection(rows: viewModel.trialEndingRows)

            if viewModel.showsSpendReports {
                SpendReportSections(
                    monthlySpend: viewModel.monthlySpend,
                    maxMonthlySpend: viewModel.maxMonthlySpend,
                    comparison: viewModel.spendComparison,
                    movers: viewModel.topMovers
                )
            }

            SecondaryButton(title: "View savings") {
                openSavings()
            }

            if viewModel.showsBudgetsEntry {
                SecondaryButton(title: "Budgets") {
                    openBudgets()
                }
                .accessibilityIdentifier("insights-budgets-button")
            }

            if viewModel.showsGoalsEntry {
                SecondaryButton(title: "Savings goals") {
                    openGoals()
                }
                .accessibilityIdentifier("insights-goals-button")
            }
        }
    }
}

/// Written observations from the on-device model, and the several ways there can be none.
///
/// Renders nothing at all when narration is off — the flag being off, or the model being
/// unavailable with no message, must leave Insights looking exactly as it did before.
private struct NarrationSection: View {
    let notes: [InsightNote]
    let isNarrating: Bool
    let failureMessage: String?
    let unavailableMessage: String?

    var body: some View {
        if let unavailableMessage {
            SiftSection {
                sectionTitle
                Text(unavailableMessage)
                    .font(.siftBody)
                    .foregroundStyle(Palette.inkSoft)
            }
            .accessibilityIdentifier("insights-narration-unavailable")
        } else if isNarrating {
            SiftSection {
                sectionTitle
                Text("Reading your numbers…")
                    .font(.siftBody)
                    .foregroundStyle(Palette.inkSoft)
            }
            .accessibilityIdentifier("insights-narration-loading")
        } else if let failureMessage {
            SiftSection {
                sectionTitle
                Text(failureMessage)
                    .font(.siftBody)
                    .foregroundStyle(Palette.inkSoft)
            }
            .accessibilityIdentifier("insights-narration-failed")
        } else if !notes.isEmpty {
            SiftSection {
                sectionTitle

                ForEach(notes) { note in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(note.headline)
                            .font(.bodyEmphasis)
                            .foregroundStyle(Palette.ink)
                        Text(note.detail)
                            .font(.siftBody)
                            .foregroundStyle(Palette.inkSoft)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                // Said plainly rather than buried in a settings screen: people should know
                // where the words came from, and that the figures did not.
                Text("Written on your iPhone. Your financial data never leaves the device.")
                    .font(.siftLabel)
                    .foregroundStyle(Palette.inkFaint)
            }
            .accessibilityIdentifier("insights-narration")
        }
    }

    private var sectionTitle: some View {
        Text("What sift noticed")
            .font(.siftLabel)
            .foregroundStyle(Palette.inkFaint)
    }
}

private struct SavingsHeroCard: View {
    let viewModel: InsightsViewModel

    var body: some View {
        SiftSection {
            Text("Potential savings")
                .font(.siftLabel)
                .foregroundStyle(Palette.accent)

            MoneyText(
                value: "\(viewModel.potentialSavings.formatted(showZeroFraction: false))/mo",
                role: .primary,
                color: Palette.accent,
                secondaryColor: Palette.accent
            )
            .minimumScaleFactor(0.72)
            .accessibilityLabel("Potential savings, \(viewModel.potentialSavings.formatted()) per month")

            Text("\(viewModel.annualSavings.formatted(showZeroFraction: false))/yr if unused subscriptions are cancelled.")
                .font(.siftBody)
                .foregroundStyle(Palette.inkSoft)
        }
    }
}

private struct CategorySpendCard: View {
    let rows: [CategorySpend]
    let maxSpend: Money

    var body: some View {
        SiftSection {
            Text("Category spend")
                .font(.siftLabel)
                .foregroundStyle(Palette.inkFaint)

            if rows.isEmpty {
                Text("Category totals will appear after subscriptions are detected.")
                    .font(.siftBody)
                    .foregroundStyle(Palette.inkSoft)
            } else {
                Chart(rows) { row in
                    BarMark(
                        x: .value("Spend", dollars(row.total)),
                        y: .value("Category", row.name)
                    )
                    .foregroundStyle(Palette.accent)
                    .cornerRadius(6)
                    .annotation(position: .trailing, alignment: .leading, spacing: 6) {
                        Text(row.total.formatted())
                            .font(.system(.caption, design: .default).weight(.semibold))
                            .foregroundStyle(Palette.ink)
                            .monospacedDigit()
                    }
                    .accessibilityLabel(row.name)
                    .accessibilityValue("\(row.total.formatted()) per month")
                }
                .chartXAxis(.hidden)
                .chartXScale(domain: 0 ... domainMax)
                .frame(height: CGFloat(rows.count) * 44 + 8)
            }
        }
    }

    private func dollars(_ money: Money) -> Double {
        Double(money.amountMinor) / 100
    }

    private var domainMax: Double {
        max(1, dollars(maxSpend) * 1.18)
    }
}

private struct CategorySpendBar: View {
    let row: CategorySpend
    let maxSpend: Money

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                Text(row.name)
                    .font(.bodyEmphasis)
                    .foregroundStyle(Palette.ink)

                Spacer()

                Text(row.total.formatted())
                    .font(.system(.body, design: .default).weight(.semibold))
                    .foregroundStyle(Palette.ink)
                    .monospacedDigit()
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Palette.surfaceSunken)

                    Capsule()
                        .fill(Palette.accent)
                        .frame(width: proxy.size.width * widthRatio)
                }
            }
            .frame(height: 8)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(row.name), \(row.total.formatted()) per month")
    }

    private var widthRatio: CGFloat {
        guard maxSpend.amountMinor > 0 else {
            return 0
        }

        return CGFloat(row.total.amountMinor) / CGFloat(maxSpend.amountMinor)
    }
}

private struct PriceChangesSection: View {
    let rows: [PriceChangeAlertRow]

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("Price changes")
                .font(.siftLabel)
                .foregroundStyle(Palette.inkFaint)

            if rows.isEmpty {
                Text("No price changes detected.")
                    .font(.siftBody)
                    .foregroundStyle(Palette.inkSoft)
            } else {
                ForEach(rows) { row in
                    AlertRow(
                        icon: row.isIncrease ? SiftIcon.arrowUp : SiftIcon.arrowDown,
                        title: row.subscriptionName,
                        detail: row.detail,
                        warns: row.isIncrease
                    )
                }
            }
        }
    }
}

private struct TrialEndingSection: View {
    let rows: [TrialEndingAlertRow]

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("Trial ending")
                .font(.siftLabel)
                .foregroundStyle(Palette.inkFaint)

            if rows.isEmpty {
                Text("No trials are ending soon.")
                    .font(.siftBody)
                    .foregroundStyle(Palette.inkSoft)
            } else {
                ForEach(rows) { row in
                    AlertRow(
                        icon: SiftIcon.calendar,
                        title: row.subscriptionName,
                        detail: row.detail,
                        warns: false
                    )
                }
            }
        }
    }
}

private struct AlertRow: View {
    let icon: String
    let title: String
    let detail: String
    let warns: Bool

    var body: some View {
        HStack(spacing: Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(warns ? Palette.negative : Palette.accent)
                .frame(width: 36, height: 36)
                .background(Palette.surface, in: RoundedRectangle(cornerRadius: Radius.tile, style: .continuous))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.bodyEmphasis)
                    .foregroundStyle(Palette.ink)
                Text(detail)
                    .font(.siftBody)
                    .foregroundStyle(warns ? Palette.negative : Palette.inkSoft)
            }

            Spacer()
        }
        .padding(Spacing.md)
        .background(Palette.surface, in: RoundedRectangle(cornerRadius: Radius.row, style: .continuous))
    }
}

private struct InsightsLoadingView: View {
    var body: some View {
        VStack(spacing: Spacing.xl) {
            SiftSection {
                Text("Potential savings")
                    .font(.siftLabel)
                MoneyText(value: "$000/mo", role: .primary)
                Text("$0/yr if unused subscriptions are cancelled.")
                    .font(.siftBody)
            }

            SiftSection {
                Text("Category spend")
                    .font(.siftLabel)
                ForEach(0 ..< 4, id: \.self) { _ in
                    CategorySpendBar(
                        row: CategorySpend(id: UUID().uuidString, name: "Category", total: .usd(10000)),
                        maxSpend: .usd(10000)
                    )
                }
            }
        }
        .redacted(reason: .placeholder)
        .accessibilityLabel("Loading insights")
    }
}

#Preview("Loaded") {
    NavigationStack {
        InsightsView(
            repositories: .mock(),
            referenceDateProvider: { insightsPreviewDate() }
        )
    }
    .environment(AppModel())
}

#Preview("Empty") {
    NavigationStack {
        InsightsView(
            repositories: .emptyMock(),
            referenceDateProvider: { insightsPreviewDate() }
        )
    }
    .environment(AppModel())
}

private func insightsPreviewDate() -> Date {
    Calendar.utc.date(from: DateComponents(year: 2026, month: 7, day: 1, hour: 10)) ?? Date()
}
