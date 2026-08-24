import SwiftData

enum SiftModelContainerFactory {
    /// `let`, not a computed `var`. As a computed property every access built a *new*
    /// `Schema`, so `makeContainer` handed one instance to `ModelConfiguration` and a
    /// different one to `ModelContainer(for:)` -- the container and its own configuration
    /// disagreeing about which schema object they were using. One instance, resolved once.
    static let schema = Schema([
        LinkedAccount.self,
        Transaction.self,
        Subscription.self,
        CancellationRequest.self,
        Category.self,
        PriceChange.self,
        AlertSettings.self,
        RecurringIncome.self,
        Bill.self,
        Budget.self,
        Goal.self,
        GoalContribution.self,
        CategoryRule.self,
    ])

    static func makeContainer(inMemory: Bool = false) throws -> ModelContainer {
        let configuration = ModelConfiguration(
            "Sift",
            schema: schema,
            isStoredInMemoryOnly: inMemory,
            cloudKitDatabase: .none
        )
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    @MainActor
    static func makeSeededInMemoryContainer(userID: String = SeedData.defaultUserID) throws -> ModelContainer {
        let container = try makeContainer(inMemory: true)
        try SeedData.insertPreviewData(into: container.mainContext, userID: userID)
        return container
    }
}
