import Foundation
import Observation

/// A goal paired with everything a row needs to render it.
struct GoalRowModel: Identifiable, Equatable {
    let id: String
    let name: String
    let targetAmount: Money
    let outcome: GoalOutcome
    let fractionComplete: Double
}

@MainActor
@Observable
final class GoalsViewModel {
    private let repositories: RepositoryContainer
    private let referenceDateProvider: () -> Date

    var isLoading = false
    var hasLoaded = false
    var errorMessage: String?
    var rows: [GoalRowModel] = []

    init(
        repositories: RepositoryContainer,
        referenceDateProvider: @escaping () -> Date = { Date() }
    ) {
        self.repositories = repositories
        self.referenceDateProvider = referenceDateProvider
    }

    var isEmpty: Bool {
        hasLoaded && rows.isEmpty && errorMessage == nil
    }

    /// Total saved across active goals. Leads the screen because progress made is what
    /// sustains engagement; the shortfall is detail, not the headline.
    var totalSaved: Money {
        (try? Money.sum(rows.map(\.outcome.saved))) ?? .zeroUSD
    }

    var totalTarget: Money {
        (try? Money.sum(rows.map(\.targetAmount))) ?? .zeroUSD
    }

    /// Goals falling short of their target date, for the Home nudge.
    var behindRows: [GoalRowModel] {
        rows.filter { row in
            switch row.outcome {
            case .behind, .overdue:
                true
            default:
                false
            }
        }
    }

    func load() {
        if !hasLoaded {
            isLoading = true
        }
        defer {
            isLoading = false
            hasLoaded = true
        }

        do {
            let today = referenceDateProvider()
            rows = try repositories.goals.all()
                .filter { $0.status != .archived }
                .map { goal in
                    let contributions = try repositories.goals.contributions(forGoal: goal.id)
                    let outcome = GoalProjector.outcome(
                        goal: goal,
                        contributions: contributions,
                        referenceDate: today
                    )

                    return GoalRowModel(
                        id: goal.id,
                        name: goal.name,
                        targetAmount: goal.targetAmount,
                        outcome: outcome,
                        fractionComplete: GoalProjector.fractionComplete(
                            target: goal.targetAmount,
                            saved: outcome.saved
                        )
                    )
                }
            errorMessage = nil
        } catch {
            errorMessage = userFacingMessage(for: error)
        }
    }

    private func userFacingMessage(for error: Error) -> String {
        if let siftError = error as? SiftError {
            return siftError.errorDescription ?? "Something went wrong."
        }

        return error.localizedDescription
    }
}
