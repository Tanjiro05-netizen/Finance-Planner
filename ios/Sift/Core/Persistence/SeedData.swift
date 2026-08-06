import Foundation
import SwiftData

enum SeedData {
    static let defaultUserID = "user-preview"
    static let referenceDate = date(year: 2026, month: 6, day: 29)

    enum ID {
        static let checking = "acct-main-checking"
        static let travelCard = "acct-travel-card"

        static let streaming = "cat-streaming"
        static let audio = "cat-audio"
        static let design = "cat-design"
        static let productivity = "cat-productivity"
        static let security = "cat-security"
        static let health = "cat-health"
        static let groceries = "cat-groceries"
        static let dining = "cat-dining"

        static let streamline = "sub-streamline-plus"
        static let tonebox = "sub-tonebox"
        static let reelhouse = "sub-reelhouse"
        static let creativeCloud = "sub-creative-cloud"
        static let notewell = "sub-notewell"
        static let atlasVPN = "sub-atlas-vpn"
        static let cloudback = "sub-cloudback"
        static let workoutLab = "sub-workout-lab"
        static let readwise = "sub-readwise"
        static let figma = "sub-figma"
        static let daybook = "sub-daybook-pro"
        static let parcelPro = "sub-parcel-pro"

        static let alertSettings = "alert-settings-preview"

        static let streamlineTransaction = "txn-streamline-jun"

        static let payrollIncome = "income-northwind-labs"
        static let rentBill = "bill-northgate-rent"

        static let groceriesBudget = "budget-groceries"
        static let diningBudget = "budget-dining"

        static let emergencyGoal = "goal-emergency-fund"
        static let laptopGoal = "goal-new-laptop"
    }

    struct Snapshot {
        var accounts: [LinkedAccount]
        var transactions: [Transaction]
        var subscriptions: [Subscription]
        var cancellationRequests: [CancellationRequest]
        var categories: [Category]
        var priceChanges: [PriceChange]
        var alertSettings: AlertSettings
        var recurringIncome: [RecurringIncome]
        var bills: [Bill]
        var budgets: [Budget]
        var goals: [Goal]
        var goalContributions: [GoalContribution]
    }

