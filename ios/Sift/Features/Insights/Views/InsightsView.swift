import SwiftUI

struct InsightsView: View {
    @Environment(AppModel.self) private var appModel
    @State private var viewModel: InsightsViewModel

    init(
        repositories: RepositoryContainer = .mock(),
        apiClient: any SiftAPIClient = MockSiftAPIClient(),
        detectionService: any DetectionServing = MockDetectionService(),
        notificationScheduler: any NotificationScheduling = NoopNotificationScheduler(),
        referenceDateProvider: @escaping () -> Date = { Date() }
    ) {
        let refresher = DefaultSubscriptionRefreshService(
            apiClient: apiClient,
            detectionService: detectionService,
            repositories: repositories,
            notificationScheduler: notificationScheduler
        )
        _viewModel = State(initialValue: InsightsViewModel(
            repositories: repositories,
            detectionService: detectionService,
            refresher: refresher,
            referenceDateProvider: referenceDateProvider
        ))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xl) {
                ScreenHeader(title: "Insights", eyebrow: "SAVINGS")
                    .accessibilityIdentifier("insights-title")

                content
            }
            .padding(.horizontal, Spacing.screenHorizontal)
            .padding(.top, Spacing.xl)
            .padding(.bottom, 84)
        }
        .background(Palette.bone)
        .navigationTitle("Insights")
        .refreshable { await viewModel.refresh() }
        .task { await viewModel.load() }
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
            InsightsContentView(viewModel: viewModel) {
                appModel.push(.savingsBreakdown, in: .insights)
            }
        }
    }
}

private struct InsightsContentView: View {
    let viewModel: InsightsViewModel
    let openSavings: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xl) {
            SavingsHeroCard(viewModel: viewModel)
            CategorySpendCard(
                rows: viewModel.categorySpend,
                maxSpend: viewModel.maxCategorySpend
            )
            PriceChangesSection(rows: viewModel.priceChangeRows)
            TrialEndingSection(rows: viewModel.trialEndingRows)

            SecondaryButton(title: "View savings") {
                openSavings()
            }
        }
    }
}

private struct SavingsHeroCard: View {
    let viewModel: InsightsViewModel

    var body: some View {
        SiftCard {
            Text("POTENTIAL SAVINGS")
                .font(.siftLabel)
                .foregroundStyle(Palette.goldDeep)

            MoneyText(
                value: "\(viewModel.potentialSavings.formatted(showZeroFraction: false))/mo",
                size: 50,
                color: Palette.goldDeep,
                secondaryColor: Palette.gold
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
        SiftCard {
            Text("CATEGORY SPEND")
                .font(.siftLabel)
                .foregroundStyle(Palette.inkFaint)

            if rows.isEmpty {
                Text("Category totals will appear after subscriptions are detected.")
                    .font(.siftBody)
                    .foregroundStyle(Palette.inkSoft)
            } else {
                VStack(spacing: Spacing.md) {
                    ForEach(rows) { row in
                        CategorySpendBar(row: row, maxSpend: maxSpend)
                    }
                }
            }
        }
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
                    .font(.custom(SiftFontPostScriptName.frauncesSemiBold.rawValue, size: 16, relativeTo: .body))
                    .foregroundStyle(Palette.ink)
                    .monospacedDigit()
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Palette.sand)

                    Capsule()
                        .fill(Palette.gold)
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
            Text("PRICE CHANGES")
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
            Text("TRIAL ENDING")
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
                .foregroundStyle(warns ? Palette.clay : Palette.goldDeep)
                .frame(width: 36, height: 36)
                .background(Palette.card, in: RoundedRectangle(cornerRadius: Radius.tile, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.tile, style: .continuous)
                        .stroke(Palette.line, lineWidth: 1)
                )
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.bodyEmphasis)
                    .foregroundStyle(Palette.ink)
                Text(detail)
                    .font(.siftBody)
                    .foregroundStyle(warns ? Palette.clay : Palette.inkSoft)
            }

            Spacer()
        }
        .padding(Spacing.md)
        .background(Palette.card, in: RoundedRectangle(cornerRadius: Radius.row, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.row, style: .continuous)
                .stroke(Palette.line, lineWidth: 1)
        )
    }
}

private struct InsightsLoadingView: View {
    var body: some View {
        VStack(spacing: Spacing.xl) {
            SiftCard {
                Text("POTENTIAL SAVINGS")
                    .font(.siftLabel)
                MoneyText(value: "$000/mo", size: 50)
                Text("$0/yr if unused subscriptions are cancelled.")
                    .font(.siftBody)
            }

            SiftCard {
                Text("CATEGORY SPEND")
                    .font(.siftLabel)
                ForEach(0..<4, id: \.self) { _ in
                    CategorySpendBar(
                        row: CategorySpend(id: UUID().uuidString, name: "Category", total: .usd(10_000)),
                        maxSpend: .usd(10_000)
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
