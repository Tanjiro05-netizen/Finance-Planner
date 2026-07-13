import Foundation
import UserNotifications

enum NotificationAuthorizationState: Equatable {
    case authorized
    case denied
    case notDetermined
}

struct NotificationReconcileResult: Equatable {
    let authorizationState: NotificationAuthorizationState
    let scheduledIdentifiers: [String]
    let cancelledIdentifiers: [String]
}

protocol NotificationCenterScheduling: AnyObject, Sendable {
    @MainActor func authorizationState() async -> NotificationAuthorizationState
    @MainActor func pendingNotificationRequests() async -> [UNNotificationRequest]
    @MainActor func add(_ request: UNNotificationRequest) async throws
    @MainActor func removePendingNotificationRequests(withIdentifiers identifiers: [String])
}

final class UserNotificationSchedulingCenter: NotificationCenterScheduling, @unchecked Sendable {
    private let center: UNUserNotificationCenter

    init(center: UNUserNotificationCenter = .current()) {
        self.center = center
    }

    @MainActor
    func authorizationState() async -> NotificationAuthorizationState {
        let settings = await center.notificationSettings()

        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return .authorized
        case .denied:
            return .denied
        case .notDetermined:
            return .notDetermined
        @unknown default:
            return .notDetermined
        }
    }

    @MainActor
    func pendingNotificationRequests() async -> [UNNotificationRequest] {
        await center.pendingNotificationRequests()
    }

    @MainActor
    func add(_ request: UNNotificationRequest) async throws {
        try await center.add(request)
    }

    @MainActor
    func removePendingNotificationRequests(withIdentifiers identifiers: [String]) {
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
    }
}

protocol NotificationScheduling: Sendable {
    @MainActor
    @discardableResult
    func reconcile(referenceDate: Date) async throws -> NotificationReconcileResult

    @MainActor func cancelAllSiftNotifications() async
    @MainActor func authorizationState() async -> NotificationAuthorizationState
}

extension NotificationScheduling {
    @MainActor
    @discardableResult
    func reconcile() async throws -> NotificationReconcileResult {
        try await reconcile(referenceDate: Date())
    }
}

struct NoopNotificationScheduler: NotificationScheduling {
    @MainActor
    func reconcile(referenceDate _: Date) async throws -> NotificationReconcileResult {
        NotificationReconcileResult(authorizationState: .notDetermined, scheduledIdentifiers: [], cancelledIdentifiers: [])
    }

    @MainActor
    func cancelAllSiftNotifications() async {}

    @MainActor
    func authorizationState() async -> NotificationAuthorizationState {
        .notDetermined
    }
}

@MainActor
final class NotificationScheduler: NotificationScheduling, @unchecked Sendable {
    static let renewalReminderLeadDays = 2
    static let trialEndingLeadDays = 2
    static let notificationHour = 9
    static let unusedNudgeDelayDays = 1
    static let priceChangeLookbackDays = 14
    static let priceChangeDelayMinutes = 5
    static let weeklySummaryWeekday = 1

    private let repositories: RepositoryContainer
    private let center: any NotificationCenterScheduling
    private let contentBuilder: NotificationContentBuilder
    private var calendar: Calendar

    init(
        repositories: RepositoryContainer,
        center: any NotificationCenterScheduling = UserNotificationSchedulingCenter(),
        contentBuilder: NotificationContentBuilder = NotificationContentBuilder(),
        calendar: Calendar = .current
    ) {
        self.repositories = repositories
        self.center = center
        self.contentBuilder = contentBuilder
        self.calendar = calendar
    }

