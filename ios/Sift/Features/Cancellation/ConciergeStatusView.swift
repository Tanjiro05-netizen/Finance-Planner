import SwiftUI

struct ConciergeStatusView: View {
    let viewModel: CancellationViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xl) {
                ScreenHeader(title: "Concierge request", eyebrow: viewModel.subscriptionName)
                    .accessibilityIdentifier("concierge-status-title")

                SiftSection {
                    Text("Status")
                        .font(.siftLabel)
                        .foregroundStyle(Palette.inkFaint)

                    StatusTimeline(items: viewModel.conciergeTimelineItems)
                        .accessibilityIdentifier("concierge-status-timeline")
                }

                if viewModel.request?.status == .needsUser {
                    needsUserCallout
                }

                if let errorMessage = viewModel.errorMessage {
                    StateMessageCard(
                        title: "Status unavailable",
                        message: errorMessage,
                        systemImage: SiftIcon.warning
                    )
                }

                actions
            }
            .padding(.horizontal, Spacing.screenHorizontal)
            .padding(.top, Spacing.xl)
            .padding(.bottom, Spacing.xxl)
        }
    }

    private var needsUserCallout: some View {
        SiftSection {
            Text("Needs you")
                .font(.siftLabel)
                .foregroundStyle(Palette.negative)

            Text("This provider requires the account holder to finish cancellation. You can switch to guided steps and keep the request tracked.")
                .font(.siftBody)
                .foregroundStyle(Palette.inkSoft)
                .fixedSize(horizontal: false, vertical: true)

            SecondaryButton(title: "Show me how") {
                Task {
                    await viewModel.switchToGuidedFromNeedsUser()
                }
            }
        }
    }

    private var actions: some View {
        VStack(spacing: Spacing.sm) {
            GoldButton(title: viewModel.isWorking ? "Checking..." : "Refresh status") {
                Task {
                    await viewModel.refreshCurrentRequest()
                }
            }
            .disabled(viewModel.isWorking)
            .accessibilityIdentifier("concierge-refresh-status")

            SecondaryButton(title: "Track in Requests") {
                Task {
                    await viewModel.showRequests()
                }
            }
            .accessibilityIdentifier("concierge-track-requests")
        }
    }
}

#Preview {
    let viewModel = previewCancellationViewModel()
    viewModel.stage = .concierge
    viewModel.request = try? RepositoryContainer.mock().cancellations.create(
        subscriptionID: SampleRouteID.subscription,
        method: .concierge,
        note: nil,
        now: SeedData.referenceDate
    )
    return ConciergeStatusView(viewModel: viewModel)
}
