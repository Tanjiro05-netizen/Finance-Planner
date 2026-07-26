import Foundation
import SwiftData

protocol IncomeDetectionServing: Sendable {
    func detect() async throws -> [DetectedRecurringIncome]
    func recompute(referenceDate: Date) async throws -> IncomeDetectionResult
}

extension IncomeDetectionServing {
    func recompute() async throws -> IncomeDetectionResult {
        try await recompute(referenceDate: Date())
    }
}

struct IncomeDetectionResult: Equatable {
    var candidates: [RecurringIncomeCandidate]

    static let empty = IncomeDetectionResult(candidates: [])
}

/// View/API-facing recurring-income value; the income analogue of `DetectedSubscription`.
struct DetectedRecurringIncome: Identifiable, Equatable {
    let id: String
    let sourceName: String
    let merchantKey: MerchantKey
    let amount: Money
    let cadence: Cadence
    let nextExpected: Date?
    let status: RecurringIncomeStatus
    let confidence: Double
    let firstSeen: Date
    let lastReceived: Date

    init(income: RecurringIncome) {
        id = income.id
        sourceName = income.sourceName
        merchantKey = income.merchantKey
        amount = income.amount
        cadence = income.cadence
        nextExpected = income.nextExpected
        status = income.status
        confidence = income.detectionConfidence
        firstSeen = income.firstSeen
        lastReceived = income.lastReceived
    }

    init(candidate: RecurringIncomeCandidate) {
        id = candidate.id
        sourceName = candidate.sourceName
        merchantKey = candidate.merchantKey
        amount = candidate.amount
        cadence = candidate.cadence
        nextExpected = candidate.nextExpected
        status = .active
        confidence = candidate.confidence
        firstSeen = candidate.firstSeen
        lastReceived = candidate.lastReceived
    }

    var candidate: RecurringIncomeCandidate {
        RecurringIncomeCandidate(
            id: id,
            sourceName: sourceName,
            merchantKey: merchantKey,
            amount: amount,
            cadence: cadence,
            nextExpected: nextExpected ?? cadence.dateAfter(lastReceived),
            confidence: confidence,
            firstSeen: firstSeen,
            lastReceived: lastReceived
        )
    }
}

final class LiveIncomeDetectionService: IncomeDetectionServing, @unchecked Sendable {
    private let actor: DetectionPersistenceActor
    private let referenceDateProvider: @Sendable () -> Date

    init(
        modelContainer: ModelContainer,
        referenceDateProvider: @escaping @Sendable () -> Date = { Date() }
    ) {
        actor = DetectionPersistenceActor(modelContainer: modelContainer)
        self.referenceDateProvider = referenceDateProvider
    }

    func detect() async throws -> [DetectedRecurringIncome] {
        let candidates = try await actor.detectIncome(referenceDate: referenceDateProvider())
        return candidates.map(DetectedRecurringIncome.init(candidate:))
    }

    func recompute(referenceDate: Date) async throws -> IncomeDetectionResult {
        let candidates = try await actor.recomputeIncome(referenceDate: referenceDate)
        return IncomeDetectionResult(candidates: candidates)
    }
}

struct MockIncomeDetectionService: IncomeDetectionServing {
    let detections: [DetectedRecurringIncome]

    init(
        detections: [DetectedRecurringIncome] = SeedData.snapshot().recurringIncome
            .filter { $0.status == .active }
            .map(DetectedRecurringIncome.init(income:))
    ) {
        self.detections = detections
    }

    func detect() async throws -> [DetectedRecurringIncome] {
        detections
    }

    func recompute(referenceDate _: Date) async throws -> IncomeDetectionResult {
        IncomeDetectionResult(candidates: detections.map(\.candidate))
    }
}
