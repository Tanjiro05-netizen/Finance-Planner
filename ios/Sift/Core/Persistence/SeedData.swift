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
            bills: makeBills(userID: userID)
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
        ] + makeDiscretionaryTransactions(userID: userID)
    }

    /// Everyday, non-recurring debits so the discretionary spend estimate (and thus the
    /// safe-to-spend comparison figure) has realistic data to average.
    static func makeDiscretionaryTransactions(userID: String) -> [Transaction] {
        let entries = [
            DiscretionaryEntry(id: "txn-grocery-jun05", merchant: "CORNER GROCERY", cents: 6247, day: 5),
            DiscretionaryEntry(id: "txn-coffee-jun07", merchant: "BLUE BOTTLE COFFEE", cents: 780, day: 7),
            DiscretionaryEntry(id: "txn-gas-jun09", merchant: "SHELL STATION 227", cents: 5210, day: 9),
            DiscretionaryEntry(id: "txn-pharmacy-jun11", merchant: "GREENLEAF PHARMACY", cents: 2394, day: 11),
            DiscretionaryEntry(id: "txn-lunch-jun14", merchant: "SAIGON KITCHEN", cents: 3185, day: 14),
            DiscretionaryEntry(id: "txn-grocery-jun19", merchant: "CORNER GROCERY", cents: 5488, day: 19),
            DiscretionaryEntry(id: "txn-hardware-jun22", merchant: "MADISON HARDWARE", cents: 4103, day: 22),
            DiscretionaryEntry(id: "txn-coffee-jun25", merchant: "BLUE BOTTLE COFFEE", cents: 640, day: 25),
        ]

        return entries.map { entry in
            Transaction(
                id: entry.id,
                userID: userID,
                accountID: ID.checking,
                merchantRaw: entry.merchant,
                merchantKey: MerchantKey(entry.merchant),
                amount: .usd(entry.cents),
                date: date(year: 2026, month: 6, day: entry.day)
            )
        }
    }

    struct DiscretionaryEntry {
        let id: String
        let merchant: String
        let cents: Int
        let day: Int
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
