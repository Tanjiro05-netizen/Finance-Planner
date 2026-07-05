import Foundation

enum SiftError: Error, Equatable, LocalizedError, Sendable {
    case notFound(String)
    case currencyMismatch
    case persistence(String)
    case network(String)
    case api(code: String, message: String)
    case unauthorized
    case decoding(String)
    case keychain(String)
    case cancelled(String)

    var errorDescription: String? {
        switch self {
        case .notFound(let label):
            "\(label) could not be found."
        case .currencyMismatch:
            "Money values must use the same currency."
        case .persistence(let message):
            message
        case .network(let message):
            message
        case .api(_, let message):
            message
        case .unauthorized:
            "Please start a new secure session."
        case .decoding(let message):
            message
        case .keychain(let message):
            message
        case .cancelled(let message):
            message
        }
    }

    var isAuthenticationExpired: Bool {
        switch self {
        case .unauthorized:
            true
        case .api(let code, _):
            code == "unauthorized" || code == "token_expired"
        default:
            false
        }
    }

    var isTransient: Bool {
        switch self {
        case .network:
            true
        case .api(let code, _):
            code == "rate_limited" || code == "temporarily_unavailable"
        default:
            false
        }
    }
}

struct SiftFeatureFlags: Equatable, Sendable {
    var conciergeEnabled: Bool

    static let launchDefault = SiftFeatureFlags(conciergeEnabled: false)

    static func current(processInfo: ProcessInfo = .processInfo) -> SiftFeatureFlags {
        let arguments = processInfo.arguments
        let environment = processInfo.environment
        let envValue = environment["SIFT_CONCIERGE_ENABLED"]?.lowercased()
        let enabledByEnvironment = envValue == "1" || envValue == "true" || envValue == "yes"

        return SiftFeatureFlags(
            conciergeEnabled: arguments.contains("-siftConciergeEnabled") || enabledByEnvironment
        )
    }
}

enum AnalyticsEvent: Equatable, Sendable {
    case apiRetry(method: String, endpoint: String, statusCode: Int?, attempt: Int)
    case cancellationStarted(method: CancellationMethod)
    case cancellationConfirmed(method: CancellationMethod)
    case featureUnavailable(name: String)
}

protocol AnalyticsRecording: Sendable {
    func record(_ event: AnalyticsEvent)
}

struct NoopAnalyticsRecorder: AnalyticsRecording {
    func record(_: AnalyticsEvent) {}
}

enum Cadence: String, Codable, CaseIterable, Sendable {
    case weekly
    case monthly
    case quarterly
    case yearly
    case unknown

    var displayName: String {
        switch self {
        case .weekly:
            "Weekly"
        case .monthly:
            "Monthly"
        case .quarterly:
            "Quarterly"
        case .yearly:
            "Yearly"
        case .unknown:
            "Unknown"
        }
    }

    var shortLabel: String {
        switch self {
        case .weekly:
            "WEEKLY"
        case .monthly:
            "MONTHLY"
        case .quarterly:
            "QUARTERLY"
        case .yearly:
            "YEARLY"
        case .unknown:
            "UNKNOWN"
        }
    }

    func monthlyEquivalent(for money: Money) -> Money {
        switch self {
        case .weekly:
            money.multiplied(by: 52).divided(by: 12)
        case .monthly:
            money
        case .quarterly:
            money.divided(by: 3)
        case .yearly:
            money.divided(by: 12)
        case .unknown:
            money
        }
    }
}

struct MerchantKey: Codable, Equatable, Hashable, RawRepresentable, Sendable {
    let rawValue: String

    init(rawValue: String) {
        self.rawValue = Self.normalized(rawValue)
    }

    init(_ merchantName: String) {
        self.init(rawValue: merchantName)
    }

    static func normalized(_ value: String) -> String {
        let allowed = CharacterSet.alphanumerics
        let scalars = value.lowercased().unicodeScalars.map { scalar in
            allowed.contains(scalar) ? Character(scalar) : "-"
        }
        let dashed = String(scalars)

        return dashed
            .split(separator: "-")
            .joined(separator: "-")
    }
}

enum LinkedAccountStatus: String, Codable, CaseIterable, Sendable {
    case connected
    case needsAttention
    case disconnected
}

enum SubscriptionStatus: String, Codable, CaseIterable, Sendable {
    case active
    case unused
    case cancelled
}

enum CancellationMethod: String, Codable, CaseIterable, Sendable {
    case concierge
    case guided
}

enum CancellationStatus: String, Codable, CaseIterable, Sendable {
    case requested
    case contacting
    case confirmed
    case needsUser
    case cancelledByUser
}

struct SubscriptionCategoryGroup: Equatable {
    let categoryID: String?
    let categoryName: String
    let subscriptions: [Subscription]

    var monthlyTotal: Money {
        let values = subscriptions
            .filter { $0.status != .cancelled }
            .map { $0.monthlyEquivalent }
        return (try? Money.sum(values)) ?? .zeroUSD
    }
}
