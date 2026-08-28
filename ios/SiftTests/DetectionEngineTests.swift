import Foundation
@testable import Sift
import Testing

struct DetectionEngineTests {
    private let engine = DetectionEngine()

    @Test func cleanMonthlyStreamProducesHighConfidenceCandidate() {
        let transactions = monthlySeries(
            merchant: "NETFLIX",
            amount: 1549,
            firstCharge: date(2025, 7, 15),
            count: 12
        )

        let result = engine.detect(transactions: transactions, referenceDate: date(2026, 7, 1))

        #expect(result.candidates.count == 1)
        let candidate = result.candidates[0]
        #expect(candidate.name == "Netflix")
        #expect(candidate.cadence == .monthly)
        #expect(candidate.amount == .usd(1549))
        #expect(candidate.confidence >= 0.95)
        #expect(candidate.nextRenewal == date(2026, 7, 15))
    }

    @Test func yearlySubscriptionNeedsOnlyTwoCharges() {
        let transactions = [
            txn("note-2025", merchant: "NOTEWELL ANNUAL", amount: 11988, date: date(2025, 6, 15)),
            txn("note-2026", merchant: "NOTEWELL ANNUAL", amount: 11988, date: date(2026, 6, 15)),
        ]

        let result = engine.detect(transactions: transactions, referenceDate: date(2026, 7, 1))

        #expect(result.candidates.count == 1)
        #expect(result.candidates[0].cadence == .yearly)
        #expect(result.candidates[0].nextRenewal == date(2027, 6, 15))
    }

    @Test func irregularGrocerySpendDoesNotSurfaceCandidate() {
        let transactions = [
            txn("grocery-1", merchant: "NORTH MARKET", amount: 3829, date: date(2026, 1, 2)),
            txn("grocery-2", merchant: "North Market #481", amount: 6412, date: date(2026, 1, 5)),
            txn("grocery-3", merchant: "NORTH MARKET", amount: 2919, date: date(2026, 1, 13)),
            txn("grocery-4", merchant: "North Market", amount: 9841, date: date(2026, 1, 28)),
            txn("grocery-5", merchant: "NORTH MARKET", amount: 5577, date: date(2026, 2, 1)),
            txn("grocery-6", merchant: "North Market", amount: 7208, date: date(2026, 2, 19)),
            txn("grocery-7", merchant: "NORTH MARKET", amount: 4113, date: date(2026, 3, 2)),
            txn("grocery-8", merchant: "North Market", amount: 8822, date: date(2026, 4, 18)),
            txn("grocery-9", merchant: "NORTH MARKET", amount: 2448, date: date(2026, 4, 21)),
            txn("grocery-10", merchant: "North Market", amount: 7402, date: date(2026, 5, 9)),
        ]

        let result = engine.detect(transactions: transactions, referenceDate: date(2026, 6, 1))

        #expect(result.candidates.isEmpty)
    }

    @Test func amountStepUsesCurrentPriceAndEmitsPriceChange() {
        let transactions = monthlySeries(
            merchant: "STREAMLINE PLUS",
            amountByIndex: { index in index < 6 ? 1199 : 1399 },
            firstCharge: date(2025, 7, 1),
            count: 12
        )

        let result = engine.detect(transactions: transactions, referenceDate: date(2026, 6, 15))

        #expect(result.candidates.count == 1)
        #expect(result.candidates[0].amount == .usd(1399))
        #expect(result.priceChanges.count == 1)
        #expect(result.priceChanges[0].oldAmount == .usd(1199))
        #expect(result.priceChanges[0].newAmount == .usd(1399))
        #expect(result.priceChanges[0].changedAt == date(2026, 1, 1))
    }

    @Test func merchantNoiseCollapsesToOneMerchantKey() {
        let transactions = [
            txn("netflix-1", merchant: "NETFLIX #4471 LOS GATOS", amount: 1549, date: date(2026, 3, 15)),
            txn("netflix-2", merchant: "Netflix.com", amount: 1549, date: date(2026, 4, 15)),
            txn("netflix-3", merchant: "NETFLIX DIGITAL", amount: 1549, date: date(2026, 5, 15)),
            txn("netflix-4", merchant: "NETFLIX #4471 CA", amount: 1549, date: date(2026, 6, 15)),
        ]

        let result = engine.detect(transactions: transactions, referenceDate: date(2026, 7, 1))

        #expect(result.candidates.count == 1)
        #expect(result.candidates[0].merchantKey == MerchantKey("Netflix"))
    }

