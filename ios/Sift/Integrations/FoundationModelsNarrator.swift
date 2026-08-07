import Foundation

#if canImport(FoundationModels)
    import FoundationModels

    /// Live `InsightNarrating` backed by Apple's on-device Foundation Models.
    ///
    /// Lives here rather than in `Core/` for the same reason `LocalAuthenticationGate` does:
    /// it can't run under unit tests. Foundation Models is only available in the Simulator
    /// when the host Mac itself has Apple Intelligence enabled, which CI runners do not, so
    /// every path below is unreachable on CI and would sit at zero coverage inside `Core/`.
    ///
    /// **On-device only.** This deliberately uses `SystemLanguageModel.default` and never
    /// `PrivateCloudComputeLanguageModel`, which would send the person's financial figures to
    /// Apple's servers. The project rule is that financial data never leaves the phone.
    @available(iOS 26.0, *)
    struct FoundationModelsNarrator: InsightNarrating {
        /// Low temperature: this is reporting, not creative writing. The same figures should
        /// produce broadly the same sentences run to run.
        private let options = GenerationOptions(temperature: 0.3)

        func availability() -> InsightAvailability {
            switch SystemLanguageModel.default.availability {
            case .available:
                .available
            case let .unavailable(reason):
                .unavailable(Self.map(reason))
            @unknown default:
                // A reason Apple adds later is still an unavailable state, not a crash.
                .unavailable(.notSupported)
            }
        }

        func narrate(facts: InsightFacts) async throws -> [InsightNote] {
            guard !facts.isEmpty else {
                return []
            }

            // Both `instructions:` and `to:` take plain strings — the builder-based
            // `Instructions { }` / `Prompt { }` forms exist for composing pieces, which
            // isn't needed here since the prompt is already one assembled block.
            let session = LanguageModelSession(instructions: InsightPromptBuilder.instructions)

            do {
                let response = try await session.respond(
                    to: InsightPromptBuilder.promptText(for: facts),
                    generating: GeneratedInsights.self,
                    options: options
                )

                return response.content.notes.enumerated().map { index, note in
                    InsightNote(
                        id: "insight-\(index)",
                        headline: note.headline,
                        detail: note.detail
                    )
                }
            } catch let error as LanguageModelSession.GenerationError {
                throw Self.map(error)
            } catch {
                throw InsightNarrationFailure.unknown
            }
        }

        private static func map(_ reason: SystemLanguageModel.Availability.UnavailableReason) -> InsightUnavailableReason {
            switch reason {
            case .appleIntelligenceNotEnabled:
                .appleIntelligenceNotEnabled
            case .deviceNotEligible:
                .deviceNotEligible
            case .modelNotReady:
                .modelNotReady
            @unknown default:
                .notSupported
            }
        }

        /// Only the cases a person could act on differently are named; `default` absorbs the
        /// rest, which also keeps this compiling as Apple adds cases. Apple's published
        /// documentation currently describes a newer `LanguageModelError` that this SDK does
        /// not have — `GenerationError` is the type that actually exists here.
        private static func map(_ error: LanguageModelSession.GenerationError) -> InsightNarrationFailure {
            switch error {
            case .exceededContextWindowSize:
                .tooMuchContext
            case .rateLimited, .concurrentRequests:
                .rateLimited
            case .refusal, .guardrailViolation:
                .refused
            case .assetsUnavailable:
                .modelUnavailable
            case .unsupportedLanguageOrLocale:
                .unsupportedLanguage
            default:
                .unknown
            }
        }
    }

    /// The shape the model must fill in, so the UI renders typed fields instead of parsing
    /// prose. Every number inside these strings is copied from the supplied figures — the
    /// instructions forbid the model from calculating one.
    @available(iOS 26.0, *)
    @Generable(description: "A short set of observations about someone's personal finances.")
    struct GeneratedInsights {
        @Guide(description: "Between one and three observations, most important first.")
        var notes: [GeneratedInsightNote]
    }

    @available(iOS 26.0, *)
    @Generable(description: "One observation about the person's finances.")
    struct GeneratedInsightNote {
        @Guide(description: "A short title of at most six words. No trailing punctuation.")
        var headline: String

        @Guide(description: "One or two calm sentences. Any figure must be copied exactly from the supplied numbers.")
        var detail: String
    }

#else

    /// Fallback used only where FoundationModels is unavailable at compile time so the app
    /// still builds; it reports that written insights aren't supported.
    struct FoundationModelsNarrator: InsightNarrating {
        func availability() -> InsightAvailability {
            .unavailable(.notSupported)
        }

        func narrate(facts _: InsightFacts) async throws -> [InsightNote] {
            []
        }
    }

#endif
