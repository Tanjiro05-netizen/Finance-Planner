import SwiftUI

struct CancellationRequestsSheetView: View {
    @Environment(AppModel.self) private var appModel
    @State private var viewModel: CancellationViewModel

    init(
        repositories: RepositoryContainer = .mock(),
        apiClient: any SiftAPIClient = MockSiftAPIClient(),
        notificationScheduler: any NotificationScheduling = NoopNotificationScheduler()
    ) {
        _viewModel = State(initialValue: CancellationViewModel(
            subscriptionID: SampleRouteID.subscription,
            repositories: repositories,
            apiClient: apiClient,
            notificationScheduler: notificationScheduler
        ))
    }

    var body: some View {
        NavigationStack {
            CancellationRequestsView(viewModel: viewModel)
                .navigationTitle("Requests")
                .task {
                    await viewModel.loadRequests()
                }
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") {
                            appModel.dismissSheet()
                        }
                    }
                }
        }
        .presentationDragIndicator(.visible)
        .presentationDetents([.large])
    }
}

struct CancellationRequestsView: View {
    let viewModel: CancellationViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xl) {
                ScreenHeader(title: "Cancellation requests")
                    .accessibilityIdentifier("cancellation-requests-title")

                savingsBanner
                content
            }
            .padding(.horizontal, Spacing.screenHorizontal)
            .padding(.top, Spacing.xl)
            .padding(.bottom, Spacing.xxl)
        }
    }

    private var savingsBanner: some View {
        SiftSection {
            Text("Confirmed savings")
                .font(.siftLabel)
                .foregroundStyle(Palette.inkFaint)

            MoneyText(value: "\(viewModel.requestsSavings.formatted())/yr", size: 46)
                .accessibilityIdentifier("requests-savings-total")

            Text("Confirmed concierge and guided cancellations are counted once.")
                .font(.siftBody)
                .foregroundStyle(Palette.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading {
            RequestsLoadingView()
        } else if viewModel.requestRows.isEmpty {
            StateMessageCard(
                title: "No requests yet",
                message: "Concierge and guided cancellations will appear here after you start one.",
                systemImage: SiftIcon.list
            )
        } else {
            VStack(spacing: Spacing.sm) {
                ForEach(viewModel.requestRows) { row in
                    CancellationRequestRow(row: row) {
                        Task {
                            await viewModel.switchToGuidedFromNeedsUser()
                        }
                    }
                }
            }
        }
    }
}

private struct CancellationRequestRow: View {
    let row: CancellationRequestRowModel
    let needsUserAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack(spacing: Spacing.md) {
                MonogramTile(letter: row.monogramLetter, color: row.tileColorToken.color)

                VStack(alignment: .leading, spacing: 2) {
                    Text(row.title)
                        .font(.bodyEmphasis)
                        .foregroundStyle(Palette.ink)

                    Text("\(row.methodText) · \(row.annualCostText)")
                        .font(.system(.caption, design: .default).weight(.medium))
                        .foregroundStyle(Palette.inkSoft)
                }

                Spacer(minLength: Spacing.sm)

                RequestStatusPill(text: row.statusText, tone: row.statusTone)
            }

            if row.needsUserAction {
                SecondaryButton(title: "Show me how", action: needsUserAction)
            }
        }
        .padding(Spacing.md)
        .background(Palette.surface, in: RoundedRectangle(cornerRadius: Radius.row, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

private struct RequestStatusPill: View {
    let text: String
    let tone: CancellationStatusTone

    var body: some View {
        Text(text)
            .font(.siftLabel)
            .foregroundStyle(foreground)
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .background(foreground.opacity(0.12), in: Capsule())
    }

    private var foreground: Color {
        switch tone {
        case .progress:
            Palette.accent
        case .confirmed:
            Palette.positive
        case .needsUser:
            Palette.negative
        }
    }
}

private struct RequestsLoadingView: View {
    var body: some View {
        VStack(spacing: Spacing.sm) {
            ForEach(0 ..< 3, id: \.self) { _ in
                CancellationRequestRow(
                    row: CancellationRequestRowModel(
                        id: UUID().uuidString,
                        title: "Subscription",
                        methodText: "Concierge",
                        statusText: "In progress",
                        statusTone: .progress,
                        annualCostText: "$000.00/yr",
                        monogramLetter: "S",
                        tileColorToken: .inkFaint,
                        needsUserAction: false
                    ),
                    needsUserAction: {}
                )
            }
        }
        .redacted(reason: .placeholder)
        .accessibilityLabel("Loading cancellation requests")
    }
}

#Preview {
    let viewModel = previewCancellationViewModel()
    viewModel.requests = (try? RepositoryContainer.mock().cancellations.all()) ?? []
    return CancellationRequestsView(viewModel: viewModel)
}

@MainActor
func previewCancellationViewModel() -> CancellationViewModel {
    let viewModel = CancellationViewModel(
        subscriptionID: SampleRouteID.subscription,
        repositories: .mock(),
        apiClient: MockSiftAPIClient()
    )
    viewModel.load()
    return viewModel
}
