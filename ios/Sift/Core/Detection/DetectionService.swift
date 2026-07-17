import Foundation
import SwiftData

protocol DetectionServing: Sendable {
    func detect() async throws -> [DetectedSubscription]
    func recompute(referenceDate: Date) async throws -> DetectionResult
}

extension DetectionServing {
    func recompute() async throws -> DetectionResult {
        try await recompute(referenceDate: Date())
    }
}

struct DetectedSubscription: Identifiable, Equatable {
    let id: String
    let name: String
    let merchantKey: MerchantKey
    let monogramLetter: String
    let tileColorToken: ColorToken
    let amount: Money
    let cadence: Cadence
    let nextRenewal: Date?
    let lastUsed: Date?
    let categoryID: String?
    let status: SubscriptionStatus
    let confidence: Double
    let firstSeen: Date
    let lastCharge: Date
    let isTrialEnding: Bool
    let isUnused: Bool

    init(subscription: Subscription) {
        id = subscription.id
        name = subscription.name
        merchantKey = subscription.merchantKey
        monogramLetter = subscription.monogramLetter
        tileColorToken = subscription.tileColorToken
        amount = subscription.amount
        cadence = subscription.cadence
        nextRenewal = subscription.nextRenewal
        lastUsed = subscription.lastUsed
        categoryID = subscription.categoryID
        status = subscription.status
        confidence = subscription.detectionConfidence
        firstSeen = subscription.firstSeen
        lastCharge = subscription.lastCharge
        isTrialEnding = subscription.isTrialEnding
        isUnused = subscription.status == .unused
    }

    init(candidate: SubscriptionCandidate) {
        id = candidate.id
        name = candidate.name
        merchantKey = candidate.merchantKey
        monogramLetter = candidate.monogramLetter
        tileColorToken = candidate.tileColorToken
        amount = candidate.amount
        cadence = candidate.cadence
        nextRenewal = candidate.nextRenewal
        lastUsed = candidate.lastUsed
        categoryID = candidate.categoryID
        status = candidate.status
        confidence = candidate.confidence
        firstSeen = candidate.firstSeen
        lastCharge = candidate.lastCharge
        isTrialEnding = candidate.isTrialEnding
        isUnused = candidate.isUnused
    }

    func makeSubscription(userID: String) -> Subscription {
        Subscription(
            id: id,
            userID: userID,
            name: name,
            merchantKey: merchantKey,
            monogramLetter: monogramLetter,
            tileColorToken: tileColorToken,
            amount: amount,
            cadence: cadence,
            nextRenewal: nextRenewal,
            lastUsed: lastUsed,
            categoryID: categoryID,
            isTrialEnding: isTrialEnding,
            status: status,
            detectionConfidence: confidence,
            firstSeen: firstSeen,
            lastCharge: lastCharge
        )
    }

    var candidate: SubscriptionCandidate {
        SubscriptionCandidate(
            id: id,
            name: name,
            merchantKey: merchantKey,
            monogramLetter: monogramLetter,
            tileColorToken: tileColorToken,
            amount: amount,
            cadence: cadence,
            nextRenewal: nextRenewal ?? cadence.dateAfter(lastCharge),
            confidence: confidence,
            firstSeen: firstSeen,
            lastCharge: lastCharge,
            lastUsed: lastUsed,
            categoryID: categoryID,
            status: status,
            isTrialEnding: isTrialEnding,
            isUnused: isUnused
        )
    }
}

final class LiveDetectionService: DetectionServing, @unchecked Sendable {
    private let actor: DetectionPersistenceActor
    private let referenceDateProvider: @Sendable () -> Date

    init(
        modelContainer: ModelContainer,
        referenceDateProvider: @escaping @Sendable () -> Date = { Date() }
    ) {
        actor = DetectionPersistenceActor(modelContainer: modelContainer)
        self.referenceDateProvider = referenceDateProvider
    }

    func detect() async throws -> [DetectedSubscription] {
        let result = try await actor.detect(referenceDate: referenceDateProvider())
        return result.candidates.map(DetectedSubscription.init(candidate:))
    }

    func recompute(referenceDate: Date) async throws -> DetectionResult {
        try await actor.recompute(referenceDate: referenceDate)
    }
}

struct MockDetectionService: DetectionServing {
    let detections: [DetectedSubscription]

    init(
        detections: [DetectedSubscription] = SeedData.snapshot().subscriptions
            .filter { $0.status != .cancelled }
            .map(DetectedSubscription.init(subscription:))
    ) {
        self.detections = detections
    }

    func detect() async throws -> [DetectedSubscription] {
        detections
    }

    func recompute(referenceDate _: Date) async throws -> DetectionResult {
        let candidates = detections.map(\.candidate)
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

        return DetectionResult(candidates: candidates, priceChanges: [], flags: flags)
    }
}

