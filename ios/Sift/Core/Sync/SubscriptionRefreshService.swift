import Foundation

struct SubscriptionRefreshResult: Equatable {
    let synced: TransactionSyncResponse
    let importedTransactionCount: Int
    let detectionResult: DetectionResult
}

protocol SubscriptionRefreshing: Sendable {
    @MainActor
    func refresh(referenceDate: Date) async throws -> SubscriptionRefreshResult
}

extension SubscriptionRefreshing {
    @MainActor
    func refresh() async throws -> SubscriptionRefreshResult {
        try await refresh(referenceDate: Date())
    }
}

final class DefaultSubscriptionRefreshService: SubscriptionRefreshing, @unchecked Sendable {
    private let apiClient: any SiftAPIClient
    private let detectionService: any DetectionServing
    private let notificationScheduler: any NotificationScheduling
    private let repositories: RepositoryContainer
    private let userID: String

    init(
        apiClient: any SiftAPIClient,
        detectionService: any DetectionServing,
        repositories: RepositoryContainer,
        notificationScheduler: any NotificationScheduling = NoopNotificationScheduler(),
        userID: String = SeedData.defaultUserID
    ) {
        self.apiClient = apiClient
        self.detectionService = detectionService
        self.repositories = repositories
        self.notificationScheduler = notificationScheduler
        self.userID = userID
    }

    @MainActor
    func refresh(referenceDate: Date) async throws -> SubscriptionRefreshResult {
        let synced = try await apiClient.syncTransactions()
        let importedCount = try await importSyncedTransactions()
        try await importAccounts()
        let result = try await detectionService.recompute(referenceDate: referenceDate)
        try await notificationScheduler.reconcile(referenceDate: referenceDate)

        return SubscriptionRefreshResult(
            synced: synced,
            importedTransactionCount: importedCount,
            detectionResult: result
        )
    }

    @MainActor
    private func importAccounts() async throws {
        let accounts = try await apiClient.listAccounts().map {
            LinkedAccount(remote: $0, userID: userID)
        }
        // Skip when empty so a transient unauthorized state can't wipe stored accounts.
        guard !accounts.isEmpty else {
            return
        }
        try repositories.accounts.replaceAll(with: accounts)
    }

    private func importSyncedTransactions() async throws -> Int {
        let pageLimit = 100
        var offset = 0
        var importedCount = 0
        let normalizer = MerchantNormalizer()

        while true {
            let records = try await apiClient.listTransactions(limit: pageLimit, offset: offset)
            guard !records.isEmpty else {
                return importedCount
            }

            for record in records {
                let merchant = normalizer.normalize(record.merchantName)
                try await upsert(record: record, merchantKey: merchant.merchantKey)
            }

            importedCount += records.count

            guard records.count == pageLimit else {
                return importedCount
            }

            offset += records.count
        }
    }

    @MainActor
    private func upsert(record: RemoteTransaction, merchantKey: MerchantKey) throws {
        let transaction = Transaction(remote: record, merchantKey: merchantKey, source: .financeKit)
        if transaction.direction == .credit {
            let priorDebits = try repositories.transactions.transactions(for: transaction.accountID)
                .filter { $0.direction == .debit }
            transaction.kind = TransactionClassifier.refine(
                kind: transaction.kind,
                direction: transaction.direction,
                merchantKey: transaction.merchantKey,
                accountID: transaction.accountID,
                amount: transaction.amount,
                date: transaction.date,
                priorDebits: priorDebits
            )
        }
        try repositories.transactions.upsert(transaction)
    }
}

struct NoopSubscriptionRefreshService: SubscriptionRefreshing {
    var result = SubscriptionRefreshResult(
        synced: TransactionSyncResponse(added: 0, modified: 0, removed: 0, hasMore: false),
        importedTransactionCount: 0,
        detectionResult: .empty
    )

    @MainActor
    func refresh(referenceDate _: Date) async throws -> SubscriptionRefreshResult {
        result
    }
}
