# Sift Release Checklist

Release readiness for TestFlight and App Store submission.

**This app is on-device only.** It reads Apple Card, Apple Cash and Apple Pay activity
through FinanceKit, stores everything locally in SwiftData, and transmits nothing. There is
no backend, no account, and no Plaid integration on the live path. Earlier revisions of this
checklist described a Plaid-and-server architecture that no longer exists; anything below
that still smells of one is a bug in this document.

Legal statements here are implementation notes. Final policy, terms, and App Store Connect
answers require counsel review.

## Blocking prerequisites

These gate everything else and are not code:

- **FinanceKit entitlement granted by Apple.** Requested per bundle ID at
  <https://developer.apple.com/contact/request/financekit>. Requires an *organization*
  Apple Developer account, submitted by the Account Holder, for an app in the Finance
  category distributed in the US or UK. Weeks of lead time — start first.
- **`DEVELOPMENT_TEAM` set** in `ios/Sift.xcodeproj`. Empty means no archive, no upload.
- **Bundle ID registered** and matching `PRODUCT_BUNDLE_IDENTIFIER`, plus
  `BGTaskSchedulerPermittedIdentifiers` in `Info.plist`.
- **Legal pages live** — see "Legal pages" below.

## Build gates

- iOS CI passes on `macos-26`: `swiftformat --lint .`, `swiftlint` (from the repo root, so
  the custom design-system rules load), `xcodebuild build`, `xcodebuild test`.
- Coverage floor: scoped iOS line coverage for `ios/Sift/Core/` plus `*ViewModel.swift`
  files is at least 80%, enforced by `scripts/check-ios-coverage.js`.
- **Device smoke on real hardware.** The FinanceKit path cannot be exercised in the
  Simulator or on CI. On a real iPhone with real Apple Card/Cash/Pay activity: grant the
  permission, confirm transactions import, confirm detection produces sensible
  subscriptions, and confirm safe-to-spend matches reality. Also run once *declining* the
  permission and confirm the app degrades rather than breaking.

## Feature flags

Every flag in `SiftFeatureFlags` defaults to **off**, and `SiftFeatureFlags.current()` reads
launch arguments and environment variables — **neither of which exists in a TestFlight
build**. Flags can only be enabled for testers by changing the defaults in code.

Decide the beta scope explicitly and record it here before each build:

| Flag | State | Notes |
|---|---|---|
| `ledgerEnabled` | | Transactions tab, safe-to-spend |
| `budgetsEnabled` | | Budgets and affordability check |
| `goalsEnabled` | | Savings goals |
| `insightNarrationEnabled` | | On-device written insights |
| `assistantEnabled` | | Ask tab |
| `conciergeEnabled` | **off** | No backend exists to service it; the UI reports it as unavailable |

## App Store assets

- App icon: `ios/Sift/Resources/Assets.xcassets/AppIcon.appiconset`.
- Launch screen: `UILaunchScreen` in `ios/Sift/Resources/Info.plist`.
- Privacy manifest: `ios/Sift/Resources/PrivacyInfo.xcprivacy`, included in target resources.
- `ITSAppUsesNonExemptEncryption` is set to `false`, so no export-compliance prompt per upload.
- Screenshots: capture from mock-service builds, not static mockups. No real bank or
  merchant logos, no live customer data.
- App Store category must be **Finance** — this is a FinanceKit entitlement requirement,
  not a preference.

## App Store Connect privacy answers

**Answer "Data Not Collected" across the board.**

