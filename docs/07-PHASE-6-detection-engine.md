# Phase 6 — Subscription detection engine

Fresh task. **Prerequisite:** Phases 3–5 merged. Reasoning effort **high**. This is the algorithmic heart of the product — TDD strictly.

## Goal
Build a deterministic, well-tested engine that turns a user's raw transactions into detected `Subscription`s: grouping charges by normalized merchant, identifying recurring cadence and amount, scoring confidence, detecting price changes and likely-unused subscriptions, and producing the Review-screen candidates. Replace the Phase 5 `DetectionService` stub with the real implementation.

## Context
- Input: `Transaction`s synced from the backend (Phase 4) and persisted (Phase 3).
- Output: candidate `Subscription`s (name, merchantKey, amount, cadence, nextRenewal, confidence) + `PriceChange` events + an `unused` signal.
- Consumers: Review screen (A7), Dashboard/Subscriptions/Insights (Phase 7), notifications (Phase 10).

## Constraints
- Pure, **side-effect-free core**: a `DetectionEngine` operating on plain value types (no SwiftData/network inside the algorithm) so it's fully unit-testable and `Sendable`. A separate `DetectionService` does the persistence/import on a background `ModelActor`.
- Deterministic given the same input (no reliance on `Date()` inside the core — pass a `referenceDate`).
- Money stays in minor units; cadence inference tolerant of real-world noise (a day or two of drift, small amount variance like tax changes).

## Algorithm (implement and document in `Core/Detection/README.md`)
1. **Normalize merchant** (`MerchantNormalizer`): lowercase, strip store numbers, card-network noise, trailing locations, common suffixes; map known aliases. Produce a stable `merchantKey`.
2. **Group** transactions by `merchantKey`.
3. **Recurring detection** per group:
   - Sort by date; compute inter-charge intervals.
   - Classify cadence by clustering intervals around 7 / 30 / 91 / 365 days within tolerance (e.g. monthly = 28–33 days). Require ≥ 2–3 intervals of consistent spacing.
   - Amount consistency: median amount; allow small variance band; flag outliers.
4. **Confidence score** (0–1) from: number of occurrences, interval regularity (low variance = high), amount stability, and merchant-known bonus. Threshold (e.g. ≥ 0.6) to surface as a candidate; below threshold → not a subscription.
5. **Next renewal**: last charge + cadence interval (clamped to future).
6. **Price-change detection**: a sustained step change in the recurring amount → emit `PriceChange(old, new, changedAt)`.
7. **Unused signal**: if the product later has app-usage signals it can refine this; for MVP, "unused" = active subscription with no *new* engagement signal and last charge older than N cycles, OR simply expose `lastUsed` as unknown and let the user mark. Document the MVP heuristic honestly (don't invent usage data we don't have).
8. **Free-trial heuristic**: first charge significantly lower/zero followed by a standard charge, or a known-trial pattern → flag `trialEnding` for the upcoming renewal.

## Detailed tasks
1. `Core/Detection/MerchantNormalizer.swift` (+ alias table, extensible).
2. `Core/Detection/DetectionEngine.swift`: `func detect(transactions:[Txn], referenceDate:Date) -> DetectionResult` where `DetectionResult` = candidates + priceChanges + flags. Pure.
3. `Core/Detection/Models.swift`: input `Txn` value type, `SubscriptionCandidate`, `DetectionResult`, `Cadence` reuse.
4. `Core/Detection/DetectionService.swift`: loads transactions via repository, runs the engine, reconciles with existing `Subscription`s (update amounts, add new, mark cancelled if charges stop), writes via repositories on a `ModelActor`. Emits `PriceChange`s.
5. Replace Phase 5 stub; Review screen now shows real candidates sorted by confidence.
6. Expose `recompute()` callable after each `transactions/sync`.

## Tests to write first (this is the priority of the phase)
Build fixture transaction sets and assert:
- Clean monthly Netflix-like stream (12 charges, same amount) → 1 candidate, cadence `monthly`, confidence high, correct nextRenewal.
- Yearly subscription (2 charges 365d apart) → cadence `yearly`.
- Irregular grocery spend (many random amounts/dates) → **no** candidate (below threshold).
- Amount step ($11.99 ×6 then $13.99 ×6) → 1 candidate at current price + 1 `PriceChange(11.99→13.99)`.
- Merchant noise (`"NETFLIX #4471 LOS GATOS"`, `"Netflix.com"`) collapses to one `merchantKey`.
- Trial pattern ($0 then $9.99 monthly) → candidate with `trialEnding` flag on next renewal.
- Determinism: same input + referenceDate → identical output across runs.
- Reconciliation: re-running detection after a new charge updates `lastCharge`/`nextRenewal` without duplicating the subscription; a stopped stream marks `cancelled`.
Aim for high coverage of the engine; it must be the best-tested module in the app.

## Done when
- All detection tests pass; the engine is pure and deterministic; `DetectionService` persists/reconciles correctly.
- Onboarding Review and the core screens now reflect engine output on Sandbox data.
- Build, lint, tests green.

## Guardrails
Keep the algorithm pure and dependency-free — no `Date()`/network/SwiftData inside `DetectionEngine`. Don't fabricate app-usage data for "unused"; document the real heuristic and its limits. Tune thresholds via tests, not guesswork.
