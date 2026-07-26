import Foundation

final class MockSubscriptionRepository: SubscriptionRepository, @unchecked Sendable {
    private var subscriptions: [Subscription]
    private var categories: [Category]
    private let userID: String

    init(snapshot: SeedData.Snapshot = SeedData.snapshot(), userID: String = SeedData.defaultUserID) {
        subscriptions = snapshot.subscriptions
        categories = snapshot.categories
        self.userID = userID
    }

    @MainActor
    func all() throws -> [Subscription] {
        subscriptions
            .filter { $0.userID == userID }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    @MainActor
    func subscription(id: String) throws -> Subscription? {
        try all().first { $0.id == id }
    }

    @MainActor
    func insert(_ subscription: Subscription) throws {
        subscriptions.append(subscription)
    }

    @MainActor
    func update(_ subscription: Subscription) throws {
        guard subscription.userID == userID else {
            throw SiftError.notFound("Subscription")
        }
    }

    @MainActor
    func delete(id: String) throws {
        subscriptions.removeAll { $0.id == id && $0.userID == userID }
    }

    @MainActor
    func deleteAll() throws {
        subscriptions.removeAll { $0.userID == userID }
    }

    @MainActor
    func monthlyTotal() throws -> Money {
        try subscriptionMonthlyTotal(for: all())
    }

    @MainActor
    func upcomingRenewals(limit: Int) throws -> [Subscription] {
        let renewals = try all()
            .filter { $0.status != .cancelled && $0.nextRenewal != nil }
            .sorted { lhs, rhs in
                guard let lhsDate = lhs.nextRenewal, let rhsDate = rhs.nextRenewal else {
                    return lhs.nextRenewal != nil
                }
                return lhsDate < rhsDate
            }

        return Array(renewals.prefix(limit))
    }

    @MainActor
    func upcomingRenewals(from startDate: Date, to endDate: Date) throws -> [Subscription] {
        try all()
            .filter { subscription in
                guard subscription.status != .cancelled, let renewal = subscription.nextRenewal else {
                    return false
                }
                return renewal >= startDate && renewal <= endDate
            }
            .sorted { ($0.nextRenewal ?? .distantFuture) < ($1.nextRenewal ?? .distantFuture) }
    }

    @MainActor
    func unused(referenceDate: Date, staleAfterDays: Int) throws -> [Subscription] {
        try unusedSubscriptions(from: all(), referenceDate: referenceDate, staleAfterDays: staleAfterDays)
    }

    @MainActor
    func byCategory() throws -> [SubscriptionCategoryGroup] {
        try categoryGroups(for: all().filter { $0.status != .cancelled }, categories: categories)
    }

    @MainActor
    func potentialSavings(referenceDate: Date, staleAfterDays: Int) throws -> Money {
        let values = try unused(referenceDate: referenceDate, staleAfterDays: staleAfterDays)
            .map(\.monthlyEquivalent)
        return try Money.sum(values)
    }
}

final class MockAccountRepository: AccountRepository, @unchecked Sendable {
    private var accounts: [LinkedAccount]
    private var onDeletePlaidItem: ((String) -> Void)?
    private let userID: String

    init(
        snapshot: SeedData.Snapshot = SeedData.snapshot(),
        userID: String = SeedData.defaultUserID,
        onDeletePlaidItem: ((String) -> Void)? = nil
    ) {
        accounts = snapshot.accounts
        self.userID = userID
        self.onDeletePlaidItem = onDeletePlaidItem
    }

    @MainActor
    func all() throws -> [LinkedAccount] {
        accounts
            .filter { $0.userID == userID }
            .sorted { $0.institutionName.localizedStandardCompare($1.institutionName) == .orderedAscending }
    }

    @MainActor
    func insert(_ account: LinkedAccount) throws {
        accounts.append(account)
    }

    @MainActor
    func replaceAll(with accounts: [LinkedAccount]) throws {
        self.accounts.removeAll { $0.userID == userID }
        self.accounts.append(contentsOf: accounts.filter { $0.userID == userID })
    }

    @MainActor
    func deletePlaidItem(id: String) throws {
        accounts.removeAll { account in
            account.userID == userID && (account.plaidItemID ?? account.id) == id
        }
        onDeletePlaidItem?(id)
    }

    @MainActor
    func deleteAll() throws {
        accounts.removeAll { $0.userID == userID }
    }
}

final class MockTransactionRepository: TransactionRepository, @unchecked Sendable {
    private var transactions: [Transaction]
    private let userID: String

    init(snapshot: SeedData.Snapshot = SeedData.snapshot(), userID: String = SeedData.defaultUserID) {
        transactions = snapshot.transactions
        self.userID = userID
    }

    @MainActor
    func all() throws -> [Transaction] {
        transactions
            .filter { $0.userID == userID }
            .sorted { $0.date > $1.date }
    }