    static func snapshot(userID: String = defaultUserID) -> Snapshot {
        let accounts = [
            LinkedAccount(
                id: ID.checking,
                userID: userID,
                plaidItemID: "item-northstar",
                institutionName: "Northstar Bank",
                mask: "4821",
                type: "Checking",
                status: .connected,
                lastSyncedAt: date(year: 2026, month: 6, day: 29, hour: 9),
                currentBalance: .usd(Cents.dollars(2450, cents: 18)),
                availableBalance: .usd(Cents.dollars(2450, cents: 18)),
                balanceAsOf: date(year: 2026, month: 6, day: 29, hour: 9)
            ),
            LinkedAccount(
                id: ID.travelCard,
                userID: userID,
                plaidItemID: "item-evergreen",
                institutionName: "Evergreen Credit",
                mask: "1194",
                type: "Credit",
                status: .connected,
                lastSyncedAt: date(year: 2026, month: 6, day: 29, hour: 9),
                currentBalance: .usd(Cents.dollars(612, cents: 40)),
                availableBalance: .usd(Cents.dollars(4387, cents: 60)),
                balanceAsOf: date(year: 2026, month: 6, day: 29, hour: 9)
            ),
        ]

        let categories = [
            Category(id: ID.streaming, userID: userID, name: "Streaming", iconToken: "play.rectangle", isAuto: true),
            Category(id: ID.audio, userID: userID, name: "Audio", iconToken: "waveform", isAuto: true),
            Category(id: ID.design, userID: userID, name: "Design", iconToken: "paintpalette", isAuto: true),
            Category(id: ID.productivity, userID: userID, name: "Productivity", iconToken: "square.and.pencil", isAuto: true),
            Category(id: ID.security, userID: userID, name: "Security", iconToken: "lock.shield", isAuto: true),
            Category(id: ID.health, userID: userID, name: "Health", iconToken: "heart.text.square", isAuto: true),
            Category(id: ID.groceries, userID: userID, name: "Groceries", iconToken: "basket", isAuto: true),
            Category(id: ID.dining, userID: userID, name: "Dining", iconToken: "fork.knife", isAuto: true),
        ]

        let subscriptions = makeSubscriptions(userID: userID)
        let transactions = makeTransactions(userID: userID)
        let requests = [
            CancellationRequest(
                id: "cancel-creative-cloud",
                userID: userID,
                subscriptionID: ID.creativeCloud,
                method: .concierge,
                status: .requested,
                createdAt: date(year: 2026, month: 6, day: 26, hour: 15),
                updatedAt: date(year: 2026, month: 6, day: 26, hour: 15),
                note: "User asked concierge to review unused design plan."
            ),
            CancellationRequest(
                id: "cancel-parcel-pro",
                userID: userID,
                subscriptionID: ID.parcelPro,
                method: .guided,
                status: .confirmed,
                createdAt: date(year: 2026, month: 5, day: 2, hour: 10),
                updatedAt: date(year: 2026, month: 5, day: 4, hour: 16),
                note: "Cancelled from provider account settings."
            ),
        ]

        let priceChanges = [
            PriceChange(
                id: "price-streamline-2026-06",
                userID: userID,
                subscriptionID: ID.streamline,
                oldAmount: .usd(Cents.dollars(13, cents: 99)),
                newAmount: .usd(Cents.dollars(15, cents: 49)),
                changedAt: date(year: 2026, month: 6, day: 12)
            ),
        ]

        let alertSettings = AlertSettings(
            id: ID.alertSettings,
            userID: userID,
            renewalReminders: true,
            priceChanges: true,
            trialEndings: true,
            unusedNudges: true,
            weeklySummary: false
        )

        return Snapshot(
            accounts: accounts,
            transactions: transactions,
            subscriptions: subscriptions,
            cancellationRequests: requests,
            categories: categories,
            priceChanges: priceChanges,
            alertSettings: alertSettings,
            recurringIncome: makeRecurringIncome(userID: userID),
            bills: makeBills(userID: userID),
            budgets: makeBudgets(userID: userID),
            goals: makeGoals(userID: userID),
            goalContributions: makeGoalContributions(userID: userID)
        )
    }

    @MainActor
    static func insertPreviewData(into context: ModelContext, userID: String = defaultUserID) throws {
        let existing = try context.fetchCount(FetchDescriptor<Subscription>())
        guard existing == 0 else {
            return
        }

        let snapshot = snapshot(userID: userID)
        snapshot.accounts.forEach(context.insert)
        snapshot.categories.forEach(context.insert)
        snapshot.transactions.forEach(context.insert)
        snapshot.subscriptions.forEach(context.insert)
        snapshot.cancellationRequests.forEach(context.insert)
        snapshot.priceChanges.forEach(context.insert)
        snapshot.recurringIncome.forEach(context.insert)
        snapshot.bills.forEach(context.insert)
        snapshot.budgets.forEach(context.insert)
        snapshot.goals.forEach(context.insert)
        snapshot.goalContributions.forEach(context.insert)
        context.insert(snapshot.alertSettings)
        try context.save()
    }
}

private extension SeedData {
    static func makeSubscriptions(userID: String) -> [Subscription] {
        streamingAndDesignSubscriptions(userID: userID)
            + productivityAndSecuritySubscriptions(userID: userID)
            + toolsAndArchivedSubscriptions(userID: userID)
    }

