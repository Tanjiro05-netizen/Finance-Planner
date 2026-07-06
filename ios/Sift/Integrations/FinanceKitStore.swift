import Foundation

#if canImport(FinanceKit)
import FinanceKit

/// Live `FinancialDataStore` backed by Apple's FinanceKit. Reads the person's real
/// Apple Card / Apple Cash / Apple Pay accounts and transactions on-device.
///
/// Using this at runtime requires the `com.apple.developer.financekit` entitlement
/// (granted per bundle ID by Apple), a real device in a supported region, and the
/// `NSFinancialDataUsageDescription` string in Info.plist. On the Simulator
/// `isDataAvailable()` returns `false`, and every fetch degrades to an empty result.
struct FinanceKitStore: FinancialDataStore {
    func isDataAvailable() -> Bool {
        FinanceStore.isDataAvailable(.financialData)
    }

    func authorizationStatus() async throws -> FinancialAuthorization {
        Self.map(try await FinanceStore.shared.authorizationStatus())
    }

    func requestAuthorization() async throws -> FinancialAuthorization {
        Self.map(try await FinanceStore.shared.requestAuthorization())
    }

    func fetchAccounts() async throws -> [FinancialAccountSnapshot] {
        let query = AccountQuery(sortDescriptors: [], predicate: nil, limit: nil, offset: nil)
        return try await FinanceStore.shared.accounts(query: query).map(Self.snapshot(from:))
    }

    func fetchTransactions() async throws -> [FinancialTransactionSnapshot] {
        let query = TransactionQuery(
            sortDescriptors: [SortDescriptor(\.transactionDate, order: .reverse)],
            predicate: nil,
            limit: nil,
            offset: nil
        )
        return try await FinanceStore.shared.transactions(query: query).map(Self.snapshot(from:))
    }

    private static func map(_ status: AuthorizationStatus) -> FinancialAuthorization {
        switch status {
        case .authorized:
            .authorized
        case .denied:
            .denied
        case .notDetermined:
            .notDetermined
        @unknown default:
            .notDetermined
        }
    }

    private static func snapshot(from account: Account) -> FinancialAccountSnapshot {
        FinancialAccountSnapshot(
            id: account.id.uuidString,
            displayName: account.displayName,
            institutionName: account.institutionName,
            currencyCode: account.currencyCode,
            isLiability: account.liabilityAccount != nil
        )
    }

    private static func snapshot(from transaction: FinanceKit.Transaction) -> FinancialTransactionSnapshot {
        FinancialTransactionSnapshot(
            id: transaction.id.uuidString,
            accountID: transaction.accountID.uuidString,
            merchantName: transaction.merchantName ?? transaction.transactionDescription,
            amount: transaction.transactionAmount.amount,
            currencyCode: transaction.transactionAmount.currencyCode,
            date: transaction.transactionDate,
            isPending: transaction.status == .pending,
            isDebit: transaction.creditDebitIndicator == .debit
        )
    }
}

#else

/// Fallback used only where FinanceKit is unavailable at compile time so the app still
/// builds; it reports no financial data.
struct FinanceKitStore: FinancialDataStore {
    func isDataAvailable() -> Bool { false }
    func authorizationStatus() async throws -> FinancialAuthorization { .notDetermined }
    func requestAuthorization() async throws -> FinancialAuthorization { .notDetermined }
    func fetchAccounts() async throws -> [FinancialAccountSnapshot] { [] }
    func fetchTransactions() async throws -> [FinancialTransactionSnapshot] { [] }
}

#endif
