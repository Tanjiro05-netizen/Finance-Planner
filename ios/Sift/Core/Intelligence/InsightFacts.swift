import Foundation

/// One already-computed figure, as a label and a formatted value.
///
/// Money arrives pre-formatted deliberately. The model is asked to *phrase* these, never to
/// compute with them: language models are unreliable at arithmetic and this app already
/// holds exact figures from tested calculators. A string can be echoed; it can't be
/// silently miscalculated.
struct InsightFactLine: Equatable, Sendable {
    let label: String
    let value: String
}

/// Everything the narrator is allowed to see.
///
/// Aggregates only. No merchant names, no individual charges, no account identifiers, no
/// dates of specific transactions. That is a privacy decision first — nothing that could
/// identify a payee enters the context window — and a quality one second, since a short
/// prompt of derived figures produces better output than a dump of rows.
struct InsightFacts: Equatable, Sendable {
    var lines: [InsightFactLine]

    init(lines: [InsightFactLine] = []) {
        self.lines = lines
    }

    var isEmpty: Bool {
        lines.isEmpty
    }
}

/// A budget, reduced to what the narrator needs.
///
/// Declared here rather than reusing `BudgetRowModel` because that type lives in
/// `Features/Budgets` — `Core/` must not depend on a feature module. The view model maps
/// its rows into these.
struct BudgetFactInput: Equatable, Sendable {
    let categoryName: String
    let progress: BudgetProgress

    init(categoryName: String, progress: BudgetProgress) {
        self.categoryName = categoryName
        self.progress = progress
    }
}

/// A goal, reduced to what the narrator needs. Same layering reason as `BudgetFactInput`.
struct GoalFactInput: Equatable, Sendable {
    let name: String
    let targetAmount: Money
    let outcome: GoalOutcome

    init(name: String, targetAmount: Money, outcome: GoalOutcome) {
        self.name = name
        self.targetAmount = targetAmount
        self.outcome = outcome
    }
}

/// Builds `InsightFacts` from the output of the deterministic layer.
///
/// Pure and framework-free: it takes values the calculators already produced rather than
/// reading repositories itself, which is what keeps it fully unit-testable and keeps the
/// redaction guarantee checkable in a test.
enum InsightPromptBuilder {
    /// Category names are the one caller-supplied string that reaches the prompt, and they
    /// come from the user's own category list rather than from transaction descriptions.
    /// Anything longer than this is truncated rather than trusted.
    static let maximumCategoryNameLength = 40

    static func facts(
        safeToSpend: SafeToSpendResult?,
        comparison: SpendComparison?,
        movers: [CategoryMover],
        budgets: [BudgetFactInput],
        goals: [GoalFactInput]
    ) -> InsightFacts {
        var lines: [InsightFactLine] = []

        if let safeToSpend {
            lines.append(InsightFactLine(
                label: "Safe to spend per day",
                value: safeToSpend.dailyAmount.formatted()
            ))
            lines.append(InsightFactLine(
                label: "Available before the next payday, after known bills",
                value: safeToSpend.netAvailable.formatted()
            ))
        }

        if let comparison {
            let window = comparison.isPartialMonth
                ? "first \(comparison.dayCount) days of each month"
                : "full month"
            lines.append(InsightFactLine(
                label: "Spent this month (\(window))",
                value: comparison.currentTotal.formatted()
            ))
            lines.append(InsightFactLine(
                label: "Spent over the same stretch last month",
                value: comparison.previousTotal.formatted()
            ))
        }

        for mover in movers {
            let direction = mover.isIncrease ? "up" : "down"
            let magnitude = Money(
                amountMinor: abs(mover.delta.amountMinor),
                currency: mover.delta.currency
            )
            lines.append(InsightFactLine(
                label: "\(safeName(mover.categoryName)) spending \(direction)",
                value: "\(magnitude.formatted()) (\(mover.previous.formatted()) to \(mover.current.formatted()))"
            ))
        }

        for budget in budgets {
            lines.append(InsightFactLine(
                label: "\(safeName(budget.categoryName)) budget, \(paceText(budget.progress.pace))",
                value: "\(budget.progress.spent.formatted()) of \(budget.progress.budgeted.formatted())"
            ))
        }

        for goal in goals {
            lines.append(InsightFactLine(
                label: "Goal: \(safeName(goal.name)) (\(outcomeText(goal.outcome)))",
                value: "\(goal.outcome.saved.formatted()) of \(goal.targetAmount.formatted()) saved"
            ))
        }

        return InsightFacts(lines: lines)
    }

    /// Spelled out here rather than reusing `BudgetPace.label` / `GoalOutcome.label`: those
    /// live in `DesignSystem/Components` and are display tokens for pills. `Core/` must not
    /// depend on the design system, and prompt wording should be free to change without
    /// dragging the UI with it.
    private static func paceText(_ pace: BudgetPace) -> String {
        switch pace {
        case .under:
            "under pace"
        case .onTrack:
            "on pace"
        case .over:
            "over pace"
        }
    }

    private static func outcomeText(_ outcome: GoalOutcome) -> String {
        switch outcome {
        case .reached:
            "reached"
        case .overdue:
            "past its date"
        case .insufficientData:
            "no target date or monthly amount set"
        case .onTrack:
            "on track"
        case .behind:
            "behind"
        case .ahead:
            "ahead"
        }
    }

    /// The prompt body: one figure per line, nothing else.
    static func promptText(for facts: InsightFacts) -> String {
        facts.lines
            .map { "\($0.label): \($0.value)" }
            .joined(separator: "\n")
    }

    /// Instructions are static and carry no user data, so they're safe to keep as a constant
    /// and cheap to prewarm against.
    static let instructions = """
    You write short, calm observations about someone's personal finances.

    Every number you mention must be copied exactly from the figures you are given. \
    Never calculate, estimate, combine, or round a number yourself — if a figure is not \
    listed, do not state it.

    Lead with what is going well before what needs attention. Do not give investment advice, \
    do not tell the person what to buy or sell, and do not moralise about their spending. \
    Keep each observation to one or two sentences.
    """

    /// Category and goal names come from the user's own records. Truncated so an absurdly
    /// long name can't crowd out the rest of the context window, and newline-stripped so a
    /// name can't fake a new instruction line in the prompt.
    private static func safeName(_ name: String) -> String {
        let flattened = name
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard flattened.count > maximumCategoryNameLength else {
            return flattened
        }

        return String(flattened.prefix(maximumCategoryNameLength))
    }
}
