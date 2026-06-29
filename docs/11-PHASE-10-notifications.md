# Phase 10 — Notifications (renewals, price changes, trials, nudges)

Fresh task. **Prerequisite:** Phases 6 (detection signals), 9 (alert settings) merged.

## Goal
Deliver the proactive value that makes Sift sticky: timely notifications for upcoming renewals, price changes, free-trial endings, unused-subscription nudges, and an optional weekly summary — each gated by the user's `AlertSettings`, each deep-linking to the right screen. Local notifications for MVP, with a clean path to server push later.

## Context
- Signals come from the detection engine (Phase 6): `nextRenewal`, `PriceChange`, `trialEnding` flags, `unused` status. Toggles from `AlertSettings` (Phase 9). Deep-linking via `AppModel.handle(deepLink:)` (Phase 2). Backend webhook (Phase 4) can trigger re-sync.

## Constraints
- Use `UNUserNotificationCenter` for **local** scheduling (MVP). Architect a `NotificationScheduler` so a future APNs server push can reuse the same payload→route mapping. Don't build the push server now, but leave the seam + document it.
- Every scheduled notification respects the corresponding `AlertSettings` flag at schedule time **and** is cancelled if the user later turns the flag off or the underlying subscription is cancelled.
- Reminders: renewal reminder = 2 days before `nextRenewal` (configurable constant); trial-ending = before the trial converts; weekly summary = Sunday local time. Quiet, non-alarmist copy with exact figures.
- Re-scheduling is idempotent: re-running after a sync updates/removes stale notifications without duplicates (use stable identifiers, e.g. `renewal-<subscriptionID>`).
- Tapping a notification routes precisely: renewal/trial → that subscription's detail; price change → Insights; weekly summary → Dashboard.

## Detailed tasks
1. `Notifications/NotificationScheduler.swift`: builds `UNNotificationRequest`s from domain signals; stable identifiers; cancel/replace logic; reads `AlertSettings`.
2. `Notifications/NotificationContentBuilder.swift`: copy + `userInfo` payload encoding a `DeepLink` (e.g. `{type:"renewal", subscriptionID:…}`).
3. `Notifications/NotificationRouter.swift`: `UNUserNotificationCenterDelegate` decoding `userInfo` → `AppModel.handle(deepLink:)`; handle foreground presentation.
4. Hook scheduling into the pipeline: after `DetectionService.recompute()` (post-sync, post-onboarding, on account add/remove), call `scheduler.reconcile()` to (re)schedule all enabled notifications and cancel obsolete ones.
5. Cancel notifications when a subscription becomes `cancelled` (Phase 8) or a toggle is turned off (Phase 9 already persists; scheduler observes/reconciles).
6. Permission: respect the A8 onboarding authorization; if denied, show a gentle in-app banner explaining what they'll miss and a link to Settings; never nag.
7. Weekly summary: schedule a repeating Sunday notification summarizing monthly recurring total + any new detections/price changes.

## Tests to write first
- `NotificationSchedulerTests`: given subscriptions + settings, produces the expected set of requests with correct fire dates and stable IDs; disabling a flag removes its notifications; cancelling a subscription removes its renewal/trial notifications; reconcile is idempotent (no duplicates on re-run).
- `NotificationContentBuilderTests`: copy includes exact amount/date; payload round-trips to a `DeepLink`.
- `NotificationRouterTests`: each `DeepLink` type maps to the correct tab + route via a mock `AppModel`.
- XCUITest (where feasible): simulate a notification tap payload → app navigates to the expected screen.

## Done when
- Enabled alert types schedule correctly and route on tap; disabling/cancelling removes them; reconcile is idempotent; permission-denied is handled gracefully.
- The scheduler is decoupled enough that a future APNs push could reuse `NotificationContentBuilder` + `NotificationRouter` (documented seam).
- Tests, build, lint green.

## Guardrails
Honor `AlertSettings` exactly — never send a disabled category. No duplicate or stale notifications after re-sync. Don't build the push backend now, but don't paint yourself into a corner either (keep payload/route mapping reusable). Keep copy calm and exact.
