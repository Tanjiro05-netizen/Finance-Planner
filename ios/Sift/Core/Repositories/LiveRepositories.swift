import Foundation
import SwiftData

final class LiveSubscriptionRepository: SubscriptionRepository, @unchecked Sendable {
    private let context: ModelContext
    private let userID: String

    init(modelContext: ModelContext, userID: String = SeedData.defaultUserID) {
        context = modelContext
        self.userID = userID
    }

    @MainActor
    func all() throws -> [Subscription] {
        try fetchUserScoped(Subscription.self, in: context, userID: userID)
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    @MainActor
    func subscription(id: String) throws -> Subscription? {
        try all().first { $0.id == id }
    }

    @MainActor
    func insert(_ subscription: Subscription) throws {
        context.insert(subscription)
        try context.save()
    }

    @MainActor
    func update(_ subscription: Subscription) throws {
        guard subscription.userID == userID else {
            throw SiftError.notFound("Subscription")
        }

        try context.save()
    }

    @MainActor
    func delete(id: String) throws {
        guard let subscription = try subscription(id: id) else {
            throw SiftError.notFound("Subscription")
        }

        context.delete(subscription)
        try context.save()
    }

    @MainActor
    func deleteAll() throws {
        for subscription in try all() {
            context.delete(subscription)
        }
        try context.save()
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
        let subscriptions = try all().filter { $0.status != .cancelled }
        let categories = try fetchUserScoped(Category.self, in: context, userID: userID)
        return categoryGroups(for: subscriptions, categories: categories)
    }

    @MainActor
    func potentialSavings(referenceDate: Date, staleAfterDays: Int) throws -> Money {
        let values = try unused(referenceDate: referenceDate, staleAfterDays: staleAfterDays)
            .map(\.monthlyEquivalent)
        return try Money.sum(values)
    }
}

final class LiveAccountRepository: AccountRepository, @unchecked Sendable {
    private let context: ModelContext
    private let userID: String

    init(modelContext: ModelContext, userID: String = SeedData.defaultUserID) {
        context = modelContext
        self.userID = userID
    }

    @MainActor
    func all() throws -> [LinkedAccount] {
        try fetchUserScoped(LinkedAccount.self, in: context, userID: userID)
            .sorted { $0.institutionName.localizedStandardCompare($1.institutionName) == .orderedAscending }
    }

    @MainActor
    func insert(_ account: LinkedAccount) throws {
        context.insert(account)
        try context.save()
    }

    @MainActor
    func replaceAll(with accounts: [LinkedAccount]) throws {
        try deleteAll()
        for account in accounts where account.userID == userID {
            context.insert(account)
        }
        try context.save()
    }

    @MainActor
    func deletePlaidItem(id: String) throws {
        let accounts = try all().filter { ($0.plaidItemID ?? $0.id) == id }
        let accountIDs = Set(accounts.map(\.id))
        let transactions = try fetchUserScoped(Transaction.self, in: context, userID: userID)

        for transaction in transactions where accountIDs.contains(transaction.accountID) {
            context.delete(transaction)
        }

        for account in accounts {
            context.delete(account)
        }

        try context.save()
    }

    @MainActor
    func deleteAll() throws {
        for account in try all() {
            context.delete(account)
        }
        try context.save()
    }
}

final class LiveTransactionRepository: TransactionRepository, @unchecked Sendable {
    private let context: ModelContext
    private let userID: String

    init(modelContext: ModelContext, userID: String = SeedData.defaultUserID) {
        context = modelContext
        self.userID = userID
    }

    @MainActor
    func all() throws -> [Transaction] {
        try fetchUserScoped(Transaction.self, in: context, userID: userID)
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
        let scopedUserID = userID
        var descriptor = FetchDescriptor<Transaction>(
            predicate: #Predicate { transaction in
                transaction.userID == scopedUserID &&
                    transaction.date >= startDate &&
                    transaction.date <= endDate
            }
        )
        descriptor.sortBy = [SortDescriptor(\.date, order: .reverse)]
        return try context.fetch(descriptor)
    }

    @MainActor
    func transaction(id: String) throws -> Transaction? {
        try all().first { $0.id == id }
    }

    @MainActor
    func insert(_ transaction: Transaction) throws {
        context.insert(transaction)
        try context.save()
    }

