# Phase 5 — Onboarding & account linking (A1–A9)

Fresh task. **Prerequisite:** Phases 1–4 merged. Attach the A1–A9 mockup screenshots from `sift-all-screens.html`.

## Goal
Build the full first-run flow — splash, welcome, connect, bank picker, the **Plaid Link** handoff, scanning, review-detected, notifications opt-in, and "all set" — wired to the Phase 4 backend (Sandbox) so a real user can link an account and arrive at a populated app.

## Context
- Screens A1–A9 designed in `@docs/` (attached). Components exist from Phase 1; navigation shell from Phase 2; models/repos from Phase 3; backend endpoints from Phase 4 (`auth/bootstrap`, `plaid/link-token`, `plaid/exchange`, `transactions/sync`).
- Plaid **LinkKit** iOS SDK (SPM) presents the secure credential UI; the app receives only a `public_token`.

## Constraints
- Credentials are entered **only inside Plaid Link**. Sift's own "Secure login" screen (A5) is the contextual lead-in/trust screen; the actual login is Plaid's sheet. Never collect bank credentials in Sift UI.
- An `OnboardingViewModel` (`@MainActor @Observable`) orchestrates steps via an `enum OnboardingStep`; it depends on an `APIClient` + repositories (protocols), never URLSession directly.
- On first launch call `auth/bootstrap`, store the JWT in the **Keychain** (not UserDefaults).
- Scanning (A6) reflects a real backend `transactions/sync` then the Phase 6 detection pass; show real progress, not a fake timer. (Until Phase 6 lands, call a `DetectionService` stub that returns seed results; replace in Phase 6.)
- Review (A7) lets the user toggle off false positives before confirming; confirmed items persist as `Subscription`s.
- Notifications (A8) uses `UNUserNotificationCenter` authorization request; respect the user's choice. "All set" (A9) shows the real monthly total and count from persisted data.

## Detailed tasks
1. `Networking/APIClient.swift`: typed async methods for the Phase 4 endpoints; injects JWT; decodes `{ data }`/`{ error }`; maps to `SiftError`. Keychain token store `Security/TokenStore.swift`.
2. `Features/Onboarding/OnboardingFlowView.swift` driving steps A1–A9 with the designed transitions; each step its own view (`SplashView`, `WelcomeView`, `ConnectIntroView`, `BankPickerView`, `SecureLeadInView`, `ScanningView`, `ReviewFoundView`, `NotificationsOptInView`, `AllSetView`).
3. Plaid integration `Features/Onboarding/PlaidLinkCoordinator.swift`: fetch `link-token` from backend → present LinkKit → on success POST `public_token` to `exchange`. Handle cancel/error states. **Confirm current LinkKit presentation API.**
4. After exchange: call `transactions/sync`, then `DetectionService.detect()` (stub now), populate `ReviewFoundView`.
5. Persist confirmed subscriptions via `SubscriptionRepository`; set onboarding-complete flag; route into the tab shell (Phase 2) on "Go to dashboard".
6. Trust UI: A3/A5 copy exactly per design ("READ-ONLY · SECURED BY PLAID · CREDENTIALS NEVER STORED"). Bank picker (A4) lists institutions (use Plaid institution search or a curated list in Sandbox).
7. Empty/error/cancel states for every network step (no dead ends).
8. Gate the app: `RootView` shows onboarding if not complete, else the tab shell.

## Tests to write first
- `OnboardingViewModelTests`: step progression; toggling off an item in review excludes it from persisted subscriptions; confirm persists the rest and sets the completion flag.
- `APIClientTests`: encodes/decodes each endpoint against fixtures; injects JWT header; surfaces `{ error }` as `SiftError`.
- `PlaidLinkCoordinatorTests`: given a mock that returns a `public_token`, the coordinator calls `exchange` exactly once; on Link cancel it returns to the connect screen without error.
- XCUITest (Sandbox): full happy path splash→…→dashboard reaches a populated Home (can use Plaid Sandbox credentials `user_good`/`pass_good`).

## Done when
- A fresh install can: bootstrap → open Plaid Link (Sandbox) → exchange → sync → see detected subscriptions in Review → confirm → land on a populated Dashboard.
- JWT stored in Keychain; no credentials ever touch Sift code; tests + build + lint pass.

## Guardrails
No bank credentials in Sift UI or storage. Don't fake the scan with a sleep — drive it from real sync + detection (stub detection only until Phase 6, and mark the TODO). Keep the Plaid token exchange entirely backend-mediated.
