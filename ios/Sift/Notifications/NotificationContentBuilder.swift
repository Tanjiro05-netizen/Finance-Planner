import Foundation
import UserNotifications

enum SiftNotificationKind: String, CaseIterable {
    case renewal
    case priceChange = "price-change"
    case trialEnding = "trial-ending"
    case unusedNudge = "unused-nudge"
    case weeklySummary = "weekly-summary"

    var identifierPrefix: String {
        switch self {
        case .renewal:
            "renewal-"
        case .priceChange:
            "price-change-"
        case .trialEnding:
            "trial-"
        case .unusedNudge:
            "unused-"
        case .weeklySummary:
            "weekly-summary"
        }
    }
}

enum SiftNotificationPayload {
    static let typeKey = "type"
    static let subscriptionIDKey = "subscriptionID"

    static func userInfo(kind: SiftNotificationKind, subscriptionID: String? = nil) -> [AnyHashable: Any] {
        var payload: [AnyHashable: Any] = [
            typeKey: kind.rawValue,
        ]

        if let subscriptionID {
            payload[subscriptionIDKey] = subscriptionID
        }

        return payload
    }

    static func deepLink(from userInfo: [AnyHashable: Any]) -> DeepLink? {
        guard
            let rawType = userInfo[typeKey] as? String,
            let kind = SiftNotificationKind(rawValue: rawType)
        else {
            return nil
        }

        switch kind {
        case .renewal, .trialEnding, .unusedNudge:
            guard let subscriptionID = userInfo[subscriptionIDKey] as? String else {
                return nil
            }
            return .subscriptionDetail(id: subscriptionID)
        case .priceChange:
            return .insights
        case .weeklySummary:
            return .home
        }
    }
}

struct WeeklyNotificationSummary: Equatable {
    let monthlyTotal: Money
    let activeSubscriptionCount: Int
    let recentPriceChangeCount: Int
}

struct NotificationContentBuilder {
    private let dateFormatter: DateFormatter

    init() {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.setLocalizedDateFormatFromTemplate("MMM d")
        dateFormatter = formatter
    }

    func renewalContent(for subscription: Subscription) -> UNMutableNotificationContent {
        baseContent(
            title: "\(subscription.name) renews soon",
            body: "\(subscription.name) renews \(dateText(subscription.nextRenewal)) for \(amountText(subscription)).",
            kind: .renewal,
            subscriptionID: subscription.id
        )
    }

    func trialEndingContent(for subscription: Subscription) -> UNMutableNotificationContent {
        baseContent(
            title: "\(subscription.name) trial is ending",
            body: "\(subscription.name) converts \(dateText(subscription.nextRenewal)) for \(amountText(subscription)).",
            kind: .trialEnding,
            subscriptionID: subscription.id
        )
    }

    func unusedNudgeContent(for subscription: Subscription) -> UNMutableNotificationContent {
        let lastUsedText = subscription.lastUsed.map { " since \(dateText($0))" } ?? ""
        return baseContent(
            title: "\(subscription.name) looks unused",
            body: "\(subscription.name) is \(amountText(subscription)) and has not been used\(lastUsedText).",
            kind: .unusedNudge,
            subscriptionID: subscription.id
        )
    }

    func priceChangeContent(_ priceChange: PriceChange, subscription: Subscription?) -> UNMutableNotificationContent {
        let name = subscription?.name ?? "A subscription"
        return baseContent(
            title: "\(name) price changed",
            body: "\(name) changed from \(priceChange.oldAmount.formatted()) to \(priceChange.newAmount.formatted()).",
            kind: .priceChange,
            subscriptionID: priceChange.subscriptionID
        )
    }

    func weeklySummaryContent(_ summary: WeeklyNotificationSummary) -> UNMutableNotificationContent {
        let subscriptionText = summary.activeSubscriptionCount == 1 ? "1 active subscription" : "\(summary.activeSubscriptionCount) active subscriptions"
        let priceText = summary.recentPriceChangeCount == 1 ? "1 price change" : "\(summary.recentPriceChangeCount) price changes"
        return baseContent(
            title: "Your Sift summary",
            body: "You are tracking \(summary.monthlyTotal.formatted())/mo across \(subscriptionText). \(priceText) this week.",
            kind: .weeklySummary
        )
    }

    private func baseContent(
        title: String,
        body: String,
        kind: SiftNotificationKind,
        subscriptionID: String? = nil
    ) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.userInfo = SiftNotificationPayload.userInfo(kind: kind, subscriptionID: subscriptionID)
        return content
    }

    private func dateText(_ date: Date?) -> String {
        guard let date else {
            return "soon"
        }

        return dateFormatter.string(from: date)
    }

    private func amountText(_ subscription: Subscription) -> String {
        "\(subscription.amount.formatted())\(suffix(for: subscription.cadence))"
    }

    private func suffix(for cadence: Cadence) -> String {
        switch cadence {
        case .weekly:
            "/wk"
        case .monthly:
            "/mo"
        case .quarterly:
            "/quarter"
        case .yearly:
            "/yr"
        case .unknown:
            ""
        }
    }
}
