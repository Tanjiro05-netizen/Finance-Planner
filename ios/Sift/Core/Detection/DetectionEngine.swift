import Foundation

struct DetectionEngine {
    var confidenceThreshold = 0.60
    var normalizer = MerchantNormalizer()

    func detect(transactions: [Txn], referenceDate: Date) -> DetectionResult {
        let normalizedTransactions = transactions
            .filter { !$0.pending && $0.amount.amountMinor >= 0 }
            .map { transaction in
                NormalizedTransaction(
                    transaction: transaction,
                    merchant: normalizer.normalize(transaction.merchantRaw)
                )
            }

        let grouped = Dictionary(grouping: normalizedTransactions) { normalized in
            normalized.merchant.merchantKey
        }

        let analyses = grouped.values.compactMap { group in
            analyze(group: group, referenceDate: referenceDate)
        }

        let candidates = analyses
            .filter { $0.candidate.confidence >= confidenceThreshold }
            .map(\.candidate)
            .sorted { lhs, rhs in
                if lhs.confidence == rhs.confidence {
                    return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
                }
                return lhs.confidence > rhs.confidence
            }

        let candidateKeys = Set(candidates.map(\.merchantKey))
        let priceChanges = analyses
            .filter { candidateKeys.contains($0.candidate.merchantKey) }
            .flatMap(\.priceChanges)
            .sorted { lhs, rhs in
                if lhs.changedAt == rhs.changedAt {
                    return lhs.merchantName.localizedStandardCompare(rhs.merchantName) == .orderedAscending
                }
                return lhs.changedAt > rhs.changedAt
            }

        let flags = candidates.flatMap { candidate -> [DetectionFlag] in
            var flags: [DetectionFlag] = []
            if candidate.isTrialEnding {
                flags.append(DetectionFlag(merchantKey: candidate.merchantKey, kind: .trialEnding))
            }
            if candidate.isUnused {
                flags.append(DetectionFlag(merchantKey: candidate.merchantKey, kind: .unused))
            }
            return flags
        }

        return DetectionResult(candidates: candidates, priceChanges: priceChanges, flags: flags)
    }

    private func analyze(group: [NormalizedTransaction], referenceDate: Date) -> MerchantAnalysis? {
        let sorted = group.sorted { lhs, rhs in
            if lhs.transaction.date == rhs.transaction.date {
                return lhs.transaction.id < rhs.transaction.id
            }
            return lhs.transaction.date < rhs.transaction.date
        }

        guard let first = sorted.first, let last = sorted.last else {
            return nil
        }

        let intervals = zip(sorted, sorted.dropFirst()).compactMap { previous, next in
            Calendar.utc.dateComponents([.day], from: previous.transaction.date, to: next.transaction.date).day
        }

        guard let cadenceMatch = inferCadence(from: intervals, occurrenceCount: sorted.count) else {
            return nil
        }

        let positiveAmounts = sorted
            .map(\.transaction.amount)
            .filter { $0.amountMinor > 0 }

        guard let currentAmount = currentRecurringAmount(from: positiveAmounts) else {
            return nil
        }

        let priceChanges = detectPriceChanges(
            in: sorted,
            merchant: first.merchant,
            currency: currentAmount.currency
        )
        let amountStability = amountStabilityScore(
            amounts: positiveAmounts,
            currentAmount: currentAmount,
            hasPriceChange: !priceChanges.isEmpty
        )
        let occurrenceScore = min(Double(sorted.count) / 6.0, 1.0)
        let confidence = min(
            1.0,
            0.28 * occurrenceScore
                + 0.34 * cadenceMatch.regularity
                + 0.28 * amountStability
                + (first.merchant.isKnownAlias ? 0.10 : 0)
        )
        let nextRenewal = nextRenewalDate(
            after: last.transaction.date,
            cadence: cadenceMatch.cadence,
            referenceDate: referenceDate
        )
        let isTrialEnding = detectsTrialPattern(in: sorted, standardAmount: currentAmount)
        let merchantName = bestDisplayName(from: sorted)

        let candidate = SubscriptionCandidate(
            id: stableSubscriptionID(for: first.merchant.merchantKey),
            name: merchantName,
            merchantKey: first.merchant.merchantKey,
            monogramLetter: monogramLetter(for: merchantName),
            tileColorToken: colorToken(for: first.merchant.merchantKey),
            amount: currentAmount,
            cadence: cadenceMatch.cadence,
            nextRenewal: nextRenewal,
            confidence: roundedConfidence(confidence),
            firstSeen: first.transaction.date,
            lastCharge: last.transaction.date,
            lastUsed: nil,
            categoryID: nil,
            status: .active,
            isTrialEnding: isTrialEnding,
            isUnused: false
        )

        return MerchantAnalysis(candidate: candidate, priceChanges: priceChanges)
    }