Apple defines "collect" as transmitting data off the device in a way that lets the developer
access it, and states that data processed only on device is not collected and need not be
disclosed ([App privacy details](https://developer.apple.com/app-store/app-privacy-details/)).
Nothing here is transmitted, so nothing is collected.

`PrivacyInfo.xcprivacy` matches: it declares an empty `NSPrivacyCollectedDataTypes`, and
`SeedDataTests.releaseReadinessArtifactsExist` asserts no collected-data declaration exists.

- Tracking: **No.** No cross-app or cross-site tracking; ATT is not used because there is
  nothing to request.
- Required-reason APIs: UserDefaults only, reason `CA92.1`. Verified against the five
  categories; nothing else applies.

**If a backend is ever wired up, this section becomes false.** `DefaultSiftAPIClient` exists
as dead code and is never instantiated. The moment it is, financial data becomes genuinely
collected, and the manifest, these answers, the privacy policy and that test must all be
revisited together.

## Legal pages

Published from `site/` to GitHub Pages by `.github/workflows/pages.yml`:

- <https://tanjiro05-netizen.github.io/Finance-Planner/privacy/>
- <https://tanjiro05-netizen.github.io/Finance-Planner/terms/>

The app builds these URLs in `ios/Sift/Core/Domain/LegalLinks.swift` — the only place the
host, base path and support address are defined.

- Pages source must be set to **GitHub Actions** in repository settings (one time).
- The deploy workflow fails while any `REPLACE_WITH_` placeholder remains, so an unfinished
  policy cannot go live.
- Verify both URLs return 200 before submitting. App Review checks the privacy policy URL
  and rejects builds where it 404s.
- Counsel must approve the published text. See the notes at the bottom of
  `docs/PRIVACY_POLICY_DRAFT.md` and `docs/TERMS_DRAFT.md`.

## TestFlight operations

- Beta support email: `JinbuJYG@proton.me`.
- Beta app description: "Sift reads your Apple Card, Apple Cash and Apple Pay activity on
  your iPhone to find recurring subscriptions, track budgets and savings goals, and show
  what you can safely spend before payday. Everything stays on your device."
- **Review notes must state the hardware and region requirement.** FinanceKit only returns
  data on a real iPhone, in the US or UK, for an account with Apple Card / Apple Cash /
  Apple Pay activity. There is no sandbox and no test credentials. A reviewer on a device
  without that activity will see empty states, and the notes must say so plainly or the
  build will be rejected as non-functional.
- Features to test: onboarding and permission grant, transaction import, recurring
  detection, dashboard, subscriptions, insights, guided cancellation, manual bills and
  income, budgets, goals, notification opt-in, and data deletion.
- Guided-only disclosure: concierge cancellation is not staffed and the app presents it as
  unavailable. Nothing in the listing may imply Sift cancels subscriptions on someone's
  behalf.
- Tester reminder: never submit account numbers, transaction contents, or screenshots
  containing real financial data in TestFlight feedback or support email.

## Launch runbooks

- Internal beta: upload a release build, assign internal testers, smoke test onboarding
  through deletion on real hardware.
- External beta: submit one build to TestFlight review with the metadata above, invite a
  small cohort first, expand after crash-free smoke and feedback triage.
- Build promotion: promote only the exact build that passed CI, device smoke, and privacy
  review. Record the build number here before release.
- Rollback: expire the affected TestFlight build in App Store Connect and notify testers
  with a calm status update. There is no server to roll back.
- Feedback triage: classify as blocker, release fix, v1.1 feature, legal/privacy, or
  support. Do not ask testers for sensitive financial details.
- Support response: acknowledge within one business day during beta; include the app
  version/build from Settings → Support.
- Release day: CI green, legal URLs live and returning 200, feature flag states correct for
  the build, support email receiving, and the App Store build matching the tested archive.

## Security notes

There is no backend, so the usual server checklist does not apply. What remains:

- No secrets or API keys anywhere in the repo, the app, or tests.
- Bank credentials are never requested, received, or stored — access is granted through
  Apple's own permission prompt and revocable in iOS Settings.
- Local data is protected by the device passcode and, when enabled, the app lock
  (`LocalAuthenticationGate`).
- AI inference uses `SystemLanguageModel.default` only. `PrivateCloudComputeLanguageModel`
  is deliberately not used — it would send financial data to Apple's servers.
- `.env` files are not committed.

## Final review

- Generate the Xcode Privacy Report from an App Store archive and compare it against the
  privacy answers above.
- Verify Reduce Motion and Reduce Transparency on device.
- Verify Dynamic Type at the largest accessibility sizes on onboarding, dashboard,
  subscription detail, cancellation, insights, settings, and the privacy screens.
- Verify VoiceOver rotor order and labels for the tab bar, money figures, cancellation
  buttons, settings rows, and the destructive deletion flow.
- Review `docs/PRIVACY_POLICY_DRAFT.md` and `docs/TERMS_DRAFT.md` with counsel.
- Confirm the published legal pages match the counsel-approved text.