    @MainActor
    func upsert(_ transaction: Transaction) throws {
        if let existing = try all().first(where: { $0.id == transaction.id }) {
            existing.accountID = transaction.accountID
            existing.merchantRaw = transaction.merchantRaw
            existing.merchantKey = transaction.merchantKey
            existing.amount = transaction.amount
            existing.date = transaction.date
            existing.pending = transaction.pending
            existing.categoryHint = transaction.categoryHint
            existing.direction = transaction.direction
            existing.kind = transaction.kind
            existing.source = transaction.source
            // categoryID/categoryManuallySet/note are left untouched: a re-sync from the
            // source never carries a resolved category, so copying them here would wipe
            // out whatever CategoryService or the person themselves already assigned.
        } else {
            context.insert(transaction)
        }

        try context.save()
    }

    @MainActor
    func update(_ transaction: Transaction) throws {
        guard transaction.userID == userID else {
            throw SiftError.notFound("Transaction")
        }

        try context.save()
    }

    @MainActor
    func delete(id: String) throws {
        guard let transaction = try transaction(id: id) else {
            throw SiftError.notFound("Transaction")
        }

        context.delete(transaction)
        try context.save()
    }

    @MainActor
    func deleteAll() throws {
        for transaction in try all() {
            context.delete(transaction)
        }
        try context.save()
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
        let categories = try fetchUserScoped(Category.self, in: context, userID: userID)
        let namesByID = Dictionary(uniqueKeysWithValues: categories.map { ($0.id, $0.name) })

        let grouped = Dictionary(grouping: scoped, by: \.categoryID)
        return grouped.map { categoryID, transactions in
            TransactionCategoryGroup(
                categoryID: categoryID,
                categoryName: categoryID.flatMap { namesByID[$0] } ?? "Uncategorized",
                transactions: transactions
            )
        }
    }
}

final class LiveCancellationRepository: CancellationRepository, @unchecked Sendable {
    private let context: ModelContext
    private let userID: String

    init(modelContext: ModelContext, userID: String = SeedData.defaultUserID) {
        context = modelContext
        self.userID = userID
    }

    @MainActor
    func all() throws -> [CancellationRequest] {
        try fetchUserScoped(CancellationRequest.self, in: context, userID: userID)
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
        context.insert(request)
        try context.save()
        return request
    }

    @MainActor
    func upsert(_ request: CancellationRequest) throws -> CancellationRequest {
        guard request.userID == userID else {
            throw SiftError.notFound("Cancellation request")
        }

        if let existing = try all().first(where: { $0.id == request.id }) {
            existing.subscriptionID = request.subscriptionID
            existing.method = request.method
            existing.status = request.status
            existing.createdAt = request.createdAt
            existing.updatedAt = request.updatedAt
            existing.note = request.note
            try context.save()
            return existing
        }

        context.insert(request)
        try context.save()
        return request
    }

    @MainActor
    func updateStatus(id: String, status: CancellationStatus, now: Date) throws -> CancellationRequest {
        guard let request = try all().first(where: { $0.id == id }) else {
            throw SiftError.notFound("Cancellation request")
        }

        request.status = status
        request.updatedAt = now
        try context.save()
        return request
    }

    @MainActor
    func delete(id: String) throws {
        guard let request = try all().first(where: { $0.id == id }) else {
            return
        }

        context.delete(request)
        try context.save()
    }

    @MainActor
    func deleteAll() throws {
        for request in try all() {
            context.delete(request)
        }
        try context.save()
    }
}

final class LiveCategoryRepository: CategoryRepository, @unchecked Sendable {
    private let context: ModelContext
    private let userID: String

    init(modelContext: ModelContext, userID: String = SeedData.defaultUserID) {
        context = modelContext
        self.userID = userID
    }

    @MainActor
    func all() throws -> [Category] {
        try fetchUserScoped(Category.self, in: context, userID: userID)
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    @MainActor
    func category(id: String) throws -> Category? {
        try all().first { $0.id == id }
    }

    @MainActor
    func insert(_ category: Category) throws {
        context.insert(category)
        try context.save()
    }

    @MainActor
    func update(_ category: Category) throws {
        guard category.userID == userID else {
            throw SiftError.notFound("Category")
        }

        try context.save()
    }

    @MainActor
    func delete(id: String) throws {
        guard let category = try category(id: id) else {
            return
        }

        context.delete(category)
        try context.save()
    }

    @MainActor
    func deleteAll() throws {
        for category in try all() {
            context.delete(category)
        }
        try context.save()
    }
}

final class LivePriceChangeRepository: PriceChangeRepository, @unchecked Sendable {
    private let context: ModelContext
    private let userID: String

