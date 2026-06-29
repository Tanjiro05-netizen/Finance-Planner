# Phase 11 — Testing, accessibility, performance & App Store readiness

Fresh task. **Prerequisite:** Phases 1–10 merged. This phase hardens and ships.

## Goal
Take the feature-complete app to release quality: fill test gaps, enforce accessibility, profile and fix performance, add observability and CI, and prepare everything App Store review will check — with special care for the privacy/financial-data scrutiny a finance app attracts.

## Context
- Whole repo. Reference `@AGENTS.md` for conventions, security guardrails, and the commands that define "done".
- Apple review is stricter for finance apps; Plaid + bank data invoke privacy requirements (App Privacy details, ATT not needed if no tracking, clear data-use disclosures).

## Constraints
- Do not weaken any security guardrail to ship. No secrets in the binary or repo. The Plaid secret stays server-side.
- Accessibility is a release gate, not a nice-to-have.

## Detailed tasks
1. **Test coverage pass:** ensure every view model and the detection engine have meaningful tests; add missing integration tests (onboarding→detection→screens→cancel). Set a coverage floor (e.g. 80% on `Core/` and view models) and document it. Add contract tests for `APIClient` against the backend's OpenAPI.
2. **CI:** GitHub Actions (or chosen CI) running on PRs — iOS: build + test + swiftlint + swiftformat lint; backend: typecheck + lint + vitest + `prisma validate`. Block merge on red. Reference these in `AGENTS.md` so Codex runs them.
3. **Accessibility audit:** VoiceOver labels/traits on every interactive element and the hero figures; Dynamic Type to the largest accessibility sizes without truncation/overlap; contrast ≥ 4.5:1 (verify gold/clay on bone for text uses gold-deep/clay at sufficient contrast — adjust tokens if any text fails); ≥ 44pt targets; `prefers-reduced-motion` honored (sheen/scan ring/transitions); VoiceOver rotor sensible ordering. Add automated a11y checks where possible.
4. **Performance:** profile cold launch, scan/detection on a large transaction set (e.g. 2k txns), and list scrolling. Move heavy detection off the main actor (it already is via `ModelActor`); ensure 60fps scrolling; lazy-load lists; cache derived totals. Fix retain cycles; verify no main-thread network/DB.
5. **Resilience & errors:** unify error presentation; offline mode (read from local store, queue sync); token refresh/expiry handling; Plaid item error states (re-auth required) surfaced with a re-link CTA; backend rate-limit/5xx backoff.
6. **Observability:** privacy-safe analytics + crash reporting hooks (no PII, no transaction contents); structured backend logs (already pino) with request IDs; a feature flag for concierge vs guided-only (so v1 can ship guided-only if ops aren't ready — see note).
7. **App Store prep:** app icon (the layered translucent style), launch screen, `PrivacyInfo.xcprivacy` manifest declaring data types (financial data via Plaid, usage), App Store privacy questionnaire answers documented, App Transport Security correct, required-reason API usage declared. Marketing screenshots can be generated from the real screens. Write `docs/RELEASE.md` with the submission checklist.
8. **Legal/compliance docs:** Privacy Policy + Terms drafts referencing Plaid as the data aggregator and read-only access; in-app links. (Drafts for review by counsel — flag clearly that legal review is required.)
9. **Decision flag — concierge readiness:** if the concierge ops aren't staffed for launch, set the feature flag to **guided-only** so the cancel fork shows only "Show me how" + reminders, and the concierge option appears as "coming soon" rather than promising a service you can't fulfill.

## Tests to write / verify
- Full integration test of the golden path on Plaid Sandbox.
- A11y tests (largest Dynamic Type renders without clipping on key screens).
- Performance test asserting detection on 2k transactions completes under a target (e.g. < 1s on device-class CI) and off the main actor.
- Security tests re-run: no token in client responses/logs; delete-my-data truly wipes.

## Done when
- CI is green on all checks; coverage floor met; a11y gates pass; performance targets met.
- `PrivacyInfo.xcprivacy`, icon, launch screen, and `docs/RELEASE.md` checklist complete; privacy questionnaire answers drafted.
- The app runs end-to-end on Sandbox with graceful error/offline handling, and ships either full cancel fork or guided-only per the feature flag.

## Guardrails
Shipping pressure never justifies relaxing the security/privacy guardrails or faking the concierge service. If concierge isn't ready, ship guided-only honestly. Flag all legal documents as requiring professional review before publication.
