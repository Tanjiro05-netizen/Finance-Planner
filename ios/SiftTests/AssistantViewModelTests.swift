import Foundation
@testable import Sift
import Testing

@MainActor
struct AssistantViewModelTests {
    private static var referenceDate: Date {
        SeedData.referenceDate
    }

    private static var enabledFlags: SiftFeatureFlags {
        SiftFeatureFlags(budgetsEnabled: true, goalsEnabled: true, assistantEnabled: true)
    }

    private func makeViewModel(
        conversation: any InsightConversing = MockInsightConversation(),
        flags: SiftFeatureFlags = enabledFlags,
        repositories: RepositoryContainer = .mock()
    ) -> AssistantViewModel {
        AssistantViewModel(
            repositories: repositories,
            conversation: conversation,
            referenceDateProvider: { Self.referenceDate },
            featureFlags: flags
        )
    }

    @Test func askingAppendsBothTurns() async {
        let viewModel = makeViewModel()

        await viewModel.ask("How am I doing this month?")

        #expect(viewModel.messages.count == 2)
        #expect(viewModel.messages.first?.author == .person)
        #expect(viewModel.messages.last?.author == .assistant)
        #expect(viewModel.errorMessage == nil)
        #expect(viewModel.isReplying == false)
    }

    @Test func sendUsesAndClearsTheDraft() async {
        let viewModel = makeViewModel()
        viewModel.draft = "  Can I afford a $200 purchase?  "

        await viewModel.send()

        #expect(viewModel.draft.isEmpty)
        #expect(viewModel.messages.first?.text == "Can I afford a $200 purchase?")
    }

    @Test func canSendRequiresTextAndAvailability() {
        let viewModel = makeViewModel()
        #expect(viewModel.canSend == false)

        viewModel.draft = "   "
        #expect(viewModel.canSend == false)

        viewModel.draft = "hello"
        #expect(viewModel.canSend)
    }

    @Test func theAssistantIsOffUntilItsFlagIsOn() async {
        let viewModel = makeViewModel(flags: SiftFeatureFlags(budgetsEnabled: true))

        await viewModel.ask("How am I doing?")

        #expect(viewModel.isAvailable == false)
        #expect(viewModel.unavailableMessage == nil)
        #expect(viewModel.messages.isEmpty)
    }

    @Test func anUnavailableModelExplainsItselfAndAcceptsNothing() async {
        let conversation = MockInsightConversation(availabilityResult: .unavailable(.deviceNotEligible))
        let viewModel = makeViewModel(conversation: conversation)

        await viewModel.ask("How am I doing?")

        #expect(viewModel.isAvailable == false)
        #expect(viewModel.unavailableMessage == InsightUnavailableReason.deviceNotEligible.message)
        #expect(viewModel.messages.isEmpty)
    }

    @Test func aFailureSurfacesAMessageAndKeepsTheQuestion() async {
        let conversation = MockInsightConversation(failure: .rateLimited)
        let viewModel = makeViewModel(conversation: conversation)

        await viewModel.ask("How am I doing?")

        #expect(viewModel.errorMessage == InsightNarrationFailure.rateLimited.message)
        // The person's own turn stays on screen; only the reply is missing.
        #expect(viewModel.messages.count == 1)
        #expect(viewModel.messages.first?.author == .person)
    }

    @Test func personalQuestionsCarryTheFactSheet() async throws {
        let conversation = MockInsightConversation()
        let viewModel = makeViewModel(conversation: conversation)

        await viewModel.ask("How much have I spent this month?")

        let facts = try #require(conversation.recorder.lastFacts)
        #expect(facts.isEmpty == false)
    }

    @Test func generalQuestionsCarryNoFinancialDataAtAll() async throws {
        let conversation = MockInsightConversation()
        let viewModel = makeViewModel(conversation: conversation)

        await viewModel.ask("What is an emergency fund?")

        // Routed .general, so nothing personal is attached — this is what would make such a
        // question safe to answer remotely.
        let facts = try #require(conversation.recorder.lastFacts)
        #expect(facts.isEmpty)
    }

    @Test func theModelNeverSeesAMerchantName() async throws {
        let repositories = RepositoryContainer.mock()
        let conversation = MockInsightConversation()
        let viewModel = makeViewModel(conversation: conversation, repositories: repositories)

        await viewModel.ask("Where is my money going?")

        let facts = try #require(conversation.recorder.lastFacts)
        let prompt = InsightPromptBuilder.promptText(for: facts)
        for transaction in try repositories.transactions.all() {
            #expect(prompt.contains(transaction.merchantRaw) == false)
        }
    }

    @Test func historyIsPassedWithoutTheCurrentQuestion() async {
        let conversation = MockInsightConversation()
        let viewModel = makeViewModel(conversation: conversation)

        await viewModel.ask("First question about my budget")
        #expect(conversation.recorder.lastHistoryCount == 0)

        await viewModel.ask("Second question about my budget")
        // Two prior turns, and the question being asked is not among them.
        #expect(conversation.recorder.lastHistoryCount == 2)
    }

    @Test func clearEmptiesTheTranscript() async {
        let viewModel = makeViewModel()
        await viewModel.ask("How am I doing?")

        viewModel.clear()

        #expect(viewModel.messages.isEmpty)
        #expect(viewModel.errorMessage == nil)
        #expect(viewModel.isEmpty)
    }

    @Test func anEmptyStoreStillAnswersRatherThanFailing() async {
        let viewModel = makeViewModel(repositories: .emptyMock())

        await viewModel.ask("How am I doing?")

        #expect(viewModel.messages.count == 2)
        #expect(viewModel.errorMessage == nil)
    }
}
