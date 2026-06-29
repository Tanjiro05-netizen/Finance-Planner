# Sift — Codex Build Pack · START HERE

This pack builds **Sift**, an iOS app that auto-detects subscriptions from a user's bank transactions and helps them cancel. It is split into one foundation file (`AGENTS.md`) and **11 phase specs**. Feed them to Codex **one at a time, in order**, each as its **own fresh task/thread** (Codex degrades when one thread carries a whole project).

---

## The golden workflow

1. **Create the repo and commit `01-AGENTS.md` as `/AGENTS.md` first.** Codex auto-loads it on every task, so all durable rules (stack, conventions, design tokens, security) live there — not in your prompts.
2. **Run each phase spec as a separate Codex task,** in numeric order (Phase 1 → Phase 11). Paste the phase file's body as the prompt, or commit it under `/docs/` and tell Codex `Implement @docs/PHASE-1...md`.
3. **For frontend phases, attach screenshots** of the HTML mockups (`sift-all-screens.html`). Codex uses images for UI work.
4. **Let Codex write tests first, then implement until they pass** (each phase has a "Tests to write first" block). Don't accept work until the "Done when" commands pass.
5. **Screenshot/commit after each green phase.** If a session goes sideways, start a fresh thread rather than fighting context rot.

## Recommended Codex settings

- Model: the current Codex model (e.g. `gpt-5.3-codex` / latest). Reasoning effort **high** for Phases 5–8 (backend, detection, core screens), **medium** elsewhere.
- Approvals: allow file writes and test runs in the repo sandbox; otherwise Codex stalls asking permission for routine work.
- Use the IDE extension or CLI so Codex can run `xcodebuild`/`npm test` itself and see results.

## Every prompt follows OpenAI's 4-part shape

Each phase is already written in this structure — keep it if you rewrite anything:

- **Goal** — the outcome, not the steps.
- **Context** — which files, docs, screenshots matter (`@mentions`).
- **Constraints** — conventions and hard rules Codex must respect.
- **Done when** — the verifiable end state (tests pass, build succeeds).

---

## The stack (locked — see AGENTS.md for detail)

- **iOS app:** SwiftUI, Swift 6 (strict concurrency), iOS 26 SDK, native Liquid Glass APIs, `@Observable` view models, **SwiftData** persistence, URLSession async/await. Plaid **LinkKit** via SPM.
- **Backend:** Node.js + TypeScript + Express, **Plaid Node SDK**, Postgres via Prisma. Holds the Plaid secret and all third-party calls. The app never sees the Plaid secret.
- **Repo layout (monorepo):**
  ```
  /AGENTS.md
  /docs/            ← these phase specs + Design.md + mockups
  /ios/             ← Xcode project (Sift.xcodeproj), AGENTS.md override
  /backend/         ← Node service, AGENTS.md override
  ```

## Phase map

| # | File | Builds |
|---|------|--------|
| — | `01-AGENTS.md` | Repo-root durable guidance (commit first) |
| 1 | `02-PHASE-1-scaffold-design-system.md` | Xcode project, design tokens, Liquid Glass component library |
| 2 | `03-PHASE-2-app-shell-navigation.md` | Tab bar, routing, app state |
| 3 | `04-PHASE-3-models-persistence.md` | SwiftData models, repositories, seed data |
| 4 | `05-PHASE-4-backend-plaid-service.md` | Node backend: Plaid link/exchange/sync, concierge API |
| 5 | `06-PHASE-5-onboarding-account-linking.md` | Setup flow A1–A9 + Plaid Link |
| 6 | `07-PHASE-6-detection-engine.md` | Recurring-charge detection algorithm + tests |
| 7 | `08-PHASE-7-core-screens.md` | Dashboard, Subscriptions, Detail, Insights (B1–B4) |
| 8 | `09-PHASE-8-cancellation-flow.md` | Cancel fork C1–C5, concierge + guided |
| 9 | `10-PHASE-9-settings-management.md` | Settings, linked accounts, alerts, categories (D1–D4) |
| 10 | `11-PHASE-10-notifications.md` | Renewal / price / trial notifications |
| 11 | `12-PHASE-11-testing-polish-release.md` | Tests, a11y, performance, App Store prep |

> **Legal note baked into the build:** the Plaid client secret stays server-side; the app stores no bank credentials; "cancel" is implemented as the two real paths (concierge request + guided steps), never as a fake universal cancel API. These are enforced in AGENTS.md guardrails.
