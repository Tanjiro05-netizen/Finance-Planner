# Phase 9 — Settings & management (D1–D4)

Fresh task. **Prerequisite:** Phases 3, 4, 5, 8 merged. Attach D1–D4 mockup screenshots.

## Goal
Build the management surface: profile & settings hub, linked accounts (add/remove banks, sync status), alert settings (the notification toggles), and categories & rules. Wire to repositories and backend so changes persist and affect behavior.

## Context
- Designs D1–D4 in `@docs/` (attached). Repositories from Phase 3 (`SettingsRepository`, `AccountRepository`, `CategoryRepository`); backend accounts + (re-)linking from Phase 4/5; cancellation requests list (C5) reachable here; alert toggles feed Phase 10 notifications.

## Constraints
- Settings hub reached from the Home profile button (Phase 2). View models depend on repository protocols; previews use mocks.
- Adding an account reuses the Phase 5 `PlaidLinkCoordinator` (link a second item). Removing an account calls a backend delete (add `DELETE /v1/plaid/item/:id` if missing — flag the small backend addition in the PR) and cleans up local data.
- Alert toggles persist to `AlertSettings` and are the single source of truth Phase 10 reads. Changing them takes effect immediately.
- Categories: list with counts; toggling "Auto-categorise" on/off; manual recategorise/merge of a subscription's category. Auto-categorisation uses a simple keyword map over `merchantKey`/Plaid category — document it; allow manual override that sticks.
- Privacy & data row: show what Sift stores, a "disconnect all & delete my data" action that revokes Plaid items (backend) and wipes local data, with a confirmation.

## Detailed tasks
1. **D1 Profile & settings** (`Features/Settings/SettingsHubView.swift`): avatar + name + plan label; `SettingsRow`s → Linked accounts, Notifications, Categories & rules, Cancellation requests (C5), Privacy & data. Sign-out clears Keychain + local store and returns to onboarding.
2. **D2 Linked accounts** (`LinkedAccountsView.swift`): `GET /v1/accounts`; rows with green/amber status dot + "N accounts" meta + last synced; floating glass "+ Add account"; row action to remove (with confirm) → backend delete + local cleanup + re-detect.
3. **D3 Alert settings** (`AlertSettingsView.swift`): toggle rows (Renewal reminders, Price-change alerts, Free-trial endings, Unused nudges, Weekly summary) bound to `AlertSettings`; persists immediately.
4. **D4 Categories & rules** (`CategoriesView.swift`): "Auto-categorise" toggle; category rows with counts; tapping a category lists its subscriptions; per-subscription recategorise; merge duplicates. `CategoryService` keyword map + manual overrides.
5. **Privacy & data** (`PrivacyDataView.swift`): disclosure copy + destructive "Disconnect & delete" with double-confirm; calls backend to revoke Plaid items and delete user data; wipes Keychain + SwiftData; returns to a clean onboarding.

## Tests to write first
- `AlertSettingsViewModelTests`: toggling persists; reading returns persisted values; defaults correct.
- `CategoryServiceTests`: auto-categorise maps known merchants; manual override persists and survives re-detection (not overwritten by auto).
- `LinkedAccountsViewModelTests` (mock API): remove account triggers backend delete + local cleanup + re-detect; status reflects sync state.
- `PrivacyDeleteTests`: delete action clears Keychain token, empties the store, and routes to onboarding (mock backend revoke called once).
- XCUITest: change an alert toggle and confirm it persists across relaunch; add a second account (Sandbox) and see it listed.

## Done when
- All four screens persist changes and affect behavior (alerts feed Phase 10; categories change grouping; account add/remove re-runs detection; delete wipes everything).
- Any backend additions (item delete, data delete) are implemented + tested and noted in the PR.
- Tests, build, lint green.

## Guardrails
The delete/disconnect path must truly revoke Plaid items server-side and wipe local data — no orphaned tokens. Don't let auto-categorisation clobber manual overrides. Keep `AlertSettings` the single source for notification behavior.
