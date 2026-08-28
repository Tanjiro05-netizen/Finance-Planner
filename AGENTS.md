# AGENTS.md — Sift

> Place this file at the **repo root** as `AGENTS.md`. Codex loads it automatically on every task. Keep it under 32 KiB. The nested `ios/AGENTS.md` override is referenced where noted.

## What we're building
Sift is a fully on-device iOS app that reads the user's own financial data (read-only, via Apple's **FinanceKit**), automatically detects recurring subscription charges, and helps the user cancel them through a **guided** walkthrough (step-by-step help). There is no backend server and no third-party data broker. Premium, calm, trustworthy fintech.

## Repository layout
```
/AGENTS.md          ← this file
/docs/              ← phase specs, Design.md, HTML mockups (reference only)
/ios/               ← SwiftUI app (Sift.xcodeproj). See ios/AGENTS.md
```
One thread per task. Do not attempt multiple phases in a single session.

## Tech stack (do not substitute without being told)
**iOS:** Swift 6 with strict concurrency; SwiftUI; minimum deployment **iOS 26**; Xcode 26. State with the **Observation** framework (`@Observable`, `@State`, `@Environment`) — no Combine, no ObservableObject. Persistence with **SwiftData**. Financial data on device with **FinanceKit** (Apple Card / Apple Cash / Apple Pay), behind the `FinancialDataStore` protocol in `Core/FinanceKit/`; the live adapter is `Integrations/FinanceKitStore.swift`. Testing with the **Swift Testing** framework (`import Testing`, `@Test`, `#expect`) for unit logic; XCUITest for flows. No backend and no third-party UI/animation/networking libraries.

> Liquid Glass, FinanceKit, and some SwiftData/Swift-Testing APIs are recent. **Before using a new API, confirm the exact current signature** against the installed SDK or Apple's documentation JSON (`developer.apple.com/tutorials/data/documentation/...`). Do not invent API names; if unsure, check then proceed.

## On-device data flow (FinanceKit)
`FinanceKitStore` (live, imports FinanceKit) reads the user's real Wallet transactions and accounts (including balances, via `AccountBalanceQuery`) and maps them into framework-free `FinancialTransactionSnapshot` / `FinancialAccountSnapshot` values. `FinancialDataMapper` (pure, fully unit-tested) turns those into the transport shapes the detection pipeline and the transaction ledger both consume; `FinanceKitAPIClient` and `FinanceKitLinkPresenter` adapt them onto the app's existing service protocols so onboarding and `SubscriptionRefreshService` work unchanged. FinanceKit needs the `com.apple.developer.financekit` entitlement, `NSFinancialDataUsageDescription`, a real device, and the user's permission; everywhere else it degrades to an empty result.

## Transaction ledger (Phase 1)
The ledger persists every synced transaction (debits **and** credits — subscription detection only ever reads the debit-scoped subset, filtered explicitly in `DetectionPersistenceActor.transactionInputs`, not by amount sign since `Money` stores an unsigned magnitude). `TransactionDirection`/`TransactionKind`/`TransactionSource` (`Core/Domain/DomainTypes.swift`) carry direction, a display/classification kind, and provenance; `Core/Categorization/TransactionClassifier.swift` is the pure, testable home for the credit→income/refund heuristic. `Core/Categorization/CategoryService.swift` auto-categorizes both subscriptions and transactions from the same keyword-rule table. The `Features/Transactions/` tab is gated behind `SiftFeatureFlags.ledgerEnabled` (same opt-in pattern as `conciergeEnabled`: `-siftLedgerEnabled` launch arg or `SIFT_LEDGER_ENABLED` env var) until it's ready to ship broadly.

## Safe-to-spend + cash flow (Phase 2)
The recurring-detection math is shared, not duplicated: `Core/Detection/CadenceInference.swift` (`CadenceMath`) holds the pure interval/cadence/amount-stability/confidence functions that both the subscription detector (`DetectionEngine`, debit-only, subscription cadences) and the income detector (`IncomeDetectionEngine`, credit-only, includes `.biweekly` for payroll) call — so `DetectionEngineTests`/`DetectionServiceTests` staying green proves the extraction is behavior-preserving. Recurring **income** persists as its own `RecurringIncome` model (cheap "next expected income" query for safe-to-spend); recurring non-subscription obligations persist as `Bill` (kept separate from `Subscription` so rent never inherits the cancel flow / trial / unused-nudge affordances) — `Core/Categorization/BillClassifier.swift` routes bill-keyword debits inside `DetectionPersistenceActor.splitCandidates`, so the subscription-facing `DetectionResult` never contains bills. `Core/Domain/SafeToSpendCalculator.swift`, `DiscretionarySpendEstimator.swift`, and `CashFlowForecaster.swift` are pure/testable; the safe-to-spend hero on Home and the `Features/CashFlow/` forecast screen (Swift Charts `AreaMark`/`LineMark`, step-interpolated) are both gated behind `SiftFeatureFlags.ledgerEnabled`. `.biweekly` cadence is scoped to income detection only — the subscription detector's candidate list is unchanged.

