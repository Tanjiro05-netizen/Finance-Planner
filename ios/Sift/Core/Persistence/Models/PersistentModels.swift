import Foundation
import SwiftData

@Model
final class LinkedAccount {
    var id: String
    var userID: String
    var plaidItemID: String?
    var institutionName: String
    var mask: String
    var type: String
    var status: LinkedAccountStatus
    var lastSyncedAt: Date?
    var currentBalance: Money?
    var availableBalance: Money?
    var balanceAsOf: Date?

    init(
        id: String,
        userID: String,
        plaidItemID: String? = nil,
        institutionName: String,
        mask: String,
        type: String,
        status: LinkedAccountStatus,
        lastSyncedAt: Date? = nil,
        currentBalance: Money? = nil,
        availableBalance: Money? = nil,
        balanceAsOf: Date? = nil
    ) {
        self.id = id
        self.userID = userID
        self.plaidItemID = plaidItemID
        self.institutionName = institutionName
        self.mask = mask
        self.type = type
        self.status = status
        self.lastSyncedAt = lastSyncedAt
        self.currentBalance = currentBalance
        self.availableBalance = availableBalance
        self.balanceAsOf = balanceAsOf
    }
}

@Model
final class Transaction {
    var id: String
    var userID: String
    var accountID: String
    var merchantRaw: String
    var merchantKey: MerchantKey
    var amount: Money
    var date: Date
    var pending: Bool
    var categoryHint: String?
    /// The card network's own classification (ISO 18245), when FinanceKit supplied one.
    /// Kept alongside `categoryHint` rather than folded into it because the hint is only
    /// ever the small set of codes `MerchantCategoryCodeMapper` has a verified opinion
    /// about -- a user rule needs to be able to name a code Sift has no opinion about.
    var merchantCategoryCode: Int16?
    var direction: TransactionDirection
    var kind: TransactionKind
    var categoryID: String?
    var categoryManuallySet: Bool
    var source: TransactionSource
    var note: String?

    init(
        id: String,
        userID: String,
        accountID: String,
        merchantRaw: String,
        merchantKey: MerchantKey,
        amount: Money,
        date: Date,
        pending: Bool = false,
        categoryHint: String? = nil,
        merchantCategoryCode: Int16? = nil,
        direction: TransactionDirection = .debit,
        kind: TransactionKind = .purchase,
        categoryID: String? = nil,
        categoryManuallySet: Bool = false,
        source: TransactionSource = .financeKit,
        note: String? = nil
    ) {
        self.id = id
        self.userID = userID
        self.accountID = accountID
        self.merchantRaw = merchantRaw
        self.merchantKey = merchantKey
        self.amount = amount
        self.date = date
        self.pending = pending
        self.categoryHint = categoryHint
        self.merchantCategoryCode = merchantCategoryCode
        self.direction = direction
        self.kind = kind
        self.categoryID = categoryID
        self.categoryManuallySet = categoryManuallySet
        self.source = source
        self.note = note
    }
}

@Model
final class Subscription {
    var id: String
    var userID: String
    var name: String
    var merchantKey: MerchantKey
    var monogramLetter: String
    var tileColorToken: ColorToken
    var amount: Money
    var cadence: Cadence
    var nextRenewal: Date?
    var lastUsed: Date?
    var categoryID: String?
    var categoryManuallySet: Bool
    var isTrialEnding: Bool = false
    var status: SubscriptionStatus
    var detectionConfidence: Double
    var firstSeen: Date
    var lastCharge: Date

    init(
        id: String,
        userID: String,
        name: String,
        merchantKey: MerchantKey,
        monogramLetter: String,
        tileColorToken: ColorToken,
        amount: Money,
        cadence: Cadence,
        nextRenewal: Date? = nil,
        lastUsed: Date? = nil,
        categoryID: String? = nil,
        categoryManuallySet: Bool = false,
        isTrialEnding: Bool = false,
        status: SubscriptionStatus,
        detectionConfidence: Double,
        firstSeen: Date,
        lastCharge: Date
    ) {
        self.id = id
        self.userID = userID
        self.name = name
        self.merchantKey = merchantKey
        self.monogramLetter = monogramLetter
        self.tileColorToken = tileColorToken
        self.amount = amount
        self.cadence = cadence
        self.nextRenewal = nextRenewal
        self.lastUsed = lastUsed
        self.categoryID = categoryID
        self.categoryManuallySet = categoryManuallySet
        self.isTrialEnding = isTrialEnding
        self.status = status
        self.detectionConfidence = detectionConfidence
        self.firstSeen = firstSeen
        self.lastCharge = lastCharge
    }

