import Foundation

@MainActor
final class CategoryService {
    struct KeywordRule {
        let name: String
        let iconToken: String
        let keywords: [String]
    }

    /// Keyword map: merchant keys and Plaid categories are lowercased, then matched
    /// against these stable terms. Manual category overrides set categoryManuallySet
    /// and are never changed by automatic categorisation.
    static let keywordRules: [KeywordRule] = [
        KeywordRule(name: "Streaming", iconToken: "play.rectangle", keywords: ["stream", "netflix", "hulu", "video", "reel", "entertainment"]),
        KeywordRule(name: "Audio", iconToken: "waveform", keywords: ["audio", "music", "spotify", "tonebox", "podcast"]),
        KeywordRule(name: "Design", iconToken: "paintpalette", keywords: ["design", "adobe", "creative", "figma", "canva"]),
        KeywordRule(name: "Productivity", iconToken: "square.and.pencil", keywords: ["productivity", "note", "readwise", "cloud", "daybook", "parcel"]),
        KeywordRule(name: "Security", iconToken: "lock.shield", keywords: ["security", "vpn", "password", "atlas"]),
        KeywordRule(name: "Health", iconToken: "heart.text.square", keywords: ["health", "fitness", "workout", "wellness"]),
        KeywordRule(name: "Groceries", iconToken: "basket", keywords: ["grocery", "groceries", "supermarket"]),
        KeywordRule(name: "Dining", iconToken: "fork.knife", keywords: ["dining", "restaurant", "cafe", "coffee", "diner", "kitchen", "bistro"]),
    ]

    private let repositories: RepositoryContainer

    init(repositories: RepositoryContainer) {
        self.repositories = repositories
    }

    func applyAutoCategorizationIfEnabled() throws {
        guard try repositories.settings.settings().autoCategorizeSubscriptions else {
            return
        }

        let transactions = try repositories.transactions.all()
        let categoryIDsByName = try ensureRuleCategories()
        let hintsByMerchant = Dictionary(grouping: transactions, by: \.merchantKey)
            .mapValues { values in
                values.compactMap(\.categoryHint).joined(separator: " ")
            }

        for subscription in try repositories.subscriptions.all() where !subscription.categoryManuallySet {
            let searchable = searchable(merchantKey: subscription.merchantKey, hint: hintsByMerchant[subscription.merchantKey])
            guard let rule = rule(for: searchable) else {
                continue
            }

            subscription.categoryID = categoryIDsByName[rule.name.lowercased()]
            try repositories.subscriptions.update(subscription)
        }
    }

    /// Same auto-categorization pass as `applyAutoCategorizationIfEnabled()`, applied to
    /// ledger transactions instead of subscriptions: a transaction's own `categoryHint`
    /// (its raw Plaid/FinanceKit category, if any) stands in for the merchant lookup.
    func applyAutoCategorizationForTransactions() throws {
        guard try repositories.settings.settings().autoCategorizeSubscriptions else {
            return
        }

        let categoryIDsByName = try ensureRuleCategories()

        for transaction in try repositories.transactions.all() where !transaction.categoryManuallySet {
            let searchable = searchable(merchantKey: transaction.merchantKey, hint: transaction.categoryHint)
            guard let rule = rule(for: searchable) else {
                continue
            }

            transaction.categoryID = categoryIDsByName[rule.name.lowercased()]
            try repositories.transactions.update(transaction)
        }
    }

    func manuallyAssign(subscriptionID: String, categoryID: String?) throws {
        guard let subscription = try repositories.subscriptions.subscription(id: subscriptionID) else {
            throw SiftError.notFound("Subscription")
        }

        subscription.categoryID = categoryID
        subscription.categoryManuallySet = true
        try repositories.subscriptions.update(subscription)
    }

    func manuallyAssign(transactionID: String, categoryID: String?) throws {
        guard let transaction = try repositories.transactions.transaction(id: transactionID) else {
            throw SiftError.notFound("Transaction")
        }

        transaction.categoryID = categoryID
        transaction.categoryManuallySet = true
        try repositories.transactions.update(transaction)
    }

    func mergeCategory(id sourceID: String, into targetID: String) throws {
        guard sourceID != targetID else {
            return
        }

        for subscription in try repositories.subscriptions.all() where subscription.categoryID == sourceID {
            subscription.categoryID = targetID
            subscription.categoryManuallySet = true
            try repositories.subscriptions.update(subscription)
        }

        for transaction in try repositories.transactions.all() where transaction.categoryID == sourceID {
            transaction.categoryID = targetID
            transaction.categoryManuallySet = true
            try repositories.transactions.update(transaction)
        }

        try repositories.categories.delete(id: sourceID)
    }

    private func ensureRuleCategories() throws -> [String: String] {
        var categories = try repositories.categories.all()

        for rule in Self.keywordRules where !categories.contains(where: { $0.name.caseInsensitiveCompare(rule.name) == .orderedSame }) {
            let category = Category(
                id: "cat-\(MerchantKey(rule.name).rawValue)",
                userID: SeedData.defaultUserID,
                name: rule.name,
                iconToken: rule.iconToken,
                isAuto: true
            )
            try repositories.categories.insert(category)
            categories.append(category)
        }

        return Dictionary(uniqueKeysWithValues: categories.map { ($0.name.lowercased(), $0.id) })
    }

    private func searchable(merchantKey: MerchantKey, hint: String?) -> String {
        "\(merchantKey.rawValue) \(hint ?? "")".lowercased()
    }

    private func rule(for searchable: String) -> KeywordRule? {
        Self.keywordRules.first { rule in
            rule.keywords.contains { searchable.contains($0) }
        }
    }
}