## Build, run, test commands
**iOS** (run from `/ios`):
- Build: `xcodebuild -scheme Sift -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build`
- Test: `xcodebuild test -scheme Sift -destination 'platform=iOS Simulator,name=iPhone 17 Pro'`
- Lint/format: `swiftformat .` and `swiftlint` (configs committed in Phase 1).

There is no backend; the app is entirely on device.

**CI / coverage:** GitHub Actions runs iOS build/test/lint on PRs, split into an independent `Lint & Format` job and an `iOS Build & Test` job so a formatting nit never hides build/test signal. The iOS coverage floor is 80% for `ios/Sift/Core/` and `*ViewModel.swift` files, enforced from `xccov` JSON by `scripts/check-ios-coverage.js`; current scoped coverage sits at ~80.4%, so new `Core/`/ViewModel code needs tests alongside it or the floor will trip. Untestable platform-integration code (e.g. the live `FinanceKitStore`) lives outside `Core/` and outside `*ViewModel.swift` so it is not in the coverage scope — keep such adapters thin and put the logic in tested, framework-free helpers.

**Codex must run the relevant build + tests before declaring a task done.** A task is not complete if the build is red or tests fail.

## Architecture conventions
- **iOS:** feature-first folders under `ios/Sift/Features/<Feature>/` each with `Views/`, `<Feature>ViewModel.swift` (a `@MainActor @Observable` class), and `Models` referenced from the shared domain layer. Shared design system in `ios/Sift/DesignSystem/`. Domain models + repositories in `ios/Sift/Core/`. View models never call `URLSession` directly — they depend on repository protocols. All repositories have a protocol + a live impl + a mock impl for previews/tests.
- **Views** are small and composable; no view body longer than ~60 lines — extract subviews. Every screen has a `#Preview` using mock data.
- **FinanceKit:** the live adapter (`Integrations/FinanceKitStore.swift`) is the only file that imports FinanceKit — keep it a thin passthrough. All mapping and paging logic lives in pure, tested helpers under `Core/FinanceKit/` behind the `FinancialDataStore` protocol, which has a live impl and a `MockFinancialDataStore` for previews/tests.
- **Errors:** typed. iOS uses a `SiftError` enum surfaced as user-friendly messages.

## Design system (authoritative — also in /docs/Design.md)
Encode these as Swift constants in `DesignSystem/Tokens.swift`. Never hardcode hex or font names elsewhere.
- Colors: ink `#1A1612`, ink-soft `#6E6357`, ink-faint `#9C9285`, bone `#F6F2EA` (bg), card `#FFFDF8`, sand `#ECE4D6`, line `#E2D9C8`, **gold `#B68A4E`** (sole accent), gold-deep `#9A7238`, clay `#A8472F` (cancel/warning), green `#3F6B3A` (success only).
- Fonts (bundled): **Fraunces** (money figures, titles), **Plus Jakarta Sans** (UI/body), **IBM Plex Mono** (tiny uppercase labels, dates, cadence). Money figures use tabular numerals.
- Radii: cards 26, rows 17, buttons/fields 16, tiles 11, pills 20. Side margins 16–18. Soft warm low shadows; 1px `line` borders on cards.
- **Liquid Glass only on the control layer:** floating tab bar, segmented control, floating bottom action bars, notification banner, sheets. Use native iOS 26 glass (`.glassEffect` / glass button styles — verify exact API). Content is always on solid `card` surfaces; never put text directly on glass.
- Motion and glass behaviour are governed by `/docs/13-MOTION-AND-GLASS.md` — implement animations from its tokens; never hardcode durations.
- No real brand logos: subscriptions render as single-letter monogram tiles in palette colors. No stock photos.

## Security & privacy guardrails (hard rules — never violate)
- **All financial data stays on device.** It is read through FinanceKit under the user's explicit permission and never transmitted off the phone. There is no server to send it to.
- The app **never stores or transmits bank credentials.** FinanceKit vends already-authorized Wallet data; the app never sees a login.
- FinanceKit access requires the `com.apple.developer.financekit` entitlement and the `NSFinancialDataUsageDescription` prompt string. Request only `financialData`.
- No secrets or API keys in the repo, code, or tests. The app has no keys to hold.
- "Cancel a subscription" is **never** implemented as a fake/universal cancel API. The only real mechanic in this on-device build is **guided steps** (show the user how to cancel). Do not fabricate provider integrations or a concierge backend.

## Copy & UX rules
Plain, calm, concrete. State money exactly (`$15.49`, `$185.88/yr`). Never alarmist. Accessibility is not optional: Dynamic Type, VoiceOver labels on every control, ≥ 4.5:1 contrast for text, ≥ 44pt tap targets, `prefers-reduced-motion` respected. Support light theme first (dark mode is a later enhancement, not this build).

## PR / commit conventions
Conventional commits (`feat:`, `fix:`, `test:`, `chore:`). One phase per PR. PR description lists what was built, the commands run to verify, and any deviations from the spec with reasons.

## Do not
- Do not add dependencies beyond those named here without flagging it in the PR description and why.
- Do not modify tests to make them pass; fix the implementation.
- Do not invent API names or endpoints — confirm against SDKs/specs.
- Do not implement features from later phases early; keep tasks scoped.