    init(modelContext: ModelContext, userID: String = SeedData.defaultUserID) {
        context = modelContext
        self.userID = userID
    }

    @MainActor
    func all() throws -> [PriceChange] {
        try fetchUserScoped(PriceChange.self, in: context, userID: userID)
            .sorted { $0.changedAt > $1.changedAt }
    }

    @MainActor
    func changes(for subscriptionID: String) throws -> [PriceChange] {
        try all().filter { $0.subscriptionID == subscriptionID }
    }

    @MainActor
    func insert(_ priceChange: PriceChange) throws {
        context.insert(priceChange)
        try context.save()
    }

    @MainActor
    func deleteAll() throws {
        for priceChange in try all() {
            context.delete(priceChange)
        }
        try context.save()
    }
}

final class LiveSettingsRepository: SettingsRepository, @unchecked Sendable {
    private let context: ModelContext
    private let userID: String

    init(modelContext: ModelContext, userID: String = SeedData.defaultUserID) {
        context = modelContext
        self.userID = userID
    }

    @MainActor
    func settings() throws -> AlertSettings {
        if let settings = try fetchUserScoped(AlertSettings.self, in: context, userID: userID).first {
            return settings
        }

        let settings = AlertSettings(
            id: SeedData.ID.alertSettings,
            userID: userID,
            renewalReminders: true,
            priceChanges: true,
            trialEndings: true,
            unusedNudges: true,
            weeklySummary: false
        )
        context.insert(settings)
        try context.save()
        return settings
    }

    @MainActor
    func update(_ settings: AlertSettings) throws {
        guard settings.userID == userID else {
            throw SiftError.notFound("Alert settings")
        }

        try context.save()
    }

    @MainActor
    func deleteAll() throws {
        for settings in try fetchUserScoped(AlertSettings.self, in: context, userID: userID) {
            context.delete(settings)
        }
        try context.save()
    }
}

final class LiveRecurringIncomeRepository: RecurringIncomeRepository, @unchecked Sendable {
    private let context: ModelContext
    private let userID: String

    init(modelContext: ModelContext, userID: String = SeedData.defaultUserID) {
        context = modelContext
        self.userID = userID
    }

    @MainActor
    func all() throws -> [RecurringIncome] {
        try fetchUserScoped(RecurringIncome.self, in: context, userID: userID)
            .sorted { $0.sourceName.localizedStandardCompare($1.sourceName) == .orderedAscending }
    }

    @MainActor
    func recurringIncome(id: String) throws -> RecurringIncome? {
        try all().first { $0.id == id }
    }

    @MainActor
    func insert(_ income: RecurringIncome) throws {
        context.insert(income)
        try context.save()
    }

    @MainActor
    func update(_ income: RecurringIncome) throws {
        guard income.userID == userID else {
            throw SiftError.notFound("Recurring income")
        }
        try context.save()
    }

    @MainActor
    func delete(id: String) throws {
        guard let income = try recurringIncome(id: id) else {
            throw SiftError.notFound("Recurring income")
        }
        context.delete(income)
        try context.save()
    }

