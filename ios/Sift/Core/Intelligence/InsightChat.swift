import Foundation

/// One turn in a conversation.
struct ChatMessage: Identifiable, Equatable, Sendable {
    enum Author: String, Equatable, Sendable {
        case person
        case assistant
    }

    let id: String
    let author: Author
    let text: String
    let date: Date

    init(id: String = UUID().uuidString, author: Author, text: String, date: Date) {
        self.id = id
        self.author = author
        self.text = text
        self.date = date
    }
}

/// Where a question may be answered.
///
/// This exists so the decision is made once, explicitly, and can be tested — rather than
/// being an implicit consequence of which adapter happens to be wired up.
enum ChatRoute: String, Equatable, Sendable {
    /// Needs the person's own figures. Must be answered on-device, always.
    case onDevice
    /// General knowledge carrying nothing personal. Safe to answer anywhere, including a
    /// remote model, if one is ever configured.
    case general
}

/// Decides whether a question needs the person's own financial data to answer.
///
/// The hybrid design rests entirely on this being right, so it fails closed: anything not
/// confidently general is routed on-device. A false `.onDevice` costs a little answer
/// quality; a false `.general` would leak someone's finances to a third party, which is the
/// thing the whole app promises not to do.
enum ChatRouter {
    /// First-person and possessive markers. If someone is asking about *their* money, the
    /// answer needs their figures and stays on the phone.
    private static let personalMarkers = [
        "my", "mine", "i ", "i'm", "im ", "i've", "we ", "our", "me ",
        "am i", "can i", "should i", "did i", "do i", "was i",
    ]

    /// Words that only mean something against this person's ledger.
    private static let ledgerMarkers = [
        "budget", "spent", "spend", "spending", "balance", "afford",
        "subscription", "subscriptions", "goal", "goals", "saved", "savings",
        "transaction", "transactions", "bill", "bills", "income", "payday",
        "account", "category", "categories", "renewal", "trial",
    ]

    static func route(for question: String) -> ChatRoute {
        let normalized = " \(question.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)) "

        guard !normalized.trimmingCharacters(in: .whitespaces).isEmpty else {
            return .onDevice
        }

        if personalMarkers.contains(where: { normalized.contains($0) }) {
            return .onDevice
        }

        if ledgerMarkers.contains(where: { normalized.contains(" \($0) ") }) {
            return .onDevice
        }

        return .general
    }
}

/// A multi-turn conversation grounded in the person's own figures.
///
/// Separate from `InsightNarrating` because the shapes genuinely differ: narration is one
/// shot over a fixed fact sheet, chat is stateful and question-led.
protocol InsightConversing: Sendable {
    func availability() -> InsightAvailability
    /// `facts` is the same redacted aggregate sheet the narrator gets — never raw rows.
    func reply(to question: String, facts: InsightFacts, history: [ChatMessage]) async throws -> String
}

/// Deterministic stand-in for tests and previews.
struct MockInsightConversation: InsightConversing {
    var availabilityResult: InsightAvailability = .available
    var failure: InsightNarrationFailure?

    /// Records what each call was allowed to see, so tests can assert redaction and routing.
    final class Recorder: @unchecked Sendable {
        private(set) var lastFacts: InsightFacts?
        private(set) var lastQuestion: String?
        private(set) var lastHistoryCount = 0

        func record(question: String, facts: InsightFacts, historyCount: Int) {
            lastQuestion = question
            lastFacts = facts
            lastHistoryCount = historyCount
        }
    }

    var recorder = Recorder()

    func availability() -> InsightAvailability {
        availabilityResult
    }

    func reply(to question: String, facts: InsightFacts, history: [ChatMessage]) async throws -> String {
        recorder.record(question: question, facts: facts, historyCount: history.count)

        if let failure {
            throw failure
        }

        return "Answering: \(question)"
    }
}
