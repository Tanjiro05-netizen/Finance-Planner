import Foundation

/// A person's authorization state for reading on-device financial data.
///
/// Mirrors `FinanceKit.AuthorizationStatus` without importing FinanceKit, so the
/// ingestion pipeline stays testable on any platform and the framework only has to
/// be linked by the thin live adapter (`FinanceKitStore`).
enum FinancialAuthorization: Equatable {
    case notDetermined
    case denied
    case authorized
}

/// A single account surfaced by the on-device financial data store (Apple Card,
/// Apple Cash, or another Wallet-linked account).
struct FinancialAccountSnapshot: Equatable {
    let id: String
    let displayName: String
    let institutionName: String
    let currencyCode: String
    let isLiability: Bool
}

/// A single transaction surfaced by the on-device financial data store.
///
/// Amounts are stored as an unsigned magnitude; direction is carried separately by
/// `isDebit` so callers decide how to treat spend versus credits.
struct FinancialTransactionSnapshot: Equatable {
    let id: String
    let accountID: String
    let merchantName: String
    let amount: Decimal
    let currencyCode: String
    let date: Date
    let isPending: Bool
    let isDebit: Bool
}

/// Read-only access to the device's financial data.
///
/// The live implementation (`FinanceKitStore`) is backed by `FinanceKit.FinanceStore`;
/// tests and previews use `MockFinancialDataStore`.
protocol FinancialDataStore: Sendable {
    /// Whether the framework can vend financial data on this device at all.
    func isDataAvailable() -> Bool
    /// The current authorization status without prompting.
    func authorizationStatus() async throws -> FinancialAuthorization
    /// Prompts the person for access and returns the resulting status.
    func requestAuthorization() async throws -> FinancialAuthorization
    func fetchAccounts() async throws -> [FinancialAccountSnapshot]
    func fetchTransactions() async throws -> [FinancialTransactionSnapshot]
}

/// Pure, framework-free translation from on-device snapshots into the transport
/// shapes (`RemoteTransaction` / `RemoteAccount`) that Sift's existing detection and
/// import pipeline already consumes. Keeping this pure keeps it fully unit-testable.
enum FinancialDataMapper {
    /// The number of minor-unit digits for an ISO 4217 currency (2 for most, 0 for
    /// zero-decimal currencies like JPY, 3 for a few Gulf currencies). Defaults to 2.
    static func fractionDigits(for currencyCode: String) -> Int16 {
        switch currencyCode.uppercased() {
        case "BIF", "CLP", "DJF", "GNF", "ISK", "JPY", "KMF", "KRW",
             "PYG", "RWF", "UGX", "UYI", "VND", "VUV", "XAF", "XOF", "XPF":
            0
        case "BHD", "IQD", "JOD", "KWD", "LYD", "OMR", "TND":
            3
        default:
            2
        }
    }

    /// Converts a decimal money amount into integer minor units for its currency
    /// (e.g. cents for USD, whole yen for JPY). The magnitude is always taken so sign
    /// lives with `isDebit`.
    static func minorUnits(from amount: Decimal, currencyCode: String = "USD") -> Int {
        let handler = NSDecimalNumberHandler(
            roundingMode: .plain,
            scale: 0,
            raiseOnExactness: false,
            raiseOnOverflow: false,
            raiseOnUnderflow: false,
            raiseOnDivideByZero: false
        )
        let magnitude = NSDecimalNumber(decimal: abs(amount))
        return magnitude
            .multiplying(byPowerOf10: fractionDigits(for: currencyCode))
            .rounding(accordingToBehavior: handler)
            .intValue
    }

    static func remoteTransaction(
        from snapshot: FinancialTransactionSnapshot,
        userID: String
    ) -> RemoteTransaction {
        RemoteTransaction(
            id: snapshot.id,
            userId: userID,
            accountId: snapshot.accountID,
            merchantName: snapshot.merchantName,
            amountMinor: minorUnits(from: snapshot.amount, currencyCode: snapshot.currencyCode),
            isoCurrency: snapshot.currencyCode,
            date: snapshot.date,
            pending: snapshot.isPending,
            category: nil
        )
    }