    @MainActor
    func deleteAll() throws {
        for income in try all() {
            context.delete(income)
        }
        try context.save()
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

final class LiveBillRepository: BillRepository, @unchecked Sendable {
    private let context: ModelContext
    private let userID: String

    init(modelContext: ModelContext, userID: String = SeedData.defaultUserID) {
        context = modelContext
        self.userID = userID
    }

    @MainActor
    func all() throws -> [Bill] {
        try fetchUserScoped(Bill.self, in: context, userID: userID)
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    @MainActor
    func bill(id: String) throws -> Bill? {
        try all().first { $0.id == id }
    }

    @MainActor
    func insert(_ bill: Bill) throws {
        context.insert(bill)
        try context.save()
    }

    @MainActor
    func update(_ bill: Bill) throws {
        guard bill.userID == userID else {
            throw SiftError.notFound("Bill")
        }
        try context.save()
    }

    @MainActor
    func delete(id: String) throws {
        guard let bill = try bill(id: id) else {
            throw SiftError.notFound("Bill")
        }
        context.delete(bill)
        try context.save()
    }

    @MainActor
    func deleteAll() throws {
        for bill in try all() {
            context.delete(bill)
        }
        try context.save()
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

final class LiveBudgetRepository: BudgetRepository, @unchecked Sendable {
    private let context: ModelContext
    private let userID: String

    init(modelContext: ModelContext, userID: String = SeedData.defaultUserID) {
        context = modelContext
        self.userID = userID
    }

    @MainActor
    func all() throws -> [Budget] {
        try fetchUserScoped(Budget.self, in: context, userID: userID)
            .sorted { $0.categoryID.localizedStandardCompare($1.categoryID) == .orderedAscending }
    }

    @MainActor
    func budget(id: String) throws -> Budget? {
        try all().first { $0.id == id }
    }

    @MainActor
    func budget(forCategory categoryID: String) throws -> Budget? {
        try all().first { $0.categoryID == categoryID && $0.status == .active }
    }

    @MainActor
    func insert(_ budget: Budget) throws {
        context.insert(budget)
        try context.save()
    }

    @MainActor
    func update(_ budget: Budget) throws {
        guard budget.userID == userID else {
            throw SiftError.notFound("Budget")
        }
        try context.save()
    }

    @MainActor
    func delete(id: String) throws {
        guard let budget = try budget(id: id) else {
            throw SiftError.notFound("Budget")
        }
        context.delete(budget)
        try context.save()
    }

    @MainActor
    func deleteAll() throws {
        for budget in try all() {
            context.delete(budget)
        }
        try context.save()
    }
}

@MainActor
private func fetchUserScoped<Model: PersistentModel>(
    _: Model.Type,
    in context: ModelContext,
    userID: String
) throws -> [Model] {
    let models = try context.fetch(FetchDescriptor<Model>())
    return models.filter { item in
        switch item {
        case let account as LinkedAccount:
            account.userID == userID
        case let transaction as Transaction:
            transaction.userID == userID
        case let subscription as Subscription:
            subscription.userID == userID
        case let request as CancellationRequest:
            request.userID == userID
        case let category as Category:
            category.userID == userID
        case let priceChange as PriceChange:
            priceChange.userID == userID
        case let settings as AlertSettings:
            settings.userID == userID
        case let income as RecurringIncome:
            income.userID == userID
        case let bill as Bill:
            bill.userID == userID
        case let budget as Budget:
            budget.userID == userID
        default:
            false
        }
    }
}

func subscriptionMonthlyTotal(for subscriptions: [Subscription]) throws -> Money {
    let values = subscriptions
        .filter { $0.status != .cancelled }
        .map(\.monthlyEquivalent)
    return try Money.sum(values)
}

func unusedSubscriptions(
    from subscriptions: [Subscription],
    referenceDate: Date,
    staleAfterDays: Int
) -> [Subscription] {
    let cutoff = Calendar.utc.date(byAdding: .day, value: -staleAfterDays, to: referenceDate) ?? referenceDate
    return subscriptions
        .filter { subscription in
            guard subscription.status != .cancelled, let lastUsed = subscription.lastUsed else {
                return false
            }
            return lastUsed <= cutoff
        }
        .sorted { $0.monthlyEquivalent.amountMinor > $1.monthlyEquivalent.amountMinor }
}

func categoryGroups(for subscriptions: [Subscription], categories: [Category]) -> [SubscriptionCategoryGroup] {
    let categoryNames = Dictionary(uniqueKeysWithValues: categories.map { ($0.id, $0.name) })
    let grouped = Dictionary(grouping: subscriptions) { subscription in
        subscription.categoryID
    }

    return grouped
        .map { categoryID, subscriptions in
            SubscriptionCategoryGroup(
                categoryID: categoryID,
                categoryName: categoryID.flatMap { categoryNames[$0] } ?? "Other",
                subscriptions: subscriptions.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
            )
        }
        .sorted { $0.categoryName.localizedStandardCompare($1.categoryName) == .orderedAscending }
}
