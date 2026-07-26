import SwiftUI

struct DetailSheetView: View {
    @Environment(AppModel.self) private var appModel
    @State private var viewModel: SubscriptionDetailViewModel
    @State private var cancelWarningTrigger = 0

    let subscriptionID: String

    init(
        subscriptionID: String,
        repositories: RepositoryContainer = .mock(),
        apiClient: any SiftAPIClient = MockSiftAPIClient(),
        detectionService: any DetectionServing = MockDetectionService(),
        incomeDetectionService: any IncomeDetectionServing = MockIncomeDetectionService(),
        notificationScheduler: any NotificationScheduling = NoopNotificationScheduler(),
        referenceDateProvider: @escaping () -> Date = { Date() }
    ) {
        self.subscriptionID = subscriptionID
        let refresher = DefaultSubscriptionRefreshService(
            apiClient: apiClient,
            detectionService: detectionService,
            repositories: repositories,
            incomeDetectionService: incomeDetectionService,
            notificationScheduler: notificationScheduler
        )
        _viewModel = State(initialValue: SubscriptionDetailViewModel(
            subscriptionID: subscriptionID,
            repositories: repositories,
            refresher: refresher,
            referenceDateProvider: referenceDateProvider
        ))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.xl) {
                    ScreenHeader(title: viewModel.title, eyebrow: "DETAIL")
                        .accessibilityIdentifier("detail-sheet-title")

                    content
                }
                .padding(.horizontal, Spacing.screenHorizontal)
                .padding(.top, Spacing.xl)
                .padding(.bottom, 104)
            }
            .background(Palette.bone)
            .navigationTitle(viewModel.title)
            .refreshable { await viewModel.refresh() }
            .task(id: subscriptionID) { viewModel.load() }
            .safeAreaInset(edge: .bottom) {
                if viewModel.subscription != nil {
                    cancelActionBar
                }
            }
            .toolbar { closeToolbarItem }
        }
        .presentationDragIndicator(.visible)
        .presentationDetents([.medium, .large])
        .sensoryFeedback(.warning, trigger: cancelWarningTrigger)
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading {
            DetailLoadingView()
        } else if let errorMessage = viewModel.errorMessage {
            StateMessageCard(
                title: "Detail unavailable",
                message: errorMessage,
                systemImage: SiftIcon.warning,
                actionTitle: "Try again"
            ) {
                viewModel.load()
            }
        } else if viewModel.isEmpty {
            StateMessageCard(
                title: "Subscription unavailable",
                message: "This subscription is not in the local data set.",
                systemImage: SiftIcon.subscriptions
            )
        } else if let subscription = viewModel.subscription {
            SubscriptionDetailContent(
                subscription: subscription,
                viewModel: viewModel
            )
        }
    }

    private var cancelActionBar: some View {
        FloatingActionBar {
            ClayButton(title: "Cancel subscription") {
                cancelWarningTrigger += 1
                appModel.present(.cancellation(subscriptionID: subscriptionID))
            }
            .accessibilityIdentifier("detail-cancel-button")
        }
        .padding(.horizontal, Spacing.screenHorizontal)
        .padding(.bottom, Spacing.sm)
    }

    @ToolbarContentBuilder
    private var closeToolbarItem: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button("Done") {
                appModel.dismissSheet()
            }
        }
    }
}

private struct SubscriptionDetailContent: View {
    let subscription: Subscription
    let viewModel: SubscriptionDetailViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xl) {
            DetailHeaderCard(subscription: subscription, paymentMeta: viewModel.paymentMeta)
            DetailStatsGrid(viewModel: viewModel)
            ChargeHistorySection(
                points: viewModel.chargeHistory,
                maxAmount: viewModel.maxChargeAmount
            )
        }
    }
}

private struct DetailHeaderCard: View {
    let subscription: Subscription
    let paymentMeta: String

