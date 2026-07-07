import Foundation
import Observation
import UserNotifications

enum OnboardingStep: Int, CaseIterable {
    case splash
    case welcome
    case connectIntro
    case bankPicker
    case secureLeadIn
    case scanning
    case reviewFound
    case notifications
    case allSet
    case connectUnavailable
}

/// Why the Apple Wallet connection produced nothing to scan.
enum ConnectUnavailableReason {
    /// The person declined the FinanceKit permission prompt.
    case accessDenied
    /// Access was granted but there is no Apple Card / Cash / Pay activity to read.
    case noWalletData
}

struct ReviewSubscriptionItem: Identifiable, Equatable {
    let detection: DetectedSubscription
    var isSelected: Bool

    var id: String {
        detection.id
    }
}

struct ScanState: Equatable {
    var progress: Double = 0
    var foundCount: Int = 0
    var status: String = "Preparing secure sync"
}

protocol NotificationAuthorizing: Sendable {
    @MainActor func requestAuthorization() async -> Bool
}

struct UserNotificationAuthorizer: NotificationAuthorizing {
    @MainActor
    func requestAuthorization() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current().requestAuthorization(
                options: [.alert, .badge, .sound]
            )
        } catch {
            return false
        }
    }
}

struct MockNotificationAuthorizer: NotificationAuthorizing {
    var authorized = true

    @MainActor
    func requestAuthorization() async -> Bool {
        authorized
    }
}

@MainActor
@Observable
final class OnboardingViewModel {
    private let apiClient: any SiftAPIClient
    private let linkCoordinator: any OnboardingLinkCoordinating
    private let detectionService: any DetectionServing
    private let notificationAuthorizer: any NotificationAuthorizing
    private let notificationScheduler: any NotificationScheduling
    private let repositories: RepositoryContainer
    private let stateStore: any OnboardingStateStoring
    private let userID: String

    var step: OnboardingStep = .splash
    var selectedInstitution: BankInstitution?
    var scanState = ScanState()
    var reviewItems: [ReviewSubscriptionItem] = []
    var isWorking = false
    var errorMessage: String?
    var notificationsAuthorized = false
    var confirmedCount = 0
    var confirmedMonthlyTotal = Money.zeroUSD
    var unavailableReason: ConnectUnavailableReason?

    init(
        apiClient: any SiftAPIClient,
        linkCoordinator: any OnboardingLinkCoordinating,
        detectionService: any DetectionServing,
        notificationAuthorizer: any NotificationAuthorizing,
        notificationScheduler: any NotificationScheduling = NoopNotificationScheduler(),
        repositories: RepositoryContainer,
        stateStore: any OnboardingStateStoring,
        userID: String = SeedData.defaultUserID
    ) {
        self.apiClient = apiClient
        self.linkCoordinator = linkCoordinator
        self.detectionService = detectionService
        self.notificationAuthorizer = notificationAuthorizer
        self.notificationScheduler = notificationScheduler
        self.repositories = repositories
        self.stateStore = stateStore
        self.userID = userID
    }

    func bootstrapIfNeeded() async {
        guard step == .splash else {
            return
        }

        await run {
            _ = try await apiClient.bootstrap()
            step = .welcome
        }
    }

    func showConnectIntro() {
        move(to: .connectIntro)
    }

    /// Apple Wallet path: move to the permission lead-in before prompting FinanceKit.
    func showConnectLeadIn() {
        move(to: .secureLeadIn)
    }

    /// Apple Wallet path: request FinanceKit access and, on success, scan on-device
    /// transactions. No institution is chosen — the source is the user's Wallet.
    func connectAppleWallet() async {
        await run {
            let outcome = try await linkCoordinator.linkAccount(institution: nil)

            switch outcome {
            case .linked:
                step = .scanning
                try await scan()
            case .cancelled:
                unavailableReason = .accessDenied
                step = .connectUnavailable
            }
        }
    }

    /// Retry the Apple Wallet permission after an unavailable state.
    func retryConnect() {
        unavailableReason = nil
        move(to: .secureLeadIn)
    }

    /// Continue onboarding without connected data (nothing to review yet).
    func skipConnect() {
        unavailableReason = nil
        confirmedCount = 0
        confirmedMonthlyTotal = .zeroUSD
        move(to: .notifications)
    }

