# Detection Engine

`DetectionEngine` is a pure, deterministic pass over plain `Txn` values. It does not read SwiftData, perform network work, or call `Date()`; callers pass a `referenceDate`.

## Pipeline

1. Normalize merchant names with `MerchantNormalizer`.
   - Known aliases map noisy labels such as `NETFLIX #4471 LOS GATOS` and `Netflix.com` to a stable `MerchantKey("Netflix")`.
   - Generic cleanup lowercases, removes store numbers/card-network noise/common suffixes, and trims common trailing location tokens.
2. Group transactions by normalized merchant key.
3. Infer recurrence from inter-charge intervals.
   - Weekly: 6-8 days.
   - Monthly: 28-33 days.
   - Quarterly: 84-98 days.
   - Yearly: 350-380 days.
   - Yearly streams can surface from two charges; shorter cadences need at least two matching intervals.
4. Score confidence from occurrence count, interval regularity, amount stability, and a known-merchant bonus. Candidates below `0.60` are suppressed.
5. Pick the current recurring amount from the latest sustained amount segment, so a real price step becomes the candidate price.
6. Emit sustained price changes when two or more charges at one amount are followed by two or more charges at a materially different amount.
7. Compute `nextRenewal` by advancing from the last charge by cadence until it is after the supplied `referenceDate`.
8. Flag likely trials when an initial free or very-low charge is followed by repeated standard charges.

## Unused Signal

Sift does not yet ingest app-usage or engagement data. For MVP, detected candidates expose `lastUsed == nil` and `isUnused == false` rather than inventing usage. Users and later product signals can mark subscriptions unused; the repository layer still supports `lastUsed`-based unused queries for seeded and user-confirmed data.

## Persistence

`LiveDetectionService` uses `DetectionPersistenceActor`, a SwiftData `ModelActor`, to load persisted transactions, run the pure engine, reconcile subscriptions by merchant key, mark stopped streams as cancelled, and persist `PriceChange` events without duplicating existing events.
