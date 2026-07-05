import SwiftUI

struct GuidedStepsView: View {
    @Environment(\.openURL) private var openURL

    let viewModel: CancellationViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xl) {
                ScreenHeader(title: "Cancel with guidance", eyebrow: viewModel.subscriptionName.uppercased())
                    .accessibilityIdentifier("guided-steps-title")

                guideSummary
                steps
                reminderCard

                if let siteMessage = viewModel.siteMessage {
                    StateMessageCard(
                        title: "Open provider site",
                        message: siteMessage,
                        systemImage: SiftIcon.externalLink
                    )
                }

                if let errorMessage = viewModel.errorMessage {
                    StateMessageCard(
                        title: "Guide unavailable",
                        message: errorMessage,
                        systemImage: SiftIcon.warning
                    )
                }
            }
            .padding(.horizontal, Spacing.screenHorizontal)
            .padding(.top, Spacing.xl)
            .padding(.bottom, 138)
        }
        .safeAreaInset(edge: .bottom) {
            bottomActions
                .padding(.horizontal, Spacing.screenHorizontal)
                .padding(.bottom, Spacing.sm)
        }
    }

    private var guideSummary: some View {
        SiftCard {
            Text((viewModel.guide?.isGeneric ?? true) ? "GENERIC GUIDE" : "VERIFIED GUIDE")
                .font(.siftLabel)
                .foregroundStyle((viewModel.guide?.isGeneric ?? true) ? Palette.inkFaint : Palette.goldDeep)

            Text(viewModel.guide?.title ?? "Cancellation guide")
                .font(.cardTitle)
                .foregroundStyle(Palette.ink)

            Text(summaryText)
                .font(.siftBody)
                .foregroundStyle(Palette.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var steps: some View {
        VStack(spacing: Spacing.sm) {
            ForEach(Array((viewModel.guide?.steps ?? []).enumerated()), id: \.offset) { index, step in
                NumberedStep(number: index + 1, text: step)
            }
        }
        .accessibilityIdentifier("guided-steps-list")
    }

    private var reminderCard: some View {
        SiftCard {
            Toggle(
                isOn: Binding(
                    get: { viewModel.remindBeforeRenewal },
                    set: { viewModel.setReminderIntent($0) }
                )
            ) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Remind me before renewal")
                        .font(.bodyEmphasis)
                        .foregroundStyle(Palette.ink)

                    Text("Sift will schedule this in notifications during Phase 10.")
                        .font(.siftBody)
                        .foregroundStyle(Palette.inkSoft)
                }
            }
            .toggleStyle(SiftToggleStyle())
            .accessibilityIdentifier("guided-reminder-toggle")
        }
    }

    private var bottomActions: some View {
        FloatingActionBar {
            VStack(spacing: Spacing.sm) {
                GoldButton(title: "Open provider site") {
                    openProviderSite()
                }
                .accessibilityIdentifier("guided-open-provider-site")

                SecondaryButton(title: viewModel.isWorking ? "Saving..." : "I've cancelled it") {
                    Task {
                        await viewModel.confirmGuidedCancellation()
                    }
                }
                .disabled(viewModel.isWorking)
                .accessibilityIdentifier("guided-confirm-cancelled")
            }
        }
    }

    private var summaryText: String {
        if viewModel.guide?.isGeneric == false {
            return "These steps are stored locally for this merchant. They do not automate cancellation."
        }

        return "We do not have verified provider-specific steps for this merchant, so this is a generic path."
    }

    private func openProviderSite() {
        guard let url = viewModel.guide?.providerURL else {
            viewModel.showMissingProviderSiteMessage()
            return
        }

        openURL(url)
    }
}

#Preview {
    let viewModel = previewCancellationViewModel()
    viewModel.stage = .guided
    return GuidedStepsView(viewModel: viewModel)
}