    static func streamingAndDesignSubscriptions(userID: String) -> [Subscription] {
        [
            Subscription(
                id: ID.streamline,
                userID: userID,
                name: "Streamline+",
                merchantKey: MerchantKey("Streamline Plus"),
                monogramLetter: "S",
                tileColorToken: .clay,
                amount: .usd(Cents.dollars(15, cents: 49)),
                cadence: .monthly,
                nextRenewal: date(year: 2026, month: 7, day: 12),
                lastUsed: date(year: 2026, month: 6, day: 26),
                categoryID: ID.streaming,
                status: .active,
                detectionConfidence: 0.98,
                firstSeen: date(year: 2025, month: 10, day: 12),
                lastCharge: date(year: 2026, month: 6, day: 12)
            ),
            Subscription(
                id: ID.tonebox,
                userID: userID,
                name: "Tonebox",
                merchantKey: MerchantKey("Tonebox"),
                monogramLetter: "T",
                tileColorToken: .goldDeep,
                amount: .usd(Cents.dollars(12, cents: 99)),
                cadence: .monthly,
                nextRenewal: date(year: 2026, month: 7, day: 2),
                lastUsed: date(year: 2026, month: 6, day: 22),
                categoryID: ID.audio,
                status: .active,
                detectionConfidence: 0.95,
                firstSeen: date(year: 2025, month: 12, day: 2),
                lastCharge: date(year: 2026, month: 6, day: 2)
            ),
            Subscription(
                id: ID.reelhouse,
                userID: userID,
                name: "Reelhouse",
                merchantKey: MerchantKey("Reelhouse"),
                monogramLetter: "R",
                tileColorToken: .inkSoft,
                amount: .usd(Cents.dollars(19, cents: 99)),
                cadence: .monthly,
                nextRenewal: date(year: 2026, month: 7, day: 8),
                lastUsed: date(year: 2026, month: 3, day: 1),
                categoryID: ID.streaming,
                status: .unused,
                detectionConfidence: 0.94,
                firstSeen: date(year: 2025, month: 8, day: 8),
                lastCharge: date(year: 2026, month: 6, day: 8)
            ),
            Subscription(
                id: ID.creativeCloud,
                userID: userID,
                name: "Creative Cloud",
                merchantKey: MerchantKey("Creative Cloud"),
                monogramLetter: "C",
                tileColorToken: .ink,
                amount: .usd(Cents.dollars(59, cents: 99)),
                cadence: .monthly,
                nextRenewal: date(year: 2026, month: 7, day: 17),
                lastUsed: date(year: 2026, month: 3, day: 14),
                categoryID: ID.design,
                status: .unused,
                detectionConfidence: 0.99,
                firstSeen: date(year: 2024, month: 7, day: 17),
                lastCharge: date(year: 2026, month: 6, day: 17)
            ),
        ]
    }

    static func productivityAndSecuritySubscriptions(userID: String) -> [Subscription] {
        [
            Subscription(
                id: ID.notewell,
                userID: userID,
                name: "Notewell",
                merchantKey: MerchantKey("Notewell"),
                monogramLetter: "N",
                tileColorToken: .gold,
                amount: .usd(Cents.dollars(119, cents: 88)),
                cadence: .yearly,
                nextRenewal: date(year: 2027, month: 4, day: 5),
                lastUsed: date(year: 2025, month: 12, day: 14),
                categoryID: ID.productivity,
                status: .unused,
                detectionConfidence: 0.91,
                firstSeen: date(year: 2024, month: 4, day: 5),
                lastCharge: date(year: 2026, month: 4, day: 5)
            ),
            Subscription(
                id: ID.atlasVPN,
                userID: userID,
                name: "Atlas VPN",
                merchantKey: MerchantKey("Atlas VPN"),
                monogramLetter: "A",
                tileColorToken: .inkFaint,
                amount: .usd(Cents.dollars(35, cents: 97)),
                cadence: .quarterly,
                nextRenewal: date(year: 2026, month: 8, day: 21),
                lastUsed: date(year: 2026, month: 6, day: 18),
                categoryID: ID.security,
                status: .active,
                detectionConfidence: 0.89,
                firstSeen: date(year: 2025, month: 2, day: 21),
                lastCharge: date(year: 2026, month: 5, day: 21)
            ),
            Subscription(
                id: ID.cloudback,
                userID: userID,
                name: "Cloudback",
                merchantKey: MerchantKey("Cloudback"),
                monogramLetter: "C",
                tileColorToken: .clay,
                amount: .usd(Cents.dollars(31, cents: 4)),
                cadence: .monthly,
                nextRenewal: date(year: 2026, month: 7, day: 4),
                lastUsed: date(year: 2026, month: 2, day: 16),
                categoryID: ID.productivity,
                status: .unused,
                detectionConfidence: 0.87,
                firstSeen: date(year: 2025, month: 6, day: 4),
                lastCharge: date(year: 2026, month: 6, day: 4)
            ),
            Subscription(
                id: ID.workoutLab,
                userID: userID,
                name: "WorkoutLab",
                merchantKey: MerchantKey("WorkoutLab"),
                monogramLetter: "W",
                tileColorToken: .goldDeep,
                amount: .usd(Cents.dollars(24, cents: 99)),
                cadence: .monthly,
                nextRenewal: date(year: 2026, month: 7, day: 20),
                lastUsed: date(year: 2026, month: 1, day: 3),
                categoryID: ID.health,
                status: .unused,
                detectionConfidence: 0.9,
                firstSeen: date(year: 2025, month: 4, day: 20),
                lastCharge: date(year: 2026, month: 6, day: 20)
            ),
        ]
    }

