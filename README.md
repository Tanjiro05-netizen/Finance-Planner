# Sift

Sift is a SwiftUI finance app that detects recurring subscription charges from read-only bank transactions and helps users cancel through concierge or guided paths.

## Layout

- `docs/` contains the build pack, visual mockup, and phase specs.
- `ios/` contains the SwiftUI app and design system.
- `backend/` is reserved for the Phase 4 Plaid service.

## Phase 1 Commands

From `ios/`:

```sh
xcodebuild -scheme Sift -destination 'platform=iOS Simulator,name=iPhone 16 Pro' build
xcodebuild test -scheme Sift -destination 'platform=iOS Simulator,name=iPhone 16 Pro'
swiftformat --lint .
swiftlint
```

## Notes

The Plaid secret is backend-only. Do not add API keys or bank credentials to the app or repository.