    private func inferCadence(from intervals: [Int], occurrenceCount: Int) -> CadenceMatch? {
        guard !intervals.isEmpty else {
            return nil
        }

        let candidates: [Cadence] = [.weekly, .monthly, .quarterly, .yearly]
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

    private func currentRecurringAmount(from amounts: [Money]) -> Money? {
        guard !amounts.isEmpty else {
            return nil
        }

        let segments = amountSegments(from: amounts.map { AmountObservation(date: .distantPast, amount: $0) })
        if let last = segments.last, last.observations.count >= 2 {
            return medianAmount(last.observations.map(\.amount))
        }

        return medianAmount(amounts)
    }

    private func amountStabilityScore(
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

    private func detectPriceChanges(
        in transactions: [NormalizedTransaction],
        merchant: NormalizedMerchant,
        currency: String
    ) -> [DetectedPriceChange] {
        let observations = transactions
            .filter { $0.transaction.amount.currency == currency && $0.transaction.amount.amountMinor > 0 }
            .map { AmountObservation(date: $0.transaction.date, amount: $0.transaction.amount) }
        let segments = amountSegments(from: observations)

        guard segments.count >= 2 else {
            return []
        }

        return zip(segments, segments.dropFirst()).compactMap { previous, next in
            guard previous.observations.count >= 2, next.observations.count >= 2 else {
                return nil
            }

            let oldAmount = medianAmount(previous.observations.map(\.amount))
            let newAmount = medianAmount(next.observations.map(\.amount))
            guard
                oldAmount.currency == newAmount.currency,
                abs(oldAmount.amountMinor - newAmount.amountMinor) > amountTolerance(for: oldAmount)
            else {
                return nil
            }

            return DetectedPriceChange(
                merchantKey: merchant.merchantKey,
                merchantName: merchant.displayName,
                oldAmount: oldAmount,
                newAmount: newAmount,
                changedAt: next.observations[0].date
            )
        }
    }

    private func amountSegments(from observations: [AmountObservation]) -> [AmountSegment] {
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

    private func detectsTrialPattern(
        in transactions: [NormalizedTransaction],
        standardAmount: Money
    ) -> Bool {
        guard
            let first = transactions.first?.transaction.amount,
            standardAmount.amountMinor > 0
        else {
            return false
        }

        let trialCeiling = max(100, standardAmount.amountMinor / 5)
        let laterStandardChargeCount = transactions.dropFirst().count(where: { transaction in
            let amount = transaction.transaction.amount
            return amount.currency == standardAmount.currency
                && abs(amount.amountMinor - standardAmount.amountMinor) <= amountTolerance(for: standardAmount)
        })

        return first.amountMinor <= trialCeiling && laterStandardChargeCount >= 2
    }

    private func nextRenewalDate(after lastCharge: Date, cadence: Cadence, referenceDate: Date) -> Date {
        var next = cadence.dateAfter(lastCharge)
        while next <= referenceDate {
            let advanced = cadence.dateAfter(next)
            guard advanced > next else {
                return next
            }
            next = advanced
        }
        return next
    }

    private func medianAmount(_ amounts: [Money]) -> Money {
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

    private func amountTolerance(for amount: Money) -> Int {
        max(100, Int((Double(amount.amountMinor) * 0.05).rounded()))
    }

    private func bestDisplayName(from transactions: [NormalizedTransaction]) -> String {
        let names = transactions.map(\.merchant.displayName)
        let grouped = Dictionary(grouping: names, by: { $0 })
        return grouped
            .sorted { lhs, rhs in
                if lhs.value.count == rhs.value.count {
                    return lhs.key.localizedStandardCompare(rhs.key) == .orderedAscending
                }
                return lhs.value.count > rhs.value.count
            }
            .first?
            .key ?? "Unknown Merchant"
    }

    private func stableSubscriptionID(for merchantKey: MerchantKey) -> String {
        "sub-\(merchantKey.rawValue)"
    }

    private func monogramLetter(for name: String) -> String {
        String(name.trimmingCharacters(in: .whitespacesAndNewlines).first ?? "S").uppercased()
    }

    private func colorToken(for merchantKey: MerchantKey) -> ColorToken {
        let options: [ColorToken] = [.ink, .inkSoft, .inkFaint, .gold, .goldDeep, .clay]
        let checksum = merchantKey.rawValue.unicodeScalars.reduce(0) { partial, scalar in
            partial + Int(scalar.value)
        }
        return options[checksum % options.count]
    }

    private func roundedConfidence(_ value: Double) -> Double {
        (value * 1000).rounded() / 1000
    }
}

private struct NormalizedTransaction {
    let transaction: Txn
    let merchant: NormalizedMerchant
}

private struct CadenceMatch {
    let cadence: Cadence
    let regularity: Double
}

private struct AmountObservation {
    let date: Date
    let amount: Money
}

private struct AmountSegment {
    var observations: [AmountObservation]
}

private struct MerchantAnalysis {
    let candidate: SubscriptionCandidate
    let priceChanges: [DetectedPriceChange]
}