    static func toolsAndArchivedSubscriptions(userID: String) -> [Subscription] {
        [
            Subscription(
                id: ID.readwise,
                userID: userID,
                name: "Readwise",
                merchantKey: MerchantKey("Readwise"),
                monogramLetter: "R",
                tileColorToken: .ink,
                amount: .usd(Cents.dollars(8, cents: 99)),
                cadence: .monthly,
                nextRenewal: date(year: 2026, month: 7, day: 6),
                lastUsed: date(year: 2026, month: 6, day: 28),
                categoryID: ID.productivity,
                status: .active,
                detectionConfidence: 0.92,
                firstSeen: date(year: 2026, month: 1, day: 6),
                lastCharge: date(year: 2026, month: 6, day: 6)
            ),
            Subscription(
                id: ID.figma,
                userID: userID,
                name: "Figma",
                merchantKey: MerchantKey("Figma"),
                monogramLetter: "F",
                tileColorToken: .inkSoft,
                amount: .usd(Cents.dollars(24, cents: 37)),
                cadence: .monthly,
                nextRenewal: date(year: 2026, month: 7, day: 24),
                lastUsed: date(year: 2026, month: 6, day: 25),
                categoryID: ID.design,
                status: .active,
                detectionConfidence: 0.96,
                firstSeen: date(year: 2025, month: 9, day: 24),
                lastCharge: date(year: 2026, month: 6, day: 24)
            ),
            Subscription(
                id: ID.daybook,
                userID: userID,
                name: "Daybook Pro",
                merchantKey: MerchantKey("Daybook Pro"),
                monogramLetter: "D",
                tileColorToken: .inkFaint,
                amount: .usd(Cents.dollars(28)),
                cadence: .monthly,
                nextRenewal: date(year: 2026, month: 7, day: 15),
                lastUsed: date(year: 2026, month: 6, day: 29),
                categoryID: ID.productivity,
                status: .active,
                detectionConfidence: 0.88,
                firstSeen: date(year: 2025, month: 7, day: 15),
                lastCharge: date(year: 2026, month: 6, day: 15)
            ),
            Subscription(
                id: ID.parcelPro,
                userID: userID,
                name: "Parcel Pro",
                merchantKey: MerchantKey("Parcel Pro"),
                monogramLetter: "P",
                tileColorToken: .inkSoft,
                amount: .usd(Cents.dollars(7, cents: 99)),
                cadence: .monthly,
                nextRenewal: nil,
                lastUsed: date(year: 2026, month: 4, day: 22),
                categoryID: ID.productivity,
                status: .cancelled,
                detectionConfidence: 0.86,
                firstSeen: date(year: 2025, month: 5, day: 2),
                lastCharge: date(year: 2026, month: 5, day: 2)
            ),
        ]
    }

