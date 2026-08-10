import Foundation
import Observation

/// Create, edit, and delete a `Bill` by hand.
///
/// Bills are normally detected, but detection is a heuristic: when it misses someone's rent
/// the headline "safe to spend" number is silently too high, because `SafeToSpendProvider`
/// builds its upcoming debits straight from `BillRepository.upcomingBills`. This editor is
/// how that number gets corrected.
@MainActor
@Observable
final class BillEditorViewModel {
    /// `.unknown` is a detection outcome, never a choice a person would make, so it is left
    /// out of the picker. A detected bill that carries it is shown as monthly — the two are
    /// already interchangeable everywhere downstream (see `Cadence.monthlyEquivalent`).
    static let selectableCadences: [Cadence] = [.weekly, .biweekly, .monthly, .quarterly, .yearly]

    private let repositories: RepositoryContainer
    private let billID: String?
    private let referenceDateProvider: () -> Date

    var name = ""
    var amountText = ""
    var cadence: Cadence = .monthly
    var hasNextDue = false
    var nextDue = Date()
    var categoryID: String?
    var errorMessage: String?
    var categories: [Category] = []

    init(
        billID: String? = nil,
        repositories: RepositoryContainer,
        referenceDateProvider: @escaping () -> Date = { Date() }
    ) {
        self.billID = billID
        self.repositories = repositories
        self.referenceDateProvider = referenceDateProvider
    }

    var isEditing: Bool {
        billID != nil
    }

    var title: String {
        isEditing ? "Edit Bill" : "New Bill"
    }

    var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && parsedAmountMinor != nil
    }

    /// Without a due date the bill never lands inside a `upcomingBills` window, so it can't
    /// move safe-to-spend. Said while editing rather than as a failure after saving.
    var needsDateToAffectSafeToSpend: Bool {
        !hasNextDue
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
        nextDue = defaultNextDue()

        do {
            categories = try repositories.categories.all()

            if let billID, let bill = try repositories.bills.bill(id: billID) {
                name = bill.name
                amountText = bill.amount.editableAmountText
                cadence = Self.selectableCadences.contains(bill.cadence) ? bill.cadence : .monthly
                hasNextDue = bill.nextDue != nil
                nextDue = bill.nextDue ?? defaultNextDue()
                categoryID = bill.categoryID
            }

            errorMessage = nil
        } catch {
            errorMessage = userFacingMessage(for: error)
        }
    }

    /// Returns true when the sheet should dismiss.
    func save() -> Bool {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty, let amountMinor = parsedAmountMinor else {
            errorMessage = "Give the bill a name and an amount."
            return false
        }

        let amount = Money(amountMinor: amountMinor, currency: "USD")
        let due = hasNextDue ? nextDue : nil
        let today = referenceDateProvider()

        do {
            if let billID, let existing = try repositories.bills.bill(id: billID) {
                existing.name = trimmedName
                existing.amount = amount
                existing.cadence = cadence
                existing.nextDue = due
                existing.categoryID = categoryID
                // `merchantKey` is deliberately not rewritten from the new name: on a
                // detected bill it is the link back to the real charges, and
                // `DiscretionarySpendEstimator` uses it to keep those charges out of the
                // everyday-spend average. Renaming the label must not break that.
                try repositories.bills.update(existing)
            } else {
                try repositories.bills.insert(Bill(
                    id: "bill-\(UUID().uuidString.lowercased())",
                    userID: SeedData.defaultUserID,
                    name: trimmedName,
                    merchantKey: MerchantKey(trimmedName),
                    amount: amount,
                    cadence: cadence,
                    nextDue: due,
                    categoryID: categoryID,
                    status: .active,
                    // Typed in by hand, so it is not a guess: full confidence keeps
                    // detection from treating it as a low-scoring candidate later.
                    detectionConfidence: 1.0,
                    firstSeen: today,
                    lastCharge: today
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
        guard let billID else {
            return false
        }

        do {
            try repositories.bills.delete(id: billID)
            return true
        } catch {
            errorMessage = userFacingMessage(for: error)
            return false
        }
    }

    /// A month out, matching the default monthly cadence, so the picker opens on a
    /// plausible future date rather than on one that has already passed.
    private func defaultNextDue() -> Date {
        let today = referenceDateProvider()
        return Calendar.utc.date(byAdding: .month, value: 1, to: today) ?? today
    }

    private func userFacingMessage(for error: Error) -> String {
        if let siftError = error as? SiftError {
            return siftError.errorDescription ?? "Something went wrong."
        }

        return error.localizedDescription
    }
}
