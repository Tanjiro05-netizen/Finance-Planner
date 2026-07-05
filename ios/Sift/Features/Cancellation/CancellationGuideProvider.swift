import Foundation

struct CancellationGuide: Equatable, Sendable {
    let merchantKey: MerchantKey
    let title: String
    let isGeneric: Bool
    let providerURL: URL?
    let steps: [String]
}

protocol CancellationGuideProviding: Sendable {
    func guide(for merchantKey: MerchantKey, merchantName: String) -> CancellationGuide
}

struct CancellationGuideProvider: CancellationGuideProviding {
    private let guides: [MerchantKey: CancellationGuide]

    init(guides: [MerchantKey: CancellationGuide] = Self.defaultGuides) {
        self.guides = guides
    }

    func guide(for merchantKey: MerchantKey, merchantName: String) -> CancellationGuide {
        if let guide = guides[merchantKey] {
            return guide
        }

        return CancellationGuide(
            merchantKey: merchantKey,
            title: "Generic cancellation guide",
            isGeneric: true,
            providerURL: nil,
            steps: [
                "Open the provider's account or billing page.",
                "Find Subscription, Membership, Plan, or Billing.",
                "Choose Cancel, End membership, or Manage plan.",
                "Confirm the final prompt and save any confirmation email or number.",
            ]
        )
    }

    private static let defaultGuides: [MerchantKey: CancellationGuide] = {
        let streamline = MerchantKey("Streamline Plus")

        return [
            streamline: CancellationGuide(
                merchantKey: streamline,
                title: "Streamline+ guide",
                isGeneric: false,
                providerURL: URL(string: "https://example.com/streamline-plus/account"),
                steps: [
                    "Open Streamline+ account settings.",
                    "Choose Plan and billing.",
                    "Select Cancel plan.",
                    "Confirm the cancellation and save the confirmation page.",
                ]
            ),
        ]
    }()
}

protocol CancellationReminderIntentStoring: Sendable {
    @MainActor func isReminderEnabled(for subscriptionID: String) -> Bool
    @MainActor func setReminderEnabled(_ isEnabled: Bool, for subscriptionID: String)
}

final class UserDefaultsCancellationReminderIntentStore: CancellationReminderIntentStoring, @unchecked Sendable {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    @MainActor
    func isReminderEnabled(for subscriptionID: String) -> Bool {
        defaults.bool(forKey: key(for: subscriptionID))
    }

    @MainActor
    func setReminderEnabled(_ isEnabled: Bool, for subscriptionID: String) {
        defaults.set(isEnabled, forKey: key(for: subscriptionID))
    }

    private func key(for subscriptionID: String) -> String {
        "sift.cancellation.reminder.\(subscriptionID)"
    }
}

enum CancellationSavings {
    static func realizedAnnualSavings(
        requests: [CancellationRequest],
        subscriptions: [Subscription]
    ) throws -> Money {
        let subscriptionsByID = Dictionary(uniqueKeysWithValues: subscriptions.map { ($0.id, $0) })
        var countedSubscriptionIDs = Set<String>()
        let values = requests.compactMap { request -> Money? in
            guard
                request.status.realizesSavings,
                countedSubscriptionIDs.insert(request.subscriptionID).inserted,
                let subscription = subscriptionsByID[request.subscriptionID]
            else {
                return nil
            }

            return subscription.monthlyEquivalent.multiplied(by: 12)
        }

        return try Money.sum(values)
    }
}

extension CancellationStatus {
    var realizesSavings: Bool {
        self == .confirmed || self == .cancelledByUser
    }

    var trackerLabel: String {
        switch self {
        case .requested, .contacting:
            "In progress"
        case .confirmed, .cancelledByUser:
            "Confirmed"
        case .needsUser:
            "Needs you"
        }
    }
}