    static func makeTransactions(userID: String) -> [Transaction] {
        [
            Transaction(
                id: "txn-streamline-jun",
                userID: userID,
                accountID: ID.travelCard,
                merchantRaw: "STREAMLINE PLUS",
                merchantKey: MerchantKey("Streamline Plus"),
                amount: .usd(Cents.dollars(15, cents: 49)),
                date: date(year: 2026, month: 6, day: 12),
                categoryHint: "Streaming"
            ),
            Transaction(
                id: "txn-tonebox-jun",
                userID: userID,
                accountID: ID.checking,
                merchantRaw: "TONEBOX AUDIO",
                merchantKey: MerchantKey("Tonebox"),
                amount: .usd(Cents.dollars(12, cents: 99)),
                date: date(year: 2026, month: 6, day: 2),
                categoryHint: "Audio"
            ),
            Transaction(
                id: "txn-creative-jun",
                userID: userID,
                accountID: ID.travelCard,
                merchantRaw: "ADOBE CREATIVE CLOUD",
                merchantKey: MerchantKey("Creative Cloud"),
                amount: .usd(Cents.dollars(59, cents: 99)),
                date: date(year: 2026, month: 6, day: 17),
                categoryHint: "Design"
            ),
            Transaction(
                id: "txn-notewell-apr",
                userID: userID,
                accountID: ID.checking,
                merchantRaw: "NOTEWELL ANNUAL",
                merchantKey: MerchantKey("Notewell"),
                amount: .usd(Cents.dollars(119, cents: 88)),
                date: date(year: 2026, month: 4, day: 5),
                categoryHint: "Productivity"
            ),
        ] + makeDiscretionaryTransactions(userID: userID) + makeHistoricalTransactions(userID: userID)
    }

    /// Everyday, non-recurring debits so the discretionary spend estimate (and thus the
    /// safe-to-spend comparison figure) has realistic data to average.
    static func makeDiscretionaryTransactions(userID: String) -> [Transaction] {
        let entries = [
            DiscretionaryEntry(id: "txn-grocery-jun05", merchant: "CORNER GROCERY", cents: 6247, day: 5, categoryID: ID.groceries),
            DiscretionaryEntry(id: "txn-coffee-jun07", merchant: "BLUE BOTTLE COFFEE", cents: 780, day: 7, categoryID: ID.dining),
            DiscretionaryEntry(id: "txn-gas-jun09", merchant: "SHELL STATION 227", cents: 5210, day: 9, categoryID: nil),
            DiscretionaryEntry(id: "txn-pharmacy-jun11", merchant: "GREENLEAF PHARMACY", cents: 2394, day: 11, categoryID: ID.health),
            DiscretionaryEntry(id: "txn-lunch-jun14", merchant: "SAIGON KITCHEN", cents: 3185, day: 14, categoryID: ID.dining),
            DiscretionaryEntry(id: "txn-grocery-jun19", merchant: "CORNER GROCERY", cents: 5488, day: 19, categoryID: ID.groceries),
            DiscretionaryEntry(id: "txn-hardware-jun22", merchant: "MADISON HARDWARE", cents: 4103, day: 22, categoryID: nil),
            DiscretionaryEntry(id: "txn-coffee-jun25", merchant: "BLUE BOTTLE COFFEE", cents: 640, day: 25, categoryID: ID.dining),
        ]

        return entries.map { entry in
            Transaction(
                id: entry.id,
                userID: userID,
                accountID: ID.checking,
                merchantRaw: entry.merchant,
                merchantKey: MerchantKey(entry.merchant),
                amount: .usd(entry.cents),
                date: date(year: 2026, month: 6, day: entry.day),
                categoryID: entry.categoryID
            )
        }
    }

    struct DiscretionaryEntry {
        let id: String
        let merchant: String
        let cents: Int
        let day: Int
        /// Pre-categorised so the seeded budgets have real spend to measure against.
        let categoryID: String?
    }

