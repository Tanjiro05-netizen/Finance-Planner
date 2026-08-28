import Foundation
import Observation

@MainActor
@Observable
final class ManualTransactionEntryViewModel {
    private let repositories: RepositoryContainer
    private let referenceDateProvider: () -> Date

    var merchantName = ""
    var amountText = ""
    var date: Date
    var direction: TransactionDirection = .debit
    var accountID: String?
    var categoryID: String?
    var note = ""
    var errorMessage: String?
    var accounts: [LinkedAccount] = []
    var categories: [Category] = []

    init(
        repositories: RepositoryContainer,
        referenceDateProvider: @escaping () -> Date = { Date() }
    ) {
        self.repositories = repositories
        self.referenceDateProvider = referenceDateProvider
        date = referenceDateProvider()
    }

    var canSave: Bool {
        !merchantName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            parsedAmountMinor != nil &&
            accountID != nil
    }

    func load() {
        do {
            accounts = try repositories.accounts.all()
            categories = try repositories.categories.all()
            if accountID == nil {
                accountID = accounts.first?.id
            }
            errorMessage = nil
        } catch {
            errorMessage = userFacingMessage(for: error)
        }
    }

    @discardableResult
    func save() -> Bool {
        guard let accountID, let amountMinor = parsedAmountMinor else {
            return false
        }

        let merchant = MerchantNormalizer().normalize(merchantName)
        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        let transaction = Transaction(
            id: "manual-\(UUID().uuidString.lowercased())",
            userID: SeedData.defaultUserID,
            accountID: accountID,
            merchantRaw: merchantName,
            merchantKey: merchant.merchantKey,
            amount: Money(amountMinor: amountMinor, currency: "USD"),
            date: date,
            pending: false,
            direction: direction,
            kind: direction == .credit ? .income : .purchase,
            categoryID: categoryID,
            categoryManuallySet: categoryID != nil,
            source: .manual,
            note: trimmedNote.isEmpty ? nil : trimmedNote
        )

        do {
            try repositories.transactions.insert(transaction)
            return true
        } catch {
            errorMessage = userFacingMessage(for: error)
            return false
        }
    }

    private var parsedAmountMinor: Int? {
        guard let decimal = Decimal(string: amountText), decimal > 0 else {
            return nil
        }
        return FinancialDataMapper.minorUnits(from: decimal)
    }

    private func userFacingMessage(for error: Error) -> String {
        if let siftError = error as? SiftError {
            return siftError.errorDescription ?? "Something went wrong."
        }

        return error.localizedDescription
    }
}
