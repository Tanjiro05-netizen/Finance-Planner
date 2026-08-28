import Foundation
import Observation

/// Create, edit, and delete a `RecurringIncome` by hand.
///
/// The mirror of `BillEditorViewModel`, and just as load-bearing: the next expected income
/// date is the horizon `SafeToSpendProvider` measures against, so a paycheque detection
/// missed makes safe-to-spend fall back to a generic window instead of "until you're paid".
@MainActor
@Observable
final class IncomeEditorViewModel {
    /// Same reasoning as the bill editor: `.unknown` is a detection outcome, not a choice,
    /// and is presented as monthly for the user to correct.
    static let selectableCadences: [Cadence] = [.weekly, .biweekly, .monthly, .quarterly, .yearly]

    private let repositories: RepositoryContainer
    private let incomeID: String?
    private let referenceDateProvider: () -> Date

    var sourceName = ""
    var amountText = ""
    var cadence: Cadence = .monthly
    var hasNextExpected = false
    var nextExpected = Date()
    var categoryID: String?
    var errorMessage: String?
    var categories: [Category] = []

    init(
        incomeID: String? = nil,
        repositories: RepositoryContainer,
        referenceDateProvider: @escaping () -> Date = { Date() }
    ) {
        self.incomeID = incomeID
        self.repositories = repositories
        self.referenceDateProvider = referenceDateProvider
    }

    var isEditing: Bool {
        incomeID != nil
    }

    var title: String {
        isEditing ? "Edit Income" : "New Income"
    }

    var canSave: Bool {
        !sourceName.trimmingCharacters(in: .whitespaces).isEmpty && parsedAmountMinor != nil
    }

    /// Without a next date this income can never become the safe-to-spend horizon, so the
    /// editor says so while there is still something to type.
    var needsDateToAffectSafeToSpend: Bool {
        !hasNextExpected
    }

    /// Parsed via `Decimal` and the shared minor-unit helper, matching manual transaction
    /// entry — money never round-trips through a binary floating point type.
    private var parsedAmountMinor: Int? {
        guard let decimal = Decimal(string: amountText), decimal > 0 else {
            return nil
        }
        return FinancialDataMapper.minorUnits(from: decimal)
    }

    func load() {
        nextExpected = defaultNextExpected()

        do {
            categories = try repositories.categories.all()

            if let incomeID, let income = try repositories.recurringIncome.recurringIncome(id: incomeID) {
                sourceName = income.sourceName
                amountText = income.amount.editableAmountText
                cadence = Self.selectableCadences.contains(income.cadence) ? income.cadence : .monthly
                hasNextExpected = income.nextExpected != nil
                nextExpected = income.nextExpected ?? defaultNextExpected()
                categoryID = income.categoryID
            }

            errorMessage = nil
        } catch {
            errorMessage = userFacingMessage(for: error)
        }
    }

    /// Returns true when the sheet should dismiss.
    func save() -> Bool {
        let trimmedName = sourceName.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty, let amountMinor = parsedAmountMinor else {
            errorMessage = "Give the income a source and an amount."
            return false
        }

        let amount = Money(amountMinor: amountMinor, currency: "USD")
        let expected = hasNextExpected ? nextExpected : nil
        let today = referenceDateProvider()

        do {
            if let incomeID, let existing = try repositories.recurringIncome.recurringIncome(id: incomeID) {
                existing.sourceName = trimmedName
                existing.amount = amount
                existing.cadence = cadence
                existing.nextExpected = expected
                existing.categoryID = categoryID
                // `merchantKey` stays as detection wrote it — it is the link back to the
                // real deposits, and renaming the label must not break that.
                try repositories.recurringIncome.update(existing)
            } else {
                try repositories.recurringIncome.insert(RecurringIncome(
                    id: "income-\(UUID().uuidString.lowercased())",
                    userID: SeedData.defaultUserID,
                    sourceName: trimmedName,
                    merchantKey: MerchantKey(trimmedName),
                    amount: amount,
                    cadence: cadence,
                    nextExpected: expected,
                    categoryID: categoryID,
                    status: .active,
                    // Typed in by hand, so it is not a guess.
                    detectionConfidence: 1.0,
                    firstSeen: today,
                    lastReceived: today
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
        guard let incomeID else {
            return false
        }

        do {
            try repositories.recurringIncome.delete(id: incomeID)
            return true
        } catch {
            errorMessage = userFacingMessage(for: error)
            return false
        }
    }

    /// Two weeks out — the most common pay rhythm, and far enough ahead that the picker
    /// never opens on a date that has already passed.
    private func defaultNextExpected() -> Date {
        let today = referenceDateProvider()
        return Calendar.utc.date(byAdding: .day, value: 14, to: today) ?? today
    }

    private func userFacingMessage(for error: Error) -> String {
        if let siftError = error as? SiftError {
            return siftError.errorDescription ?? "Something went wrong."
        }

        return error.localizedDescription
    }
}
