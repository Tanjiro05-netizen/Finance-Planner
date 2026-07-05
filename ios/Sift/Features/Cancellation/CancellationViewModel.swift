import Foundation
import Observation

enum CancellationFlowStage: Equatable {
    case options
    case concierge
    case guided
    case confirmed
    case requests
}

enum CancellationStatusTone: Equatable {
    case progress
    case confirmed
    case needsUser
}

struct CancellationRequestRowModel: Identifiable, Equatable {
    let id: String
    let title: String
    let methodText: String
    let statusText: String
    let statusTone: CancellationStatusTone
    let annualCostText: String
    let monogramLetter: String
    let tileColorToken: ColorToken
    let needsUserAction: Bool
}

@MainActor
@Observable
final class CancellationViewModel {
    private let repositories: RepositoryContainer
    private let apiClient: any SiftAPIClient
    private let guideProvider: any CancellationGuideProviding
    private let reminderStore: any CancellationReminderIntentStoring
    private let notificationScheduler: any NotificationScheduling
    private let featureFlags: SiftFeatureFlags
    private let analyticsRecorder: any AnalyticsRecording
    private let now: () -> Date

    let subscriptionID: String

    var stage: CancellationFlowStage = .options
    var subscription: Subscription?
    var request: CancellationRequest?
    var requests: [CancellationRequest] = []
    var guide: CancellationGuide?
    var remindBeforeRenewal = false
    var isLoading = false
    var isWorking = false
    var errorMessage: String?
    var siteMessage: String?

    init(
        subscriptionID: String,
        repositories: RepositoryContainer,
        apiClient: any SiftAPIClient,
        guideProvider: any CancellationGuideProviding = CancellationGuideProvider(),
        reminderStore: any CancellationReminderIntentStoring = UserDefaultsCancellationReminderIntentStore(),
        notificationScheduler: any NotificationScheduling = NoopNotificationScheduler(),
        featureFlags: SiftFeatureFlags = .launchDefault,
        analyticsRecorder: any AnalyticsRecording = NoopAnalyticsRecorder(),
        now: @escaping () -> Date = { Date() }
    ) {
        self.subscriptionID = subscriptionID
        self.repositories = repositories
        self.apiClient = apiClient
        self.guideProvider = guideProvider
        self.reminderStore = reminderStore
        self.notificationScheduler = notificationScheduler
        self.featureFlags = featureFlags
        self.analyticsRecorder = analyticsRecorder
        self.now = now
    }

    var subscriptionName: String {
        subscription?.name ?? "Subscription"
    }

    var annualSavings: Money {
        subscription?.monthlyEquivalent.multiplied(by: 12) ?? .zeroUSD
    }

    var isConciergeEnabled: Bool {
        featureFlags.conciergeEnabled
    }

    var requestsSavings: Money {
        let subscriptions = (try? repositories.subscriptions.all()) ?? []
        return (try? CancellationSavings.realizedAnnualSavings(
            requests: requests,
            subscriptions: subscriptions
        )) ?? .zeroUSD
    }

    var requestRows: [CancellationRequestRowModel] {
        requests.map { request in
            let subscription = (try? repositories.subscriptions.subscription(id: request.subscriptionID)) ?? nil
            let annualCost = subscription?.monthlyEquivalent.multiplied(by: 12) ?? .zeroUSD

            return CancellationRequestRowModel(
                id: request.id,
                title: subscription?.name ?? request.subscriptionID,
                methodText: request.method == .concierge ? "Concierge" : "Guided",
                statusText: request.status.trackerLabel,
                statusTone: tone(for: request.status),
                annualCostText: "\(annualCost.formatted())/yr",
                monogramLetter: subscription?.monogramLetter ?? String((subscription?.name ?? "S").prefix(1)),
                tileColorToken: subscription?.tileColorToken ?? .inkFaint,
                needsUserAction: request.status == .needsUser
            )
        }
    }

