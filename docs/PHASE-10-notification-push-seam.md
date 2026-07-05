# Phase 10 Notification Push Seam

Sift schedules local notifications for the MVP, but the payload contract is intentionally reusable for APNs.

- `NotificationContentBuilder` owns notification copy and `userInfo` payloads.
- `SiftNotificationPayload` decodes `userInfo` into `DeepLink`.
- `NotificationRouter` is the single tap-routing path for local notifications and future push notifications.
- `NotificationScheduler` is the local-only adapter that turns repository state into `UNNotificationRequest`s.

A future server-push implementation should emit the same `userInfo` keys (`type`, optional `subscriptionID`) and route through `NotificationRouter` on receipt. Server push should not duplicate the deep-link mapping or notification category semantics.
