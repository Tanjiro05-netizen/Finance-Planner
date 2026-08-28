import Foundation
@testable import Sift
import Testing

struct IncomeDetectionEngineTests {
    private let referenceDate = Date(timeIntervalSince1970: 1_720_000_000)

    private func payroll(daysApart: Int, count: Int, amount: Int, merchant: String = "NORTHWIND LABS PAYROLL") -> [Txn] {
        (0 ..< count).map { index in
            Txn(
                id: "\(merchant)-\(index)",
                merchantRaw: merchant,
                amount: .usd(amount),
                date: referenceDate.addingTimeInterval(TimeInterval(-(count - index) * daysApart * 86400))
            )
        }
    }

    @Test func detectsBiweeklyPayroll() throws {
        let engine = IncomeDetectionEngine()
        let candidates = engine.detect(transactions: payroll(daysApart: 14, count: 6, amount: 210_000), referenceDate: referenceDate)

        let candidate = try #require(candidates.first)
        #expect(candidate.cadence == .biweekly)
        #expect(candidate.amount == .usd(210_000))
        #expect(candidate.merchantKey == MerchantKey("Northwind Labs Payroll"))
        #expect(candidate.nextExpected > referenceDate)
        #expect(candidate.confidence >= 0.6)
    }

    @Test func detectsMonthlyPayroll() throws {
        let engine = IncomeDetectionEngine()
        let candidates = engine.detect(transactions: payroll(daysApart: 30, count: 5, amount: 450_000), referenceDate: referenceDate)
        let candidate = try #require(candidates.first)
        #expect(candidate.cadence == .monthly)
    }

    @Test func irregularGigIncomeIsNotDetected() {
        let engine = IncomeDetectionEngine()
        let gigs = [
            Txn(id: "g1", merchantRaw: "GIG PLATFORM", amount: .usd(12000), date: referenceDate.addingTimeInterval(-90 * 86400)),
            Txn(id: "g2", merchantRaw: "GIG PLATFORM", amount: .usd(48000), date: referenceDate.addingTimeInterval(-61 * 86400)),
            Txn(id: "g3", merchantRaw: "GIG PLATFORM", amount: .usd(9000), date: referenceDate.addingTimeInterval(-12 * 86400)),
        ]
        #expect(engine.detect(transactions: gigs, referenceDate: referenceDate).isEmpty)
    }

    @Test func pendingTransactionsAreIgnored() {
        let engine = IncomeDetectionEngine()
        var txns = payroll(daysApart: 14, count: 6, amount: 210_000)
        txns.append(Txn(id: "pending", merchantRaw: "NORTHWIND LABS PAYROLL", amount: .usd(210_000), date: referenceDate, pending: true))
        let candidates = engine.detect(transactions: txns, referenceDate: referenceDate)
        #expect(candidates.count == 1)
    }
}
