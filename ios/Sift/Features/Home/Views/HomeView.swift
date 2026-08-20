import SwiftUI

struct HomeView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var viewModel: HomeViewModel

    init(
        repositories: RepositoryContainer = .mock(),
        apiClient: any SiftAPIClient = MockSiftAPIClient(),
        detectionService: any DetectionServing = MockDetectionService(),
        incomeDetectionService: any IncomeDetectionServing = MockIncomeDetectionService(),
        notificationScheduler: any NotificationScheduling = NoopNotificationScheduler(),
        featureFlags: SiftFeatureFlags = .launchDefault,
        referenceDateProvider: @escaping () -> Date = { Date() }
    ) {
        let refresher = DefaultSubscriptionRefreshService(
            apiClient: apiClient,
            detectionService: detectionService,
            repositories: repositories,
            incomeDetectionService: incomeDetectionService,
            notificationScheduler: notificationScheduler
        )
        _viewModel = State(initialValue: HomeViewModel(
            repositories: repositories,
            refresher: refresher,
            featureFlags: featureFlags,
            referenceDateProvider: referenceDateProvider
        ))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xl) {
                ScreenHeader(title: viewModel.greeting, eyebrow: viewModel.dateLabel)
                    .accessibilityIdentifier("home-title")

                content
            }
            .padding(.horizontal, Spacing.screenHorizontal)
            .padding(.top, Spacing.xl)
            .padding(.bottom, 84)
        }
        .background(Palette.ground)
        .navigationTitle("Home")
        .refreshable { await viewModel.refresh() }
        .task { viewModel.load() }
        .onChange(of: appModel.sheet) { _, newValue in
            if newValue == nil {
                viewModel.load()
            }
        }
        .toolbar { settingsToolbarItem }
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading {
            DashboardLoadingView()
        } else if let errorMessage = viewModel.errorMessage {
            StateMessageCard(
                title: "Sync paused",
                message: errorMessage,
                systemImage: SiftIcon.warning,
                actionTitle: "Try again"
            ) {
                viewModel.load()
            }
        } else if viewModel.isEmpty {
            StateMessageCard(
                title: "No subscriptions yet",
                message: "Connect an account and Sift will place recurring charges here.",
                systemImage: SiftIcon.subscriptions
            )
        } else {
            DashboardContentView(
                viewModel: viewModel,
                openDetail: { subscriptionID in
                    appModel.present(.subscriptionDetail(id: subscriptionID))
                },
                openForecast: { appModel.push(.cashFlowForecast, in: .home) },
                openBudgets: {
                    appModel.select(tab: .insights)
                    appModel.push(.budgets, in: .insights)
                }
            )
        }
    }

    @ToolbarContentBuilder
    private var settingsToolbarItem: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                withAnimation(Motion.reduced(Motion.gentle, reduceMotion: reduceMotion)) {
                    appModel.push(.settings, in: .home)
                }
            } label: {
                Image(systemName: SiftIcon.profile)
            }
            .accessibilityLabel("Settings")
            .accessibilityIdentifier("home-profile-button")
        }
    }
}

private struct DashboardContentView: View {
    let viewModel: HomeViewModel
    let openDetail: (String) -> Void
    let openForecast: () -> Void
    let openBudgets: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xl) {
            if viewModel.showsSafeToSpend, let safeToSpend = viewModel.safeToSpend {
                SafeToSpendCard(outcome: safeToSpend, onTap: openForecast)
            }

            if viewModel.showsBudgetNudge {
                BudgetNudgeCard(rows: viewModel.overPaceBudgets, onTap: openBudgets)
            }

            DashboardHeroCard(viewModel: viewModel)

            if let unusedNudge = viewModel.unusedNudge {
                UnusedNudgeCard(
                    subscription: unusedNudge,
                    review: { openDetail(unusedNudge.id) },
                    keep: { viewModel.dismissNudge() }
                )
            }

            RenewSoonSection(
                subscriptions: viewModel.upcomingRenewals,
                openDetail: openDetail
            )
        }
    }
}

private struct DashboardHeroCard: View {
    let viewModel: HomeViewModel

