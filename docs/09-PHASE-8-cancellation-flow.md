# Phase 8 — Cancellation flow (C1–C5)

Fresh task. **Prerequisite:** Phases 4 (backend cancellations) + 7 merged. Attach C1–C5 mockup screenshots.

## Goal
Build the cancellation experience: the **fork** (concierge vs guided), the concierge **status tracker**, the **guided steps**, the **confirmation**, and the **requests list** — wired to the Phase 4 cancellation API. This is the product's defining flow and must be honest about how cancellation really works.

## Context
- Designs C1–C5 in `@docs/` (attached). Backend endpoints from Phase 4: `POST /v1/cancellations`, `GET /v1/cancellations`, `PATCH /v1/cancellations/:id`. Models from Phase 3 (`CancellationRequest`). Entry point is the Detail sheet's "Cancel subscription" button (Phase 7).

## Constraints
- Cancellation is **only** the two real mechanics: concierge (create a tracked request the backend/our ops advance) and guided (show provider-specific steps + reminders). **No fake universal cancel API**; no fabricated provider automations.
- `CancellationViewModel` (`@MainActor @Observable`) depends on `CancellationRepository` (local mirror) + `APIClient` (server source of truth). Optimistic local update with server reconcile.
- Guided steps come from a local, editable `CancellationGuideProvider` keyed by `merchantKey` with a sensible **generic fallback** ("Open the provider's account/billing page → find Subscription/Membership → Cancel → confirm"). Do not invent specific steps for providers you don't have data for — use the generic guide and label it generic.
- Confirmation and tracker show concrete, exact figures (amount saved per year). Calm tone; success uses green sparingly.

## Detailed tasks
1. **C1 Cancel options** (`Features/Cancellation/CancelOptionsView.swift`): title + cost line (annual savings from the subscription), two `OptionCard`s — "Cancel for me" (recommended, gold) and "Show me how" (plain) — plus the honest note that there's no universal cancel button.
2. **Concierge path → C2** (`ConciergeStatusView.swift`): on choosing concierge, `POST /v1/cancellations { method: concierge }`; show the vertical `StatusTimeline` (Request received ✓ / Contacting provider ● / Confirmed pending) bound to the request's `status`; "Track in Requests" button → C5.
3. **Guided path → C3** (`GuidedStepsView.swift`): `POST /v1/cancellations { method: guided }`; render numbered steps from `CancellationGuideProvider`; "Remind me before renewal" toggle (schedules a local notification in Phase 10 — stub now with a TODO + persist intent); floating glass "Open provider site" button (opens `SFSafariViewController`/URL if known, else instructs).
4. **C4 Confirmed** (`CancelConfirmedView.swift`): shown when status becomes `confirmed` (concierge) or the user taps "I've cancelled it" (guided → status `cancelledByUser`); green check, exact "$X/yr saved", updates the `Subscription` to `cancelled` (removed from active totals) via repository; "Done".
5. **C5 Requests tracker** (`CancellationRequestsView.swift`): `GET /v1/cancellations`; savings banner (sum of confirmed cancellations' annual cost); rows with status pills (In progress / Confirmed / Needs you). Reachable from Settings (Phase 9) and the concierge "Track" button.
6. Reconcile: when a request hits `confirmed`/`cancelledByUser`, the subscription leaves active totals and the Dashboard/Insights update.
7. Handle `needsUser` status (e.g. provider requires the account holder) with a clear callout and a switch-to-guided option.

## Tests to write first
- `CancellationViewModelTests` (mock API + repo): choosing concierge creates a request (status `requested`) and shows the timeline; advancing to `confirmed` marks the subscription cancelled and removes it from active totals; guided "I've cancelled it" sets `cancelledByUser`.
- `CancellationGuideProviderTests`: known merchant returns specific steps; unknown returns the labeled generic guide.
- `SavingsTests`: requests tracker savings banner sums confirmed annual costs correctly.
- XCUITest: from Detail → Cancel → "Cancel for me" → status screen → (simulate PATCH confirmed) → confirmation → subscription gone from list.

## Done when
- Both cancel paths work end-to-end against the backend (Sandbox/dev); statuses round-trip; confirmed cancellations update all totals; requests list reflects server state.
- Guided steps never fabricate provider-specific instructions without data (generic fallback verified by test).
- Tests, build, lint green.

## Guardrails
Never implement or imply an automated universal cancel. Don't hardcode misleading provider steps. Keep the server as the source of truth for request status; the app mirrors it. Match the honest copy in the design.
