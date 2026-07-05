# Sift Backend

Phase 4 backend API for Plaid Link brokering, transaction sync, account reads, and concierge cancellation request tracking.

## Local Setup

```sh
npm ci
cp .env.example .env
npm run db:migrate
npm run dev
```

Generate a 32-byte encryption key for `TOKEN_ENCRYPTION_KEY`:

```sh
openssl rand -base64 32
```

The backend stores Plaid access tokens only as AES-256-GCM ciphertext. The API never returns Plaid access tokens.

## Environment

- `DATABASE_URL`: Postgres connection string.
- `JWT_SECRET`: long random signing secret, at least 32 characters.
- `TOKEN_ENCRYPTION_KEY`: 32-byte base64 or 64-character hex key.
- `PLAID_ENV`: `sandbox`, `development`, or `production`.
- `PLAID_CLIENT_ID`: Plaid client id.
- `PLAID_SECRET`: Plaid secret. Server-side only.
- `PLAID_CLIENT_NAME`: displayed in Plaid Link, defaults to `Sift`.
- `PLAID_WEBHOOK_URL`: public webhook URL for Plaid item webhooks.
- `CONCIERGE_ENABLED`: set to `true` only when concierge cancellation operations are staffed; defaults to guided-only.
- `ADMIN_TOKEN`: optional internal token for future concierge admin tooling.

## Docker

```sh
docker compose up --build
```

The compose stack starts Postgres on `localhost:5432` and the API on `localhost:3000`.

## Verification

```sh
npm run typecheck
npm run lint
npm test
```

## API Shape

All success responses are wrapped as:

```json
{ "data": {} }
```

All errors are wrapped as:

```json
{ "error": { "code": "validation_error", "message": "..." } }
```

## Sandbox Flow

Plaid Sandbox test institution: `First Platypus Bank` (`ins_109508`).

Common Sandbox credentials:

- Username: `user_good`
- Password: `pass_good`
- MFA code: `1234` when prompted

Bootstrap a Sift user:

```sh
TOKEN=$(curl -s -X POST http://localhost:3000/v1/auth/bootstrap \
  -H 'content-type: application/json' \
  -d '{}' | jq -r '.data.token')
```

Create a Link token for the iOS app:

```sh
curl -s -X POST http://localhost:3000/v1/plaid/link-token \
  -H "authorization: Bearer $TOKEN" \
  -H 'content-type: application/json' \
  -d '{}'
```

After Plaid Link returns a `public_token`, exchange it:

```sh
curl -s -X POST http://localhost:3000/v1/plaid/exchange \
  -H "authorization: Bearer $TOKEN" \
  -H 'content-type: application/json' \
  -d '{ "public_token": "PUBLIC_TOKEN_FROM_LINK" }'
```

Sync transactions:

```sh
curl -s -X POST http://localhost:3000/v1/transactions/sync \
  -H "authorization: Bearer $TOKEN" \
  -H 'content-type: application/json' \
  -d '{}'
```

List safe account fields:

```sh
curl -s http://localhost:3000/v1/accounts \
  -H "authorization: Bearer $TOKEN"
```

List transactions:

```sh
curl -s 'http://localhost:3000/v1/transactions?limit=50&offset=0' \
  -H "authorization: Bearer $TOKEN"
```

Create a guided cancellation request:

```sh
curl -s -X POST http://localhost:3000/v1/cancellations \
  -H "authorization: Bearer $TOKEN" \
  -H 'content-type: application/json' \
  -d '{ "subscriptionRef": "sub_123", "merchantName": "Streambox", "method": "guided" }'
```

Concierge requests require `CONCIERGE_ENABLED=true`; otherwise the API returns `feature_disabled` and the iOS app presents concierge as coming soon.

## Endpoints

- `POST /v1/auth/bootstrap`
- `POST /v1/plaid/link-token`
- `POST /v1/plaid/exchange`
- `POST /v1/transactions/sync`
- `GET /v1/accounts`
- `GET /v1/transactions?since=&limit=&offset=`
- `POST /v1/webhook/plaid`
- `POST /v1/cancellations`
- `GET /v1/cancellations`
- `PATCH /v1/cancellations/:id`

See `openapi.yaml` for request and response schemas.
