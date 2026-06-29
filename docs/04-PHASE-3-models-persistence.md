# Phase 3 — Domain models, persistence & repositories

Fresh task. **Prerequisite:** Phase 2 merged.

## Goal
Define the **domain model**, **SwiftData persistence**, and **repository layer** (protocols + live SwiftData impls + in-memory mocks) that every screen and the detection engine will use. Seed realistic mock data so all later UI work renders against real types without needing the backend.

## Context
- Entities implied by the app: linked accounts, transactions, subscriptions, cancellation requests, categories, alert settings, price-change events.
- Consumers: detection engine (Phase 6), core screens (Phase 7), cancel flow (Phase 8), settings (Phase 9), notifications (Phase 10).
- `AGENTS.md` mandates repository protocols with live + mock impls and user-scoped data.

## Constraints
- Use **SwiftData** (`@Model`) for persisted entities; expose them to the app through repository **protocols** so views/view models never touch `ModelContext` directly.
- All money is stored as integer **minor units** (cents) in a `Money` value type with currency; never `Double` for money. Provide formatting via the `MoneyText` component from Phase 1.
- Dates stored UTC; cadence is a typed enum.
- Everything `Sendable`-correct under Swift 6 strict concurrency. Repositories are `@MainActor` where they touch the main `ModelContext`, or use a background `ModelActor` for sync-heavy writes (detection import).
- Provide a deterministic **seed dataset** matching the mockups (Streamline+, Tonebox, Reelhouse, Creative Cloud [unused 3 months], Notewell yearly, etc.) for previews/tests.

## Detailed tasks
1. **Value types** (`Core/Domain/`): `Money` (amountMinor: Int, currency), `Cadence` enum (`weekly, monthly, quarterly, yearly, unknown`), `Cents` helpers, `MerchantKey` (normalized merchant id).
2. **`@Model` entities** (`Core/Persistence/Models/`):
   - `LinkedAccount` (id, institutionName, mask, type, status, lastSyncedAt).
   - `Transaction` (id, accountID, merchantRaw, merchantKey, amount: Money, date, pending, categoryHint).
   - `Subscription` (id, name, merchantKey, monogramLetter, tileColorToken, amount: Money, cadence, nextRenewal: Date?, lastUsed: Date?, categoryID, status [`active, unused, cancelled`], detectionConfidence: Double, firstSeen, lastCharge).
   - `CancellationRequest` (id, subscriptionID, method [`concierge, guided`], status [`requested, contacting, confirmed, needsUser, cancelledByUser`], createdAt, updatedAt, note).
   - `Category` (id, name, iconToken, isAuto).
   - `PriceChange` (id, subscriptionID, oldAmount, newAmount, changedAt).
   - `AlertSettings` (singleton: renewalReminders, priceChanges, trialEndings, unusedNudges, weeklySummary — Bools).
3. **Repository protocols** (`Core/Repositories/`): `SubscriptionRepository`, `AccountRepository`, `TransactionRepository`, `CancellationRepository`, `CategoryRepository`, `SettingsRepository`. CRUD + queries the screens need (e.g. `monthlyTotal()`, `upcomingRenewals(limit:)`, `unused()`, `byCategory()`, `potentialSavings()`).
4. **Live impls** backed by SwiftData; **mock impls** (`Mock*Repository`) returning the seed dataset, used by previews and tests.
5. **Seed data**: `Core/Persistence/SeedData.swift` building the mock dataset; a `--uitesting`/preview path that loads it into an in-memory `ModelContainer`.
6. **DI**: extend the environment so view models receive repository protocols; provide a `RepositoryContainer` with `.live` and `.mock` factories.
7. Wire the Phase 2 placeholder screens to pull from the **mock** repositories (e.g. Home shows the real monthly total from seed data) to prove the layer end-to-end.

## Tests to write first
- `MoneyTests`: arithmetic, rounding, formatting in minor units; no floating error.
- `SubscriptionRepositoryTests` (against in-memory container): `monthlyTotal()` sums monthly-equivalent of mixed cadences correctly (yearly ÷ 12, etc.); `unused()` filters by `lastUsed` age; `upcomingRenewals` sorts by date.
- `CancellationRepositoryTests`: create request → status transitions persist.
- `SeedDataTests`: seed loads N subscriptions with expected totals matching the mockup ($247.83/mo, $146/mo potential savings).

## Done when
- All repositories have protocol + live + mock; in-memory tests pass.
- Phase 2 screens now display real figures from seed data via mock repositories.
- Build, tests, lint clean. No `Double` used for money anywhere (lint/grep check in PR).

## Guardrails
No networking in this phase — repositories are local only (the backend sync arrives in Phase 4/5). Keep the monthly-equivalent math centralized in one place (used by Dashboard, Subscriptions, Insights) to avoid divergence. Don't expose `ModelContext` outside the persistence layer.