    static func makeRecurringIncome(userID: String) -> [RecurringIncome] {
        [
            RecurringIncome(
                id: ID.payrollIncome,
                userID: userID,
                sourceName: "Northwind Labs",
                merchantKey: MerchantKey("Northwind Labs Payroll"),
                amount: .usd(Cents.dollars(2100)),
                cadence: .biweekly,
                nextExpected: date(year: 2026, month: 7, day: 3),
                status: .active,
                detectionConfidence: 0.94,
                firstSeen: date(year: 2026, month: 1, day: 2),
                lastReceived: date(year: 2026, month: 6, day: 19)
            ),
        ]
    }

    static func makeBills(userID: String) -> [Bill] {
        [
            Bill(
                id: ID.rentBill,
                userID: userID,
                name: "Northgate Apartments",
                merchantKey: MerchantKey("Northgate Apartments Rent"),
                amount: .usd(Cents.dollars(1850)),
                cadence: .monthly,
                nextDue: date(year: 2026, month: 7, day: 1),
                status: .active,
                detectionConfidence: 0.9,
                firstSeen: date(year: 2026, month: 1, day: 1),
                lastCharge: date(year: 2026, month: 6, day: 1)
            ),
        ]
    }

    /// Two monthly budgets over the pre-categorised everyday spend, so the budgets screen
    /// has something real to render. Deliberately both healthy — overspent and
    /// over-pace states are exercised in tests rather than baked into demo data.
    static func makeBudgets(userID: String) -> [Budget] {
        [
            Budget(
                id: ID.groceriesBudget,
                userID: userID,
                categoryID: ID.groceries,
                amount: .usd(Cents.dollars(400)),
                period: .monthly,
                rolloverEnabled: false,
                startDate: date(year: 2026, month: 1, day: 1)
            ),
            Budget(
                id: ID.diningBudget,
                userID: userID,
                categoryID: ID.dining,
                amount: .usd(Cents.dollars(100)),
                period: .monthly,
                rolloverEnabled: true,
                startDate: date(year: 2026, month: 1, day: 1)
            ),
        ]
    }

    /// Two goals in deliberately different states: one comfortably on track with a date, one
    /// with a contribution but no date so the "derive the completion estimate" path renders.
    static func makeGoals(userID: String) -> [Goal] {
        [
            Goal(
                id: ID.emergencyGoal,
                userID: userID,
                name: "Emergency fund",
                targetAmount: .usd(Cents.dollars(3000)),
                targetDate: date(year: 2026, month: 12, day: 1),
                monthlyContribution: .usd(Cents.dollars(250)),
                createdAt: date(year: 2026, month: 1, day: 6)
            ),
            Goal(
                id: ID.laptopGoal,
                userID: userID,
                name: "New laptop",
                targetAmount: .usd(Cents.dollars(1800)),
                monthlyContribution: .usd(Cents.dollars(150)),
                createdAt: date(year: 2026, month: 3, day: 14)
            ),
        ]
    }

    /// Monthly deposits plus one withdrawal, so the signed-contribution behaviour is visible
    /// in previews rather than only in tests.
    static func makeGoalContributions(userID: String) -> [GoalContribution] {
        let emergency = (0 ..< 5).map { index in
            GoalContribution(
                id: "contrib-emergency-\(index)",
                userID: userID,
                goalID: ID.emergencyGoal,
                amount: .usd(Cents.dollars(250)),
                date: date(year: 2026, month: index + 1, day: 6)
            )
        }

        let laptop = [
            GoalContribution(
                id: "contrib-laptop-0",
                userID: userID,
                goalID: ID.laptopGoal,
                amount: .usd(Cents.dollars(150)),
                date: date(year: 2026, month: 4, day: 14)
            ),
            GoalContribution(
                id: "contrib-laptop-1",
                userID: userID,
                goalID: ID.laptopGoal,
                amount: .usd(Cents.dollars(150)),
                date: date(year: 2026, month: 5, day: 14)
            ),
            GoalContribution(
                id: "contrib-laptop-withdrawal",
                userID: userID,
                goalID: ID.laptopGoal,
                amount: .usd(-Cents.dollars(60)),
                date: date(year: 2026, month: 5, day: 20),
                note: "Borrowed for a repair"
            ),
        ]

        return emergency + laptop
    }