    var body: some View {
        SiftSection {
            HStack(alignment: .firstTextBaseline) {
                Text("Recurring this month")
                    .font(.siftLabel)
                    .foregroundStyle(Palette.inkFaint)

                Spacer()

                Pill(text: viewModel.trend.text, variant: pillVariant)
            }

            MoneyText(value: viewModel.monthlyTotal.formatted(), role: .primary)
                .minimumScaleFactor(0.72)
                .accessibilityLabel("Recurring this month, \(viewModel.monthlyTotal.formatted())")
                .accessibilityIdentifier("dashboard-monthly-total")

            Text(viewModel.summaryText)
                .font(.siftBody)
                .foregroundStyle(Palette.inkSoft)

            RenewalTimelineStrip(
                marks: viewModel.timelineMarks.map { mark in
                    RenewalMark(
                        position: CGFloat(mark.position),
                        color: mark.isNext ? Palette.accent : Palette.inkFaint,
                        label: mark.isNext ? "Next" : nil
                    )
                },
                monthLabel: viewModel.timelineMonthLabel
            )
        }
    }

    private var pillVariant: PillVariant {
        switch viewModel.trend.direction {
        case .up:
            .up
        case .down:
            .down
        case .neutral:
            .neutral
        }
    }
}

private struct UnusedNudgeCard: View {
    let subscription: Subscription
    let review: () -> Void
    let keep: () -> Void

    var body: some View {
        SiftSection {
            Text("Flagged unused")
                .font(.siftLabel)
                .foregroundStyle(Palette.negative)

            HStack(spacing: Spacing.md) {
                MonogramTile(
                    letter: subscription.monogramLetter,
                    color: subscription.tileColorToken.color,
                    size: 44
                )

                VStack(alignment: .leading, spacing: 3) {
                    Text(subscription.name)
                        .font(.bodyEmphasis)
                        .foregroundStyle(Palette.ink)
                    Text("Last opened \(lastUsedText)")
                        .font(.siftBody)
                        .foregroundStyle(Palette.negative)
                }

                Spacer()

                MoneyText(value: subscription.monthlyEquivalent.formatted(), role: .row, color: Palette.negative)
            }

            HStack(spacing: Spacing.sm) {
                GoldButton(title: "Review") {
                    review()
                }
                SecondaryButton(title: "Keep") {
                    keep()
                }
            }
        }
    }

    private var lastUsedText: String {
        subscription.lastUsed?.formatted(.dateTime.month(.abbreviated).day()) ?? "not seen"
    }
}

private struct RenewSoonSection: View {
    let subscriptions: [Subscription]
    let openDetail: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("Renews soon")
                .font(.siftLabel)
                .foregroundStyle(Palette.inkFaint)

            if subscriptions.isEmpty {
                StateMessageCard(
                    title: "Nothing due this week",
                    message: "Upcoming renewals will appear here after the next sync.",
                    systemImage: SiftIcon.calendar
                )
            } else {
                ForEach(subscriptions, id: \.id) { subscription in
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
                    .accessibilityLabel("\(subscription.name), \(metadata(for: subscription)), \(subscription.amount.formatted())")
                }
            }
        }
    }

    private func metadata(for subscription: Subscription) -> String {
        guard let nextRenewal = subscription.nextRenewal else {
            return "No renewal scheduled"
        }

        return "Renews \(nextRenewal.formatted(.dateTime.month(.abbreviated).day()))"
    }
}

private struct DashboardLoadingView: View {
    var body: some View {
        VStack(spacing: Spacing.xl) {
            SiftSection {
                Text("Recurring this month")
                    .font(.siftLabel)
                MoneyText(value: "$000.00", role: .primary)
                Text("Across 0 subscriptions · 0 renew this week")
                    .font(.siftBody)
                RenewalTimelineStrip(marks: [], monthLabel: "JULY")
            }

            ForEach(0 ..< 3, id: \.self) { _ in
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
        .accessibilityLabel("Loading dashboard")
    }
}

#Preview("Loaded") {
    NavigationStack {
        HomeView(
            repositories: .mock(),
            referenceDateProvider: { previewDate() }
        )
    }
    .environment(AppModel())
}

#Preview("Empty") {
    NavigationStack {
        HomeView(
            repositories: .emptyMock(),
            referenceDateProvider: { previewDate() }
        )
    }
    .environment(AppModel())
}

private func previewDate() -> Date {
    Calendar.utc.date(from: DateComponents(year: 2026, month: 7, day: 1, hour: 10)) ?? Date()
}
