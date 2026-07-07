import Foundation

struct Txn: Equatable {
    let id: String
    let merchantRaw: String
    let amount: Money
    let date: Date
    let pending: Bool
    let categoryHint: String?

    init(
        id: String,
        merchantRaw: String,
        amount: Money,
        date: Date,
        pending: Bool = false,
        categoryHint: String? = nil
    ) {
        self.id = id
        self.merchantRaw = merchantRaw
        self.amount = amount
        self.date = date
        self.pending = pending
        self.categoryHint = categoryHint
    }
}

struct SubscriptionCandidate: Identifiable, Equatable {
    let id: String
    let name: String
    let merchantKey: MerchantKey
    let monogramLetter: String
    let tileColorToken: ColorToken
    let amount: Money
    let cadence: Cadence
    let nextRenewal: Date
    let confidence: Double
    let firstSeen: Date
    let lastCharge: Date
    let lastUsed: Date?
    let categoryID: String?
    let status: SubscriptionStatus
    let isTrialEnding: Bool
    let isUnused: Bool
}

struct DetectedPriceChange: Equatable {
    let merchantKey: MerchantKey
    let merchantName: String
    let oldAmount: Money
    let newAmount: Money
    let changedAt: Date
}

struct DetectionFlag: Equatable {
    enum Kind: Equatable {
        case trialEnding
        case unused
    }

    let merchantKey: MerchantKey
    let kind: Kind
}

struct DetectionResult: Equatable {
    var candidates: [SubscriptionCandidate]
    var priceChanges: [DetectedPriceChange]
    var flags: [DetectionFlag]

    static let empty = DetectionResult(candidates: [], priceChanges: [], flags: [])
}

extension Cadence {
    var detectionTargetDays: Int {
        switch self {
        case .weekly:
            7
        case .monthly:
            30
        case .quarterly:
            91
        case .yearly:
            365
        case .unknown:
            0
        }
    }

    var detectionToleranceDays: ClosedRange<Int> {
        switch self {
        case .weekly:
            6 ... 8
        case .monthly:
            28 ... 33
        case .quarterly:
            84 ... 98
        case .yearly:
            350 ... 380
        case .unknown:
            0 ... 0
        }
    }

    var missedChargeGraceDays: Int {
        switch self {
        case .weekly:
            10
        case .monthly:
            18
        case .quarterly:
            40
        case .yearly:
            60
        case .unknown:
            0
        }
    }

    func dateAfter(_ date: Date, calendar: Calendar = .utc) -> Date {
        switch self {
        case .weekly:
            calendar.date(byAdding: .day, value: 7, to: date) ?? date
        case .monthly:
            calendar.date(byAdding: .month, value: 1, to: date) ?? date
        case .quarterly:
            calendar.date(byAdding: .month, value: 3, to: date) ?? date
        case .yearly:
            calendar.date(byAdding: .year, value: 1, to: date) ?? date
        case .unknown:
            date
        }
    }
}
