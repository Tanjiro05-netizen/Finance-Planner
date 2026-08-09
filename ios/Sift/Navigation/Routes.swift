enum AppTab: String, CaseIterable, Identifiable, Hashable {
    case home
    case subscriptions
    case insights
    case transactions
    case assistant

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
        case .assistant:
            "Ask"
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
        case .assistant:
            isSelected ? "sparkles" : SiftIcon.assistant
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
    case budgets
    case goals

    var title: String {
        switch self {
        case .savingsBreakdown:
            "Savings"
        case .budgets:
            "Budgets"
        case .goals:
            "Goals"
        }
    }
}

enum AppSheet: Hashable, Identifiable {
    case subscriptionDetail(id: String)
    case cancellation(subscriptionID: String)
    case cancellationRequests
    case manualTransactionEntry
    case transactionDetail(id: String)
    /// nil creates a new budget; a value edits the existing one.
    case budgetEditor(budgetID: String?)
    case affordabilityCheck
    /// nil creates a new goal; a value edits the existing one.
    case goalEditor(goalID: String?)
    case goalContribution(goalID: String)

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
        case let .budgetEditor(budgetID):
            "budget-editor-\(budgetID ?? "new")"
        case .affordabilityCheck:
            "affordability-check"
        case let .goalEditor(goalID):
            "goal-editor-\(goalID ?? "new")"
        case let .goalContribution(goalID):
            "goal-contribution-\(goalID)"
        }
    }

    static var samples: [Self] {
        [
            .subscriptionDetail(id: SampleRouteID.subscription),
            .cancellation(subscriptionID: SampleRouteID.subscription),
            .cancellationRequests,
            .manualTransactionEntry,
            .transactionDetail(id: SampleRouteID.transaction),
            .budgetEditor(budgetID: nil),
            .budgetEditor(budgetID: SampleRouteID.budget),
            .affordabilityCheck,
            .goalEditor(goalID: nil),
            .goalEditor(goalID: SampleRouteID.goal),
            .goalContribution(goalID: SampleRouteID.goal),
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
    case budgets
    case goals
}

enum SampleRouteID {
    static let subscription = SeedData.ID.streamline
    static let transaction = SeedData.ID.streamlineTransaction
    static let budget = SeedData.ID.groceriesBudget
    static let goal = SeedData.ID.emergencyGoal
}
