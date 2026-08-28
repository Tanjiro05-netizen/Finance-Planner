# Sift Privacy Policy Draft

**Draft for counsel review. Not legal advice. Do not publish until reviewed and approved by qualified counsel.**

*Last updated: [DATE BEFORE PUBLISHING]*

## The short version

Sift keeps your financial data on your iPhone. There is no Sift account, no Sift server, and no copy of your transactions anywhere but your own device. We cannot see your data, because it is never sent to us.

## What Sift does

Sift reads your Apple Card, Apple Cash and Apple Pay activity — with your explicit permission, through Apple's FinanceKit framework — and uses it to find recurring subscriptions, track budgets and savings goals, and work out how much you can safely spend before your next payday.

## What Sift collects

**Nothing.**

Apple defines "collect" as transmitting data off the device in a way that lets a developer access it. Sift does not transmit your financial data anywhere. It is read on your iPhone, processed on your iPhone, and stored on your iPhone.

That means we hold no database of your spending, no account for you, and nothing to hand over, sell, or lose in a breach.

## What is stored on your device

All of this stays local, in Apple's on-device storage, and is removed when you delete the app or use the deletion option in Settings:

- Transactions read from Apple Wallet: merchant name, amount, date, pending status, category
- Account names, types and balances
- Subscriptions, bills and recurring income that Sift detected, plus any you added or edited yourself
- Budgets, savings goals, and goal contributions
- Categories and categorisation rules
- Notification preferences and onboarding state

## Bank credentials

Sift never asks for, receives, or stores your bank username, password, or card numbers. Access to your financial data is granted by you through Apple's own permission prompt and can be revoked at any time in iOS Settings.

## Artificial intelligence

Where your device supports it, Sift can write short summaries of your finances and answer questions about them. This runs entirely on your iPhone using Apple's on-device Foundation Models.

Your financial figures are not sent to any AI service, ours or anyone else's. Sift does not use cloud-based AI — including Apple's Private Cloud Compute — for anything involving your financial data.

## Tracking, advertising and analytics

Sift does not track you across other apps or websites, does not show advertising, does not use App Tracking Transparency (because there is no tracking to request), and does not collect usage analytics. Sift does not sell personal data, because it does not have any.

## Sharing

Sift shares your data with no one. There are no service providers, data aggregators, hosting providers, or advertising partners involved in handling your financial information, because that information never leaves your device.

## Deleting your data

Settings → Privacy & data → delete. This removes Sift's local data from your device. Deleting the app removes everything.

Because we hold nothing, there is no separate request to make of us and no server-side copy to wait on.

## Notifications

Renewal reminders, price-change alerts and similar notifications are scheduled locally by your iPhone. Their contents are not sent through any server.

## Children

Sift is not directed at children under 13 and should not be used by them.

## Changes to this policy

If Sift's handling of data ever changes — in particular, if any feature begins sending data off the device — this policy will be updated before that feature ships, and the change will be described here.

## Contact

JinbuJYG@proton.me

---

## Notes for counsel and for engineering — remove before publishing

**These claims are verifiable in the codebase and must be re-verified before each release:**

- The live path uses `FinanceKitAPIClient` (`ios/Sift/Core/FinanceKit/FinanceKitAdapters.swift`), which has no `URLSession` and makes no network calls.
- `DefaultSiftAPIClient` — a full HTTP client with a Plaid-oriented API — **exists in the codebase but is never instantiated**. It is dead code retained for a possible future backend. If it is ever wired up, this policy becomes false and must be rewritten first.
- Analytics is `NoopAnalyticsRecorder` at every wiring point.
- AI uses `SystemLanguageModel.default` only; `PrivateCloudComputeLanguageModel` is deliberately not used (`ios/Sift/Integrations/FoundationModelsConversation.swift`).
- `PrivacyInfo.xcprivacy` declares no collected data types, and `SeedDataTests.releaseReadinessArtifactsExist` asserts that no such declaration exists — so wiring a backend fails the test suite and forces this document to be reconsidered.

**Still needs counsel input:** governing law, jurisdiction, GDPR/UK GDPR lawful-basis framing if distributing in the UK, CCPA/CPRA disclosures for California, breach-notification language, and whether any retention statement is needed given that no data is retained by us.

**Note on concierge cancellation:** if concierge is ever enabled, it requires a server and an account, and personal data would then genuinely be collected. This policy would need substantial revision at that point, not a small amendment.
