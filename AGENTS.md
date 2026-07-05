# AGENTS.md — Sift

> Place this file at the **repo root** as `AGENTS.md`. Codex loads it automatically on every task. Keep it under 32 KiB. Nested `ios/AGENTS.md` and `backend/AGENTS.md` overrides are referenced where noted.

## What we're building
Sift is an iOS app that connects to a user's bank (read-only, via Plaid), automatically detects recurring subscription charges, and helps the user cancel them through one of two real paths: a **concierge** request (our team cancels) or a **guided** walkthrough (the user cancels with step-by-step help). Premium, calm, trustworthy fintech.

## Repository layout
```
/AGENTS.md          ← this file
/docs/              ← phase specs, Design.md, HTML mockups (reference only)
/ios/               ← SwiftUI app (Sift.xcodeproj). See ios/AGENTS.md
/backend/           ← Node + TypeScript service. See backend/AGENTS.md
```
One thread per task. Do not attempt multiple phases in a single session.

## Tech stack (do not substitute without being told)
**iOS:** Swift 6 with strict concurrency; SwiftUI; minimum deployment **iOS 26**; Xcode 26. State with the **Observation** framework (`@Observable`, `@State`, `@Environment`) — no Combine, no ObservableObject. Persistence with **SwiftData**. Networking with `URLSession` + `async/await` behind a typed `APIClient`. Plaid via **LinkKit** (Swift Package Manager). Testing with the **Swift Testing** framework (`import Testing`, `@Test`, `#expect`) for unit logic; XCUITest for flows. No third-party UI/animation/networking libraries.

**Backend:** Node.js (LTS) + TypeScript (strict); Express; **plaid** official Node SDK; Postgres via **Prisma**; `zod` for request validation; `vitest` for tests; `pino` for logging. No ORM other than Prisma.

> Liquid Glass and some SwiftData/Swift-Testing APIs are recent. **Before using a new API, confirm the exact current signature** against the installed SDK (e.g. read the SwiftUI interface or Plaid LinkKit headers). Do not invent API names; if unsure, check then proceed.

## Build, run, test commands
**iOS** (run from `/ios`):
- Build: `xcodebuild -scheme Sift -destination 'platform=iOS Simulator,name=iPhone 16 Pro' build`
- Test: `xcodebuild test -scheme Sift -destination 'platform=iOS Simulator,name=iPhone 16 Pro'`
- Lint/format: `swiftformat .` and `swiftlint` (configs committed in Phase 1).

**Backend** (run from `/backend`):
- Install: `npm ci`
- Dev: `npm run dev`
- Test: `npm test` (vitest)
- Lint/typecheck: `npm run lint && npm run typecheck`
- DB validation: `npm run db:validate`
- DB: `npm run db:migrate` (Prisma)

**CI / coverage:** GitHub Actions runs iOS build/test/lint and backend typecheck/lint/vitest/Prisma validation on PRs. The iOS coverage floor is 80% for `ios/Sift/Core/` and `*ViewModel.swift` files, enforced from `xccov` JSON by `scripts/check-ios-coverage.js`.

**Codex must run the relevant build + tests before declaring a task done.** A task is not complete if the build is red or tests fail.

## Architecture conventions
- **iOS:** feature-first folders under `ios/Sift/Features/<Feature>/` each with `Views/`, `<Feature>ViewModel.swift` (a `@MainActor @Observable` class), and `Models` referenced from the shared domain layer. Shared design system in `ios/Sift/DesignSystem/`. Domain models + repositories in `ios/Sift/Core/`. View models never call `URLSession` directly — they depend on repository protocols. All repositories have a protocol + a live impl + a mock impl for previews/tests.
- **Views** are small and composable; no view body longer than ~60 lines — extract subviews. Every screen has a `#Preview` using mock data.
- **Backend:** layered — `routes/` (thin) → `services/` (logic) → `repositories/` (Prisma) → Prisma client. Validate every request body with `zod`. Never put logic in routes.
- **Errors:** typed. iOS uses a `SiftError` enum surfaced as user-friendly messages; backend returns `{ error: { code, message } }` with correct HTTP status.

## Design system (authoritative — also in /docs/Design.md)
Encode these as Swift constants in `DesignSystem/Tokens.swift`. Never hardcode hex or font names elsewhere.
- Colors: ink `#1A1612`, ink-soft `#6E6357`, ink-faint `#9C9285`, bone `#F6F2EA` (bg), card `#FFFDF8`, sand `#ECE4D6`, line `#E2D9C8`, **gold `#B68A4E`** (sole accent), gold-deep `#9A7238`, clay `#A8472F` (cancel/warning), green `#3F6B3A` (success only).
- Fonts (bundled): **Fraunces** (money figures, titles), **Plus Jakarta Sans** (UI/body), **IBM Plex Mono** (tiny uppercase labels, dates, cadence). Money figures use tabular numerals.
- Radii: cards 26, rows 17, buttons/fields 16, tiles 11, pills 20. Side margins 16–18. Soft warm low shadows; 1px `line` borders on cards.
- **Liquid Glass only on the control layer:** floating tab bar, segmented control, floating bottom action bars, notification banner, sheets. Use native iOS 26 glass (`.glassEffect` / glass button styles — verify exact API). Content is always on solid `card` surfaces; never put text directly on glass.
- Motion and glass behaviour are governed by `/docs/13-MOTION-AND-GLASS.md` — implement animations from its tokens; never hardcode durations.
- No real brand logos: subscriptions render as single-letter monogram tiles in palette colors. No stock photos.

## Security & privacy guardrails (hard rules — never violate)
- The **Plaid `client_secret` lives only in the backend** environment. It must never appear in the iOS app, in client requests, in logs, or in the repo. All Plaid API calls happen server-side.
- The app **never stores or transmits bank credentials.** Credential entry happens inside Plaid Link only; the app receives a `public_token`, nothing else.
- Plaid access tokens are stored **only** in the backend DB, encrypted at rest; never returned to the client.
- No secrets in the repo. Use `.env` (gitignored) + a committed `.env.example`. No API keys in code or tests.
- PII (transactions, account names) is access-controlled per user; every backend query is scoped by authenticated `userId`.
- "Cancel a subscription" is **never** implemented as a fake/universal cancel API. Only the two real mechanics: create a concierge `CancellationRequest` (backend tracks status) or show guided steps. Do not fabricate provider integrations.

## Copy & UX rules
Plain, calm, concrete. State money exactly (`$15.49`, `$185.88/yr`). Never alarmist. Accessibility is not optional: Dynamic Type, VoiceOver labels on every control, ≥ 4.5:1 contrast for text, ≥ 44pt tap targets, `prefers-reduced-motion` respected. Support light theme first (dark mode is a later enhancement, not this build).

## PR / commit conventions
Conventional commits (`feat:`, `fix:`, `test:`, `chore:`). One phase per PR. PR description lists what was built, the commands run to verify, and any deviations from the spec with reasons.

## Do not
- Do not add dependencies beyond those named here without flagging it in the PR description and why.
- Do not modify tests to make them pass; fix the implementation.
- Do not invent API names or endpoints — confirm against SDKs/specs.
- Do not implement features from later phases early; keep tasks scoped.