    /// Plaid path (retained for a future Android port and covered by tests).
    func showBankPicker() {
        move(to: .bankPicker)
    }

    func selectInstitution(_ institution: BankInstitution) {
        selectedInstitution = institution
        move(to: .secureLeadIn)
    }

    func connectSelectedInstitution() async {
        guard selectedInstitution != nil else {
            move(to: .bankPicker)
            return
        }

        await run {
            let outcome = try await linkCoordinator.linkAccount(institution: selectedInstitution)

            switch outcome {
            case .linked:
                step = .scanning
                try await scan()
            case .cancelled:
                step = .connectIntro
                errorMessage = "Connection canceled. You can try again whenever you're ready."
            }
        }
    }

    func toggleReviewItem(id: String) {
        guard let index = reviewItems.firstIndex(where: { $0.id == id }) else {
            return
        }

        reviewItems[index].isSelected.toggle()
    }

    func confirmSubscriptions() {
        do {
            let confirmed = reviewItems.filter(\.isSelected).map(\.detection)

            for detection in confirmed {
                let subscription = detection.makeSubscription(userID: userID)

                if try repositories.subscriptions.subscription(id: subscription.id) == nil {
                    try repositories.subscriptions.insert(subscription)
                } else {
                    try repositories.subscriptions.update(subscription)
                }
            }

            confirmedCount = confirmed.count
            confirmedMonthlyTotal = try Money.sum(confirmed.map { $0.cadence.monthlyEquivalent(for: $0.amount) })
            step = .notifications
            errorMessage = nil
        } catch {
            errorMessage = userFacingMessage(for: error)
        }
    }

    func requestNotifications() async {
        notificationsAuthorized = await notificationAuthorizer.requestAuthorization()
        if notificationsAuthorized {
            _ = try? await notificationScheduler.reconcile()
        }
        move(to: .allSet)
    }

    func skipNotifications() {
        notificationsAuthorized = false
        move(to: .allSet)
    }

    func completeOnboarding() {
        stateStore.setComplete(true)
    }

    private func scan() async throws {
        scanState = ScanState(progress: 0.18, foundCount: 0, status: "Syncing recent transactions")
        let sync = try await apiClient.syncTransactions()
        scanState = ScanState(
            progress: 0.52,
            foundCount: 0,
            status: "Scanned \(sync.added + sync.modified) transactions"
        )

        let importedCount = try await importSyncedTransactions()
        try await importAccounts()
        scanState = ScanState(
            progress: 0.72,
            foundCount: 0,
            status: "Imported \(importedCount) transactions"
        )

        let detections = try await detectionService.detect()

        if detections.isEmpty, importedCount == 0 {
            unavailableReason = .noWalletData
            step = .connectUnavailable
            return
        }

        reviewItems = detections.map { ReviewSubscriptionItem(detection: $0, isSelected: true) }
        scanState = ScanState(
            progress: 1,
            foundCount: detections.count,
            status: "\(detections.count) found · grouping by merchant"
        )
        step = .reviewFound
    }

    private func importAccounts() async throws {
        let accounts = try await apiClient.listAccounts().map {
            LinkedAccount(remote: $0, userID: userID)
        }
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
                try repositories.transactions.upsert(Transaction(
                    id: record.id,
                    userID: record.userId,
                    accountID: record.accountId,
                    merchantRaw: record.merchantName,
                    merchantKey: merchant.merchantKey,
                    amount: Money(amountMinor: record.amountMinor, currency: record.isoCurrency),
                    date: record.date,
                    pending: record.pending,
                    categoryHint: record.category
                ))
            }

            importedCount += records.count
            guard records.count == pageLimit else {
                return importedCount
            }
            offset += records.count
        }
    }

    private func run(_ operation: () async throws -> Void) async {
        isWorking = true
        errorMessage = nil

        do {
            try await operation()
        } catch is CancellationError {
            isWorking = false
            return
        } catch {
            errorMessage = userFacingMessage(for: error)
        }

        isWorking = false
    }

    private func move(to nextStep: OnboardingStep) {
        errorMessage = nil
        step = nextStep
    }

    private func userFacingMessage(for error: Error) -> String {
        if let siftError = error as? SiftError {
            return siftError.errorDescription ?? "Something went wrong."
        }

        return error.localizedDescription
    }
}
