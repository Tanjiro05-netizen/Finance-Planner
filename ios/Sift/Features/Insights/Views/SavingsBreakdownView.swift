import SwiftUI

struct SavingsBreakdownView: View {
    @Environment(\.repositories) private var repositories

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xl) {
            ScreenHeader(title: "Savings")
            SiftCard {
                MoneyText(value: "\(annualSavings.formatted(showZeroFraction: false))/yr", size: 42)
                Text("\(unusedSubscriptions.count) subscriptions look unused based on recent activity.")
                    .font(.siftBody)
                    .foregroundStyle(Palette.inkSoft)
            }
            VStack(spacing: Spacing.md) {
                ForEach(unusedSubscriptions, id: \.id) { subscription in
                    SubscriptionRow(
                        letter: subscription.monogramLetter,
                        color: subscription.tileColorToken.color,
                        name: subscription.name,
                        meta: "Monthly equivalent \(subscription.monthlyEquivalent.formatted())",
                        amount: subscription.amount.formatted(),
                        cadence: subscription.cadence.displayName,
                        warns: true
                    )
                }
            }
            Spacer()
        }
        .padding(.horizontal, Spacing.screenHorizontal)
        .padding(.top, Spacing.xl)
        .background(Palette.bone)
        .navigationTitle("Savings")
    }

    private var unusedSubscriptions: [Subscription] {
        (try? repositories.subscriptions.unused()) ?? []
    }

    private var annualSavings: Money {
        ((try? repositories.subscriptions.potentialSavings()) ?? .zeroUSD).multiplied(by: 12)
    }
}

#Preview {
    NavigationStack {
        SavingsBreakdownView()
    }
    .environment(\.repositories, .mock())
}
