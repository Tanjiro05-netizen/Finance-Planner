import Foundation

/// A detected recurring income stream — payroll, pension, regular transfers in. The
/// direction-agnostic sibling of `SubscriptionCandidate`, trimmed to the fields income
/// actually needs (no monogram tile, cancel status, trial/unused flags).
struct RecurringIncomeCandidate: Identifiable, Equatable {
    let id: String
    let sourceName: String
    let merchantKey: MerchantKey
    let amount: Money
    let cadence: Cadence
    let nextExpected: Date
    let confidence: Double
    let firstSeen: Date
    let lastReceived: Date
}

/// Detects recurring income from credit-side transactions using the same `CadenceMath`
/// the subscription detector uses for debits. The only differences from `DetectionEngine`:
/// it considers `.biweekly` cadence (common for payroll) and skips trial/price-change
/// heuristics, which have no meaning for income.
struct IncomeDetectionEngine {
    var confidenceThreshold = 0.60
    var normalizer = MerchantNormalizer()

    func detect(transactions: [Txn], referenceDate: Date) -> [RecurringIncomeCandidate] {
        let normalized = transactions
            .filter { !$0.pending && $0.amount.amountMinor >= 0 }
            .map { transaction in
                NormalizedIncomeTransaction(
                    transaction: transaction,
                    merchant: normalizer.normalize(transaction.merchantRaw)
                )
            }

        let grouped = Dictionary(grouping: normalized) { $0.merchant.merchantKey }

        return grouped.values
            .compactMap { analyze(group: $0, referenceDate: referenceDate) }
            .filter { $0.confidence >= confidenceThreshold }
            .sorted { lhs, rhs in
                if lhs.confidence == rhs.confidence {
                    return lhs.sourceName.localizedStandardCompare(rhs.sourceName) == .orderedAscending
                }
                return lhs.confidence > rhs.confidence
            }
    }

    private func analyze(
        group: [NormalizedIncomeTransaction],
        referenceDate: Date
    ) -> RecurringIncomeCandidate? {
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
        guard let cadenceMatch = CadenceMath.inferCadence(
            from: intervals,
            occurrenceCount: sorted.count,
            candidates: CadenceMath.incomeCadences
        ) else {
            return nil
        }

        let positiveAmounts = sorted.map(\.transaction.amount).filter { $0.amountMinor > 0 }
        guard let currentAmount = CadenceMath.currentRecurringAmount(from: positiveAmounts) else {
            return nil
        }

        let amountStability = CadenceMath.amountStabilityScore(
            amounts: positiveAmounts,
            currentAmount: currentAmount,
            hasPriceChange: false
        )
        let confidence = CadenceMath.confidence(
            occurrenceScore: CadenceMath.occurrenceScore(count: sorted.count),
            cadenceRegularity: cadenceMatch.regularity,
            amountStability: amountStability,
            aliasBonus: first.merchant.isKnownAlias ? 0.10 : 0
        )
        let nextExpected = CadenceMath.nextOccurrenceDate(
            after: last.transaction.date,
            cadence: cadenceMatch.cadence,
            referenceDate: referenceDate
        )

        return RecurringIncomeCandidate(
            id: "income-\(first.merchant.merchantKey.rawValue)",
            sourceName: bestDisplayName(from: sorted),
            merchantKey: first.merchant.merchantKey,
            amount: currentAmount,
            cadence: cadenceMatch.cadence,
            nextExpected: nextExpected,
            confidence: CadenceMath.roundedConfidence(confidence),
            firstSeen: first.transaction.date,
            lastReceived: last.transaction.date
        )
    }

    private func bestDisplayName(from transactions: [NormalizedIncomeTransaction]) -> String {
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
            .key ?? "Income"
    }
}

private struct NormalizedIncomeTransaction {
    let transaction: Txn
    let merchant: NormalizedMerchant
}
