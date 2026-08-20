import SwiftUI

struct CancelOptionsView: View {
    let viewModel: CancellationViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xl) {
                ScreenHeader(title: "Choose how to cancel", eyebrow: viewModel.subscriptionName)
                    .accessibilityIdentifier("cancel-options-title")

                savingsCard

                VStack(spacing: Spacing.md) {
                    optionButton(
                        title: viewModel.isConciergeEnabled ? "Cancel for me" : "Concierge coming soon",
                        detail: conciergeDetail,
                        recommended: viewModel.isConciergeEnabled,
                        badgeText: viewModel.isConciergeEnabled ? nil : "COMING SOON",
                        identifier: "cancel-concierge-option",
                        isDisabled: !viewModel.isConciergeEnabled
                    ) {
                        Task {
                            await viewModel.chooseConcierge()
                        }
                    }

                    optionButton(
                        title: "Show me how",
                        detail: "Follow provider-specific steps when we have them, or a clearly labeled generic guide when we do not.",
                        recommended: !viewModel.isConciergeEnabled,
                        identifier: "cancel-guided-option"
                    ) {
                        Task {
                            await viewModel.chooseGuided()
                        }
                    }
                }

                honestNote

                if let errorMessage = viewModel.errorMessage {
                    StateMessageCard(
                        title: "Cancellation unavailable",
                        message: errorMessage,
                        systemImage: SiftIcon.warning
                    )
                }
            }
            .padding(.horizontal, Spacing.screenHorizontal)
            .padding(.top, Spacing.xl)
            .padding(.bottom, Spacing.xxl)
        }
    }

    private var savingsCard: some View {
        SiftSection {
            Text("Annual cost")
                .font(.siftLabel)
                .foregroundStyle(Palette.inkFaint)

            MoneyText(value: "\(viewModel.annualSavings.formatted())/yr", size: 46)
                .accessibilityLabel("\(viewModel.annualSavings.formatted()) per year")

            Text("Cancelling \(viewModel.subscriptionName) removes this from active totals after confirmation.")
                .font(.siftBody)
                .foregroundStyle(Palette.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var honestNote: some View {
        Text(honestNoteText)
            .font(.siftBody)
            .foregroundStyle(Palette.inkSoft)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var conciergeDetail: String {
        if viewModel.isConciergeEnabled {
            return "Our concierge team creates and tracks a real cancellation request. Your bank connection stays read-only."
        }

        // Says what the feature will be and what it needs, rather than an open-ended
        // "coming soon" — people are entitled to know why it isn't here.
        return """
        A person on our team would contact the provider and track the request to completion. \
        That needs a Sift account and a server, which this build runs without — everything \
        here happens on your iPhone. Guided steps and renewal reminders work today.
        """
    }

    private var honestNoteText: String {
        if viewModel.isConciergeEnabled {
            return """
            There is no universal cancel button. Sift either creates a concierge request our \
            team can track, or shows you the real steps to cancel yourself.
            """
        }

        return """
        There is no universal cancel button — no app can cancel on your behalf without \
        contacting the provider. Sift shows you the real steps and can remind you before \
        the next renewal.
        """
    }

    private func optionButton(
        title: String,
        detail: String,
        recommended: Bool,
        badgeText: String? = nil,
        identifier: String,
        isDisabled: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            OptionCard(title: title, detail: detail, recommended: recommended, badgeText: badgeText)
        }
        .buttonStyle(.plain)
        .disabled(viewModel.isWorking || isDisabled)
        .accessibilityIdentifier(identifier)
    }
}

#Preview {
    CancelOptionsView(viewModel: previewCancellationViewModel())
}
