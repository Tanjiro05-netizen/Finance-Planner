import Foundation
import LocalAuthentication

#if canImport(BackgroundTasks)
    @preconcurrency import BackgroundTasks
#endif

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
        private let syncState: any FinancialSyncStateStoring

        init(syncState: any FinancialSyncStateStoring = UserDefaultsFinancialSyncState()) {
            self.syncState = syncState
        }

        func isDataAvailable() -> Bool {
            FinanceStore.isDataAvailable(.financialData)
        }

        func authorizationStatus() async throws -> FinancialAuthorization {
            try await Self.map(FinanceStore.shared.authorizationStatus())
        }

        func requestAuthorization() async throws -> FinancialAuthorization {
            try await Self.map(FinanceStore.shared.requestAuthorization())
        }

        func fetchAccounts() async throws -> [FinancialAccountSnapshot] {
            let query = AccountQuery(sortDescriptors: [], predicate: nil, limit: nil, offset: nil)
            let accounts = try await FinanceStore.shared.accounts(query: query)

            let balanceQuery = AccountBalanceQuery(sortDescriptors: [], predicate: nil, limit: nil, offset: nil)
            let balances = try await FinanceStore.shared.accountBalances(query: balanceQuery)
            let balancesByAccountID = Dictionary(
                balances.map { ($0.accountID, $0) },
                uniquingKeysWith: { first, _ in first }
            )

            return accounts.map { account in
                Self.snapshot(from: account, balance: balancesByAccountID[account.id])
            }
        }

        /// Incremental fetch: only transactions since the last successful sync (with a
        /// month of overlap), instead of the full history each time. On the first sync this
        /// looks back roughly six months.
        func fetchTransactions() async throws -> [FinancialTransactionSnapshot] {
            let now = Date()
            let start = FinancialSyncWindow.startDate(lastSync: syncState.lastSyncDate, now: now)
            let predicate = #Predicate<FinanceKit.Transaction> { transaction in
                transaction.transactionDate >= start
            }
            let query = TransactionQuery(
                sortDescriptors: [SortDescriptor(\.transactionDate, order: .reverse)],
                predicate: predicate,
                limit: nil,
                offset: nil
            )
            let snapshots = try await FinanceStore.shared.transactions(query: query).map(Self.snapshot(from:))
            syncState.recordSync(at: now)
            return snapshots
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

        private static func snapshot(from account: Account, balance: AccountBalance?) -> FinancialAccountSnapshot {
            FinancialAccountSnapshot(
                id: account.id.uuidString,
                displayName: account.displayName,
                institutionName: account.institutionName,
                currencyCode: account.currencyCode,
                isLiability: account.liabilityAccount != nil,
                currentBalance: balance.map(currentAmount(from:)),
                availableBalance: balance?.available?.amount.amount
            )
        }

        /// `AccountBalance.currentBalance` may carry only the available side, only the
        /// booked side, or both; when both are present the booked amount is the settled
        /// balance, which is what "current balance" means to a person looking at the app.
        private static func currentAmount(from balance: AccountBalance) -> Decimal {
            switch balance.currentBalance {
            case let .available(value):
                value.amount.amount
            case let .booked(value):
                value.amount.amount
            case let .availableAndBooked(_, booked):
                booked.amount.amount
            }
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
        func isDataAvailable() -> Bool {
            false
        }

        func authorizationStatus() async throws -> FinancialAuthorization {
            .notDetermined
        }

        func requestAuthorization() async throws -> FinancialAuthorization {
            .notDetermined
        }

        func fetchAccounts() async throws -> [FinancialAccountSnapshot] {
            []
        }

        func fetchTransactions() async throws -> [FinancialTransactionSnapshot] {
            []
        }
    }

#endif

/// Live device-owner authentication (Face ID / Touch ID / passcode). Lives here rather
/// than in `Core/` because `LAContext` can't run under unit tests.
struct LocalAuthenticationGate: BiometricAuthenticating {
    func canAuthenticate() -> Bool {
        var error: NSError?
        // deviceOwnerAuthentication includes passcode, so the person can never be locked out.
        return LAContext().canEvaluatePolicy(.deviceOwnerAuthentication, error: &error)
    }

    func authenticate(reason: String) async -> Bool {
        do {
            return try await LAContext().evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason)
        } catch {
            return false
        }
    }
}

#if canImport(BackgroundTasks)
    /// Registers and schedules a background app-refresh task so Sift can pull new on-device
    /// transactions while closed. The identifier must also appear under
    /// `BGTaskSchedulerPermittedIdentifiers` in Info.plist.
    @MainActor
    final class BackgroundRefreshController {
        static let taskIdentifier = "com.sift.app.refresh"

        private let refresh: @MainActor () async -> Void
        private let interval: TimeInterval

        init(interval: TimeInterval = 6 * 3600, refresh: @escaping @MainActor () async -> Void) {
            self.interval = interval
            self.refresh = refresh
        }

        /// Call once during launch, before the app finishes launching.
        func register() {
            BGTaskScheduler.shared.register(
                forTaskWithIdentifier: Self.taskIdentifier,
                using: .main
            ) { task in
                MainActor.assumeIsolated {
                    self.handle(task)
                }
            }
        }

        func schedule() {
            let request = BGAppRefreshTaskRequest(identifier: Self.taskIdentifier)
            request.earliestBeginDate = Date(timeIntervalSinceNow: interval)
            try? BGTaskScheduler.shared.submit(request)
        }

        private func handle(_ task: BGTask) {
            schedule()

            let work = Task { @MainActor in
                await refresh()
                task.setTaskCompleted(success: true)
            }

            task.expirationHandler = {
                work.cancel()
            }
        }
    }
#endif