    @MainActor
    func recent(limit: Int) throws -> [Transaction] {
        try Array(all().prefix(limit))
    }

    @MainActor
    func transactions(for accountID: String) throws -> [Transaction] {
        try all().filter { $0.accountID == accountID }
    }

    @MainActor
    func transactions(from startDate: Date, to endDate: Date) throws -> [Transaction] {
        try all().filter { $0.date >= startDate && $0.date <= endDate }
    }

    @MainActor
    func transaction(id: String) throws -> Transaction? {
        try all().first { $0.id == id }
    }

    @MainActor
    func insert(_ transaction: Transaction) throws {
        transactions.append(transaction)
    }

    @MainActor
    func upsert(_ transaction: Transaction) throws {
        if let index = transactions.firstIndex(where: { $0.id == transaction.id && $0.userID == userID }) {
            let existing = transactions[index]
            transaction.categoryID = existing.categoryID
            transaction.categoryManuallySet = existing.categoryManuallySet
            transaction.note = existing.note
            transactions[index] = transaction
        } else {
            transactions.append(transaction)
        }
    }

    @MainActor
    func update(_: Transaction) throws {}

    @MainActor
    func delete(id: String) throws {
        transactions.removeAll { $0.id == id && $0.userID == userID }
    }

    @MainActor
    func deleteAll() throws {
        transactions.removeAll { $0.userID == userID }
    }

    @MainActor
    func totalSpend(from startDate: Date, to endDate: Date) throws -> Money {
        let values = try transactions(from: startDate, to: endDate)
            .filter { $0.direction == .debit }
            .map(\.amount)
        return try Money.sum(values)
    }

    @MainActor
    func totalIncome(from startDate: Date, to endDate: Date) throws -> Money {
        let values = try transactions(from: startDate, to: endDate)
            .filter { $0.direction == .credit }
            .map(\.amount)
        return try Money.sum(values)
    }

    @MainActor
    func byCategory(from startDate: Date, to endDate: Date) throws -> [TransactionCategoryGroup] {
        let scoped = try transactions(from: startDate, to: endDate)
        let grouped = Dictionary(grouping: scoped, by: \.categoryID)
        return grouped.map { categoryID, transactions in
            TransactionCategoryGroup(
                categoryID: categoryID,
                categoryName: categoryID ?? "Uncategorized",
                transactions: transactions
            )
        }
    }
}

final class MockCancellationRepository: CancellationRepository, @unchecked Sendable {
    private var requests: [CancellationRequest]
    private let userID: String

    init(snapshot: SeedData.Snapshot = SeedData.snapshot(), userID: String = SeedData.defaultUserID) {
        requests = snapshot.cancellationRequests
        self.userID = userID
    }

    @MainActor
    func all() throws -> [CancellationRequest] {
        requests
            .filter { $0.userID == userID }
            .sorted { $0.createdAt > $1.createdAt }
    }

    @MainActor
    func requests(for subscriptionID: String) throws -> [CancellationRequest] {
        try all().filter { $0.subscriptionID == subscriptionID }
    }

    @MainActor
    func create(
        subscriptionID: String,
        method: CancellationMethod,
        note: String?,
        now: Date
    ) throws -> CancellationRequest {
        let request = CancellationRequest(
            id: "cancel-\(UUID().uuidString.lowercased())",
            userID: userID,
            subscriptionID: subscriptionID,
            method: method,
            status: .requested,
            createdAt: now,
            updatedAt: now,
            note: note
        )
        requests.append(request)
        return request
    }

    @MainActor
    func upsert(_ request: CancellationRequest) throws -> CancellationRequest {
        guard request.userID == userID else {
            throw SiftError.notFound("Cancellation request")
        }

        if let index = requests.firstIndex(where: { $0.id == request.id && $0.userID == userID }) {
            let existing = requests[index]
            existing.subscriptionID = request.subscriptionID
            existing.method = request.method
            existing.status = request.status
            existing.createdAt = request.createdAt
            existing.updatedAt = request.updatedAt
            existing.note = request.note
            return existing
        }

        requests.append(request)
        return request
    }

    @MainActor
    func updateStatus(id: String, status: CancellationStatus, now: Date) throws -> CancellationRequest {
        guard let request = requests.first(where: { $0.id == id && $0.userID == userID }) else {
            throw SiftError.notFound("Cancellation request")
        }

        request.status = status
        request.updatedAt = now
        return request
    }

    @MainActor
    func delete(id: String) throws {
        requests.removeAll { $0.id == id && $0.userID == userID }
    }

    @MainActor
    func deleteAll() throws {
        requests.removeAll { $0.userID == userID }
    }
}

final class MockCategoryRepository: CategoryRepository, @unchecked Sendable {
    private var categories: [Category]
    private let userID: String

    init(snapshot: SeedData.Snapshot = SeedData.snapshot(), userID: String = SeedData.defaultUserID) {
        categories = snapshot.categories
        self.userID = userID
    }

