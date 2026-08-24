import Foundation
@testable import Sift
import SwiftData
import Testing

@MainActor
struct CategoryRuleViewModelTests {
    private struct Fixture {
        let container: ModelContainer
        let repositories: RepositoryContainer
    }

    private func makeFixture() throws -> Fixture {
        let container = try SiftModelContainerFactory.makeSeededInMemoryContainer()
        return Fixture(container: container, repositories: .live(modelContext: container.mainContext))
    }

    private func insertRule(
        _ fixture: Fixture,
        id: String,
        pattern: String,
        sortIndex: Int,
        isEnabled: Bool = true
    ) throws {
        try fixture.repositories.categoryRules.insert(CategoryRule(
            id: id,
            userID: SeedData.defaultUserID,
            kind: .merchantContains,
            pattern: pattern,
            categoryID: SeedData.ID.dining,
            sortIndex: sortIndex,
            isEnabled: isEnabled
        ))
    }

    // MARK: - List

    @Test func listStartsEmptyAndLoadsInOrder() throws {
        let fixture = try makeFixture()
        let viewModel = CategoryRulesViewModel(repositories: fixture.repositories)

        viewModel.load()
        #expect(viewModel.isEmpty)

        try insertRule(fixture, id: "b", pattern: "B", sortIndex: 1)
        try insertRule(fixture, id: "a", pattern: "A", sortIndex: 0)
        viewModel.load()

        #expect(viewModel.isEmpty == false)
        #expect(viewModel.rules.map(\.id) == ["a", "b"])
    }

    @Test func summaryReadsAsASentence() throws {
        let fixture = try makeFixture()
        try insertRule(fixture, id: "a", pattern: "BLUE BOTTLE", sortIndex: 0)
        let viewModel = CategoryRulesViewModel(repositories: fixture.repositories)
        viewModel.load()

        let rule = try #require(viewModel.rules.first)
        #expect(viewModel.summary(for: rule) == "Merchant name contains \"BLUE BOTTLE\"")
        #expect(viewModel.categoryName(for: rule) == "Dining")
    }

    @Test func moveRewritesOrder() throws {
        let fixture = try makeFixture()
        try insertRule(fixture, id: "a", pattern: "A", sortIndex: 0)
        try insertRule(fixture, id: "b", pattern: "B", sortIndex: 1)
        try insertRule(fixture, id: "c", pattern: "C", sortIndex: 2)
        let viewModel = CategoryRulesViewModel(repositories: fixture.repositories)
        viewModel.load()

        viewModel.move(from: IndexSet(integer: 2), to: 0)

        #expect(viewModel.rules.map(\.id) == ["c", "a", "b"])
        #expect(viewModel.rules.map(\.sortIndex) == [0, 1, 2])
    }

    @Test func deleteRemovesTheRuleAndReloads() throws {
        let fixture = try makeFixture()
        try insertRule(fixture, id: "a", pattern: "A", sortIndex: 0)
        try insertRule(fixture, id: "b", pattern: "B", sortIndex: 1)
        let viewModel = CategoryRulesViewModel(repositories: fixture.repositories)
        viewModel.load()

        viewModel.delete(id: "a")

        #expect(viewModel.rules.map(\.id) == ["b"])
        #expect(viewModel.errorMessage == nil)
    }

    /// Turning a rule off has to re-run too: it changes the outcome exactly as much as
    /// editing one does. The rule points somewhere the built-in keywords never would, so
    /// the revert is visible rather than coincidental.
    @Test func disablingARuleRevertsWhatItHadCategorised() throws {
        let fixture = try makeFixture()
        try fixture.repositories.categoryRules.insert(CategoryRule(
            id: "a",
            userID: SeedData.defaultUserID,
            kind: .merchantContains,
            pattern: "BLUE BOTTLE",
            categoryID: SeedData.ID.audio,
            sortIndex: 0
        ))
        let viewModel = CategoryRulesViewModel(repositories: fixture.repositories)
        viewModel.load()
        viewModel.rerun()

        func coffeeCategory() throws -> String? {
            try fixture.repositories.transactions.all()
                .first { $0.merchantRaw.localizedCaseInsensitiveContains("BLUE BOTTLE") }?
                .categoryID
        }

        #expect(try coffeeCategory() == SeedData.ID.audio)

        let rule = try #require(viewModel.rules.first)
        viewModel.setEnabled(false, for: rule)

        // Back to the built-in keyword outcome ("coffee" -> Dining), not stuck on the
        // disabled rule's category.
        #expect(rule.isEnabled == false)
        #expect(try coffeeCategory() == SeedData.ID.dining)
    }

    @Test func summaryTextPluralisesCorrectly() {
        #expect(CategoryRulesViewModel.summaryText(changed: 0) == "No transactions changed category.")
        #expect(CategoryRulesViewModel.summaryText(changed: 1) == "1 transaction recategorised.")
        #expect(CategoryRulesViewModel.summaryText(changed: 4) == "4 transactions recategorised.")
    }

    // MARK: - Editor