    var conciergeTimelineItems: [StatusTimelineItem] {
        let status = request?.status ?? .requested

        return [
            StatusTimelineItem(
                id: "request-received",
                title: "Request received",
                subtitle: "We have the subscription and the cancellation method.",
                state: .done
            ),
            StatusTimelineItem(
                id: "provider-contact",
                title: status == .needsUser ? "Needs your help" : "Contacting provider",
                subtitle: status == .needsUser ? "The provider requires the account holder." : "We are checking the verified cancellation path.",
                state: middleTimelineState(for: status)
            ),
            StatusTimelineItem(
                id: "confirmed",
                title: "Confirmed",
                subtitle: "The subscription leaves your active total once confirmed.",
                state: status.realizesSavings ? .done : .pending
            ),
        ]
    }

    func load() {
        do {
            subscription = try repositories.subscriptions.subscription(id: subscriptionID)
            if let subscription {
                guide = guideProvider.guide(for: subscription.merchantKey, merchantName: subscription.name)
            }
            request = try repositories.cancellations.requests(for: subscriptionID).first
            remindBeforeRenewal = reminderStore.isReminderEnabled(for: subscriptionID)
            errorMessage = nil
        } catch {
            errorMessage = userFacingMessage(for: error)
        }
    }

    func chooseConcierge() async {
        guard featureFlags.conciergeEnabled else {
            analyticsRecorder.record(.featureUnavailable(name: "concierge"))
            errorMessage = "Concierge cancellation is coming soon. You can use guided steps and reminders today."
            return
        }

        await createCancellation(method: .concierge)
    }

    func chooseGuided() async {
        await createCancellation(method: .guided)
    }

    func showRequests() async {
        stage = .requests
        await loadRequests()
    }

