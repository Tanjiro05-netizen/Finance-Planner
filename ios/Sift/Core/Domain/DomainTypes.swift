import Foundation

enum SiftError: Error, Equatable, LocalizedError {
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
        case let .notFound(label):
            "\(label) could not be found."
        case .currencyMismatch:
            "Money values must use the same currency."
        case let .persistence(message):
            message
        case let .network(message):
            message
        case let .api(_, message):
            message
        case .unauthorized:
            "Please start a new secure session."
        case let .decoding(message):
            message
        case let .keychain(message):
            message
        case let .cancelled(message):
            message
        }
    }

    var isAuthenticationExpired: Bool {
        switch self {
        case .unauthorized:
            true
        case let .api(code, _):
            code == "unauthorized" || code == "token_expired"
        default:
            false
        }
    }

    var isTransient: Bool {
        switch self {
        case .network:
            true
        case let .api(code, _):
            code == "rate_limited" || code == "temporarily_unavailable"
        default:
            false
        }
    }
}

struct SiftFeatureFlags: Equatable {
    var conciergeEnabled: Bool
    var ledgerEnabled: Bool
    var budgetsEnabled: Bool
    var goalsEnabled: Bool
    var insightNarrationEnabled: Bool
    var assistantEnabled: Bool
    var categoryRulesEnabled: Bool

    /// Defaulted so adding a flag stays additive — call sites that only care about one
    /// flag don't have to be updated every time a new one lands.
    init(
        conciergeEnabled: Bool = false,
        ledgerEnabled: Bool = false,
        budgetsEnabled: Bool = false,
        goalsEnabled: Bool = false,
        insightNarrationEnabled: Bool = false,
        assistantEnabled: Bool = false,
        categoryRulesEnabled: Bool = false
    ) {
        self.conciergeEnabled = conciergeEnabled
        self.ledgerEnabled = ledgerEnabled
        self.budgetsEnabled = budgetsEnabled
        self.goalsEnabled = goalsEnabled
        self.insightNarrationEnabled = insightNarrationEnabled
        self.assistantEnabled = assistantEnabled
        self.categoryRulesEnabled = categoryRulesEnabled
    }

    static let launchDefault = SiftFeatureFlags()

    static func current(processInfo: ProcessInfo = .processInfo) -> SiftFeatureFlags {
        SiftFeatureFlags(
            conciergeEnabled: isEnabled("-siftConciergeEnabled", "SIFT_CONCIERGE_ENABLED", processInfo),
            ledgerEnabled: isEnabled("-siftLedgerEnabled", "SIFT_LEDGER_ENABLED", processInfo),
            budgetsEnabled: isEnabled("-siftBudgetsEnabled", "SIFT_BUDGETS_ENABLED", processInfo),
            goalsEnabled: isEnabled("-siftGoalsEnabled", "SIFT_GOALS_ENABLED", processInfo),
            insightNarrationEnabled: isEnabled(
                "-siftInsightNarrationEnabled",
                "SIFT_INSIGHT_NARRATION_ENABLED",
                processInfo
            ),
            assistantEnabled: isEnabled("-siftAssistantEnabled", "SIFT_ASSISTANT_ENABLED", processInfo),
            categoryRulesEnabled: isEnabled("-siftCategoryRulesEnabled", "SIFT_CATEGORY_RULES_ENABLED", processInfo)
        )
    }

    /// A flag is on when either the launch argument is present or the environment variable
    /// reads as truthy, so UI tests and CI can each use whichever is available to them.
    private static func isEnabled(_ argument: String, _ variable: String, _ processInfo: ProcessInfo) -> Bool {
        if processInfo.arguments.contains(argument) {
            return true
        }

        let value = processInfo.environment[variable]?.lowercased()
        return value == "1" || value == "true" || value == "yes"
    }
}

enum AnalyticsEvent: Equatable {
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

enum Cadence: String, Codable, CaseIterable {
    case weekly
    case biweekly
    case monthly
    case quarterly
    case yearly
    case unknown

