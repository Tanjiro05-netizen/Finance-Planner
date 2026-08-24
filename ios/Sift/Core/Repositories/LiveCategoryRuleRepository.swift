import SwiftData

/// Lives in its own file rather than alongside the other live repositories: adding it to
/// `LiveRepositories.swift` pushed that file past SwiftLint's 900-line `file_length` error
/// threshold. Splitting is the honest fix -- the repo already carries one
/// `swiftlint:disable file_length`, and a second would just be hiding the same problem.
///
/// `fetchUserScoped` is shared from `LiveRepositories.swift`, which is why it is internal
/// rather than file-private there.
final class LiveCategoryRuleRepository: CategoryRuleRepository, @unchecked Sendable {
    private let context: ModelContext
    private let userID: String

    init(modelContext: ModelContext, userID: String = SeedData.defaultUserID) {
        context = modelContext
        self.userID = userID
    }

    @MainActor
    func all() throws -> [CategoryRule] {
        try fetchUserScoped(CategoryRule.self, in: context, userID: userID)
            .sorted { $0.order < $1.order }
    }

    @MainActor
    func rule(id: String) throws -> CategoryRule? {
        try all().first { $0.id == id }
    }

    @MainActor
    func insert(_ rule: CategoryRule) throws {
        context.insert(rule)
        try context.save()
    }

    @MainActor
    func update(_ rule: CategoryRule) throws {
        guard rule.userID == userID else {
            throw SiftError.notFound("Rule")
        }
        try context.save()
    }

    @MainActor
    func delete(id: String) throws {
        guard let rule = try rule(id: id) else {
            throw SiftError.notFound("Rule")
        }
        context.delete(rule)
        try context.save()
    }

    @MainActor
    func reorder(ids: [String]) throws {
        let rulesByID = try Dictionary(uniqueKeysWithValues: all().map { ($0.id, $0) })
        for (index, id) in ids.enumerated() {
            rulesByID[id]?.order = index
        }
        try context.save()
    }

    @MainActor
    func deleteAll() throws {
        for rule in try all() {
            context.delete(rule)
        }
        try context.save()
    }
}
