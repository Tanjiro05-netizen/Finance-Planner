# Sift Release Checklist

Phase 11 release readiness checklist for App Store submission. Legal and privacy statements here are implementation notes and draft answers; final policy, terms, and App Store Connect responses require counsel review before publication.

## Build Gates

- iOS CI passes on `macos-26`: `swiftformat --lint .`, `swiftlint`, `xcodebuild build`, and `xcodebuild test` with code coverage.
- Backend CI passes on `ubuntu-latest`: `npm ci`, `npm run typecheck`, `npm run lint`, `npm test`, and `npm run db:validate`.
- Coverage floor: scoped iOS line coverage for `ios/Sift/Core/` plus `*ViewModel.swift` files is at least 80%, enforced by `scripts/check-ios-coverage.js`.
- Manual Sandbox smoke: bootstrap, Plaid Link Sandbox, transaction sync, detection, subscription detail, guided cancellation, notification opt-in, data deletion.

## App Store Assets

- App icon: `ios/Sift/Resources/Assets.xcassets/AppIcon.appiconset`.
- Launch screen: configured through `UILaunchScreen` in `ios/Sift/Resources/Info.plist`.
- Privacy manifest: `ios/Sift/Resources/PrivacyInfo.xcprivacy` is included in the app target resources.
- Screenshots: capture from real mock-service screens, not static mockups. Use light theme, no real bank or merchant logos, and no live customer data.

## Privacy Answers Draft

- Tracking: No. Sift does not track users across apps or websites and does not use ATT.
- Data linked to user: financial info from Plaid, linked account metadata, app user/session ID, cancellation request status.
- Data not used for tracking: all collected data is used for app functionality, fraud/security, or customer support.
- Financial data: read-only transaction and account metadata from Plaid. No bank credentials are collected, stored, or transmitted by Sift.
- User content: cancellation notes/status may be stored if the user starts a guided or concierge cancellation.
- Diagnostics/analytics: only privacy-safe hooks are present in app code for non-PII events; no transaction contents, account names, access tokens, or bank credentials may be recorded.
- Data deletion: users can delete Sift data and revoke linked Plaid items from Settings > Privacy & data.

## Launch Flags

- `CONCIERGE_ENABLED=false` is the backend launch default.
- iOS defaults to guided-only. Enable concierge only with `SIFT_CONCIERGE_ENABLED=true` or `-siftConciergeEnabled`.
- Guided-only launch copy must show concierge as coming soon and must not imply that Sift will cancel subscriptions manually.

## TestFlight Operations

- Beta support email: `support@sift.app`.
- Beta app description: "Sift connects through Plaid Sandbox, detects recurring subscriptions from transaction history, and helps test guided cancellation workflows."
- Features to test: onboarding, Plaid Sandbox linking, transaction sync, recurring detection, dashboard/subscriptions/insights screens, guided cancellation, notification opt-in, linked account management, and data deletion.
- TestFlight review notes: use Plaid Sandbox only; no real bank credentials are needed. Sandbox institution: `First Platypus Bank` (`ins_109508`), username `user_good`, password `pass_good`, MFA `1234` when prompted.
- Guided-only disclosure: concierge cancellation is not staffed for launch and appears as coming soon unless explicitly enabled by ops.
- Tester reminder: never submit bank credentials, account numbers, transaction contents, screenshots containing real financial data, or Plaid tokens in TestFlight feedback or support email.

## Launch Runbooks

- Internal beta: upload a release build, assign only App Store Connect internal testers, smoke test onboarding through deletion, verify `/health` and `/ready`, and confirm `CONCIERGE_ENABLED=false` in backend logs.
- External beta: submit one build to TestFlight review with the metadata above, invite a small cohort first, then expand only after crash-free smoke and feedback triage.
- Build promotion: promote only the exact build that passed CI, Sandbox smoke, privacy review, and support-link verification. Capture the build number in this checklist before release.
- Rollback/expiry: expire the affected TestFlight build in App Store Connect, redeploy the last healthy backend if needed, keep guided-only copy, and notify testers with a calm status update.
- Feedback triage: classify reports as blocker, release fix, v1.1 feature, legal/privacy, or support. Do not ask testers for sensitive financial details; request redacted screenshots only when needed.
- Support response: acknowledge within one business day during beta, include the app version/build from Settings > Support, and route deletion/privacy requests to the privacy checklist.
- Privacy review: before external beta and App Store submission, compare the archive privacy report, `PrivacyInfo.xcprivacy`, App Store privacy answers, and legal drafts. Counsel must approve published legal text.
- Privacy answers: `PrivacyInfo.xcprivacy` declares **no collected data**, so App Store Connect must be answered "Data Not Collected" across the board. Apple defines "collect" as transmitting off the device, and explicitly says data processed only on device is not collected and need not be disclosed ([App privacy details](https://developer.apple.com/app-store/app-privacy-details/)). This holds only while the app stays on-device: `DefaultSiftAPIClient` is currently dead code and the live path uses `FinanceKitAPIClient`. **If a backend is ever wired up, financial data becomes genuinely collected** — the manifest, these answers, and `SeedDataTests.releaseReadinessArtifactsExist` must all be revisited together.
- Release day: verify CI green, backend `/ready` reachable, Plaid Sandbox smoke passes, guided-only flag state is correct, support email works, legal URLs are live, and the App Store build matches the tested archive.

## Ops Endpoints

- `GET /health`: public liveness with `{ ok, service, version, build, timestamp }`; no secrets or environment details.
- `GET /ready`: deploy readiness with `{ ok, database, timestamp }`; returns `503` when Postgres is unavailable.
- Backend startup logs may include service, version/build, port, node env, Plaid environment, webhook configured boolean, and concierge enabled boolean only.

## Security Checklist

- Plaid secret exists only in backend environment variables.
- Plaid access tokens are encrypted at rest and never returned in API responses.
- Backend logs include request IDs and redact auth headers, public tokens, link tokens, secrets, client secrets, and encrypted access token fields.
- API responses for errors use `{ "error": { "code", "message" } }`.
- Backend queries remain scoped by authenticated `userId`.
- `.env` files are not committed; `.env.example` contains placeholders only.

## Final Review

- Generate Xcode Privacy Report from an App Store archive and compare it to the privacy answers above.
- Verify Reduce Motion and Reduce Transparency settings on device or simulator.
- Verify Dynamic Type at the largest accessibility sizes on onboarding, dashboard, subscription detail, cancellation, settings, and privacy screens.
- Verify VoiceOver rotor order and labels for the tab bar, money figures, cancellation buttons, settings rows, and destructive data deletion flow.
- Review `docs/PRIVACY_POLICY_DRAFT.md` and `docs/TERMS_DRAFT.md` with counsel.
- Host approved legal pages at `https://sift.app/privacy` and `https://sift.app/terms`, or update the Settings legal URLs before archive.
