import SwiftUI

struct CancelConfirmedView: View {
    let viewModel: CancellationViewModel
    let done: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var checkTrigger = 0

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xl) {
                checkIcon

                ScreenHeader(title: "Cancelled", eyebrow: viewModel.subscriptionName)
                    .accessibilityIdentifier("cancel-confirmed-title")

                SiftSection {
                    Text("Saved")
                        .font(.siftLabel)
                        .foregroundStyle(Palette.positive)

                    MoneyText(
                        value: "\(viewModel.annualSavings.formatted())/yr",
                        size: 50,
                        color: Palette.positive,
                        secondaryColor: Palette.inkSoft
                    )
                    .accessibilityIdentifier("cancel-confirmed-savings")

                    Text("\(viewModel.subscriptionName) is marked cancelled and removed from active totals.")
                        .font(.siftBody)
                        .foregroundStyle(Palette.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                }

                GoldButton(title: "Done", action: done)
                    .accessibilityIdentifier("cancel-confirmed-done")
            }
            .padding(.horizontal, Spacing.screenHorizontal)
            .padding(.top, Spacing.xl)
            .padding(.bottom, Spacing.xxl)
        }
        .onAppear {
            checkTrigger += 1
        }
        .sensoryFeedback(.success, trigger: checkTrigger)
    }

    @ViewBuilder
    private var checkIcon: some View {
        if reduceMotion {
            Image(systemName: SiftIcon.check)
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(Palette.surface)
                .frame(width: 62, height: 62)
                .background(Palette.positive, in: Circle())
                .accessibilityHidden(true)
        } else {
            Image(systemName: SiftIcon.check)
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(Palette.surface)
                .frame(width: 62, height: 62)
                .background(Palette.positive, in: Circle())
                .symbolEffect(.bounce, value: checkTrigger)
                .accessibilityHidden(true)
        }
    }
}

#Preview {
    let viewModel = previewCancellationViewModel()
    viewModel.stage = .confirmed
    return CancelConfirmedView(viewModel: viewModel) {}
}
