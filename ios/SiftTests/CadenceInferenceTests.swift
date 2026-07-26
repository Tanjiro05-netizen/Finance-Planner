import Foundation
@testable import Sift
import Testing

struct CadenceInferenceTests {
    private let epoch = Date(timeIntervalSince1970: 1_700_000_000)

    private func dates(daysApart: Int, count: Int) -> [Date] {
        (0 ..< count).map { epoch.addingTimeInterval(TimeInterval($0 * daysApart * 86400)) }
    }

    @Test func intervalsAreDayGapsBetweenSortedDates() {
        let intervals = CadenceMath.intervals(forSortedDates: dates(daysApart: 30, count: 4))
        #expect(intervals == [30, 30, 30])
    }

    @Test func infersMonthlyFromMonthlyIntervals() throws {
        let intervals = CadenceMath.intervals(forSortedDates: dates(daysApart: 30, count: 5))
        let match = try #require(CadenceMath.inferCadence(from: intervals, occurrenceCount: 5))
        #expect(match.cadence == .monthly)
        #expect(match.regularity > 0.8)
    }

    @Test func infersWeeklyAndYearlyAtToleranceBounds() {
        let weekly = CadenceMath.inferCadence(from: [6, 8, 7], occurrenceCount: 4)
        #expect(weekly?.cadence == .weekly)

        // Yearly only needs a single in-range interval.
        let yearly = CadenceMath.inferCadence(from: [365], occurrenceCount: 2)
        #expect(yearly?.cadence == .yearly)
    }

    @Test func subscriptionCadencesExcludeBiweekly() {
        // 14-day intervals don't match any subscription cadence tolerance range.
        let match = CadenceMath.inferCadence(from: [14, 14, 14], occurrenceCount: 4)
        #expect(match == nil)
    }

    @Test func incomeCadencesDetectBiweekly() throws {
        let match = try #require(CadenceMath.inferCadence(
            from: [14, 14, 13, 15],
            occurrenceCount: 5,
            candidates: CadenceMath.incomeCadences
        ))
        #expect(match.cadence == .biweekly)
    }

    @Test func returnsNilWhenIntervalsTooIrregular() {
        #expect(CadenceMath.inferCadence(from: [3, 47, 200], occurrenceCount: 3) == nil)
        #expect(CadenceMath.inferCadence(from: [], occurrenceCount: 0) == nil)
    }

    @Test func medianHandlesOddAndEvenCounts() {
        #expect(CadenceMath.medianAmount([.usd(100), .usd(300), .usd(200)]) == .usd(200))
        #expect(CadenceMath.medianAmount([.usd(100), .usd(200), .usd(300), .usd(400)]) == .usd(250))
        #expect(CadenceMath.medianAmount([]) == .zeroUSD)
    }

    @Test func amountToleranceUsesFivePercentFloorOfOneDollar() {
        // Below the floor: 5% of $10 is $0.50, so the $1 (100¢) floor wins.
        #expect(CadenceMath.amountTolerance(for: .usd(1000)) == 100)
        // Above the floor: 5% of $100 is $5 (500¢).
        #expect(CadenceMath.amountTolerance(for: .usd(10000)) == 500)
    }

    @Test func amountSegmentsSplitOnPriceJump() {
        let segments = CadenceMath.amountSegments(from: [
            AmountObservation(date: epoch, amount: .usd(999)),
            AmountObservation(date: epoch, amount: .usd(1005)),
            AmountObservation(date: epoch, amount: .usd(1499)),
        ])
        #expect(segments.count == 2)
        #expect(segments[0].observations.count == 2)
        #expect(segments[1].observations.count == 1)
    }

    @Test func stabilityScoreIsHighForConsistentAmounts() {
        let score = CadenceMath.amountStabilityScore(
            amounts: [.usd(1500), .usd(1500), .usd(1499)],
            currentAmount: .usd(1500),
            hasPriceChange: false
        )
        #expect(score == 1.0)
    }

    @Test func confidenceWeightsComponents() {
        let confidence = CadenceMath.confidence(
            occurrenceScore: 1.0,
            cadenceRegularity: 1.0,
            amountStability: 1.0,
            aliasBonus: 0.10
        )
        #expect(confidence == 1.0)

        let modest = CadenceMath.confidence(
            occurrenceScore: 0.5,
            cadenceRegularity: 0.5,
            amountStability: 0.5,
            aliasBonus: 0
        )
        #expect(abs(modest - 0.45) < 0.0001)
    }
}
