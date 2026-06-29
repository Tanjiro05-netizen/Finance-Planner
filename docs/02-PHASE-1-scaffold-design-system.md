# Phase 1 — Project scaffold & design system

Run as a fresh Codex task. **Prerequisite:** `AGENTS.md` committed at repo root. Attach screenshots of `sift-all-screens.html` (any 2–3 screens) so Codex sees the target aesthetic.

## Goal
Stand up the monorepo and the iOS app skeleton, and build the **reusable Liquid Glass design-system component library** so every later screen is assembled from these parts. No feature screens yet — just the foundation and a "component gallery" preview that proves the system.

## Context
- Design tokens and rules: `@docs/Design.md` and the design-system section of `@AGENTS.md`.
- Visual target: the attached mockup screenshots. Match warmth, spacing, rounded geometry, and the frosted floating controls.
- Stack per `AGENTS.md`: SwiftUI, iOS 26, Swift 6, Observation, SwiftData (set up but unused this phase), Swift Testing.

## Constraints
- Create the repo layout from `AGENTS.md` (`/ios`, `/backend` placeholder, `/docs`). Add `ios/AGENTS.md` and `backend/AGENTS.md` override stubs.
- Bundle the three fonts (Fraunces, Plus Jakarta Sans, IBM Plex Mono) via `Info.plist` `UIAppFonts`; download the static + variable files into `ios/Sift/Resources/Fonts/`. If a font can't be fetched in-sandbox, create the registration + a `// TODO: add font file` and a fallback, and note it in the PR.
- All colors/fonts/radii come from `DesignSystem/Tokens.swift`. Nothing hardcoded elsewhere — add a SwiftLint rule forbidding raw hex literals outside Tokens.
- Liquid Glass uses the **native iOS 26 API**; verify the exact modifier names against the SwiftUI SDK before use. Provide a `GlassSurface` wrapper so the rest of the app is insulated from API churn.
- Respect `prefers-reduced-motion` in any animated component (e.g. the specular sheen → static when reduced).

## Detailed tasks
1. **Repo + tooling:** `.gitignore` (Xcode, Node, `.env`), `.swiftformat`, `.swiftlint.yml`, root `README.md`. Create `Sift.xcodeproj` (or a Swift Package + app target) with scheme `Sift`, min deploy iOS 26, Swift 6 strict concurrency on.
2. **`DesignSystem/Tokens.swift`:** `enum Palette` (Color statics for every token), `enum Radius`, `enum Spacing`, `enum Elevation` (shadow configs). `Color` init from hex helper kept `private` to this file.
3. **`DesignSystem/Typography.swift`:** a `Font` extension exposing semantic styles — `.heroFigure` (Fraunces, tabular), `.screenTitle` (Fraunces), `.body`/`.bodyEmphasis` (Plus Jakarta), `.label` / `.cadence` (IBM Plex Mono, uppercase, letter-spaced). A `MoneyText` view that renders `$247.83` with the raised half-size dollar/cents per the design.
4. **`DesignSystem/GlassSurface.swift`:** a `ViewModifier`/wrapper applying the native glass effect with the correct tint and a thin light top edge; a `.glassSurface()` convenience. Include the moving specular sheen as an optional overlay (off when reduced motion).
5. **Core components** in `DesignSystem/Components/`:
   - `SiftCard` (solid card: radius 26, line border, soft shadow).
   - `SubscriptionRow` (monogram tile + name + meta + `MoneyText` + cadence; `warn` meta style in clay).
   - `MonogramTile` (letter, solid palette color, serif glyph; size param).
   - `Pill` (up/down/neutral variants).
   - `PrimaryButton` (ink), `GoldButton`, `ClayButton`, `SecondaryButton` (bordered) — all 44pt+ tall.
   - `GlassTabBar` (3 tabs, line icons, active in gold) — purely visual here.
   - `SegmentedControlGlass`, `FloatingActionBar` (glass).
   - `StatCell`, `Toggle` styling (gold-on), `SettingsRow`, `StatusTimeline`, `NumberedStep`, `OptionCard` (rec/plain).
   - `RenewalTimelineStrip` (line + dot marks + gold "next" flag + 1/15/30 axis).
6. **Component gallery:** `DesignSystem/Gallery/ComponentGalleryView.swift` showing every component on the bone background, plus a `#Preview`. Make this the app's temporary root so the build is runnable.
7. **Icons:** thin line SF Symbols mapped in `DesignSystem/Icons.swift` (house, rectangle.stack, chart.bar, bell, lock, gear, etc.).

## Tests to write first
- `TokensTests`: hex parsing produces expected RGBA; every semantic color is defined.
- `MoneyTextTests`: `$0`, `$15.49`, `$1,247.83`, `$146/mo`, `$185.88/yr` format correctly (dollars, cents, suffix, thousands separator, tabular).
- `TypographyTests`: each semantic font resolves to the intended family (guards against missing font files / fallbacks).
- A snapshot or render test that the gallery builds without runtime errors.

## Done when
- `xcodebuild -scheme Sift ... build` succeeds and the app launches showing the component gallery.
- `xcodebuild test ...` passes; `swiftlint` and `swiftformat --lint` are clean.
- No raw hex or font-name string literals exist outside `Tokens.swift`/`Typography.swift` (lint-enforced).
- PR notes any font files that need manual addition.

## Guardrails
Build the **system**, not screens — no Dashboard/Onboarding yet. Don't pull in any animation or styling libraries. If the iOS 26 glass API differs from expectation, adapt `GlassSurface` and document the real API in the PR; do not fake it with a plain blur if the native effect is available.
