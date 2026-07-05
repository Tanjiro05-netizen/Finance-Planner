import Foundation
import Testing
import UserNotifications
@testable import Sift

@MainActor
struct NotificationSchedulerTests {
    @Test func makeRequestsBuildsExpectedIdentifiersAndFireDates() throws {
        let repositories = try notificationRepositories()
        let scheduler = NotificationScheduler(
            repositories: repositories,
            center: RecordingNotificationCenter(),
            calendar: notificationTestCalendar()
        )

        let requests = try scheduler.makeRequests(referenceDate: notificationTestDate(2026, 7, 1))
        let identifiers = requests.map(\.identifier)

        #expect(identifiers == [
            "price-change-price-streamline",
            "renewal-sub-renewal",
            "trial-sub-trial",
            "unused-sub-unused",
        ])

        let renewalTrigger = try trigger(in: requests, id: "renewal-sub-renewal")
        #expect(renewalTrigger.repeats == false)
        #expect(renewalTrigger.dateComponents.year == 2026)
        #expect(renewalTrigger.dateComponents.month == 7)
        #expect(renewalTrigger.dateComponents.day == 3)
        #expect(renewalTrigger.dateComponents.hour == NotificationScheduler.notificationHour)

        let trialTrigger = try trigger(in: requests, id: "trial-sub-trial")
        #expect(trialTrigger.dateComponents.day == 4)

        let unusedTrigger = try trigger(in: requests, id: "unused-sub-unused")
        #expect(unusedTrigger.dateComponents.day == 2)

        let priceTrigger = try trigger(in: requests, id: "price-change-price-streamline")
        #expect(priceTrigger.dateComponents.minute == 5)
    }

    @Test func disablingAFlagRemovesPendingNotificationsForThatKind() async throws {
        let repositories = try notificationRepositories()
        let center = RecordingNotificationCenter()
        let scheduler = NotificationScheduler(
            repositories: repositories,
            center: center,
            calendar: notificationTestCalendar()
        )
        let referenceDate = notificationTestDate(2026, 7, 1)

        _ = try await scheduler.reconcile(referenceDate: referenceDate)
        #expect(center.pendingIdentifiers.contains("renewal-sub-renewal"))

        let settings = try repositories.settings.settings()
        settings.renewalReminders = false
        try repositories.settings.update(settings)
        let result = try await scheduler.reconcile(referenceDate: referenceDate)

        #expect(!center.pendingIdentifiers.contains("renewal-sub-renewal"))
        #expect(result.cancelledIdentifiers.contains("renewal-sub-renewal"))
    }

    @Test func cancellingSubscriptionRemovesRenewalAndTrialRequests() async throws {
        let repositories = try notificationRepositories()
        let center = RecordingNotificationCenter()
        let scheduler = NotificationScheduler(
            repositories: repositories,
            center: center,
            calendar: notificationTestCalendar()
        )
        let referenceDate = notificationTestDate(2026, 7, 1)

        _ = try await scheduler.reconcile(referenceDate: referenceDate)
        #expect(center.pendingIdentifiers.contains("trial-sub-trial"))

        let trial = try #require(try repositories.subscriptions.subscription(id: "sub-trial"))
        trial.status = .cancelled
        trial.nextRenewal = nil
        try repositories.subscriptions.update(trial)
        _ = try await scheduler.reconcile(referenceDate: referenceDate)

        #expect(!center.pendingIdentifiers.contains("trial-sub-trial"))
    }

    @Test func reconcileIsIdempotentByStableIdentifier() async throws {
        let repositories = try notificationRepositories()
        let center = RecordingNotificationCenter()
        let scheduler = NotificationScheduler(
            repositories: repositories,
            center: center,
            calendar: notificationTestCalendar()
        )
        let referenceDate = notificationTestDate(2026, 7, 1)

        let first = try await scheduler.reconcile(referenceDate: referenceDate)
        let second = try await scheduler.reconcile(referenceDate: referenceDate)

        #expect(first.scheduledIdentifiers == second.scheduledIdentifiers)
        #expect(center.pendingIdentifiers.count == Set(center.pendingIdentifiers).count)
        #expect(center.pendingIdentifiers.sorted() == first.scheduledIdentifiers)
    }

    @Test func weeklySummaryUsesRepeatingSundayTriggerWhenEnabled() throws {
        let repositories = try notificationRepositories()
        let settings = try repositories.settings.settings()
        settings.weeklySummary = true
        try repositories.settings.update(settings)
        let scheduler = NotificationScheduler(
            repositories: repositories,
            center: RecordingNotificationCenter(),
            calendar: notificationTestCalendar()
        )

        let requests = try scheduler.makeRequests(referenceDate: notificationTestDate(2026, 7, 1))
        let weeklyTrigger = try trigger(in: requests, id: "weekly-summary")

        #expect(weeklyTrigger.repeats)
        #expect(weeklyTrigger.dateComponents.weekday == NotificationScheduler.weeklySummaryWeekday)
        #expect(weeklyTrigger.dateComponents.hour == NotificationScheduler.notificationHour)
    }
}

@MainActor
private func notificationRepositories() throws -> RepositoryContainer {
    let repositories = RepositoryContainer.emptyMock()
    try repositories.subscriptions.insert(notificationTestSubscription(
        id: "sub-renewal",
        name: "Renewal App",
        nextRenewal: notificationTestDate(2026, 7, 5),
        status: .active
    ))
    try repositories.subscriptions.insert(notificationTestSubscription(
        id: "sub-trial",
        name: "Trial App",
        nextRenewal: notificationTestDate(2026, 7, 6),
        isTrialEnding: true,
        status: .active
    ))
    try repositories.subscriptions.insert(notificationTestSubscription(
        id: "sub-unused",
        name: "Unused App",
        nextRenewal: notificationTestDate(2026, 7, 10),
        lastUsed: notificationTestDate(2026, 4, 1),
        status: .unused
    ))
    try repositories.subscriptions.insert(notificationTestSubscription(
        id: "sub-cancelled",
        name: "Cancelled App",
        nextRenewal: notificationTestDate(2026, 7, 5),
        status: .cancelled
    ))
    try repositories.priceChanges.insert(PriceChange(
        id: "price-streamline",
        userID: SeedData.defaultUserID,
        subscriptionID: "sub-renewal",
        oldAmount: .usd(999),
        newAmount: .usd(1_199),
        changedAt: notificationTestDate(2026, 6, 30)
    ))
    return repositories
}

private func trigger(
    in requests: [UNNotificationRequest],
    id: String
) throws -> UNCalendarNotificationTrigger {
    let request = try #require(requests.first { $0.identifier == id })
    return try #require(request.trigger as? UNCalendarNotificationTrigger)
}

@MainActor
private final class RecordingNotificationCenter: NotificationCenterScheduling, @unchecked Sendable {
    var state: NotificationAuthorizationState = .authorized
    private var requestsByIdentifier: [String: UNNotificationRequest] = [:]
    private(set) var removedIdentifiers: [String] = []

    var pendingIdentifiers: [String] {
        requestsByIdentifier.keys.sorted()
    }

    func authorizationState() async -> NotificationAuthorizationState {
        state
    }

    func pendingNotificationRequests() async -> [UNNotificationRequest] {
        Array(requestsByIdentifier.values)
    }

    func add(_ request: UNNotificationRequest) async throws {
        requestsByIdentifier[request.identifier] = request
    }

    func removePendingNotificationRequests(withIdentifiers identifiers: [String]) {
        removedIdentifiers.append(contentsOf: identifiers)
        for identifier in identifiers {
            requestsByIdentifier[identifier] = nil
        }
    }
}