    var displayName: String {
        switch self {
        case .weekly:
            "Weekly"
        case .biweekly:
            "Every 2 weeks"
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
        case .biweekly:
            "BIWEEKLY"
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
        case .biweekly:
            money.multiplied(by: 26).divided(by: 12)
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

struct MerchantKey: Codable, Equatable, Hashable, RawRepresentable {
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

enum LinkedAccountStatus: String, Codable, CaseIterable {
    case connected
    case needsAttention
    case disconnected
}

enum SubscriptionStatus: String, Codable, CaseIterable {
    case active
    case unused
    case cancelled
}

enum RecurringIncomeStatus: String, Codable, CaseIterable {
    case active
    case stopped
}

enum BillStatus: String, Codable, CaseIterable {
    case active
    case stopped
}

enum BudgetStatus: String, Codable, CaseIterable {
    case active
    case archived
}

/// What a user-written categorisation rule tests a transaction against.
///
/// Two kinds rather than one because they fail in opposite situations. Merchant text is
/// readable and easy to write, but useless against the acquirer gibberish a lot of card
/// descriptors are ("SQ *4471 ABC"). A category code is unreadable but always present when
/// FinanceKit supplies one, and it is the card network's own classification rather than a
/// guess at one.
enum CategoryRuleKind: String, Codable, CaseIterable {
    case merchantContains
    case merchantCategoryCode

    var label: String {
        switch self {
        case .merchantContains:
            "Merchant name contains"
        case .merchantCategoryCode:
            "Category code is"
        }
    }
}

/// A rule's condition, resolved into something the engine can actually evaluate.
///
/// `CategoryRule` stores its condition as a `kind` plus a free-text `pattern`, because that
/// is what SwiftData persists cleanly. Nothing evaluates that string directly: a rule
/// resolves to one of these first, or to `nil` when the stored pattern doesn't fit its kind
/// (an MCC rule whose pattern isn't an integer). A malformed row is then skipped rather
/// than silently matching everything or crashing the pass.
enum CategoryRuleMatcher: Equatable {
    case merchantContains(String)
    case merchantCategoryCode(Int16)
}

enum GoalStatus: String, Codable, CaseIterable {
    case active
    case reached
    case archived
}

/// How often a budget's allowance resets. Weekly and monthly cover the way people
/// actually think about discretionary spending; longer horizons belong to goals.
enum BudgetPeriod: String, Codable, CaseIterable {
    case weekly
    case monthly

    var displayName: String {
        switch self {
        case .weekly:
            "Weekly"
        case .monthly:
            "Monthly"
        }
    }

    var shortLabel: String {
        switch self {
        case .weekly:
            "WEEKLY"
        case .monthly:
            "MONTHLY"
        }
    }

    /// The `Calendar.Component` this period resets on, so period math has one source of truth.
    var calendarComponent: Calendar.Component {
        switch self {
        case .weekly:
            .weekOfYear
        case .monthly:
            .month
        }
    }
}

/// Whether spending is tracking ahead of, behind, or in line with an even burn-down of the
/// budget across the period. This is what turns a budget from a scoreboard into a warning.
enum BudgetPace: String, Codable, CaseIterable {
    case under
    case onTrack
    case over
}

enum CancellationMethod: String, Codable, CaseIterable {
    case concierge
    case guided
}

enum CancellationStatus: String, Codable, CaseIterable {
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
            .map(\.monthlyEquivalent)
        return (try? Money.sum(values)) ?? .zeroUSD
    }
}

/// Whether money left the account (`debit`) or entered it (`credit`). Objective, derived
/// directly from the source data (`FinanceKit.CreditDebitIndicator` or a Plaid sign).
enum TransactionDirection: String, Codable, CaseIterable {
    case debit
    case credit
}

/// A categorization/heuristic layer on top of `TransactionDirection`, used for display and
/// later budget rules. A `.credit` might be `.refund` or `.income`; a `.debit` is usually
/// `.purchase` unless it matches a known subscription charge.
enum TransactionKind: String, Codable, CaseIterable {
    case purchase
    case subscriptionCharge
    case refund
    case income
    case transfer
    case other
}

/// Where a transaction row came from, so the ledger can distinguish auto-imported data
/// from what a person typed in themselves.
enum TransactionSource: String, Codable, CaseIterable {
    case financeKit
    /// Reserved for a future Plaid/bank-sync backend; unused in Phase 1.
    case plaid
    case manual
}

struct TransactionCategoryGroup: Equatable {
    let categoryID: String?
    let categoryName: String
    let transactions: [Transaction]

    var total: Money {
        let values = transactions.map(\.amount)
        return (try? Money.sum(values)) ?? .zeroUSD
    }
}
