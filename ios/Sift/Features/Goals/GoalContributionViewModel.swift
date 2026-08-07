import Foundation
import Observation

/// Whether an entry adds to or takes from a goal. Withdrawals are recorded as negative
/// amounts, so this only decides the sign the user's input carries.
enum GoalContributionDirection: String, CaseIterable {
    case deposit
    case withdrawal

    var displayName: String {
        switch self {
        case .deposit:
            "Add"
        case .withdrawal:
            "Withdraw"
        }
    }
}

@MainActor
@Observable
final class GoalContributionViewModel {
    private let repositories: RepositoryContainer
    private let goalID: String
    private let referenceDateProvider: () -> Date

    var amountText = ""
    var direction: GoalContributionDirection = .deposit
    var date = Date()
    var note = ""
    var errorMessage: String?
    var goalName = ""
    var contributions: [GoalContribution] = []

    init(
        goalID: String,
        repositories: RepositoryContainer,
        referenceDateProvider: @escaping () -> Date = { Date() }
    ) {
        self.goalID = goalID
        self.repositories = repositories
        self.referenceDateProvider = referenceDateProvider
    }

    var canSave: Bool {
        parsedAmountMinor != nil
    }

    var savedSoFar: Money {
        GoalProjector.saved(from: contributions)
    }

    private var parsedAmountMinor: Int? {
        guard let decimal = Decimal(string: amountText), decimal > 0 else {
            return nil
        }
        return FinancialDataMapper.minorUnits(from: decimal)
    }

    func load() {
        date = referenceDateProvider()

        do {
            goalName = try repositories.goals.goal(id: goalID)?.name ?? ""
            contributions = try repositories.goals.contributions(forGoal: goalID)
            errorMessage = nil
        } catch {
            errorMessage = userFacingMessage(for: error)
        }
    }

    /// Returns true when the sheet should dismiss.
    func save() -> Bool {
        guard let amountMinor = parsedAmountMinor else {
            errorMessage = "Enter an amount."
            return false
        }

        // The sign lives on the stored amount, so the running total is a plain sum and can
        // never disagree with the history the user sees.
        let signed = direction == .withdrawal ? -amountMinor : amountMinor
        let trimmedNote = note.trimmingCharacters(in: .whitespaces)

        do {
            try repositories.goals.addContribution(GoalContribution(
                id: "contrib-\(UUID().uuidString.lowercased())",
                userID: SeedData.defaultUserID,
                goalID: goalID,
                amount: Money(amountMinor: signed, currency: "USD"),
                date: date,
                note: trimmedNote.isEmpty ? nil : trimmedNote
            ))

            errorMessage = nil
            return true
        } catch {
            errorMessage = userFacingMessage(for: error)
            return false
        }
    }

    func delete(contributionID: String) {
        do {
            try repositories.goals.deleteContribution(id: contributionID)
            load()
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
