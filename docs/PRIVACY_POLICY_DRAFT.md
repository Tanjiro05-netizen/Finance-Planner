# Sift Privacy Policy Draft

Draft for counsel review. This document is not legal advice and must not be published until reviewed and approved by qualified counsel.

## What Sift Does

Sift helps users identify recurring subscription charges from read-only bank transaction data and manage cancellation steps. Sift connects to financial institutions through Plaid. Bank credential entry happens only inside Plaid Link; Sift does not receive or store bank usernames or passwords.

## Data We Collect

- Account connection metadata, such as institution name, account type, account mask, and connection status.
- Read-only transaction data needed to detect recurring charges, including merchant name, amount, currency, date, pending state, and category.
- Subscription records derived from transaction data, such as merchant, cadence, amount, renewal date, and cancellation status.
- App session identifiers used to authenticate requests.
- Cancellation request metadata if a user starts a guided or concierge cancellation.
- Notification preferences and onboarding state stored locally on the device.

## How We Use Data

- To provide account linking, transaction sync, recurring-charge detection, subscription dashboards, guided cancellation steps, reminders, and data deletion.
- To secure the service, troubleshoot failures, and maintain reliable backend operations.
- To support privacy-safe product analytics only when implemented without transaction contents, account names, bank credentials, Plaid access tokens, or other sensitive financial details.

## Plaid

Sift uses Plaid as the data aggregator for read-only financial data access. Plaid may process information under its own privacy practices. Sift receives a Plaid public token from Plaid Link and exchanges it server-side. Plaid access tokens are encrypted at rest and are never returned to the iOS app.

## Tracking And Advertising

Sift does not track users across other companies' apps or websites, does not sell personal data, and does not use App Tracking Transparency because no tracking is performed.

## Data Sharing

Sift shares data only with service providers necessary to operate the app, such as Plaid and hosting providers. Sift does not share bank credentials because Sift never receives them.

## Data Retention And Deletion

Users can request deletion in Settings > Privacy & data. Deletion revokes linked Plaid items where possible and deletes local Sift data for the authenticated user. Backup and legal retention details require counsel review before publication.

## Security

Sift uses server-side Plaid calls, encrypted token storage, authenticated user-scoped backend queries, and log redaction for secrets and token fields. No system can be guaranteed perfectly secure; incident response language requires counsel review.

## Contact

Add final support and legal contact details before publication.
