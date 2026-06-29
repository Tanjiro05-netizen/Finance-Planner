# Phase 7 — Core screens (Dashboard, Subscriptions, Detail, Insights · B1–B4)

Fresh task. **Prerequisite:** Phases 1–6 merged. Reasoning effort **high**. Attach the B1–B4 mockup screenshots.

## Goal
Build the four tabbed core screens at full fidelity, wired to the real repositories and detection output, replacing the Phase 2 placeholders. This is where the design system, data, and engine meet the user.

## Context
- Designs B1–B4 in `@docs/` (attached). Components from Phase 1; navigation/sheets from Phase 2; repositories from Phase 3; detection from Phase 6.
- Centralized money math (monthly-equivalent, totals, savings) lives in the repository layer (Phase 3) — reuse it; do not recompute per screen.

## Constraints
- Each screen has a `@MainActor @Observable` view model depending on repository protocols; `#Preview`s use mock repositories with seed data.
- View bodies stay small; compose from Phase 1 components. No raw tokens.
- Loading / empty / error states for every screen (e.g. "no subscriptions yet", sync failure with retry).
- Pull-to-refresh triggers `transactions/sync` + `DetectionService.recompute()`; reflect updates.
- Liquid Glass only on tab bar / segment control / floating action bar (already components). Content on solid cards.
- Accessibility: VoiceOver labels (e.g. the hero figure reads "Recurring this month, $247.83"), Dynamic Type scales, contrast ok, reduced-motion respected.

## Detailed tasks
**B1 Dashboard** (`Features/Home/`):
- Greeting + date; hero `SiftCard` with eyebrow, `MoneyText` total (monthly recurring), month-over-month `Pill` (clay up/green down), "Across N subscriptions · M renew this week".
- `RenewalTimelineStrip` populated from real `nextRenewal` dates across the current month; next renewal flagged.
- A "flagged unused" nudge card (top unused subscription from detection) with Review/Keep actions (Review → opens detail; Keep → dismisses for now).
- "Renews soon" list (next 2–3) using `SubscriptionRow`; tapping a row presents the detail sheet (Phase 2 routing).

**B2 Subscriptions** (`Features/Subscriptions/`):
- Glass segmented control: All / Active / Unused (counts live).
- Monthly total `MoneyText`; rows grouped by `Category`, sorted by amount; unused rows show clay meta. Tap → detail sheet. Search optional.

**B3 Subscription detail** (`Features/SubscriptionDetail/`):
- Presented as the glass sheet. Header (monogram + name + payment meta); 2×2 `StatCell` grid (Per month, Annual cost in clay, Next charge, Last opened — from data); charge-history mini bar chart from `Transaction`s; floating glass action bar with a clay "Cancel subscription" button → launches the cancel flow (Phase 8 entry; until then route to C1 placeholder).

**B4 Insights** (`Features/Insights/`):
- "Potential savings" hero in gold `MoneyText` (sum of monthly cost of unused/flagged); category spend bars (gold fill, Fraunces values) from repository aggregation; "Price changes" alert rows from `PriceChange` events; "trial ending" alerts from detection flags.

Wire all four into the tab shell; remove placeholders.

## Tests to write first
- View-model tests (with mock repos): Dashboard total + count + "renew this week" derive correctly from seed; nudge picks the right unused sub; Subscriptions segment filters/counts correct; Insights savings sum + category totals correct; Detail computes annual = monthly×12 (and yearly handled).
- Snapshot tests (or render assertions) for each screen in light mode at default + large Dynamic Type sizes.
- XCUITest: tap a subscription row → detail sheet shows that subscription's data; pull-to-refresh shows a refreshed state.

## Done when
- All four screens render real data, match the mockups closely, handle loading/empty/error, and pass VoiceOver/Dynamic Type checks.
- Tapping rows opens the correct detail; cancel button routes to the flow entry.
- Tests, build, lint green; no recomputed money math outside the repository layer (review in PR).

## Guardrails
Reuse the centralized totals/savings math — don't duplicate it. Don't put glass on content. Keep view models thin and repository-driven; no networking calls inside views. Match copy exactly to the design (mono labels uppercase, etc.).