    @MainActor
    func all() throws -> [Category] {
        categories
            .filter { $0.userID == userID }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    @MainActor
    func category(id: String) throws -> Category? {
        try all().first { $0.id == id }
    }

    @MainActor
    func insert(_ category: Category) throws {
        categories.append(category)
    }

    @MainActor
    func update(_ category: Category) throws {
        guard category.userID == userID else {
            throw SiftError.notFound("Category")
        }
    }

    @MainActor
    func delete(id: String) throws {
        categories.removeAll { $0.id == id && $0.userID == userID }
    }

    @MainActor
    func deleteAll() throws {
        categories.removeAll { $0.userID == userID }
    }
}

final class MockPriceChangeRepository: PriceChangeRepository, @unchecked Sendable {
    private var priceChanges: [PriceChange]
    private let userID: String

    init(snapshot: SeedData.Snapshot = SeedData.snapshot(), userID: String = SeedData.defaultUserID) {
        priceChanges = snapshot.priceChanges
        self.userID = userID
    }

    @MainActor
    func all() throws -> [PriceChange] {
        priceChanges
            .filter { $0.userID == userID }
            .sorted { $0.changedAt > $1.changedAt }
    }

    @MainActor
    func changes(for subscriptionID: String) throws -> [PriceChange] {
        try all().filter { $0.subscriptionID == subscriptionID }
    }

    @MainActor
    func insert(_ priceChange: PriceChange) throws {
        priceChanges.append(priceChange)
    }

    @MainActor
    func deleteAll() throws {
        priceChanges.removeAll { $0.userID == userID }
    }
}

final class MockSettingsRepository: SettingsRepository, @unchecked Sendable {
    private var alertSettings: AlertSettings

    init(snapshot: SeedData.Snapshot = SeedData.snapshot()) {
        alertSettings = snapshot.alertSettings
    }

    @MainActor
    func settings() throws -> AlertSettings {
        alertSettings
    }

    @MainActor
    func update(_ settings: AlertSettings) throws {
        alertSettings = settings
    }

    @MainActor
    func deleteAll() throws {}
}

final class MockRecurringIncomeRepository: RecurringIncomeRepository, @unchecked Sendable {
    private var incomes: [RecurringIncome]
    private let userID: String

    init(snapshot: SeedData.Snapshot = SeedData.snapshot(), userID: String = SeedData.defaultUserID) {
        incomes = snapshot.recurringIncome
        self.userID = userID
    }

    @MainActor
    func all() throws -> [RecurringIncome] {
        incomes
            .filter { $0.userID == userID }
            .sorted { $0.sourceName.localizedStandardCompare($1.sourceName) == .orderedAscending }
    }

    @MainActor
    func recurringIncome(id: String) throws -> RecurringIncome? {
        try all().first { $0.id == id }
    }

    @MainActor
    func insert(_ income: RecurringIncome) throws {
        incomes.append(income)
    }

    @MainActor
    func update(_: RecurringIncome) throws {}

    @MainActor
    func delete(id: String) throws {
        incomes.removeAll { $0.id == id && $0.userID == userID }
    }

    @MainActor
    func deleteAll() throws {
        incomes.removeAll { $0.userID == userID }
    }

    @MainActor
    func nextExpectedIncome(after referenceDate: Date) throws -> RecurringIncome? {
        try all()
            .filter { income in
                guard income.status == .active, let expected = income.nextExpected else {
                    return false
                }
                return expected >= referenceDate
            }
            .min { ($0.nextExpected ?? .distantFuture) < ($1.nextExpected ?? .distantFuture) }
    }
}

final class MockBillRepository: BillRepository, @unchecked Sendable {
    private var bills: [Bill]
    private let userID: String

    init(snapshot: SeedData.Snapshot = SeedData.snapshot(), userID: String = SeedData.defaultUserID) {
        bills = snapshot.bills
        self.userID = userID
    }

    @MainActor
    func all() throws -> [Bill] {
        bills
            .filter { $0.userID == userID }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    @MainActor
    func bill(id: String) throws -> Bill? {
        try all().first { $0.id == id }
    }

    @MainActor
    func insert(_ bill: Bill) throws {
        bills.append(bill)
    }

    @MainActor
    func update(_: Bill) throws {}

    @MainActor
    func delete(id: String) throws {
        bills.removeAll { $0.id == id && $0.userID == userID }
    }

    @MainActor
    func deleteAll() throws {
        bills.removeAll { $0.userID == userID }
    }

    @MainActor
    func upcomingBills(from startDate: Date, to endDate: Date) throws -> [Bill] {
        try all()
            .filter { bill in
                guard bill.status == .active, let due = bill.nextDue else {
                    return false
                }
                return due >= startDate && due <= endDate
            }
            .sorted { ($0.nextDue ?? .distantFuture) < ($1.nextDue ?? .distantFuture) }
    }
}
