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

                ScreenHeader(title: "Cancelled", eyebrow: viewModel.subscriptionName.uppercased())
                    .accessibilityIdentifier("cancel-confirmed-title")

                SiftCard {
                    Text("SAVED")
                        .font(.siftLabel)
                        .foregroundStyle(Palette.green)

                    MoneyText(
                        value: "\(viewModel.annualSavings.formatted())/yr",
                        size: 50,
                        color: Palette.green,
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
                .foregroundStyle(Palette.card)
                .frame(width: 62, height: 62)
                .background(Palette.green, in: Circle())
                .accessibilityHidden(true)
        } else {
            Image(systemName: SiftIcon.check)
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(Palette.card)
                .frame(width: 62, height: 62)
                .background(Palette.green, in: Circle())
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