    var monthlyEquivalent: Money {
        cadence.monthlyEquivalent(for: amount)
    }
}

@Model
final class CancellationRequest {
    var id: String
    var userID: String
    var subscriptionID: String
    var method: CancellationMethod
    var status: CancellationStatus
    var createdAt: Date
    var updatedAt: Date
    var note: String?

    init(
        id: String,
        userID: String,
        subscriptionID: String,
        method: CancellationMethod,
        status: CancellationStatus,
        createdAt: Date,
        updatedAt: Date,
        note: String? = nil
    ) {
        self.id = id
        self.userID = userID
        self.subscriptionID = subscriptionID
        self.method = method
        self.status = status
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.note = note
    }
}

@Model
final class Category {
    var id: String
    var userID: String
    var name: String
    var iconToken: String
    var isAuto: Bool

    init(id: String, userID: String, name: String, iconToken: String, isAuto: Bool) {
        self.id = id
        self.userID = userID
        self.name = name
        self.iconToken = iconToken
        self.isAuto = isAuto
    }
}

/// A detected stream of recurring income (payroll, pension, regular transfers in).
/// Kept separate from `Subscription` so "next expected income date" is a cheap indexed
/// read for safe-to-spend without re-running detection on every screen load.
@Model
final class RecurringIncome {
    var id: String
    var userID: String
    var sourceName: String
    var merchantKey: MerchantKey
    var amount: Money
    var cadence: Cadence
    var nextExpected: Date?
    var categoryID: String?
    var status: RecurringIncomeStatus
    var detectionConfidence: Double
    var firstSeen: Date
    var lastReceived: Date

    init(
        id: String,
        userID: String,
        sourceName: String,
        merchantKey: MerchantKey,
        amount: Money,
        cadence: Cadence,
        nextExpected: Date? = nil,
        categoryID: String? = nil,
        status: RecurringIncomeStatus,
        detectionConfidence: Double,
        firstSeen: Date,
        lastReceived: Date
    ) {
        self.id = id
        self.userID = userID
        self.sourceName = sourceName
        self.merchantKey = merchantKey
        self.amount = amount
        self.cadence = cadence
        self.nextExpected = nextExpected
        self.categoryID = categoryID
        self.status = status
        self.detectionConfidence = detectionConfidence
        self.firstSeen = firstSeen
        self.lastReceived = lastReceived
    }
}

/// A recurring non-subscription obligation (rent, utilities, insurance, loans). Distinct
/// from `Subscription` so bills never inherit subscription-only affordances like the
/// cancel flow, trial-ending, or the "unused, cancel to save" nudge.
@Model
final class Bill {
    var id: String
    var userID: String
    var name: String
    var merchantKey: MerchantKey
    var amount: Money
    var cadence: Cadence
    var nextDue: Date?
    var categoryID: String?
    var status: BillStatus
    var detectionConfidence: Double
    var firstSeen: Date
    var lastCharge: Date

    init(
        id: String,
        userID: String,
        name: String,
        merchantKey: MerchantKey,
        amount: Money,
        cadence: Cadence,
        nextDue: Date? = nil,
        categoryID: String? = nil,
        status: BillStatus,
        detectionConfidence: Double,
        firstSeen: Date,
        lastCharge: Date
    ) {
        self.id = id
        self.userID = userID
        self.name = name
        self.merchantKey = merchantKey
        self.amount = amount
        self.cadence = cadence
        self.nextDue = nextDue
        self.categoryID = categoryID
        self.status = status
        self.detectionConfidence = detectionConfidence
        self.firstSeen = firstSeen
        self.lastCharge = lastCharge
    }
}

/// A spending allowance for one category over a repeating period. Actuals are never stored
/// here — they're derived from the ledger at read time, so a budget can't drift out of sync
/// with the transactions it measures.
@Model
final class Budget {
    var id: String
    var userID: String
    var categoryID: String
    var amount: Money
    var period: BudgetPeriod
    /// When on, an underspent period's remainder carries into the next one.
    var rolloverEnabled: Bool
    var startDate: Date
    var status: BudgetStatus

    init(
        id: String,
        userID: String,
        categoryID: String,
        amount: Money,
        period: BudgetPeriod,
        rolloverEnabled: Bool = false,
        startDate: Date,
        status: BudgetStatus = .active
    ) {
        self.id = id
        self.userID = userID
        self.categoryID = categoryID
        self.amount = amount
        self.period = period
        self.rolloverEnabled = rolloverEnabled
        self.startDate = startDate
        self.status = status
    }
}

