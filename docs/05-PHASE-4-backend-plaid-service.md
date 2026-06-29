# Phase 4 — Backend service (Plaid + concierge API)

Fresh task. **Prerequisite:** Phase 3 merged. This phase is **backend only** (`/backend`). Use reasoning effort **high**.

## Goal
Build the Node + TypeScript backend that (a) brokers Plaid securely so the iOS app never sees the Plaid secret or bank credentials, (b) syncs transactions, and (c) stores and tracks **cancellation requests** for the concierge flow. Provide a typed, validated, tested HTTP API the app will consume in later phases.

## Context
- Security rules in `@AGENTS.md`: Plaid `client_secret` server-side only; access tokens encrypted at rest, never returned to client; all queries scoped by authenticated `userId`.
- Plaid official **Node SDK** (`plaid`). Flow: backend creates a `link_token` → app opens Plaid Link → app returns a `public_token` → backend exchanges it for an `access_token` (stored) → backend pulls `/transactions/sync` → webhook notifies of new data. **Verify current Plaid SDK method names/versions before coding.**
- Consumers: Phase 5 (linking), Phase 6 (detection runs on synced transactions), Phase 8 (concierge requests).

## Constraints
- TypeScript strict; Express; **zod** validation on every request body/params; **Prisma** + Postgres; **vitest** tests; **pino** logging (never log tokens/PII). No secrets in repo: `.env` (gitignored) + `.env.example`.
- AuthN: app users authenticate with a bearer JWT (simple email-less device/account model is fine for MVP — issue a token on first launch tied to a `User`). Every data route requires a valid JWT and scopes by `userId`.
- Access tokens encrypted at rest (libsodium/`crypto` AES-GCM with a key from env). Decrypt only in-memory for Plaid calls.
- Idempotent transaction sync using Plaid's `cursor`; store the cursor per item.
- Webhooks verified (Plaid webhook verification) before processing.

## Data model (Prisma)
`User(id, createdAt)`, `PlaidItem(id, userId, accessTokenEnc, itemId, institutionName, cursor, status, createdAt)`, `Account(id, userId, plaidItemId, mask, name, type)`, `Transaction(id, userId, accountId, plaidTxnId, merchantName, amountMinor, isoCurrency, date, pending, category)`, `CancellationRequest(id, userId, subscriptionRef, merchantName, method, status, note, createdAt, updatedAt)`. Indexes on `userId`, `accountId`, `date`.

## API (document in `/backend/README.md` and an OpenAPI `openapi.yaml`)
- `POST /v1/auth/bootstrap` → `{ token }` (creates/returns a User + JWT).
- `POST /v1/plaid/link-token` (auth) → `{ link_token }`.
- `POST /v1/plaid/exchange` (auth) `{ public_token }` → `{ ok: true }` (exchanges, stores item + accounts; **never returns the access token**).
- `POST /v1/transactions/sync` (auth) → runs `/transactions/sync`, upserts transactions, returns `{ added, modified, removed, hasMore }` counts (no raw token).
- `GET /v1/accounts` (auth) → linked accounts (safe fields only).
- `GET /v1/transactions?since=` (auth) → user's transactions (paginated).
- `POST /v1/webhook/plaid` (no auth, signature-verified) → marks items needing sync.
- `POST /v1/cancellations` (auth) `{ subscriptionRef, merchantName, method }` → creates request (status `requested`).
- `GET /v1/cancellations` (auth) → list with statuses.
- `PATCH /v1/cancellations/:id` (auth/admin) → advance status (`contacting`, `confirmed`, `needsUser`).
All responses: success `{ data }`; error `{ error: { code, message } }` with proper status.

## Detailed tasks
1. Scaffold: `package.json` scripts (`dev`, `test`, `lint`, `typecheck`, `db:migrate`), `tsconfig` strict, Prisma schema + first migration, Express app factory (`createApp()` for tests), pino logger, error middleware, zod validation middleware, JWT middleware.
2. `services/plaidService.ts`: link-token creation, public-token exchange, transactions sync (cursor loop), webhook verification — all secrets from env, tokens encrypted via `services/crypto.ts`.
3. `services/cancellationService.ts`: create/list/advance requests.
4. Routes thin → services → Prisma repositories.
5. Seed/dev: a `sandbox` mode using Plaid Sandbox credentials so the whole flow works without real banks; document Sandbox test institution + credentials in README.
6. Dockerfile + `docker-compose.yml` (Postgres + app) for local run.

## Tests to write first (vitest, against the app factory + a test Postgres or Prisma SQLite)
- Auth: protected routes 401 without token; 200 with.
- `exchange`: given a mocked Plaid client returning an access token, the response body **never contains the token**; DB stores it **encrypted** (assert ciphertext ≠ plaintext, decrypts back).
- `transactions/sync`: cursor advances; idempotent re-sync adds 0 duplicates.
- `webhook`: invalid signature → 400; valid → 200 and item flagged.
- `cancellations`: create → list shows `requested`; PATCH advances status; cross-user access is denied (user A cannot read user B's requests).
- crypto round-trip test.

## Done when
- `npm ci && npm run typecheck && npm run lint && npm test` all pass; `docker-compose up` runs the API; the **Plaid Sandbox** link→exchange→sync flow completes end-to-end (documented curl sequence in README).
- No secret or token is ever logged or returned to the client (grep + tests confirm).

## Guardrails
Do not put any Plaid secret in the iOS app or in client responses. Do not store access tokens in plaintext. Do not implement real third-party cancellation integrations — `CancellationRequest` is a tracked record only. Confirm Plaid SDK method names against the installed version before using them.
