import Foundation

/// A cadence guess plus how regular the observed intervals were (0...1).
struct CadenceMatch: Equatable {
    let cadence: Cadence
    let regularity: Double
}

/// A single dated amount, used to detect price/amount changes over time.
struct AmountObservation {
    let date: Date
    let amount: Money
}

/// A run of consecutive observations whose amounts are all within tolerance of
/// each other — the unit price/amount detection works in.
struct AmountSegment {
    var observations: [AmountObservation]
}

/// Pure, direction-agnostic math for turning a `(date, amount)` series into a
/// cadence guess, a stable recurring amount, and a confidence score.
///
/// Extracted verbatim from `DetectionEngine` so both the subscription pipeline
/// (debits) and the recurring-income pipeline (credits) share exactly the same
/// arithmetic. Nothing here knows or cares whether the money came in or went out.
enum CadenceMath {
    /// The cadences the subscription detector considers. Kept as the default so
    /// existing subscription behavior is unchanged; the income detector passes an
    /// extended list that also includes `.biweekly` (common for payroll).
    static let subscriptionCadences: [Cadence] = [.weekly, .monthly, .quarterly, .yearly]
    static let incomeCadences: [Cadence] = [.weekly, .biweekly, .monthly, .quarterly, .yearly]

    /// Day-gaps between consecutive dates. `dates` must already be sorted ascending.
    static func intervals(forSortedDates dates: [Date], calendar: Calendar = .utc) -> [Int] {
        zip(dates, dates.dropFirst()).compactMap { previous, next in
            calendar.dateComponents([.day], from: previous, to: next).day
        }
    }

    static func inferCadence(
        from intervals: [Int],
        occurrenceCount: Int,
        candidates: [Cadence] = subscriptionCadences
    ) -> CadenceMatch? {
        guard !intervals.isEmpty else {
            return nil
        }

        let matches = candidates.compactMap { cadence -> CadenceMatch? in
            let matchedIntervals = intervals.filter { cadence.detectionToleranceDays.contains($0) }
            let minimumIntervals = cadence == .yearly ? 1 : 2

            guard matchedIntervals.count >= minimumIntervals else {
                return nil
            }

            let intervalRegularity = Double(matchedIntervals.count) / Double(intervals.count)
            let countBonus = min(Double(occurrenceCount) / 4.0, 1.0)
            let regularity = min(1.0, intervalRegularity * 0.85 + countBonus * 0.15)
            return CadenceMatch(cadence: cadence, regularity: regularity)
        }

        return matches.max { lhs, rhs in
            if lhs.regularity == rhs.regularity {
                return lhs.cadence.detectionTargetDays < rhs.cadence.detectionTargetDays
            }
            return lhs.regularity < rhs.regularity
        }
    }

    static func currentRecurringAmount(from amounts: [Money]) -> Money? {
        guard !amounts.isEmpty else {
            return nil
        }

        let segments = amountSegments(from: amounts.map { AmountObservation(date: .distantPast, amount: $0) })
        if let last = segments.last, last.observations.count >= 2 {
            return medianAmount(last.observations.map(\.amount))
        }

        return medianAmount(amounts)
    }

    static func amountStabilityScore(
        amounts: [Money],
        currentAmount: Money,
        hasPriceChange: Bool
    ) -> Double {
        guard !amounts.isEmpty else {
            return 0
        }

        let tolerance = amountTolerance(for: currentAmount)
        let stableCount = amounts.count(where: { amount in
            amount.currency == currentAmount.currency
                && abs(amount.amountMinor - currentAmount.amountMinor) <= tolerance
        })
        let rawScore = Double(stableCount) / Double(amounts.count)

        if hasPriceChange {
            return max(rawScore, 0.55)
        }

        return rawScore
    }

    static func amountSegments(from observations: [AmountObservation]) -> [AmountSegment] {
        var segments: [AmountSegment] = []

        for observation in observations {
            guard var current = segments.popLast() else {
                segments.append(AmountSegment(observations: [observation]))
                continue
            }

            let currentMedian = medianAmount(current.observations.map(\.amount))
            let tolerance = amountTolerance(for: currentMedian)

            if
                currentMedian.currency == observation.amount.currency,
                abs(currentMedian.amountMinor - observation.amount.amountMinor) <= tolerance
            {
                current.observations.append(observation)
                segments.append(current)
            } else {
                segments.append(current)
                segments.append(AmountSegment(observations: [observation]))
            }
        }

        return segments
    }

    static func nextOccurrenceDate(after last: Date, cadence: Cadence, referenceDate: Date) -> Date {
        var next = cadence.dateAfter(last)
        while next <= referenceDate {
            let advanced = cadence.dateAfter(next)
            guard advanced > next else {
                return next
            }
            next = advanced
        }
        return next
    }

    static func medianAmount(_ amounts: [Money]) -> Money {
        guard let firstCurrency = amounts.first?.currency else {
            return .zeroUSD
        }

        let sorted = amounts
            .filter { $0.currency == firstCurrency }
            .map(\.amountMinor)
            .sorted()
        let middle = sorted.count / 2

        if sorted.count.isMultiple(of: 2) {
            return Money(amountMinor: (sorted[middle - 1] + sorted[middle]) / 2, currency: firstCurrency)
        }

        return Money(amountMinor: sorted[middle], currency: firstCurrency)
    }

    static func amountTolerance(for amount: Money) -> Int {
        max(100, Int((Double(amount.amountMinor) * 0.05).rounded()))
    }

    static func occurrenceScore(count: Int) -> Double {
        min(Double(count) / 6.0, 1.0)
    }

    static func confidence(
        occurrenceScore: Double,
        cadenceRegularity: Double,
        amountStability: Double,
        aliasBonus: Double
    ) -> Double {
        min(
            1.0,
            0.28 * occurrenceScore
                + 0.34 * cadenceRegularity
                + 0.28 * amountStability
                + aliasBonus
        )
    }

    static func roundedConfidence(_ value: Double) -> Double {
        (value * 1000).rounded() / 1000
    }
}
