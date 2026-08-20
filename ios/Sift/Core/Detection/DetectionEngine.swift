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

        let intervals = CadenceMath.intervals(forSortedDates: sorted.map(\.transaction.date))

        guard let cadenceMatch = CadenceMath.inferCadence(from: intervals, occurrenceCount: sorted.count) else {
            return nil
        }

        let positiveAmounts = sorted
            .map(\.transaction.amount)
            .filter { $0.amountMinor > 0 }

        guard let currentAmount = CadenceMath.currentRecurringAmount(from: positiveAmounts) else {
            return nil
        }

        let priceChanges = detectPriceChanges(
            in: sorted,
            merchant: first.merchant,
            currency: currentAmount.currency
        )
        let amountStability = CadenceMath.amountStabilityScore(
            amounts: positiveAmounts,
            currentAmount: currentAmount,
            hasPriceChange: !priceChanges.isEmpty
        )
        let confidence = CadenceMath.confidence(
            occurrenceScore: CadenceMath.occurrenceScore(count: sorted.count),
            cadenceRegularity: cadenceMatch.regularity,
            amountStability: amountStability,
            aliasBonus: first.merchant.isKnownAlias ? 0.10 : 0
        )
        let nextRenewal = CadenceMath.nextOccurrenceDate(
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
            confidence: CadenceMath.roundedConfidence(confidence),
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

    private func detectPriceChanges(
        in transactions: [NormalizedTransaction],
        merchant: NormalizedMerchant,
        currency: String
    ) -> [DetectedPriceChange] {
        let observations = transactions
            .filter { $0.transaction.amount.currency == currency && $0.transaction.amount.amountMinor > 0 }
            .map { AmountObservation(date: $0.transaction.date, amount: $0.transaction.amount) }
        let segments = CadenceMath.amountSegments(from: observations)

        guard segments.count >= 2 else {
            return []
        }

        return zip(segments, segments.dropFirst()).compactMap { previous, next in
            guard previous.observations.count >= 2, next.observations.count >= 2 else {
                return nil
            }

            let oldAmount = CadenceMath.medianAmount(previous.observations.map(\.amount))
            let newAmount = CadenceMath.medianAmount(next.observations.map(\.amount))
            guard
                oldAmount.currency == newAmount.currency,
                abs(oldAmount.amountMinor - newAmount.amountMinor) > CadenceMath.amountTolerance(for: oldAmount)
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
                && abs(amount.amountMinor - standardAmount.amountMinor) <= CadenceMath.amountTolerance(for: standardAmount)
        })

        return first.amountMinor <= trialCeiling && laterStandardChargeCount >= 2
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
        // Neutrals only. A merchant monogram is decoration, and `negative`/`positive`/`accent`
        // carry meaning elsewhere -- a tile tinted "overspent red" because of a checksum is
        // exactly the overload this palette was rebuilt to remove.
        let options: [ColorToken] = [.ink, .inkSoft, .inkFaint]
        let checksum = merchantKey.rawValue.unicodeScalars.reduce(0) { partial, scalar in
            partial + Int(scalar.value)
        }
        return options[checksum % options.count]
    }
}

private struct NormalizedTransaction {
    let transaction: Txn
    let merchant: NormalizedMerchant
}

private struct MerchantAnalysis {
    let candidate: SubscriptionCandidate
    let priceChanges: [DetectedPriceChange]
}