    @Test func freeTrialPatternFlagsUpcomingRenewal() {
        let transactions = [
            txn("trial-0", merchant: "READWISE", amount: 0, date: date(2026, 4, 10)),
            txn("trial-1", merchant: "READWISE", amount: 999, date: date(2026, 5, 10)),
            txn("trial-2", merchant: "READWISE", amount: 999, date: date(2026, 6, 10)),
        ]

        let result = engine.detect(transactions: transactions, referenceDate: date(2026, 6, 20))

        #expect(result.candidates.count == 1)
        #expect(result.candidates[0].isTrialEnding)
        #expect(result.flags == [
            DetectionFlag(merchantKey: MerchantKey("Readwise"), kind: .trialEnding),
        ])
    }

    @Test func detectionIsDeterministicForSameInputAndReferenceDate() {
        let transactions = monthlySeries(
            merchant: "FIGMA",
            amount: 2437,
            firstCharge: date(2025, 9, 24),
            count: 10
        ).reversed()

        let first = engine.detect(transactions: Array(transactions), referenceDate: date(2026, 7, 1))
        let second = engine.detect(transactions: Array(transactions), referenceDate: date(2026, 7, 1))

        #expect(first == second)
    }

    @Test func detectionProcessesTwoThousandTransactionsUnderOneSecond() {
        let transactions = largeTransactionSet(merchantCount: 80, chargesPerMerchant: 25)

        // Best-of-three wall-clock timing: the engine is pure and deterministic, so
        // the fastest run reflects its real cost even when a shared CI runner is
        // starved and a single sample would measure scheduler noise instead.
        var fastest = TimeInterval.infinity
        var result = DetectionResult.empty
        for _ in 0 ..< 3 {
            let startedAt = Date()
            result = engine.detect(transactions: transactions, referenceDate: date(2026, 7, 1))
            fastest = min(fastest, Date().timeIntervalSince(startedAt))
        }

        #expect(transactions.count == 2000)
        #expect(result.candidates.count == 80)
        #expect(fastest < 1)
    }
}

private func monthlySeries(
    merchant: String,
    amount: Int,
    firstCharge: Date,
    count: Int
) -> [Txn] {
    monthlySeries(
        merchant: merchant,
        amountByIndex: { _ in amount },
        firstCharge: firstCharge,
        count: count
    )
}

private func monthlySeries(
    merchant: String,
    amountByIndex: (Int) -> Int,
    firstCharge: Date,
    count: Int
) -> [Txn] {
    (0 ..< count).map { index in
        txn(
            "\(merchant)-\(index)",
            merchant: merchant,
            amount: amountByIndex(index),
            date: Calendar.utc.date(byAdding: .month, value: index, to: firstCharge) ?? firstCharge
        )
    }
}

private func txn(
    _ id: String,
    merchant: String,
    amount: Int,
    date: Date,
    pending: Bool = false
) -> Txn {
    Txn(
        id: id,
        merchantRaw: merchant,
        amount: .usd(amount),
        date: date,
        pending: pending
    )
}

private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
    var components = DateComponents()
    components.calendar = Calendar.utc
    components.timeZone = TimeZone(secondsFromGMT: 0)
    components.year = year
    components.month = month
    components.day = day
    components.hour = 12
    return components.date ?? Date(timeIntervalSince1970: 0)
}

private func largeTransactionSet(merchantCount: Int, chargesPerMerchant: Int) -> [Txn] {
    (0 ..< merchantCount).flatMap { merchantIndex in
        let day = (merchantIndex % 24) + 1
        let firstCharge = date(2024, 1, day)
        let amount = 799 + merchantIndex

        return monthlySeries(
            merchant: "MERCHANT \(merchantSuffix(for: merchantIndex))",
            amount: amount,
            firstCharge: firstCharge,
            count: chargesPerMerchant
        )
    }
}

private func merchantSuffix(for index: Int) -> String {
    let alphabet = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ")
    let first = alphabet[index / alphabet.count]
    let second = alphabet[index % alphabet.count]
    return "\(first)\(second)"
}
