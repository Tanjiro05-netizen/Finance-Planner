import SwiftUI

struct SubscriptionsView: View {
    @Environment(AppModel.self) private var appModel
    @State private var viewModel: SubscriptionsViewModel

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
        _viewModel = State(initialValue: SubscriptionsViewModel(
            repositories: repositories,
            refresher: refresher,
            referenceDateProvider: referenceDateProvider
        ))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xl) {
                ScreenHeader(title: "Subscriptions", eyebrow: "RECURRING")
                    .accessibilityIdentifier("subscriptions-title")

                content
            }
            .padding(.horizontal, Spacing.screenHorizontal)
            .padding(.top, Spacing.xl)
            .padding(.bottom, 84)
        }
        .background(Palette.bone)
        .navigationTitle("Subscriptions")
        .refreshable { await viewModel.refresh() }
        .task { viewModel.load() }
        .onChange(of: appModel.sheet) { _, newValue in
            if newValue == nil {
                viewModel.load()
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading {
            SubscriptionsLoadingView()
        } else if let errorMessage = viewModel.errorMessage {
            StateMessageCard(
                title: "Subscriptions unavailable",
                message: errorMessage,
                systemImage: SiftIcon.warning,
                actionTitle: "Try again"
            ) {
                viewModel.load()
            }
        } else {
            SubscriptionsContentView(viewModel: viewModel) { subscriptionID in
                appModel.present(.subscriptionDetail(id: subscriptionID))
            }
        }
    }
}

private struct SubscriptionsContentView: View {
    let viewModel: SubscriptionsViewModel
    let openDetail: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xl) {
            SubscriptionsTotalCard(viewModel: viewModel)

            SegmentedControlGlass(
                segments: viewModel.segmentTitles,
                selection: Binding(
                    get: { viewModel.selectedSegmentTitle },
                    set: { viewModel.selectSegment(title: $0) }
                )
            )
            .accessibilityIdentifier("subscriptions-segmented-control")

            if viewModel.isEmpty {
                StateMessageCard(
                    title: emptyTitle,
                    message: emptyMessage,
                    systemImage: SiftIcon.subscriptions
                )
            } else {
                ForEach(viewModel.sections) { section in
                    SubscriptionCategorySectionView(
                        section: section,
                        openDetail: openDetail
                    )
                }
            }
        }
    }

    private var emptyTitle: String {
        switch viewModel.selectedSegment {
        case .all:
            "No subscriptions yet"
        case .active:
            "No active subscriptions"
        case .unused:
            "No unused subscriptions"
        }
    }

    private var emptyMessage: String {
        switch viewModel.selectedSegment {
        case .all:
            "Recurring charges will appear after the next account sync."
        case .active:
            "Everything currently tracked is either unused or cancelled."
        case .unused:
            "Sift has not flagged any recurring charges as unused."
        }
    }
}

private struct SubscriptionsTotalCard: View {
    let viewModel: SubscriptionsViewModel

    var body: some View {
        SiftCard {
            Text("MONTHLY TOTAL")
                .font(.siftLabel)
                .foregroundStyle(Palette.inkFaint)

            MoneyText(value: viewModel.monthlyTotal.formatted(), size: 48)
                .minimumScaleFactor(0.74)
                .accessibilityLabel("Monthly recurring total, \(viewModel.monthlyTotal.formatted())")

            HStack {
                Text("\(viewModel.allCount) tracked · \(viewModel.unusedCount) unused")
                    .font(.siftBody)
                    .foregroundStyle(Palette.inkSoft)

                Spacer()

                Pill(
                    text: "\(viewModel.potentialSavings.formatted(showZeroFraction: false))/mo",
                    variant: viewModel.potentialSavings.amountMinor > 0 ? .up : .neutral
                )
            }
        }
    }
}

private struct SubscriptionCategorySectionView: View {
    let section: SubscriptionCategorySection
    let openDetail: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text(section.title.uppercased())
                .font(.siftLabel)
                .foregroundStyle(Palette.inkFaint)

            ForEach(section.subscriptions, id: \.id) { subscription in
                Button {
                    openDetail(subscription.id)
                } label: {
                    SubscriptionRow(
                        letter: subscription.monogramLetter,
                        color: subscription.tileColorToken.color,
                        name: subscription.name,
                        meta: metadata(for: subscription),
                        amount: subscription.amount.formatted(),
                        cadence: subscription.cadence.displayName,
                        warns: subscription.status == .unused
                    )
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier(accessibilityIdentifier(for: subscription))
                .accessibilityLabel("\(subscription.name), \(metadata(for: subscription)), \(subscription.amount.formatted())")
            }
        }
    }

    private func metadata(for subscription: Subscription) -> String {
        if subscription.status == .unused {
            return "Unused since \(lastUsedLabel(for: subscription))"
        }

        guard let nextRenewal = subscription.nextRenewal else {
            return "No upcoming renewal"
        }

        return "Renews \(nextRenewal.formatted(.dateTime.month(.abbreviated).day()))"
    }

    private func lastUsedLabel(for subscription: Subscription) -> String {
        subscription.lastUsed?.formatted(.dateTime.month(.abbreviated).day()) ?? "unknown"
    }

    private func accessibilityIdentifier(for subscription: Subscription) -> String {
        subscription.id == SampleRouteID.subscription ? "sample-subscription-row" : "subscription-row-\(subscription.id)"
    }
}

private struct SubscriptionsLoadingView: View {
    var body: some View {
        VStack(spacing: Spacing.xl) {
            SiftCard {
                Text("MONTHLY TOTAL")
                    .font(.siftLabel)
                MoneyText(value: "$000.00", size: 48)
                Text("0 tracked · 0 unused")
                    .font(.siftBody)
            }

            ForEach(0 ..< 5, id: \.self) { _ in
                SubscriptionRow(
                    letter: "S",
                    color: Palette.inkFaint,
                    name: "Subscription",
                    meta: "Renews soon",
                    amount: "$00.00",
                    cadence: "Monthly"
                )
            }
        }
        .redacted(reason: .placeholder)
        .accessibilityLabel("Loading subscriptions")
    }
}

#Preview("Loaded") {
    NavigationStack {
        SubscriptionsView(
            repositories: .mock(),
            referenceDateProvider: { subscriptionsPreviewDate() }
        )
    }
    .environment(AppModel())
}

#Preview("Empty") {
    NavigationStack {
        SubscriptionsView(
            repositories: .emptyMock(),
            referenceDateProvider: { subscriptionsPreviewDate() }
        )
    }
    .environment(AppModel())
}

private func subscriptionsPreviewDate() -> Date {
    Calendar.utc.date(from: DateComponents(year: 2026, month: 7, day: 1, hour: 10)) ?? Date()
}
