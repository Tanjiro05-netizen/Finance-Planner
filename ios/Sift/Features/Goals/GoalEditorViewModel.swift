import Foundation
import Observation

@MainActor
@Observable
final class GoalEditorViewModel {
    private let repositories: RepositoryContainer
    private let goalID: String?
    private let referenceDateProvider: () -> Date

    var name = ""
    var targetAmountText = ""
    var hasTargetDate = false
    var targetDate = Date()
    var hasMonthlyContribution = false
    var monthlyContributionText = ""
    var errorMessage: String?

    init(
        goalID: String? = nil,
        repositories: RepositoryContainer,
        referenceDateProvider: @escaping () -> Date = { Date() }
    ) {
        self.goalID = goalID
        self.repositories = repositories
        self.referenceDateProvider = referenceDateProvider
    }

    var isEditing: Bool {
        goalID != nil
    }

    var title: String {
        isEditing ? "Edit Goal" : "New Goal"
    }

    var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && parsedTarget != nil
    }

    /// Neither a date nor a contribution means nothing can be projected. Surfaced as guidance
    /// while editing rather than as a failure after saving.
    var needsMoreForProjection: Bool {
        !hasTargetDate && parsedMonthly == nil
    }

    private var parsedTarget: Int? {
        minorUnits(from: targetAmountText)
    }

    private var parsedMonthly: Int? {
        hasMonthlyContribution ? minorUnits(from: monthlyContributionText) : nil
    }

    private func minorUnits(from text: String) -> Int? {
        guard let decimal = Decimal(string: text), decimal > 0 else {
            return nil
        }
        return FinancialDataMapper.minorUnits(from: decimal)
    }

    func load() {
        targetDate = defaultTargetDate()

        guard let goalID else {
            return
        }

        do {
            guard let goal = try repositories.goals.goal(id: goalID) else {
                return
            }

            name = goal.name
            targetAmountText = goal.targetAmount.editableAmountText
            hasTargetDate = goal.targetDate != nil
            targetDate = goal.targetDate ?? defaultTargetDate()
            hasMonthlyContribution = goal.monthlyContribution != nil
            monthlyContributionText = goal.monthlyContribution?.editableAmountText ?? ""
            errorMessage = nil
        } catch {
            errorMessage = userFacingMessage(for: error)
        }
    }

    /// Returns true when the sheet should dismiss.
    func save() -> Bool {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty, let targetMinor = parsedTarget else {
            errorMessage = "Give the goal a name and a target amount."
            return false
        }

        let target = Money(amountMinor: targetMinor, currency: "USD")
        let monthly = parsedMonthly.map { Money(amountMinor: $0, currency: "USD") }
        let date = hasTargetDate ? targetDate : nil

        do {
            if let goalID, let existing = try repositories.goals.goal(id: goalID) {
                existing.name = trimmedName
                existing.targetAmount = target
                existing.targetDate = date
                existing.monthlyContribution = monthly
                try repositories.goals.update(existing)
            } else {
                try repositories.goals.insert(Goal(
                    id: "goal-\(UUID().uuidString.lowercased())",
                    userID: SeedData.defaultUserID,
                    name: trimmedName,
                    targetAmount: target,
                    targetDate: date,
                    monthlyContribution: monthly,
                    createdAt: referenceDateProvider()
                ))
            }

            errorMessage = nil
            return true
        } catch {
            errorMessage = userFacingMessage(for: error)
            return false
        }
    }

    /// Returns true when the sheet should dismiss.
    func delete() -> Bool {
        guard let goalID else {
            return false
        }

        do {
            try repositories.goals.delete(id: goalID)
            return true
        } catch {
            errorMessage = userFacingMessage(for: error)
            return false
        }
    }

    private func defaultTargetDate() -> Date {
        let today = referenceDateProvider()
        return Calendar.utc.date(byAdding: .month, value: 6, to: today) ?? today
    }

    private func userFacingMessage(for error: Error) -> String {
        if let siftError = error as? SiftError {
            return siftError.errorDescription ?? "Something went wrong."
        }

        return error.localizedDescription
    }
}