    /// Five months of everyday spending before June, so the trend and month-over-month
    /// reports have real shape.
    ///
    /// Every date here is **29 May 2026 or earlier, deliberately**. The safe-to-spend
    /// discretionary estimate averages the trailing 30 days from the 29 June reference date,
    /// and the budget cycle covers June — so keeping this history strictly before 30 May
    /// leaves every existing June-derived assertion untouched.
    static func makeHistoricalTransactions(userID: String) -> [Transaction] {
        let entries: [HistoricalEntry] = [
            HistoricalEntry(month: 1, day: 8, merchant: "CORNER GROCERY", cents: 7120, categoryID: ID.groceries),
            HistoricalEntry(month: 1, day: 17, merchant: "SAIGON KITCHEN", cents: 2890, categoryID: ID.dining),
            HistoricalEntry(month: 1, day: 24, merchant: "SHELL STATION 227", cents: 4870, categoryID: nil),
            HistoricalEntry(month: 2, day: 6, merchant: "CORNER GROCERY", cents: 6640, categoryID: ID.groceries),
            HistoricalEntry(month: 2, day: 13, merchant: "BLUE BOTTLE COFFEE", cents: 920, categoryID: ID.dining),
            HistoricalEntry(month: 2, day: 21, merchant: "GREENLEAF PHARMACY", cents: 3140, categoryID: ID.health),
            HistoricalEntry(month: 3, day: 4, merchant: "CORNER GROCERY", cents: 8215, categoryID: ID.groceries),
            HistoricalEntry(month: 3, day: 12, merchant: "SAIGON KITCHEN", cents: 4460, categoryID: ID.dining),
            HistoricalEntry(month: 3, day: 26, merchant: "MADISON HARDWARE", cents: 5330, categoryID: nil),
            HistoricalEntry(month: 4, day: 9, merchant: "CORNER GROCERY", cents: 5980, categoryID: ID.groceries),
            HistoricalEntry(month: 4, day: 18, merchant: "BLUE BOTTLE COFFEE", cents: 1240, categoryID: ID.dining),
            HistoricalEntry(month: 4, day: 27, merchant: "GREENLEAF PHARMACY", cents: 2075, categoryID: ID.health),
            HistoricalEntry(month: 5, day: 5, merchant: "CORNER GROCERY", cents: 9410, categoryID: ID.groceries),
            HistoricalEntry(month: 5, day: 14, merchant: "SAIGON KITCHEN", cents: 3720, categoryID: ID.dining),
            HistoricalEntry(month: 5, day: 22, merchant: "SHELL STATION 227", cents: 5115, categoryID: nil),
            HistoricalEntry(month: 5, day: 27, merchant: "BLUE BOTTLE COFFEE", cents: 860, categoryID: ID.dining),
        ]

        return entries.map { entry in
            Transaction(
                id: "txn-hist-\(entry.month)-\(entry.day)",
                userID: userID,
                accountID: ID.checking,
                merchantRaw: entry.merchant,
                merchantKey: MerchantKey(entry.merchant),
                amount: .usd(entry.cents),
                date: date(year: 2026, month: entry.month, day: entry.day),
                categoryID: entry.categoryID
            )
        }
    }

    struct HistoricalEntry {
        let month: Int
        let day: Int
        let merchant: String
        let cents: Int
        let categoryID: String?
    }

    static func date(year: Int, month: Int, day: Int, hour: Int = 12) -> Date {
        var components = DateComponents()
        components.calendar = Calendar.utc
        components.timeZone = TimeZone(secondsFromGMT: 0)
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        return components.date ?? Date(timeIntervalSince1970: 0)
    }
}

extension Calendar {
    static var utc: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }
}