    func loadRequests() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let remoteRequests = try await apiClient.listCancellations()
            if remoteRequests.isEmpty {
                requests = try repositories.cancellations.all()
            } else {
                requests = try remoteRequests.map { try reconcile(remote: $0) }
            }
            try reconcileResolvedSubscriptions(in: requests)
            errorMessage = nil
        } catch {
            requests = (try? repositories.cancellations.all()) ?? []
            errorMessage = userFacingMessage(for: error)
        }
    }

    func refreshCurrentRequest() async {
        isWorking = true
        defer { isWorking = false }

        do {
            let remoteRequests = try await apiClient.listCancellations()
            let reconciled = try remoteRequests.map { try reconcile(remote: $0) }
            requests = reconciled

            if let currentID = request?.id {
                request = reconciled.first { $0.id == currentID }
                    ?? reconciled.first { $0.subscriptionID == subscriptionID }
            } else {
                request = reconciled.first { $0.subscriptionID == subscriptionID }
            }

            if let request, request.status.realizesSavings {
                try markSubscriptionCancelled(subscriptionID: request.subscriptionID)
                stage = .confirmed
                analyticsRecorder.record(.cancellationConfirmed(method: request.method))
            }

            errorMessage = nil
        } catch {
            errorMessage = userFacingMessage(for: error)
        }
    }

    func confirmGuidedCancellation() async {
        guard let request else {
            return
        }

        isWorking = true
        defer { isWorking = false }

        do {
            _ = try repositories.cancellations.updateStatus(
                id: request.id,
                status: .cancelledByUser,
                now: now()
            )
            let remote = try await apiClient.updateCancellation(
                id: request.id,
                status: .cancelledByUser,
                note: "User confirmed cancellation in the guided flow."
            )
            let reconciled = try reconcile(remote: remote)
            self.request = reconciled
            try markSubscriptionCancelled(subscriptionID: reconciled.subscriptionID)
            stage = .confirmed
            analyticsRecorder.record(.cancellationConfirmed(method: reconciled.method))
            errorMessage = nil
        } catch {
            errorMessage = userFacingMessage(for: error)
        }
    }

    func switchToGuidedFromNeedsUser() async {
        await chooseGuided()
    }

    func setReminderIntent(_ isEnabled: Bool) {
        remindBeforeRenewal = isEnabled
        reminderStore.setReminderEnabled(isEnabled, for: subscriptionID)
        reconcileNotifications()
    }

    func showMissingProviderSiteMessage() {
        siteMessage = "We do not have a verified provider link for \(subscriptionName). Open the provider's website or app and follow the steps here."
    }

    private func createCancellation(method: CancellationMethod) async {
        if subscription == nil {
            load()
        }

        guard let subscription else {
            errorMessage = "This subscription is not available."
            return
        }

        isWorking = true
        errorMessage = nil
        var optimisticID: String?

        do {
            let optimistic = try repositories.cancellations.create(
                subscriptionID: subscription.id,
                method: method,
                note: method == .concierge ? "Concierge request created from the iOS app." : "Guided cancellation started from the iOS app.",
                now: now()
            )
            optimisticID = optimistic.id
            request = optimistic
            stage = method == .concierge ? .concierge : .guided
            guide = guideProvider.guide(for: subscription.merchantKey, merchantName: subscription.name)
            remindBeforeRenewal = reminderStore.isReminderEnabled(for: subscription.id)
            analyticsRecorder.record(.cancellationStarted(method: method))

            let remote = try await apiClient.createCancellation(
                subscriptionRef: subscription.id,
                merchantName: subscription.name,
                method: method
            )
            let reconciled = try reconcile(remote: remote, replacingLocalID: optimistic.id)
            request = reconciled

            if reconciled.status.realizesSavings {
                try markSubscriptionCancelled(subscriptionID: reconciled.subscriptionID)
                stage = .confirmed
                analyticsRecorder.record(.cancellationConfirmed(method: reconciled.method))
            }
        } catch {
            if let optimisticID {
                try? repositories.cancellations.delete(id: optimisticID)
            }
            request = nil
            stage = .options
            errorMessage = userFacingMessage(for: error)
        }

        isWorking = false
    }

    private func reconcile(
        remote: RemoteCancellationRequest,
        replacingLocalID localID: String? = nil
    ) throws -> CancellationRequest {
        if let localID, localID != remote.id {
            try repositories.cancellations.delete(id: localID)
        }

        let local = CancellationRequest(
            id: remote.id,
            userID: remote.userId,
            subscriptionID: remote.subscriptionRef,
            method: remote.method,
            status: remote.status,
            createdAt: remote.createdAt,
            updatedAt: remote.updatedAt,
            note: remote.note
        )
        let saved = try repositories.cancellations.upsert(local)

        if saved.status.realizesSavings {
            try markSubscriptionCancelled(subscriptionID: saved.subscriptionID)
        }

        return saved
    }

    private func reconcileResolvedSubscriptions(in requests: [CancellationRequest]) throws {
        for request in requests where request.status.realizesSavings {
            try markSubscriptionCancelled(subscriptionID: request.subscriptionID)
        }
    }

    private func markSubscriptionCancelled(subscriptionID: String) throws {
        guard let subscription = try repositories.subscriptions.subscription(id: subscriptionID) else {
            return
        }

        guard subscription.status != .cancelled else {
            return
        }

        subscription.status = .cancelled
        subscription.nextRenewal = nil
        try repositories.subscriptions.update(subscription)
        self.subscription = subscription.id == self.subscriptionID ? subscription : self.subscription
        reconcileNotifications()
    }

    private func reconcileNotifications() {
        let referenceDate = now()
        Task { [notificationScheduler] in
            try? await notificationScheduler.reconcile(referenceDate: referenceDate)
        }
    }

    private func middleTimelineState(for status: CancellationStatus) -> StatusTimelineState {
        switch status {
        case .confirmed, .cancelledByUser:
            .done
        case .requested, .contacting, .needsUser:
            .current
        }
    }

    private func tone(for status: CancellationStatus) -> CancellationStatusTone {
        switch status {
        case .requested, .contacting:
            .progress
        case .confirmed, .cancelledByUser:
            .confirmed
        case .needsUser:
            .needsUser
        }
    }

    private func userFacingMessage(for error: Error) -> String {
        if let siftError = error as? SiftError {
            return siftError.errorDescription ?? "Something went wrong."
        }

        return error.localizedDescription
    }
}
