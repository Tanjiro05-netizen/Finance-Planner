import Foundation
@testable import Sift
import Testing
import UserNotifications

@MainActor
struct NotificationContentBuilderTests {
    @Test func renewalCopyIncludesExactAmountDateAndPayload() {
        let subscription = notificationTestSubscription(
            id: "sub-streamline",
            name: "Streamline+",
            amount: .usd(1549),
            cadence: .monthly,
            nextRenewal: notificationTestDate(2026, 7, 5)
        )
        let content = NotificationContentBuilder().renewalContent(for: subscription)

        #expect(content.title == "Streamline+ renews soon")
        #expect(content.body.contains("$15.49/mo"))
        #expect(content.body.contains("Jul 5"))
        #expect(SiftNotificationPayload.deepLink(from: content.userInfo) == .subscriptionDetail(id: "sub-streamline"))
    }

    @Test func priceChangePayloadRoutesToInsights() {
        let priceChange = PriceChange(
            id: "price-streamline",
            userID: SeedData.defaultUserID,
            subscriptionID: "sub-streamline",
            oldAmount: .usd(1199),
            newAmount: .usd(1549),
            changedAt: notificationTestDate(2026, 7, 1)
        )
        let subscription = notificationTestSubscription(id: "sub-streamline", name: "Streamline+")

        let content = NotificationContentBuilder().priceChangeContent(priceChange, subscription: subscription)

        #expect(content.body.contains("$11.99"))
        #expect(content.body.contains("$15.49"))
        #expect(SiftNotificationPayload.deepLink(from: content.userInfo) == .insights)
    }

    @Test func weeklySummaryPayloadRoutesHome() {
        let summary = WeeklyNotificationSummary(
            monthlyTotal: .usd(6248),
            activeSubscriptionCount: 4,
            recentPriceChangeCount: 1
        )

        let content = NotificationContentBuilder().weeklySummaryContent(summary)

        #expect(content.body.contains("$62.48/mo"))
        #expect(content.body.contains("4 active subscriptions"))
        #expect(content.body.contains("1 price change"))
        #expect(SiftNotificationPayload.deepLink(from: content.userInfo) == .home)
    }
}

func notificationTestSubscription(
    id: String = "sub-test",
    name: String = "Test App",
    amount: Money = .usd(999),
    cadence: Cadence = .monthly,
    nextRenewal: Date? = notificationTestDate(2026, 7, 10),
    lastUsed: Date? = notificationTestDate(2026, 5, 1),
    isTrialEnding: Bool = false,
    status: SubscriptionStatus = .active
) -> Subscription {
    Subscription(
        id: id,
        userID: SeedData.defaultUserID,
        name: name,
        merchantKey: MerchantKey(name),
        monogramLetter: String(name.prefix(1)),
        tileColorToken: .gold,
        amount: amount,
        cadence: cadence,
        nextRenewal: nextRenewal,
        lastUsed: lastUsed,
        categoryID: nil,
        isTrialEnding: isTrialEnding,
        status: status,
        detectionConfidence: 0.94,
        firstSeen: notificationTestDate(2026, 1, 1),
        lastCharge: notificationTestDate(2026, 6, 10)
    )
}

func notificationTestDate(_ year: Int, _ month: Int, _ day: Int, hour: Int = 8, minute: Int = 0) -> Date {
    var components = DateComponents()
    components.calendar = notificationTestCalendar()
    components.timeZone = TimeZone(secondsFromGMT: 0)
    components.year = year
    components.month = month
    components.day = day
    components.hour = hour
    components.minute = minute
    return components.date ?? Date(timeIntervalSince1970: 0)
}

func notificationTestCalendar() -> Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    return calendar
}
