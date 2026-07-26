import Foundation

protocol SubscriptionRepository: AnyObject, Sendable {
    @MainActor func all() throws -> [Subscription]
    @MainActor func subscription(id: String) throws -> Subscription?
    @MainActor func insert(_ subscription: Subscription) throws
    @MainActor func update(_ subscription: Subscription) throws
    @MainActor func delete(id: String) throws
    @MainActor func deleteAll() throws
    @MainActor func monthlyTotal() throws -> Money
    @MainActor func upcomingRenewals(limit: Int) throws -> [Subscription]
    @MainActor func upcomingRenewals(from startDate: Date, to endDate: Date) throws -> [Subscription]
    @MainActor func unused(referenceDate: Date, staleAfterDays: Int) throws -> [Subscription]
    @MainActor func byCategory() throws -> [SubscriptionCategoryGroup]
    @MainActor func potentialSavings(referenceDate: Date, staleAfterDays: Int) throws -> Money
}

extension SubscriptionRepository {
    @MainActor func unused() throws -> [Subscription] {
        try unused(referenceDate: referenceDate, staleAfterDays: staleAfterDays)
    }

    @MainActor func potentialSavings() throws -> Money {
        try potentialSavings(referenceDate: referenceDate, staleAfterDays: staleAfterDays)
    }

    private var referenceDate: Date {
        SeedData.referenceDate
    }

    private var staleAfterDays: Int {
        60
    }
}

protocol AccountRepository: AnyObject, Sendable {
    @MainActor func all() throws -> [LinkedAccount]
    @MainActor func insert(_ account: LinkedAccount) throws
    @MainActor func replaceAll(with accounts: [LinkedAccount]) throws
    @MainActor func deletePlaidItem(id: String) throws
    @MainActor func deleteAll() throws
}

extension AccountRepository {
    /// Spendable cash across linked deposit accounts. Credit/liability accounts are
    /// excluded (a card balance is money owed, not money to spend). Returns nil only when
    /// no account reports any balance at all (FinanceKit unauthorized or not yet synced);
    /// a partial sum is returned when some accounts have balances and others don't.
    @MainActor func totalBalance() throws -> Money? {
        // LinkedAccount.type is an unstructured String today ("Checking"/"Credit"); this is
        // a string-match heuristic until type is promoted to a proper enum.
        let balances = try all()
            .filter { !$0.type.localizedCaseInsensitiveContains("credit") }
            .compactMap(\.currentBalance)
        guard !balances.isEmpty else {
            return nil
        }
        return try? Money.sum(balances)
    }
}

protocol RecurringIncomeRepository: AnyObject, Sendable {
    @MainActor func all() throws -> [RecurringIncome]
    @MainActor func recurringIncome(id: String) throws -> RecurringIncome?
    @MainActor func insert(_ income: RecurringIncome) throws
    @MainActor func update(_ income: RecurringIncome) throws
    @MainActor func delete(id: String) throws
    @MainActor func deleteAll() throws
    @MainActor func nextExpectedIncome(after referenceDate: Date) throws -> RecurringIncome?
}

protocol BillRepository: AnyObject, Sendable {
    @MainActor func all() throws -> [Bill]
    @MainActor func bill(id: String) throws -> Bill?
    @MainActor func insert(_ bill: Bill) throws
    @MainActor func update(_ bill: Bill) throws
    @MainActor func delete(id: String) throws
    @MainActor func deleteAll() throws
    @MainActor func upcomingBills(from startDate: Date, to endDate: Date) throws -> [Bill]
}

protocol TransactionRepository: AnyObject, Sendable {
    @MainActor func all() throws -> [Transaction]
    @MainActor func recent(limit: Int) throws -> [Transaction]
    @MainActor func transactions(for accountID: String) throws -> [Transaction]
    @MainActor func transactions(from startDate: Date, to endDate: Date) throws -> [Transaction]
    @MainActor func transaction(id: String) throws -> Transaction?
    @MainActor func insert(_ transaction: Transaction) throws
    @MainActor func upsert(_ transaction: Transaction) throws
    @MainActor func update(_ transaction: Transaction) throws
    @MainActor func delete(id: String) throws
    @MainActor func deleteAll() throws
    @MainActor func totalSpend(from startDate: Date, to endDate: Date) throws -> Money
    @MainActor func totalIncome(from startDate: Date, to endDate: Date) throws -> Money
    @MainActor func byCategory(from startDate: Date, to endDate: Date) throws -> [TransactionCategoryGroup]
}

protocol CancellationRepository: AnyObject, Sendable {
    @MainActor func all() throws -> [CancellationRequest]
    @MainActor func requests(for subscriptionID: String) throws -> [CancellationRequest]
    @MainActor func create(
        subscriptionID: String,
        method: CancellationMethod,
        note: String?,
        now: Date
    ) throws -> CancellationRequest
    @MainActor func upsert(_ request: CancellationRequest) throws -> CancellationRequest
    @MainActor func updateStatus(id: String, status: CancellationStatus, now: Date) throws -> CancellationRequest
    @MainActor func delete(id: String) throws
    @MainActor func deleteAll() throws
}

protocol CategoryRepository: AnyObject, Sendable {
    @MainActor func all() throws -> [Category]
    @MainActor func category(id: String) throws -> Category?
    @MainActor func insert(_ category: Category) throws
    @MainActor func update(_ category: Category) throws
    @MainActor func delete(id: String) throws
    @MainActor func deleteAll() throws
}

protocol PriceChangeRepository: AnyObject, Sendable {
    @MainActor func all() throws -> [PriceChange]
    @MainActor func changes(for subscriptionID: String) throws -> [PriceChange]
    @MainActor func insert(_ priceChange: PriceChange) throws
    @MainActor func deleteAll() throws
}

protocol SettingsRepository: AnyObject, Sendable {
    @MainActor func settings() throws -> AlertSettings
    @MainActor func update(_ settings: AlertSettings) throws
    @MainActor func deleteAll() throws
}
