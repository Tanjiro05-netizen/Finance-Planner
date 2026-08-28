@testable import Sift
import Testing

/// The router is the whole basis of the hybrid design: anything it marks `.general` would be
/// eligible to leave the device if a remote model is ever configured. It must fail closed.
struct ChatRouterTests {
    @Test(arguments: [
        "How am I doing this month?",
        "Can I afford a new laptop?",
        "What did I spend on groceries?",
        "Am I on track for my emergency fund?",
        "Should I cancel Netflix?",
        "my budget",
        "How much have we saved?",
        "Show me my subscriptions",
        "What is my balance",
        "did i overspend",
    ])
    func personalQuestionsStayOnDevice(question: String) {
        #expect(ChatRouter.route(for: question) == .onDevice)
    }

    @Test(arguments: [
        "What is an emergency fund?",
        "How does compound interest work?",
        "What does APR mean?",
    ])
    func generalKnowledgeIsRoutable(question: String) {
        #expect(ChatRouter.route(for: question) == .general)
    }

    @Test func ledgerWordsAloneAreEnoughToStayOnDevice() {
        // No first-person marker, but "budget" only means something against their ledger.
        #expect(ChatRouter.route(for: "is the budget on track") == .onDevice)
        #expect(ChatRouter.route(for: "any subscriptions worth dropping") == .onDevice)
    }

    @Test func emptyOrWhitespaceFailsClosed() {
        #expect(ChatRouter.route(for: "") == .onDevice)
        #expect(ChatRouter.route(for: "    ") == .onDevice)
    }

    @Test func routingIsCaseInsensitive() {
        #expect(ChatRouter.route(for: "CAN I AFFORD THIS?") == .onDevice)
        #expect(ChatRouter.route(for: "My Spending") == .onDevice)
    }
}