    @Test func editorDefaultsToTheFirstCategoryWhenCreating() throws {
        let fixture = try makeFixture()
        let viewModel = CategoryRuleEditorViewModel(repositories: fixture.repositories)

        viewModel.load()

        #expect(viewModel.isEditing == false)
        #expect(viewModel.title == "New Rule")
        #expect(viewModel.categoryID != nil)
        #expect(viewModel.isEnabled)
    }

    @Test func editorLoadsAnExistingRule() throws {
        let fixture = try makeFixture()
        try insertRule(fixture, id: "a", pattern: "BLUE BOTTLE", sortIndex: 0, isEnabled: false)
        let viewModel = CategoryRuleEditorViewModel(ruleID: "a", repositories: fixture.repositories)

        viewModel.load()

        #expect(viewModel.isEditing)
        #expect(viewModel.title == "Edit Rule")
        #expect(viewModel.pattern == "BLUE BOTTLE")
        #expect(viewModel.categoryID == SeedData.ID.dining)
        #expect(viewModel.isEnabled == false)
    }

    /// `canSave` is validated through the same `matcher` the engine uses, so the button can
    /// never enable a rule the engine would then silently skip.
    @Test func canSaveRejectsWhatTheEngineWouldSkip() throws {
        let fixture = try makeFixture()
        let viewModel = CategoryRuleEditorViewModel(repositories: fixture.repositories)
        viewModel.load()

        viewModel.pattern = ""
        #expect(viewModel.canSave == false)

        viewModel.pattern = "   "
        #expect(viewModel.canSave == false)

        viewModel.pattern = "BLUE BOTTLE"
        #expect(viewModel.canSave)

        viewModel.kind = .merchantCategoryCode
        #expect(viewModel.canSave == false, "a non-numeric code pattern must not be saveable")

        viewModel.pattern = "5411"
        #expect(viewModel.canSave)

        viewModel.pattern = "99999"
        #expect(viewModel.canSave == false, "a code past Int16 must not be saveable")
    }

    @Test func savingCreatesARuleAndAppliesItToTheExistingLedger() throws {
        let fixture = try makeFixture()
        let viewModel = CategoryRuleEditorViewModel(repositories: fixture.repositories)
        viewModel.load()
        viewModel.pattern = "BLUE BOTTLE"
        viewModel.categoryID = SeedData.ID.audio

        #expect(viewModel.save())

        let stored = try fixture.repositories.categoryRules.all()
        #expect(stored.count == 1)
        #expect(stored.first?.pattern == "BLUE BOTTLE")

        let coffee = try #require(
            try fixture.repositories.transactions.all()
                .first { $0.merchantRaw.localizedCaseInsensitiveContains("BLUE BOTTLE") }
        )
        #expect(coffee.categoryID == SeedData.ID.audio)
        #expect(viewModel.lastChangedCount > 0)
    }

    @Test func savingTrimsThePattern() throws {
        let fixture = try makeFixture()
        let viewModel = CategoryRuleEditorViewModel(repositories: fixture.repositories)
        viewModel.load()
        viewModel.pattern = "  BLUE BOTTLE  "
        viewModel.categoryID = SeedData.ID.audio

        #expect(viewModel.save())
        #expect(try fixture.repositories.categoryRules.all().first?.pattern == "BLUE BOTTLE")
    }

    @Test func newRulesAppendToTheEndOfTheOrder() throws {
        let fixture = try makeFixture()
        try insertRule(fixture, id: "existing", pattern: "A", sortIndex: 0)

        let viewModel = CategoryRuleEditorViewModel(repositories: fixture.repositories)
        viewModel.load()
        viewModel.pattern = "B"
        viewModel.categoryID = SeedData.ID.dining
        #expect(viewModel.save())

        let stored = try fixture.repositories.categoryRules.all()
        #expect(stored.map(\.sortIndex) == [0, 1])
        #expect(stored.last?.pattern == "B")
    }

    @Test func editingUpdatesInPlaceRatherThanAppending() throws {
        let fixture = try makeFixture()
        try insertRule(fixture, id: "a", pattern: "OLD", sortIndex: 0)
        let viewModel = CategoryRuleEditorViewModel(ruleID: "a", repositories: fixture.repositories)
        viewModel.load()
        viewModel.pattern = "NEW"

        #expect(viewModel.save())

        let stored = try fixture.repositories.categoryRules.all()
        #expect(stored.count == 1)
        #expect(stored.first?.pattern == "NEW")
    }

    @Test func deletingRemovesTheRule() throws {
        let fixture = try makeFixture()
        try insertRule(fixture, id: "a", pattern: "A", sortIndex: 0)
        let viewModel = CategoryRuleEditorViewModel(ruleID: "a", repositories: fixture.repositories)
        viewModel.load()

        #expect(viewModel.delete())
        #expect(try fixture.repositories.categoryRules.all().isEmpty)
    }

    @Test func deletingIsANoOpWhenCreating() throws {
        let fixture = try makeFixture()
        let viewModel = CategoryRuleEditorViewModel(repositories: fixture.repositories)
        viewModel.load()

        #expect(viewModel.delete() == false)
    }
}