    static func remoteAccount(from snapshot: FinancialAccountSnapshot) -> RemoteAccount {
        RemoteAccount(
            id: snapshot.id,
            plaidItemId: snapshot.id,
            institutionName: snapshot.institutionName,
            mask: nil,
            name: snapshot.displayName,
            type: snapshot.isLiability ? "credit" : "depository",
            status: "active"
        )
    }

    /// Charges eligible for subscription detection: settled or pending debits, most
    /// recent first with a stable tiebreak so paging is deterministic.
    static func spendTransactions(
        from snapshots: [FinancialTransactionSnapshot]
    ) -> [FinancialTransactionSnapshot] {
        snapshots
            .filter(\.isDebit)
            .sorted { lhs, rhs in
                if lhs.date != rhs.date {
                    return lhs.date > rhs.date
                }
                return lhs.id < rhs.id
            }
    }
}

/// In-memory `FinancialDataStore` for previews and tests.
struct MockFinancialDataStore: FinancialDataStore {
    var available: Bool
    var status: FinancialAuthorization
    var accounts: [FinancialAccountSnapshot]
    var transactions: [FinancialTransactionSnapshot]
    var fetchError: FinancialDataError?

    init(
        available: Bool = true,
        status: FinancialAuthorization = .authorized,
        accounts: [FinancialAccountSnapshot] = [],
        transactions: [FinancialTransactionSnapshot] = [],
        fetchError: FinancialDataError? = nil
    ) {
        self.available = available
        self.status = status
        self.accounts = accounts
        self.transactions = transactions
        self.fetchError = fetchError
    }

    func isDataAvailable() -> Bool {
        available
    }

    func authorizationStatus() async throws -> FinancialAuthorization {
        status
    }

    func requestAuthorization() async throws -> FinancialAuthorization {
        status
    }

    func fetchAccounts() async throws -> [FinancialAccountSnapshot] {
        if let fetchError {
            throw fetchError
        }
        return accounts
    }

    func fetchTransactions() async throws -> [FinancialTransactionSnapshot] {
        if let fetchError {
            throw fetchError
        }
        return transactions
    }
}

enum FinancialDataError: Error, Equatable {
    case unavailable
    case notAuthorized
}

/// Records the last successful FinanceKit sync so the live store can fetch only recent
/// transactions instead of the full history each time.
protocol FinancialSyncStateStoring: Sendable {
    var lastSyncDate: Date? { get }
    func recordSync(at date: Date)
}

struct UserDefaultsFinancialSyncState: FinancialSyncStateStoring {
    // UserDefaults is thread-safe but not marked Sendable.
    private nonisolated(unsafe) let defaults: UserDefaults
    private let key = "sift.financekit.lastSync"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var lastSyncDate: Date? {
        let timestamp = defaults.double(forKey: key)
        return timestamp > 0 ? Date(timeIntervalSince1970: timestamp) : nil
    }

    func recordSync(at date: Date) {
        defaults.set(date.timeIntervalSince1970, forKey: key)
    }
}

/// Pure calculation of the earliest transaction date to fetch on a sync.
enum FinancialSyncWindow {
    /// Re-fetch a month of overlap on incremental syncs; combined with upsert de-duping
    /// this guards against gaps if an earlier sync failed after advancing the marker.
    static let overlap: TimeInterval = 31 * 86400
    /// First-ever sync looks back roughly six months (Sift's detection horizon).
    static let fullLookback: TimeInterval = 182 * 86400

    static func startDate(lastSync: Date?, now: Date) -> Date {
        guard let lastSync else {
            return now.addingTimeInterval(-fullLookback)
        }
        return min(lastSync.addingTimeInterval(-overlap), now)
    }
}
