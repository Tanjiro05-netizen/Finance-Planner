import Foundation

/// `CategoryRuleRepository` over a JSON blob in `UserDefaults`.
///
/// Named for what it is rather than `Live*`, because unlike its siblings it is not a
/// SwiftData adapter -- see the note on `CategoryRule` for why rules are a value type.
/// It follows the `UserDefaultsFinancialSyncState` /
/// `UserDefaultsCancellationReminderIntentStore` convention already in this codebase.
///
/// Rules are a short ordered list read in full on every evaluation pass, so it decodes the
/// whole array rather than indexing into it. Anything large enough for that to matter would
/// belong back in a real store.
final class UserDefaultsCategoryRuleRepository: CategoryRuleRepository, @unchecked Sendable {
    // UserDefaults is thread-safe but not marked Sendable.
    private nonisolated(unsafe) let defaults: UserDefaults
    private let userID: String
    private let key = "sift.categoryRules"

    init(defaults: UserDefaults = .standard, userID: String = SeedData.defaultUserID) {
        self.defaults = defaults
        self.userID = userID
    }

    @MainActor
    func all() throws -> [CategoryRule] {
        stored()
            .filter { $0.userID == userID }
            .sorted { $0.sortIndex < $1.sortIndex }
    }

    @MainActor
    func rule(id: String) throws -> CategoryRule? {
        try all().first { $0.id == id }
    }

    @MainActor
    func insert(_ rule: CategoryRule) throws {
        var rules = stored()
        rules.append(rule)
        write(rules)
    }

    @MainActor
    func update(_ rule: CategoryRule) throws {
        guard rule.userID == userID else {
            throw SiftError.notFound("Rule")
        }

        var rules = stored()
        guard let index = rules.firstIndex(where: { $0.id == rule.id && $0.userID == userID }) else {
            throw SiftError.notFound("Rule")
        }

        rules[index] = rule
        write(rules)
    }

    @MainActor
    func delete(id: String) throws {
        var rules = stored()
        guard let index = rules.firstIndex(where: { $0.id == id && $0.userID == userID }) else {
            throw SiftError.notFound("Rule")
        }

        rules.remove(at: index)
        write(rules)
    }

    @MainActor
    func reorder(ids: [String]) throws {
        var rules = stored()
        for (position, id) in ids.enumerated() {
            guard let index = rules.firstIndex(where: { $0.id == id && $0.userID == userID }) else {
                continue
            }
            rules[index].sortIndex = position
        }
        write(rules)
    }

    @MainActor
    func deleteAll() throws {
        write(stored().filter { $0.userID != userID })
    }

    /// Every rule for every user. A decode failure yields an empty list rather than
    /// throwing: a corrupt blob should cost the person their rules, not the whole app.
    private func stored() -> [CategoryRule] {
        guard let data = defaults.data(forKey: key) else {
            return []
        }
        return (try? JSONDecoder().decode([CategoryRule].self, from: data)) ?? []
    }

    private func write(_ rules: [CategoryRule]) {
        guard let data = try? JSONEncoder().encode(rules) else {
            return
        }
        defaults.set(data, forKey: key)
    }
}
