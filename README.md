# Sift

Sift is a fully on-device SwiftUI finance app. It reads recurring subscription charges from the user's own financial data with Apple's **FinanceKit**, detects the recurring ones, and helps the user cancel through a guided walkthrough — with no backend server and no third-party data broker.

## Layout

- `docs/` contains the build pack, visual mockup, and phase specs.
- `ios/` contains the SwiftUI app, the FinanceKit ingestion layer, and the design system.

## Architecture

The app is 100% Swift and runs entirely on device:

- **Data source:** `FinanceKit` reads the user's real Apple Card, Apple Cash, and Apple Pay transactions on device (`ios/Sift/Integrations/FinanceKitStore.swift`). Nothing leaves the phone.
- **Ingestion:** A framework-free layer (`ios/Sift/Core/FinanceKit/`) maps those transactions into the domain model and feeds the existing recurring-charge detection engine.
- **Persistence:** `SwiftData` stores accounts, transactions, and detected subscriptions locally.
- **No server:** there is no backend, no API keys, and no bank credentials anywhere in the app or repo.

## FinanceKit requirements

FinanceKit data only appears on a real device once these are in place:

1. The `com.apple.developer.financekit` entitlement is granted to the app's bundle ID by Apple (requested through your Developer account).
2. The build runs on a real iPhone (iOS 17.4+) in a supported region with Apple Card / Apple Cash / Apple Pay activity.
3. The user grants access at the FinanceKit permission prompt.

Where FinanceKit is unavailable (Simulator, unentitled builds, no Wallet data) the app degrades gracefully to an empty state, and preview/test builds use seeded sample data.

## Verification Commands

From `ios/`:

```sh
xcodebuild -scheme Sift -destination 'platform=iOS Simulator,name=iPhone 16 Pro' build
xcodebuild test -scheme Sift -destination 'platform=iOS Simulator,name=iPhone 16 Pro'
swiftformat --lint .
swiftlint
```

CI enforces an 80% scoped iOS coverage floor for `Core/` and view model files from Xcode coverage reports.

## Notes

No bank credentials are ever stored or transmitted. All financial data is read on device through FinanceKit under the user's explicit permission.