    @discardableResult
    func reconcile(referenceDate: Date) async throws -> NotificationReconcileResult {
        let state = await center.authorizationState()
        let pendingIDs = await managedPendingIdentifiers()

        guard state == .authorized else {
            center.removePendingNotificationRequests(withIdentifiers: pendingIDs)
            return NotificationReconcileResult(
                authorizationState: state,
                scheduledIdentifiers: [],
                cancelledIdentifiers: pendingIDs
            )
        }

        let requests = try makeRequests(referenceDate: referenceDate)
        let desiredIDs = requests.map(\.identifier)
        let idsToReplace = Array(Set(pendingIDs).union(desiredIDs)).sorted()
        center.removePendingNotificationRequests(withIdentifiers: idsToReplace)

        for request in requests {
            try await center.add(request)
        }

        return NotificationReconcileResult(
            authorizationState: state,
            scheduledIdentifiers: desiredIDs.sorted(),
            cancelledIdentifiers: idsToReplace.filter { !desiredIDs.contains($0) }
        )
    }

    func cancelAllSiftNotifications() async {
        let pendingIDs = await managedPendingIdentifiers()
        center.removePendingNotificationRequests(withIdentifiers: pendingIDs)
    }

    func authorizationState() async -> NotificationAuthorizationState {
        await center.authorizationState()
    }

    func makeRequests(referenceDate: Date) throws -> [UNNotificationRequest] {
        let settings = try repositories.settings.settings()
        let subscriptions = try repositories.subscriptions.all()
            .filter { $0.status != .cancelled }
        let subscriptionsByID = Dictionary(uniqueKeysWithValues: subscriptions.map { ($0.id, $0) })
        let priceChanges = try repositories.priceChanges.all()
        var requests: [UNNotificationRequest] = []

        if settings.renewalReminders {
            requests += subscriptions.compactMap { subscription in
                // Active subscriptions only: unused ones get the nudge instead of a
                // renewal reminder, and trial-ending ones get the trial alert.
                guard subscription.status == .active, !subscription.isTrialEnding else {
                    return nil
                }

                return renewalRequest(for: subscription, referenceDate: referenceDate)
            }
        }

        if settings.trialEndings {
            requests += subscriptions.compactMap { subscription in
                guard subscription.isTrialEnding else {
                    return nil
                }

                return trialEndingRequest(for: subscription, referenceDate: referenceDate)
            }
        }

        if settings.unusedNudges {
            requests += subscriptions.compactMap { subscription in
                guard subscription.status == .unused else {
                    return nil
                }

                return unusedNudgeRequest(for: subscription, referenceDate: referenceDate)
            }
        }

        if settings.priceChanges {
            requests += priceChanges.compactMap { priceChange in
                priceChangeRequest(
                    for: priceChange,
                    subscription: subscriptionsByID[priceChange.subscriptionID],
                    referenceDate: referenceDate
                )
            }
        }

        if settings.weeklySummary {
            requests.append(weeklySummaryRequest(
                subscriptions: subscriptions,
                priceChanges: priceChanges,
                referenceDate: referenceDate
            ))
        }

        return requests.sorted { $0.identifier < $1.identifier }
    }

    private func renewalRequest(for subscription: Subscription, referenceDate: Date) -> UNNotificationRequest? {
        guard let fireDate = reminderFireDate(
            renewalDate: subscription.nextRenewal,
            leadDays: Self.renewalReminderLeadDays,
            referenceDate: referenceDate
        ) else {
            return nil
        }

        return UNNotificationRequest(
            identifier: "\(SiftNotificationKind.renewal.identifierPrefix)\(subscription.id)",
            content: contentBuilder.renewalContent(for: subscription),
            trigger: oneShotTrigger(fireDate: fireDate)
        )
    }

    private func trialEndingRequest(for subscription: Subscription, referenceDate: Date) -> UNNotificationRequest? {
        guard let fireDate = reminderFireDate(
            renewalDate: subscription.nextRenewal,
            leadDays: Self.trialEndingLeadDays,
            referenceDate: referenceDate
        ) else {
            return nil
        }

        return UNNotificationRequest(
            identifier: "\(SiftNotificationKind.trialEnding.identifierPrefix)\(subscription.id)",
            content: contentBuilder.trialEndingContent(for: subscription),
            trigger: oneShotTrigger(fireDate: fireDate)
        )
    }

