import Foundation

/// Why narration isn't available right now.
///
/// Mirrors `SystemLanguageModel.Availability.UnavailableReason` without importing
/// FoundationModels, so `Core/` stays framework-free and testable. `.notSupported` covers
/// the cases that enum has no word for: the framework missing at compile time, or an OS
/// below the floor.
enum InsightUnavailableReason: String, Equatable, Sendable {
    case appleIntelligenceNotEnabled
    case deviceNotEligible
    case modelNotReady
    case notSupported

    /// Plain, actionable, and free of framework vocabulary — this is shown to a person.
    var message: String {
        switch self {
        case .appleIntelligenceNotEnabled:
            "Turn on Apple Intelligence in Settings to see written insights."
        case .deviceNotEligible:
            "This iPhone can't run Sift's on-device insights."
        case .modelNotReady:
            "Apple Intelligence is still getting ready. Check back shortly."
        case .notSupported:
            "Written insights aren't available on this device."
        }
    }
}

enum InsightAvailability: Equatable, Sendable {
    case available
    case unavailable(InsightUnavailableReason)

    var isAvailable: Bool {
        self == .available
    }

    var unavailableMessage: String? {
        switch self {
        case .available:
            nil
        case let .unavailable(reason):
            reason.message
        }
    }
}

/// Why narration failed after it was attempted.
///
/// Every case maps from a `LanguageModelError` case in the live adapter. Raw framework
/// error text is never surfaced — it names internals and reads as a crash report.
enum InsightNarrationFailure: String, Equatable, Sendable, Error {
    case tooMuchContext
    case rateLimited
    case refused
    case timedOut
    case unsupportedLanguage
    case unknown

    var message: String {
        switch self {
        case .tooMuchContext:
            "There was too much to summarise at once."
        case .rateLimited:
            "Insights are catching up. Try again in a moment."
        case .refused, .unknown:
            "Sift couldn't write up your insights this time."
        case .timedOut:
            "Writing your insights took too long."
        case .unsupportedLanguage:
            "Written insights aren't available in this language yet."
        }
    }
}

/// One written observation. The UI renders these fields directly and never parses prose.
struct InsightNote: Identifiable, Equatable, Sendable {
    let id: String
    let headline: String
    let detail: String
}

/// Turns already-computed figures into short written observations.
///
/// The live implementation runs Apple's on-device model; tests and previews use
/// `MockInsightNarrator`. Deliberately not `@MainActor` — generation is slow and belongs
/// off the main thread.
protocol InsightNarrating: Sendable {
    /// Cheap and synchronous, so a view can gate on it without awaiting a model load.
    func availability() -> InsightAvailability
    func narrate(facts: InsightFacts) async throws -> [InsightNote]
}

/// Deterministic stand-in. Echoes the facts it was handed rather than inventing text, so
/// tests assert on plumbing without depending on model output.
struct MockInsightNarrator: InsightNarrating {
    var availabilityResult: InsightAvailability = .available
    var failure: InsightNarrationFailure?
    /// Records what the last call was asked to narrate, for tests that check redaction.
    final class Recorder: @unchecked Sendable {
        private(set) var lastFacts: InsightFacts?

        func record(_ facts: InsightFacts) {
            lastFacts = facts
        }
    }

    var recorder = Recorder()

    func availability() -> InsightAvailability {
        availabilityResult
    }

    func narrate(facts: InsightFacts) async throws -> [InsightNote] {
        recorder.record(facts)

        if let failure {
            throw failure
        }

        return facts.lines.enumerated().map { index, line in
            InsightNote(id: "mock-\(index)", headline: line.label, detail: line.value)
        }
    }
}
