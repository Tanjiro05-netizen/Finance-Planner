import SwiftUI

struct SubscriptionDetailRouteView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.repositories) private var repositories

    let subscriptionID: String

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xl) {
            ScreenHeader(title: subscription?.name ?? "Subscription", eyebrow: "NAVIGATION")
            SiftCard {
                Text(routeDetailText)
                    .font(.siftBody)
                    .foregroundStyle(Palette.inkSoft)
                GoldButton(title: "Open detail sheet") {
                    appModel.present(.subscriptionDetail(id: subscriptionID))
                }
            }
            Spacer()
        }
        .padding(.horizontal, Spacing.screenHorizontal)
        .padding(.top, Spacing.xl)
        .background(Palette.bone)
        .navigationTitle("Detail")
    }

    private var subscription: Subscription? {
        try? repositories.subscriptions.subscription(id: subscriptionID)
    }

    private var routeDetailText: String {
        guard let subscription else {
            return "This subscription is not available in the local data set."
        }

        return "\(subscription.name) is \(subscription.amount.formatted()) on a \(subscription.cadence.displayName.lowercased()) cadence."
    }
}

#Preview {
    NavigationStack {
        SubscriptionDetailRouteView(subscriptionID: SampleRouteID.subscription)
    }
    .environment(AppModel())
    .environment(\.repositories, .mock())
}
