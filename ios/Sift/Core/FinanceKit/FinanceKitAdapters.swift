import Foundation

/// A `SiftAPIClient` backed entirely by on-device financial data instead of a remote
/// server. It lets the existing onboarding scan and `SubscriptionRefreshService`
/// pipelines pull real Apple Wallet transactions without any code changes downstream:
/// `syncTransactions()` reports how many charges are available and
/// `listTransactions(limit:offset:)` pages the mapped debits into the detection engine.
///
/// Server-only concepts (Plaid item linking, concierge cancellation) resolve locally or
/// report as unsupported, since this build has no backend.
struct FinanceKitAPIClient: SiftAPIClient {
    private let store: any FinancialDataStore
    private let userID: String

    init(store: any FinancialDataStore, userID: String = SeedData.defaultUserID) {
        self.store = store
        self.userID = userID
    }

    func bootstrap() async throws -> AuthBootstrapResponse {
        AuthBootstrapResponse(token: "on-device")
    }

    func createLinkToken() async throws -> LinkTokenResponse {
        // Authorization happens through the FinanceKit permission sheet, not a Plaid
        // link token; this value is only a placeholder for the shared link flow.
        LinkTokenResponse(linkToken: "on-device")
    }

    func exchange(publicToken _: String) async throws -> ExchangePublicTokenResponse {
        ExchangePublicTokenResponse(ok: true)
    }

    func listAccounts() async throws -> [RemoteAccount] {
        try await authorizedSnapshotAccounts().map(FinancialDataMapper.remoteAccount(from:))
    }

    func deletePlaidItem(id _: String) async throws -> APIOKResponse {
        APIOKResponse(ok: true)
    }

    func deleteUserData() async throws -> APIOKResponse {
        APIOKResponse(ok: true)
    }

    func syncTransactions() async throws -> TransactionSyncResponse {
        // Counts every ledger row (debits and credits), not just subscription-eligible
        // charges -- this response reports what's available to import, and the ledger
        // wants the full picture. Subscription detection reads its own debit-only path.
        let rows = try await allTransactions()
        return TransactionSyncResponse(
            added: rows.count,
            modified: 0,
            removed: 0,
            hasMore: false
        )
    }

    func listTransactions(limit: Int, offset: Int) async throws -> [RemoteTransaction] {
        let rows = try await allTransactions()
        guard limit > 0, offset < rows.count else {
            return []
        }

        let start = max(offset, 0)
        let end = min(start + limit, rows.count)
        guard start < end else {
            return []
        }

        return rows[start ..< end].map {
            FinancialDataMapper.remoteTransaction(from: $0, userID: userID)
        }
    }

    /// No server, so no concierge. Declared rather than discovered by failing a request.
    var supportsConcierge: Bool {
        false
    }

    func createCancellation(
        subscriptionRef _: String,
        merchantName _: String,
        method _: CancellationMethod
    ) async throws -> RemoteCancellationRequest {
        throw SiftError.api(
            code: "unsupported",
            message: "Concierge cancellation needs a Sift account and isn't available in on-device mode."
        )
    }

    func listCancellations() async throws -> [RemoteCancellationRequest] {
        []
    }

    func updateCancellation(
        id _: String,
        status _: CancellationStatus,
        note _: String?
    ) async throws -> RemoteCancellationRequest {
        throw SiftError.api(
            code: "unsupported",
            message: "Concierge cancellation needs a Sift account and isn't available in on-device mode."
        )
    }

    private func allTransactions() async throws -> [FinancialTransactionSnapshot] {
        guard store.isDataAvailable() else {
            return []
        }
        guard try await store.authorizationStatus() == .authorized else {
            return []
        }

        return try await FinancialDataMapper.allTransactions(from: store.fetchTransactions())
    }

    private func authorizedSnapshotAccounts() async throws -> [FinancialAccountSnapshot] {
        guard store.isDataAvailable() else {
            return []
        }
        guard try await store.authorizationStatus() == .authorized else {
            return []
        }

        return try await store.fetchAccounts()
    }
}

/// Presents the FinanceKit authorization prompt in place of the Plaid Link sheet.
///
/// It conforms to `PlaidLinkPresenting` so the existing `PlaidLinkCoordinator`
/// onboarding orchestration continues to work unchanged: a granted prompt reports
/// success, a denied or undetermined prompt reads as a cancellation the person can retry.
final class FinanceKitLinkPresenter: PlaidLinkPresenting, @unchecked Sendable {
    private let store: any FinancialDataStore

    init(store: any FinancialDataStore) {
        self.store = store
    }

    @MainActor
    func link(with _: String, institutionName _: String?) async throws -> PlaidLinkResult {
        guard store.isDataAvailable() else {
            throw SiftError.api(
                code: "financekit_unavailable",
                message: "This device can't share financial data. Apple Card, Apple Cash, or Apple Pay is required."
            )
        }

        switch try await store.requestAuthorization() {
        case .authorized:
            return .success(publicToken: "on-device")
        case .denied, .notDetermined:
            return .cancelled
        }
    }
}
