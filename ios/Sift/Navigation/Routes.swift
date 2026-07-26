enum AppTab: String, CaseIterable, Identifiable, Hashable {
    case home
    case subscriptions
    case insights
    case transactions

    var id: Self {
        self
    }

    var title: String {
        switch self {
        case .home:
            "Home"
        case .subscriptions:
            "Subscriptions"
        case .insights:
            "Insights"
        case .transactions:
            "Transactions"
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
        case .transactions:
            isSelected ? "list.bullet.rectangle.fill" : SiftIcon.transactions
        }
    }
}

enum HomeRoute: Hashable, CaseIterable {
    case settings
    case cashFlowForecast

    var title: String {
        switch self {
        case .settings:
            "Settings"
        case .cashFlowForecast:
            "Cash Flow"
        }
    }
}

enum SubscriptionsRoute: Hashable {
    case detail(id: String)

    static var samples: [Self] {
        [.detail(id: SampleRouteID.subscription)]
    }
}

enum InsightsRoute: Hashable, CaseIterable {
    case savingsBreakdown

    var title: String {
        switch self {
        case .savingsBreakdown:
            "Savings"
        }
    }
}

enum AppSheet: Hashable, Identifiable {
    case subscriptionDetail(id: String)
    case cancellation(subscriptionID: String)
    case cancellationRequests
    case manualTransactionEntry
    case transactionDetail(id: String)

    var id: String {
        switch self {
        case let .subscriptionDetail(id):
            "subscription-detail-\(id)"
        case let .cancellation(subscriptionID):
            "cancellation-\(subscriptionID)"
        case .cancellationRequests:
            "cancellation-requests"
        case .manualTransactionEntry:
            "manual-transaction-entry"
        case let .transactionDetail(id):
            "transaction-detail-\(id)"
        }
    }

    static var samples: [Self] {
        [
            .subscriptionDetail(id: SampleRouteID.subscription),
            .cancellation(subscriptionID: SampleRouteID.subscription),
            .cancellationRequests,
            .manualTransactionEntry,
            .transactionDetail(id: SampleRouteID.transaction),
        ]
    }
}

enum DeepLink: Hashable {
    case home
    case subscriptions
    case insights
    case transactions
    case settings
    case subscriptionDetail(id: String)
    case cancellation(subscriptionID: String)
}

enum SampleRouteID {
    static let subscription = SeedData.ID.streamline
    static let transaction = SeedData.ID.streamlineTransaction
}
