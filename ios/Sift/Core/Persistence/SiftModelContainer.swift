import SwiftData

enum SiftModelContainerFactory {
    static var schema: Schema {
        Schema([
            LinkedAccount.self,
            Transaction.self,
            Subscription.self,
            CancellationRequest.self,
            Category.self,
            PriceChange.self,
            AlertSettings.self,
            RecurringIncome.self,
            Bill.self,
        ])
    }

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