actor DetectionPersistenceActor: ModelActor {
    nonisolated let modelContainer: ModelContainer
    nonisolated let modelExecutor: any ModelExecutor

    private let engine = DetectionEngine()

    init(modelContainer: ModelContainer) {
        let modelContext = ModelContext(modelContainer)
        self.modelContainer = modelContainer
        modelExecutor = DefaultSerialModelExecutor(modelContext: modelContext)
    }

    func detect(referenceDate: Date, userID: String = SeedData.defaultUserID) throws -> DetectionResult {
        let transactions = try transactionInputs(userID: userID)
        return engine.detect(transactions: transactions, referenceDate: referenceDate)
    }

    func recompute(referenceDate: Date, userID: String = SeedData.defaultUserID) throws -> DetectionResult {
        let result = try detect(referenceDate: referenceDate, userID: userID)
        try reconcile(result: result, userID: userID, referenceDate: referenceDate)
        try modelContext.save()
        return result
    }

    private func transactionInputs(userID: String) throws -> [Txn] {
        try modelContext.fetch(FetchDescriptor<Transaction>())
            .filter { $0.userID == userID && $0.direction == .debit }
            .map { transaction in
                Txn(
                    id: transaction.id,
                    merchantRaw: transaction.merchantRaw,
                    amount: transaction.amount,
                    date: transaction.date,
                    pending: transaction.pending,
                    categoryHint: transaction.categoryHint
                )
            }
    }

    private func reconcile(
        result: DetectionResult,
        userID: String,
        referenceDate: Date
    ) throws {
        var subscriptionsByMerchant = try Dictionary(
            uniqueKeysWithValues: userSubscriptions(userID: userID).map { ($0.merchantKey, $0) }
        )
        let existingPriceChanges = try userPriceChanges(userID: userID)

        for candidate in result.candidates {
            let subscription = subscriptionsByMerchant[candidate.merchantKey]
                ?? makeSubscription(from: candidate, userID: userID)

            apply(candidate: candidate, to: subscription)

            if subscription.modelContext == nil {
                modelContext.insert(subscription)
            }

            subscriptionsByMerchant[candidate.merchantKey] = subscription
        }

        markStoppedSubscriptions(
            subscriptionsByMerchant: subscriptionsByMerchant,
            candidates: result.candidates,
            referenceDate: referenceDate
        )

        for priceChange in result.priceChanges {
            guard let subscription = subscriptionsByMerchant[priceChange.merchantKey] else {
                continue
            }

            if !hasPriceChange(priceChange, for: subscription, in: existingPriceChanges) {
                modelContext.insert(makePersistentPriceChange(
                    priceChange,
                    subscription: subscription,
                    userID: userID
                ))
            }
        }
    }

    private func userSubscriptions(userID: String) throws -> [Subscription] {
        try modelContext.fetch(FetchDescriptor<Subscription>())
            .filter { $0.userID == userID }
    }

    private func userPriceChanges(userID: String) throws -> [PriceChange] {
        try modelContext.fetch(FetchDescriptor<PriceChange>())
            .filter { $0.userID == userID }
    }

    private func makeSubscription(from candidate: SubscriptionCandidate, userID: String) -> Subscription {
        Subscription(
            id: candidate.id,
            userID: userID,
            name: candidate.name,
            merchantKey: candidate.merchantKey,
            monogramLetter: candidate.monogramLetter,
            tileColorToken: candidate.tileColorToken,
            amount: candidate.amount,
            cadence: candidate.cadence,
            nextRenewal: candidate.nextRenewal,
            lastUsed: candidate.lastUsed,
            categoryID: candidate.categoryID,
            isTrialEnding: candidate.isTrialEnding,
            status: candidate.status,
            detectionConfidence: candidate.confidence,
            firstSeen: candidate.firstSeen,
            lastCharge: candidate.lastCharge
        )
    }

    private func apply(candidate: SubscriptionCandidate, to subscription: Subscription) {
        subscription.name = candidate.name
        subscription.monogramLetter = candidate.monogramLetter
        subscription.tileColorToken = candidate.tileColorToken
        subscription.amount = candidate.amount
        subscription.cadence = candidate.cadence
        subscription.nextRenewal = candidate.nextRenewal
        subscription.detectionConfidence = candidate.confidence
        subscription.firstSeen = min(subscription.firstSeen, candidate.firstSeen)
        subscription.lastCharge = candidate.lastCharge
        subscription.isTrialEnding = candidate.isTrialEnding
        subscription.status = candidate.isUnused ? .unused : .active
    }

    private func markStoppedSubscriptions(
        subscriptionsByMerchant: [MerchantKey: Subscription],
        candidates: [SubscriptionCandidate],
        referenceDate: Date
    ) {
        let candidatesByMerchant = Dictionary(uniqueKeysWithValues: candidates.map { ($0.merchantKey, $0) })

        for subscription in subscriptionsByMerchant.values where subscription.status != .cancelled {
            let lastCharge = candidatesByMerchant[subscription.merchantKey]?.lastCharge ?? subscription.lastCharge
            let cadence = candidatesByMerchant[subscription.merchantKey]?.cadence ?? subscription.cadence

            if isStopped(lastCharge: lastCharge, cadence: cadence, referenceDate: referenceDate) {
                subscription.status = .cancelled
                subscription.nextRenewal = nil
            }
        }
    }

    private func isStopped(lastCharge: Date, cadence: Cadence, referenceDate: Date) -> Bool {
        guard cadence != .unknown else {
            return false
        }

        let expectedCharge = cadence.dateAfter(lastCharge)
        let deadline = Calendar.utc.date(
            byAdding: .day,
            value: cadence.missedChargeGraceDays,
            to: expectedCharge
        ) ?? expectedCharge

        return deadline < referenceDate
    }

    private func hasPriceChange(
        _ priceChange: DetectedPriceChange,
        for subscription: Subscription,
        in existing: [PriceChange]
    ) -> Bool {
        existing.contains { persisted in
            persisted.subscriptionID == subscription.id
                && persisted.changedAt == priceChange.changedAt
                && persisted.oldAmount == priceChange.oldAmount
                && persisted.newAmount == priceChange.newAmount
        }
    }

    private func makePersistentPriceChange(
        _ priceChange: DetectedPriceChange,
        subscription: Subscription,
        userID: String
    ) -> PriceChange {
        PriceChange(
            id: "price-\(subscription.id)-\(Int(priceChange.changedAt.timeIntervalSince1970))-\(priceChange.newAmount.amountMinor)",
            userID: userID,
            subscriptionID: subscription.id,
            oldAmount: priceChange.oldAmount,
            newAmount: priceChange.newAmount,
            changedAt: priceChange.changedAt
        )
    }
}
