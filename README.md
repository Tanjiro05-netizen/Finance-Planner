# Sift

Sift is a SwiftUI finance app that detects recurring subscription charges from read-only bank transactions and helps users cancel through concierge or guided paths.

## Layout

- `docs/` contains the build pack, visual mockup, and phase specs.
- `ios/` contains the SwiftUI app and design system.
- `backend/` contains the Plaid, transaction sync, privacy, and cancellation API.

## Verification Commands

From `ios/`:

```sh
xcodebuild -scheme Sift -destination 'platform=iOS Simulator,name=iPhone 16 Pro' build
xcodebuild test -scheme Sift -destination 'platform=iOS Simulator,name=iPhone 16 Pro'
swiftformat --lint .
swiftlint
```

CI also enforces an 80% scoped iOS coverage floor for `Core/` and view model files from Xcode coverage reports.

From `backend/`:

```sh
npm run typecheck
npm run lint
npm test
npm run db:validate
```

## Notes

The Plaid secret is backend-only. Do not add API keys or bank credentials to the app or repository.
