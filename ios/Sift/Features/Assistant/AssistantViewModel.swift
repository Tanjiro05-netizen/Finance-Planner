import Foundation
import Observation

@MainActor
@Observable
final class AssistantViewModel {
    private let repositories: RepositoryContainer
    private let conversation: any InsightConversing
    private let referenceDateProvider: () -> Date
    private let featureFlags: SiftFeatureFlags

    var messages: [ChatMessage] = []
    var draft = ""
    var isReplying = false
    var errorMessage: String?

    init(
        repositories: RepositoryContainer,
        conversation: any InsightConversing = MockInsightConversation(),
        referenceDateProvider: @escaping () -> Date = { Date() },
        featureFlags: SiftFeatureFlags = .launchDefault
    ) {
        self.repositories = repositories
        self.conversation = conversation
        self.referenceDateProvider = referenceDateProvider
        self.featureFlags = featureFlags
    }

    var isAvailable: Bool {
        featureFlags.assistantEnabled && conversation.availability().isAvailable
    }

    /// Shown instead of the composer when the model can't run. An ordinary state, not an error.
    var unavailableMessage: String? {
        guard featureFlags.assistantEnabled else {
            return nil
        }

        return conversation.availability().unavailableMessage
    }

    var canSend: Bool {
        !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isReplying && isAvailable
    }

    var isEmpty: Bool {
        messages.isEmpty
    }

    /// Starter questions, so an empty chat isn't a blank box. Deliberately phrased in the
    /// first person, which also routes them on-device.
    var suggestions: [String] {
        [
            "How am I doing this month?",
            "Can I afford a $200 purchase?",
            "Which subscriptions should I look at?",
        ]
    }

    func send() async {
        let question = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !question.isEmpty, !isReplying else {
            return
        }

        draft = ""
        await ask(question)
    }

    func ask(_ question: String) async {
        guard isAvailable, !isReplying else {
            return
        }

        isReplying = true
        defer { isReplying = false }

        let now = referenceDateProvider()
        let history = messages
        messages.append(ChatMessage(author: .person, text: question, date: now))
        errorMessage = nil

        // Questions about the person's own money are answered on-device, always. The route
        // is computed here rather than inside the adapter so the decision is visible at the
        // call site and testable without a model.
        let route = ChatRouter.route(for: question)
        let facts = route == .onDevice ? buildFacts(today: now) : InsightFacts()

        do {
            let answer = try await conversation.reply(to: question, facts: facts, history: history)
            messages.append(ChatMessage(author: .assistant, text: answer, date: now))
        } catch let failure as InsightNarrationFailure {
            errorMessage = failure.message
        } catch {
            errorMessage = InsightNarrationFailure.unknown.message
        }
    }

    func clear() {
        messages = []
        errorMessage = nil
    }

    /// Aggregates only, exactly as the narrator gets. A repository failure yields an empty
    /// sheet rather than blocking the answer — the model can still say it lacks the figure.
    private func buildFacts(today: Date) -> InsightFacts {
        var safeToSpend: SafeToSpendResult?
        if
            let outcome = try? SafeToSpendProvider.outcome(repositories: repositories, today: today),
            case let .available(result) = outcome
        {
            safeToSpend = result
        }

        let transactions = (try? widestWindowTransactions(today: today)) ?? []
        let categoryNames = (try? categoryNameLookup()) ?? [:]
        let comparison = SpendReportBuilder.comparison(
            transactions: transactions,
            referenceDate: today,
            categoryNames: categoryNames
        )

        return InsightPromptBuilder.facts(
            safeToSpend: safeToSpend,
            comparison: comparison,
            movers: SpendReportBuilder.topMovers(comparison: comparison),
            budgets: (try? budgetFacts(today: today, transactions: transactions, names: categoryNames)) ?? [],
            goals: (try? goalFacts(today: today)) ?? []
        )
    }

    private func widestWindowTransactions(today: Date) throws -> [Transaction] {
        let calendar = Calendar.utc
        let month = calendar.dateInterval(of: .month, for: today) ?? DateInterval(start: today, end: today)
        let start = calendar.date(byAdding: .month, value: -1, to: month.start) ?? month.start
        return try repositories.transactions.transactions(from: start, to: month.end)
    }

    private func categoryNameLookup() throws -> [String: String] {
        try Dictionary(
            repositories.categories.all().map { ($0.id, $0.name) },
            uniquingKeysWith: { first, _ in first }
        )
    }

    private func budgetFacts(
        today: Date,
        transactions: [Transaction],
        names: [String: String]
    ) throws -> [BudgetFactInput] {
        guard featureFlags.budgetsEnabled else {
            return []
        }

        return try repositories.budgets.all()
            .filter { $0.status == .active }
            .map { budget in
                BudgetFactInput(
                    categoryName: names[budget.categoryID] ?? "Uncategorized",
                    progress: BudgetProgressCalculator.progress(
                        budget: budget,
                        transactions: transactions,
                        referenceDate: today
                    )
                )
            }
    }

    private func goalFacts(today: Date) throws -> [GoalFactInput] {
        guard featureFlags.goalsEnabled else {
            return []
        }

        return try repositories.goals.all()
            .filter { $0.status != .archived }
            .map { goal in
                let contributions = try repositories.goals.contributions(forGoal: goal.id)
                return GoalFactInput(
                    name: goal.name,
                    targetAmount: goal.targetAmount,
                    outcome: GoalProjector.outcome(
                        goal: goal,
                        contributions: contributions,
                        referenceDate: today
                    )
                )
            }
    }
}
