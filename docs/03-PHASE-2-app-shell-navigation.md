# Phase 2 — App shell & navigation

Fresh task. **Prerequisite:** Phase 1 merged (design system + gallery build green).

## Goal
Replace the gallery root with the real **app shell**: a glass tab bar driving three tabs (Home, Subscriptions, Insights), per-tab navigation stacks, a global app-state object, and a routing layer that can present the subscription detail sheet and the cancellation flow as overlays/sheets. Screens are placeholders this phase — the skeleton and navigation must be correct and animated.

## Context
- Components from `@ios/Sift/DesignSystem/` (GlassTabBar, FloatingActionBar, sheets).
- Navigation targets come from the screen inventory in `@docs/` (B1–B4 tabs; B3 detail sheet; C1–C5 cancel flow; D1–D4 settings reachable from a profile entry).
- State framework: Observation (`@Observable`), per `AGENTS.md`.

## Constraints
- Use `TabView` with the native iOS 26 tab styling so the bar gets real Liquid Glass; wrap each tab in its own `NavigationStack`. Confirm the iOS 26 `TabView`/`Tab` API.
- A single `@MainActor @Observable final class AppModel` holds: selected tab, navigation paths per tab, and presentation state (which sheet is up). Injected via `.environment`.
- Routing is **type-safe**: a `Route` enum per stack (e.g. `SubscriptionsRoute.detail(id:)`), pushed onto `NavigationPath`. Sheets driven by an optional `enum Sheet` on `AppModel`.
- No business logic here; placeholder views show only their title and a sample component so navigation is visible.
- Deep-link-ready: `AppModel.handle(_ deepLink:)` stub that can select a tab and push a route (used later by notifications in Phase 10).

## Detailed tasks
1. `App/SiftApp.swift`: `@main`, creates `AppModel`, injects environment, sets `RootView` as root.
2. `App/AppModel.swift`: observable state as above + intents (`select(tab:)`, `present(_ sheet:)`, `dismissSheet()`, `push(_ route:in:)`).
3. `App/RootView.swift`: `TabView` bound to `appModel.selectedTab`; three `Tab`s with title + SF Symbol, each hosting a `NavigationStack(path:)`. Apply the glass tab styling.
4. Tab roots (placeholders): `Features/Home/HomeView.swift`, `Features/Subscriptions/SubscriptionsView.swift`, `Features/Insights/InsightsView.swift` — each a titled scaffold with a `.navigationTitle` and one sample card.
5. Routing: `Navigation/Routes.swift` (per-stack `Route` enums + `Sheet` enum), `.navigationDestination(for:)` wiring in each stack, `.sheet(item:)` for detail + cancel presented from `AppModel`.
6. Sheet host: `Features/SubscriptionDetail/DetailSheetView.swift` placeholder presented as a sheet with a grab handle and the glass surface; a button inside that triggers the cancel flow sheet (C1 placeholder).
7. Settings entry: a profile toolbar button on Home that pushes the (placeholder) Settings stack.
8. Wire `prefers-reduced-motion` to disable custom transition animations.

## Tests to write first
- `AppModelTests`: `select(tab:)` updates state; `present`/`dismissSheet` toggle the sheet; `push(_:in:)` appends to the correct path.
- `RoutingTests`: each `Route`/`Sheet` case is `Hashable`/`Identifiable` and maps to a destination (no missing `navigationDestination`).
- A UI smoke test (XCUITest): app launches on Home, tapping each tab changes the visible title; opening and dismissing the detail sheet works.

## Done when
- App launches into a working 3-tab shell with a glass tab bar; tabs switch; back navigation works; detail and cancel sheets present and dismiss.
- All Phase 1 + Phase 2 tests pass; build and lint clean.
- No feature logic present; only navigation + placeholders.

## Guardrails
Keep screens as placeholders — real content is Phases 5–9. Don't introduce a navigation library; use SwiftUI `NavigationStack`/`TabView`. Don't let `AppModel` reach into networking or persistence yet.