/// A user-written rule assigning a category to anything matching a condition.
///
/// Exists because `CategoryService.keywordRules` is compiled into the app: when it puts a
/// merchant in the wrong place, the only recourse today is correcting every transaction by
/// hand, forever. These rules are evaluated ahead of those built-ins, so a person can
/// override Sift's opinion without waiting for a release.
///
/// The condition is stored as `kind` + `pattern` rather than as separate typed columns,
/// which keeps persistence simple. `matcher` (in `CategoryRuleEngine.swift`) resolves it
/// into a typed value and returns nil for a malformed row -- it lives in an extension
/// because `@Model` inspects every `var` in the class body and cannot handle a computed
/// property whose type it has no way to persist. `order` is dense and zero-based,
/// rewritten wholesale by
/// `CategoryRuleRepository.reorder(ids:)` -- first match wins, so order is the whole
/// disambiguation story when two rules could both fire.
@Model
final class CategoryRule {
    var id: String
    var userID: String
    var kind: CategoryRuleKind
    var pattern: String
    var categoryID: String
    var order: Int
    var isEnabled: Bool

    init(
        id: String,
        userID: String,
        kind: CategoryRuleKind,
        pattern: String,
        categoryID: String,
        order: Int,
        isEnabled: Bool = true
    ) {
        self.id = id
        self.userID = userID
        self.kind = kind
        self.pattern = pattern
        self.categoryID = categoryID
        self.order = order
        self.isEnabled = isEnabled
    }
}

/// Something the user is saving toward. Progress is never stored here — it's summed from
/// `GoalContribution` rows, so a withdrawal can't leave the goal claiming money that's gone.
///
/// `targetDate` and `monthlyContribution` are both optional on purpose: the user supplies any
/// two of {target, date, contribution} and `GoalProjector` derives the third. With only the
/// target, there is genuinely nothing to project, and the UI says so rather than inventing it.
@Model
final class Goal {
    var id: String
    var userID: String
    var name: String
    var targetAmount: Money
    var targetDate: Date?
    var monthlyContribution: Money?
    var status: GoalStatus
    var createdAt: Date
    var note: String?

    init(
        id: String,
        userID: String,
        name: String,
        targetAmount: Money,
        targetDate: Date? = nil,
        monthlyContribution: Money? = nil,
        status: GoalStatus = .active,
        createdAt: Date,
        note: String? = nil
    ) {
        self.id = id
        self.userID = userID
        self.name = name
        self.targetAmount = targetAmount
        self.targetDate = targetDate
        self.monthlyContribution = monthlyContribution
        self.status = status
        self.createdAt = createdAt
        self.note = note
    }
}

/// One movement into or out of a goal. `amount` is signed — a negative entry is a withdrawal.
/// Keeping withdrawals as first-class entries rather than silent edits means the running total
/// always reconciles with the history the user can see.
@Model
final class GoalContribution {
    var id: String
    var userID: String
    var goalID: String
    var amount: Money
    var date: Date
    var note: String?

    init(
        id: String,
        userID: String,
        goalID: String,
        amount: Money,
        date: Date,
        note: String? = nil
    ) {
        self.id = id
        self.userID = userID
        self.goalID = goalID
        self.amount = amount
        self.date = date
        self.note = note
    }
}

@Model
final class PriceChange {
    var id: String
    var userID: String
    var subscriptionID: String
    var oldAmount: Money
    var newAmount: Money
    var changedAt: Date

    init(
        id: String,
        userID: String,
        subscriptionID: String,
        oldAmount: Money,
        newAmount: Money,
        changedAt: Date
    ) {
        self.id = id
        self.userID = userID
        self.subscriptionID = subscriptionID
        self.oldAmount = oldAmount
        self.newAmount = newAmount
        self.changedAt = changedAt
    }
}

@Model
final class AlertSettings {
    var id: String
    var userID: String
    var renewalReminders: Bool
    var priceChanges: Bool
    var trialEndings: Bool
    var unusedNudges: Bool
    var weeklySummary: Bool
    var autoCategorizeSubscriptions: Bool
    var budgetAlerts: Bool

    init(
        id: String,
        userID: String,
        renewalReminders: Bool,
        priceChanges: Bool,
        trialEndings: Bool,
        unusedNudges: Bool,
        weeklySummary: Bool,
        autoCategorizeSubscriptions: Bool = true,
        budgetAlerts: Bool = true
    ) {
        self.id = id
        self.userID = userID
        self.renewalReminders = renewalReminders
        self.priceChanges = priceChanges
        self.trialEndings = trialEndings
        self.unusedNudges = unusedNudges
        self.weeklySummary = weeklySummary
        self.autoCategorizeSubscriptions = autoCategorizeSubscriptions
        self.budgetAlerts = budgetAlerts
    }
}