    private func unusedNudgeRequest(for subscription: Subscription, referenceDate: Date) -> UNNotificationRequest {
        let startOfDay = calendar.startOfDay(for: referenceDate)
        let nudgeDay = calendar.date(byAdding: .day, value: Self.unusedNudgeDelayDays, to: startOfDay) ?? referenceDate
        let fireDate = calendar.date(bySettingHour: Self.notificationHour, minute: 0, second: 0, of: nudgeDay) ?? nudgeDay

        return UNNotificationRequest(
            identifier: "\(SiftNotificationKind.unusedNudge.identifierPrefix)\(subscription.id)",
            content: contentBuilder.unusedNudgeContent(for: subscription),
            trigger: oneShotTrigger(fireDate: fireDate)
        )
    }

    private func priceChangeRequest(
        for priceChange: PriceChange,
        subscription: Subscription?,
        referenceDate: Date
    ) -> UNNotificationRequest? {
        let cutoff = calendar.date(
            byAdding: .day,
            value: -Self.priceChangeLookbackDays,
            to: referenceDate
        ) ?? referenceDate

        guard priceChange.changedAt >= cutoff else {
            return nil
        }

        let fireDate = calendar.date(
            byAdding: .minute,
            value: Self.priceChangeDelayMinutes,
            to: referenceDate
        ) ?? referenceDate

        return UNNotificationRequest(
            identifier: "\(SiftNotificationKind.priceChange.identifierPrefix)\(priceChange.id)",
            content: contentBuilder.priceChangeContent(priceChange, subscription: subscription),
            trigger: oneShotTrigger(fireDate: fireDate)
        )
    }

    private func weeklySummaryRequest(
        subscriptions: [Subscription],
        priceChanges: [PriceChange],
        referenceDate: Date
    ) -> UNNotificationRequest {
        let weekCutoff = calendar.date(byAdding: .day, value: -7, to: referenceDate) ?? referenceDate
        let monthlyTotal = (try? Money.sum(subscriptions.map(\.monthlyEquivalent))) ?? .zeroUSD
        let summary = WeeklyNotificationSummary(
            monthlyTotal: monthlyTotal,
            activeSubscriptionCount: subscriptions.count,
            recentPriceChangeCount: priceChanges.count(where: { $0.changedAt >= weekCutoff })
        )

        var components = DateComponents()
        components.calendar = calendar
        components.timeZone = calendar.timeZone
        components.weekday = Self.weeklySummaryWeekday
        components.hour = Self.notificationHour
        components.minute = 0

        return UNNotificationRequest(
            identifier: SiftNotificationKind.weeklySummary.identifierPrefix,
            content: contentBuilder.weeklySummaryContent(summary),
            trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        )
    }

    private func reminderFireDate(renewalDate: Date?, leadDays: Int, referenceDate: Date) -> Date? {
        guard
            let renewalDate,
            let reminderDay = calendar.date(byAdding: .day, value: -leadDays, to: renewalDate)
        else {
            return nil
        }

        let fireDate = calendar.date(
            bySettingHour: Self.notificationHour,
            minute: 0,
            second: 0,
            of: reminderDay
        ) ?? reminderDay

        return fireDate > referenceDate ? fireDate : nil
    }

    private func oneShotTrigger(fireDate: Date) -> UNCalendarNotificationTrigger {
        var components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
        components.calendar = calendar
        components.timeZone = calendar.timeZone
        return UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
    }

    private func managedPendingIdentifiers() async -> [String] {
        let pending = await center.pendingNotificationRequests()
        return pending.map(\.identifier)
            .filter(Self.isManagedIdentifier)
            .sorted()
    }

    static func isManagedIdentifier(_ identifier: String) -> Bool {
        SiftNotificationKind.allCases.contains { kind in
            switch kind {
            case .weeklySummary:
                identifier == kind.identifierPrefix
            case .renewal, .priceChange, .trialEnding, .unusedNudge:
                identifier.hasPrefix(kind.identifierPrefix)
            }
        }
    }
}
