# Phase 12 — TestFlight launch operations

Fresh task. **Prerequisite:** Phase 11 merged and green. This phase does not add v1.1 product features; it turns the release-ready build into a controlled beta and launch operation.

## Goal
Ship Sift through internal TestFlight, external TestFlight, and App Store submission with clear operational runbooks, safe feedback/support paths, deploy health checks, and launch-day rollback procedures.

## Context
- Whole repo. Reference `@AGENTS.md`, `@docs/RELEASE.md`, `@docs/PRIVACY_POLICY_DRAFT.md`, and `@docs/TERMS_DRAFT.md`.
- Apple TestFlight external testing requires beta test information and may require Beta App Review. The first external build for a version gets reviewed more fully than later builds.
- Sift launches guided-only unless concierge operations are staffed: `CONCIERGE_ENABLED=false` and no client flag.

## Constraints
- Do not add third-party analytics, crash, support, or monitoring SDKs in this phase.
- Do not expose secrets or sensitive financial data in logs, health responses, support email bodies, TestFlight metadata, or screenshots.
- Do not promise concierge cancellation unless operations are staffed and the backend flag is explicitly enabled.
- Legal and privacy drafts remain counsel-review drafts until approved.

## Detailed tasks
1. **Runbooks:** document internal beta, external beta, build promotion, build expiry/rollback, feedback triage, support response, privacy review, release-day checks, and post-launch monitoring in `docs/RELEASE.md`.
2. **TestFlight metadata:** add beta description, features to test, support email, review notes, Sandbox guidance, guided-only concierge disclosure, and tester data-safety reminders.
3. **Backend ops surfaces:** keep public `GET /health` as liveness with service/version/build/timestamp only. Add `GET /ready` for deploy readiness, returning DB reachability and `503` when the DB is unavailable.
4. **Backend startup logging:** log only non-sensitive config: service, version/build, port, node env, Plaid environment, webhook configured boolean, and concierge enabled boolean.
5. **iOS support/about:** add a compact Settings section showing app version/build and a safe beta feedback action. The prefilled support body must never include transaction details, account names, tokens, or credentials.

## Tests to write / verify
- Backend tests for `/health`, `/ready` success/failure, startup log context, and logger redaction keys.
- Swift Testing coverage for support metadata and safe feedback URL construction.
- XCUITest coverage that Settings shows version/build and the beta feedback action in mock-service mode.

## Done when
- `docs/RELEASE.md` has a complete beta and launch operations runbook.
- `GET /health` and `GET /ready` are implemented and tested.
- Settings shows support/about metadata and a feedback action without including financial data.
- Backend verification passes: `npm run typecheck && npm run lint && npm test && npm run db:validate`.
- iOS verification passes: `swiftformat --lint .`, `swiftlint`, `xcodebuild -scheme Sift -destination 'platform=iOS Simulator,name=iPhone 16 Pro' build`, and `xcodebuild test -scheme Sift -destination 'platform=iOS Simulator,name=iPhone 16 Pro'`.

## Guardrails
Treat this as launch operations, not feature expansion. If a beta tester reports a product feature request, triage it for v1.1 rather than adding it to this phase. If concierge is not staffed, all metadata and in-app copy must describe guided cancellation honestly.
