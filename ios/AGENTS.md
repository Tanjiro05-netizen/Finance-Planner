# iOS Override

- Follow the root `AGENTS.md` stack and design system rules.
- Keep SwiftUI views small and composable; extract repeated UI into `Sift/DesignSystem`.
- Use Observation (`@Observable`, `@State`, `@Environment`) for state. Do not introduce Combine or `ObservableObject`.
- Use native iOS 26 Liquid Glass APIs only through `GlassSurface` unless a later phase explicitly needs a lower-level glass transition.
- Keep feature implementation out of Phase 1; the temporary root is the component gallery.
