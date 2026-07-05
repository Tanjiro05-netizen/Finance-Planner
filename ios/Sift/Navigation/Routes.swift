enum AppTab: String, CaseIterable, Identifiable, Hashable, Sendable {
    case home
    case subscriptions
    case insights

    var id: Self { self }

    var title: String {
        switch self {
        case .home:
            "Home"
        case .subscriptions:
            "Subscriptions"
        case .insights:
            "Insights"
        }
    }

    func symbol(isSelected: Bool = false) -> String {
        switch self {
        case .home:
            isSelected ? "house.fill" : SiftIcon.home
        case .subscriptions:
            isSelected ? "rectangle.stack.fill" : SiftIcon.subscriptions
        case .insights:
            isSelected ? "chart.bar.fill" : SiftIcon.insights
        }
    }
}

enum HomeRoute: Hashable, CaseIterable, Sendable {
    case settings

    var title: String {
        switch self {
        case .settings:
            "Settings"
        }
    }
}

enum SubscriptionsRoute: Hashable, Sendable {
    case detail(id: String)

    static var samples: [Self] {
        [.detail(id: SampleRouteID.subscription)]
    }
}

enum InsightsRoute: Hashable, CaseIterable, Sendable {
    case savingsBreakdown

    var title: String {
        switch self {
        case .savingsBreakdown:
            "Savings"
        }
    }
}

enum AppSheet: Hashable, Identifiable, Sendable {
    case subscriptionDetail(id: String)
    case cancellation(subscriptionID: String)
    case cancellationRequests

    var id: String {
        switch self {
        case .subscriptionDetail(let id):
            "subscription-detail-\(id)"
        case .cancellation(let subscriptionID):
            "cancellation-\(subscriptionID)"
        case .cancellationRequests:
            "cancellation-requests"
        }
    }

    static var samples: [Self] {
        [
            .subscriptionDetail(id: SampleRouteID.subscription),
            .cancellation(subscriptionID: SampleRouteID.subscription),
            .cancellationRequests,
        ]
    }
}

enum DeepLink: Hashable, Sendable {
    case home
    case subscriptions
    case insights
    case settings
    case subscriptionDetail(id: String)
    case cancellation(subscriptionID: String)
}

enum SampleRouteID {
    static let subscription = SeedData.ID.streamline
}