    var body: some View {
        SiftCard {
            HStack(spacing: Spacing.md) {
                MonogramTile(
                    letter: subscription.monogramLetter,
                    color: subscription.tileColorToken.color,
                    size: 52
                )

                VStack(alignment: .leading, spacing: 4) {
                    Text(subscription.name)
                        .font(.cardTitle)
                        .foregroundStyle(Palette.ink)
                    Text(paymentMeta)
                        .font(.siftBody)
                        .foregroundStyle(Palette.inkSoft)
                }
            }

            Text("\(subscription.amount.formatted()) · \(subscription.cadence.displayName)")
                .font(.cadence)
                .foregroundStyle(Palette.inkFaint)
        }
    }
}

private struct DetailStatsGrid: View {
    let viewModel: SubscriptionDetailViewModel

    private let columns = [
        GridItem(.flexible(), spacing: Spacing.md),
        GridItem(.flexible(), spacing: Spacing.md),
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: Spacing.md) {
            StatCell(
                label: "Per month",
                value: viewModel.monthlyCost.formatted()
            )
            StatCell(
                label: "Annual cost",
                value: viewModel.annualCost.formatted(),
                warns: true
            )
            StatCell(
                label: "Next charge",
                value: viewModel.nextChargeText
            )
            StatCell(
                label: "Last opened",
                value: viewModel.lastOpenedText
            )
        }
    }
}

private struct ChargeHistorySection: View {
    let points: [ChargeHistoryPoint]
    let maxAmount: Money

    var body: some View {
        SiftCard {
            HStack {
                Text("CHARGE HISTORY")
                    .font(.siftLabel)
                    .foregroundStyle(Palette.inkFaint)

                Spacer()

                Text("\(points.count) charges")
                    .font(.cadence)
                    .foregroundStyle(Palette.inkFaint)
            }

            if points.isEmpty {
                Text("No charge history is available yet.")
                    .font(.siftBody)
                    .foregroundStyle(Palette.inkSoft)
            } else {
                ChargeHistoryChart(points: points, maxAmount: maxAmount)
            }
        }
    }
}

private struct ChargeHistoryChart: View {
    let points: [ChargeHistoryPoint]
    let maxAmount: Money

    var body: some View {
        HStack(alignment: .bottom, spacing: Spacing.sm) {
            ForEach(points) { point in
                VStack(spacing: Spacing.sm) {
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(Palette.gold)
                        .frame(height: barHeight(for: point))
                        .accessibilityLabel("\(point.date.formatted(.dateTime.month(.abbreviated).day())), \(point.amount.formatted())")

                    Text(point.date.formatted(.dateTime.month(.abbreviated).day()))
                        .font(.cadence)
                        .foregroundStyle(Palette.inkFaint)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .frame(height: 126, alignment: .bottom)
    }

    private func barHeight(for point: ChargeHistoryPoint) -> CGFloat {
        guard maxAmount.amountMinor > 0 else {
            return 8
        }

        let ratio = Double(point.amount.amountMinor) / Double(maxAmount.amountMinor)
        return max(12, CGFloat(ratio) * 86)
    }
}

private struct DetailLoadingView: View {
    var body: some View {
        VStack(spacing: Spacing.xl) {
            SiftCard {
                HStack {
                    MonogramTile(letter: "S", color: Palette.inkFaint, size: 52)
                    VStack(alignment: .leading) {
                        Text("Subscription")
                            .font(.cardTitle)
                        Text("Payment method")
                            .font(.siftBody)
                    }
                }
            }

            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: Spacing.md),
                    GridItem(.flexible(), spacing: Spacing.md),
                ],
                spacing: Spacing.md
            ) {
                StatCell(label: "Per month", value: "$00.00")
                StatCell(label: "Annual cost", value: "$000.00", warns: true)
                StatCell(label: "Next charge", value: "Soon")
                StatCell(label: "Last opened", value: "Recent")
            }
        }
        .redacted(reason: .placeholder)
        .accessibilityLabel("Loading subscription detail")
    }
}

#Preview("Loaded") {
    DetailSheetView(
        subscriptionID: SampleRouteID.subscription,
        repositories: .mock()
    )
    .environment(AppModel())
}

#Preview("Missing") {
    DetailSheetView(
        subscriptionID: "missing",
        repositories: .mock()
    )
    .environment(AppModel())
}
