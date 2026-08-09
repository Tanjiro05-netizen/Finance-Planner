import Foundation

#if canImport(FoundationModels)
    import FoundationModels

    /// Live `InsightConversing` backed by Apple's on-device model.
    ///
    /// Same placement rationale as `FoundationModelsNarrator`: it can't run under unit tests,
    /// so it lives outside `Core/` where it isn't charged against the coverage gate.
    ///
    /// **On-device only.** `SystemLanguageModel.default`, never
    /// `PrivateCloudComputeLanguageModel`. Questions that need the person's figures are
    /// answered here or not at all — see `ChatRouter`.
    @available(iOS 26.0, *)
    struct FoundationModelsConversation: InsightConversing {
        /// Slightly warmer than narration: this is conversation, and identical phrasing on
        /// every turn reads as canned. Still low enough that figures stay stable.
        private let options = GenerationOptions(temperature: 0.5)

        func availability() -> InsightAvailability {
            switch SystemLanguageModel.default.availability {
            case .available:
                .available
            case let .unavailable(reason):
                .unavailable(Self.map(reason))
            @unknown default:
                .unavailable(.notSupported)
            }
        }

        func reply(to question: String, facts: InsightFacts, history: [ChatMessage]) async throws -> String {
            let session = LanguageModelSession(instructions: Self.instructions)

            do {
                let response = try await session.respond(
                    to: Self.prompt(question: question, facts: facts, history: history),
                    options: options
                )
                return response.content
            } catch let error as LanguageModelSession.GenerationError {
                throw Self.map(error)
            } catch {
                throw InsightNarrationFailure.unknown
            }
        }

        /// The whole conversation is rebuilt into one prompt rather than kept in a live
        /// session across turns. Sessions are per-reply here because the fact sheet is
        /// recomputed each time — the person's figures can change between questions, and a
        /// stale transcript would have the model answering from numbers that have moved.
        private static func prompt(question: String, facts: InsightFacts, history: [ChatMessage]) -> String {
            var blocks: [String] = []

            if !facts.isEmpty {
                blocks.append("Here are the person's current figures:\n\(InsightPromptBuilder.promptText(for: facts))")
            }

            // Only the recent tail: the context window is small, and older turns matter less
            // than current figures.
            let recent = history.suffix(6)
            if !recent.isEmpty {
                let transcript = recent
                    .map { "\($0.author == .person ? "Person" : "You"): \($0.text)" }
                    .joined(separator: "\n")
                blocks.append("Conversation so far:\n\(transcript)")
            }

            blocks.append("Person: \(question)")
            return blocks.joined(separator: "\n\n")
        }

        private static let instructions = [
            "You answer questions about someone's personal finances, briefly and calmly.",
            """
            Every number you state must be copied exactly from the figures you are given. \
            Never calculate, estimate, combine, or round a number yourself. If the answer \
            needs a figure you were not given, say you don't have it rather than guessing.
            """,
            """
            Do not give investment advice, do not tell the person what to buy or sell, and \
            do not moralise about their spending. Two or three sentences is usually plenty.
            """,
        ].joined(separator: "\n\n")

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

#else

    /// Fallback so the app still builds where FoundationModels is missing at compile time.
    struct FoundationModelsConversation: InsightConversing {
        func availability() -> InsightAvailability {
            .unavailable(.notSupported)
        }

        func reply(to _: String, facts _: InsightFacts, history _: [ChatMessage]) async throws -> String {
            throw InsightNarrationFailure.modelUnavailable
        }
    }

#endif
