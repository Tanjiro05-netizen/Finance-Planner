# Motion & Liquid Glass — specification

> Cross-cutting reference. Commit under `/docs/` and add one line to `AGENTS.md` (Design System section): *"Motion and glass behaviour are governed by `/docs/13-MOTION-AND-GLASS.md` — implement animations from its tokens; never hardcode durations."* Phases 1, 2, 5, 6, 7, 8, 10 each reference the relevant section here.

All APIs below are **iOS 26 SwiftUI** and verified against Apple's documentation. Confirm signatures against the installed SDK before use.

---

## 1. The feel (aesthetic intent)

Motion in Sift is **calm, physical, and earned.** Nothing bounces for attention. Things move because the user moved them, or because money moved. The reference is a heavy, well-balanced object: it responds instantly to touch, settles without overshoot, and rests completely still. When in doubt, slower and softer. Glass is the one place light plays — a single slow specular pass — and even that yields to Reduce Motion. The emotional beat we animate is the **money figure changing**: when a subscription is cancelled and the monthly total drops, that number counts down. That is the reward, and it is the only number that performs.

Three rules: **one thing moves at a time** per interaction; **no animation exceeds ~0.6s** except ambient loops; **every motion has a Reduce Motion fallback** that is instant or a cross-fade, never a jump that loses context.

---

## 2. Motion tokens

Create `DesignSystem/Motion.swift`. Every `withAnimation`/`.animation` call references these — no inline durations anywhere (lint for it).

```swift
import SwiftUI

enum Motion {
    // Content & navigation
    static let gentle   = Animation.smooth(duration: 0.35)          // content fades, screen content settle
    static let sheet    = Animation.spring(response: 0.42, dampingFraction: 0.82) // sheet present/dismiss
    static let glassMorph = Animation.bouncy(duration: 0.45, extraBounce: 0.06)   // tab/glass cluster morph

    // Controls
    static let snappy   = Animation.snappy(duration: 0.24)          // segmented control, toggle, filter
    static let press    = Animation.spring(response: 0.22, dampingFraction: 0.70) // button press scale

    // Data
    static let count    = Animation.smooth(duration: 0.60)          // numeric figure transitions
    static let staggerStep = 0.04                                   // per-row delay on first list appearance

    // Ambient
    static let sheenPeriod: TimeInterval = 8.0                      // one specular pass per 8s
    static let scanSpin = Animation.linear(duration: 2.4).repeatForever(autoreverses: false)
}
```

`@Environment(\.accessibilityReduceMotion)` and `\.accessibilityReduceTransparency` are read by a small helper that swaps each token for its fallback (see §8). Never branch on these inline more than once — centralise in `Motion.reduced(_:)`.

---

## 3. Liquid Glass — implementation

**Where glass goes (unchanged rule):** floating tab bar, segmented control, floating bottom action bars, the notification preview banner, sheets. **Never on content.** Never stack glass on glass.

**Custom controls** use the native modifier:
```swift
// Floating action bar holding the Cancel button
HStack { ClayButton("Cancel subscription") { … } }
    .padding(12)
    .glassEffect(.regular, in: .rect(cornerRadius: Radius.actionBar))
```
- Use `.regular` for our light, frosted control bars. Reserve `.clear` for moments over imagery (none in this app by default).
- For touchable glass (the floating "Open site", "+ Add account", confirm buttons) add `.interactive()` — it gives the system's scale + shimmer + bounce on press, which replaces any custom press animation on those elements:
```swift
.glassEffect(.regular.tint(Palette.gold.opacity(0.0)).interactive(), in: .capsule)
```
  Keep the tint near-neutral; our glass is bone-frosted, not coloured. (Tint exists for semantic cases; we mostly omit it.)
- **Native toolbars, sheets, and the `TabView` tab bar receive Liquid Glass automatically** when built against the iOS 26 SDK. Do not re-implement those by hand — configure, don't rebuild.
- Migration note for any leftover material: replace `.background(.ultraThinMaterial)` with `.glassEffect()`, and `.matchedGeometryEffect(id:in:)` on glass with `.glassEffectID(_:in:)`.

**Concentric corners:** glass shapes use the design radii (tab bar 24, action bar 24, sheet 36–40, segmented 15) so the curvature stays concentric with the device and the cards beneath.

**Specular highlight / rim:** the native effect renders lensing and a light rim itself. Our only *added* flourish is the slow sheen pass (§4.5) layered as an overlay on the tab bar and primary action bar — subtle, single, and reduced-motion-aware.

---

## 4. Choreography (per interaction, precise)

### 4.1 Tab switch — glass morph
The `TabView` bar is native glass and morphs on its own. For our **active-tab indicator** (the gold pill/treatment behind the selected icon), drive it with a shared namespace so it physically slides rather than fades:
```swift
@Namespace private var tabGlass
// active background
.glassEffectID("activeTab", in: tabGlass)
```
Wrap the indicator group in a `GlassEffectContainer(spacing: 20)` and animate selection with `Motion.glassMorph`. Content of the incoming tab uses `Motion.gentle` cross-fade with a 6pt upward settle. **Reduce Motion:** indicator cross-fades in place; no slide.

### 4.2 Sheet present / dismiss (Subscription detail, Cancel flow)
Native `.sheet` already uses the system spring; do **not** fight it. For our content *inside* the sheet (stats grid, history bars) apply a `Motion.gentle` appear so it settles a beat after the sheet arrives. Scrim behind: fade 0→0.34 opacity over the sheet's duration. Grabber is the system one. **Reduce Motion:** sheet still uses system present (it's already gentle); internal content appears without the settle.

### 4.3 Button press
Non-glass buttons (the ink/gold/clay CTAs on solid cards): scale to `0.97` with `Motion.press` on `isPressed`, return on release. Glass buttons: rely on `.interactive()` — no custom scale. Always pair with a haptic (§7). **Reduce Motion:** drop the scale; keep the haptic + a brief opacity dip to `0.85`.

### 4.4 The money figure — the one number that performs
Hero figures (`MoneyText`) animate value changes with numeric text transition:
```swift
Text(total, format: .currency(code: "USD"))
    .contentTransition(.numericText(value: total))
    .animation(Motion.count, value: total)
    .monospacedDigit() // tabular; digits don't reflow
```
Used when: the monthly total **drops after a cancellation** (count down — the reward), savings tick up on the Insights/Requests banners, and the Dashboard total updates after a sync. This is the single most important animation in the app; get its easing right (`Motion.count`, smooth, no bounce). **Reduce Motion:** value swaps instantly (numericText already degrades gracefully).

### 4.5 Specular sheen (ambient, glass only)
A single soft light band crosses the tab bar and primary action bar once per `Motion.sheenPeriod` (8s), with most of the period at rest (band off-screen ~75% of the time, then a ~1.2s pass). Implement with a `TimelineView(.animation)` driving a masked linear-gradient overlay clipped to the glass shape — never a continuous shimmer. **Reduce Motion or Reduce Transparency:** remove entirely (static glass).

### 4.6 Scanning screen (A6)
Progress ring rotates continuously with `Motion.scanSpin`; the centre count uses `.contentTransition(.numericText())` as detections are found; the SF Symbol pulses with `.symbolEffect(.pulse)`. Progress bar fills with `Motion.gentle` as real sync/detection progresses (never a fake timer). **Reduce Motion:** ring is static, shown as a determinate arc tied to real progress; count still updates (instant); no pulse.

### 4.7 Review-found reveal (A7)
Detected rows appear with a staggered fade + 8pt rise: row *i* delayed by `i * Motion.staggerStep`, capped at ~8 rows of stagger, using `Motion.gentle`. Toggling a row off animates the row to `0.4` opacity with `Motion.snappy`. **Reduce Motion:** all rows appear at once, no rise.

### 4.8 Segmented control & toggles
Segmented selection: the cream selected-pill slides under the chosen segment via `glassEffectID` in the control's namespace with `Motion.snappy`. Gold toggles: knob travels with `Motion.snappy`; track colour crossfades sand→gold. **Reduce Motion:** pill/knob crossfade in place.

### 4.9 Cancellation confirmation (C4)
The success check uses `.symbolEffect(.bounce, value:)` drawn on once (a single calm bounce, not repeating); the savings figure counts up with `Motion.count`; the underlying subscription row, if visible, fades out with `Motion.gentle` as it leaves active totals. Success uses green sparingly — no confetti, no celebration motion. **Reduce Motion:** check appears static; figure swaps instantly.

### 4.10 Status timeline (C2 concierge)
When a request advances (`requested → contacting → confirmed`), the active dot fills with `Motion.snappy` and the connecting line draws downward with `Motion.gentle`. **Reduce Motion:** dots/line update without draw.

### 4.11 Icon / symbol swaps
Anywhere an SF Symbol changes meaning (e.g. tab selection state, show/hide password, expand): `.contentTransition(.symbolEffect(.replace))`. Cheap, native, always on (it's subtle enough to keep under Reduce Motion).

### 4.12 Pull-to-refresh
Use the system `.refreshable`; its indicator is fine. On completion, the Dashboard total runs its §4.4 count transition if the value changed. No custom spinner.

---

## 5. List & screen entrances
First appearance of a tab's primary list: header settles with `Motion.gentle`; rows stagger (§4.7 pattern). Subsequent visits do **not** re-animate (track an `hasAppeared` flag) — re-running entrance animations on every tab switch reads as cheap. **Reduce Motion:** no entrance animation.

---

## 6. What must NOT move
- Body text, labels, card content — static. No parallax, no drifting backgrounds, no looping gradients on content.
- No more than one ambient loop visible at once (the sheen; the scan ring only exists on A6).
- No spring overshoot on money figures, status, or anything financial — overshoot reads as imprecise, which is poison for a finance app.

---

## 7. Haptics (SwiftUI `sensoryFeedback`)
Map events to feedback; no UIKit. Examples:
```swift
.sensoryFeedback(.selection, trigger: selectedTab)          // tab + segment change
.sensoryFeedback(.impact(weight: .light), trigger: toggleOn) // toggles
.sensoryFeedback(.success, trigger: cancellationConfirmed)   // C4 confirmation
.sensoryFeedback(.warning, trigger: cancelInitiated)         // tapping Cancel subscription (B3→C1)
.sensoryFeedback(.increase, trigger: detectedCount)          // each detection found on A6 (subtle)
```
Press feedback on primary CTAs: `.impact(weight: .medium)` on touch-down. Never haptic-spam scrolling or row appearance.

---

## 8. Accessibility fallbacks (a release gate)
Centralise:
```swift
@Environment(\.accessibilityReduceMotion) private var reduceMotion
@Environment(\.accessibilityReduceTransparency) private var reduceTransparency
```
- **Reduce Motion:** every §4 entry lists its fallback — generally instant value swaps or in-place cross-fades; ambient sheen and scan spin OFF; entrances OFF. Symbol `.replace` may stay.
- **Reduce Transparency:** glass surfaces fall back to a solid bone/`card` fill with the line border and shadow (legible, still premium). Provide `GlassSurface` a `reduceTransparency` branch so the whole app adapts in one place. Test the app with this enabled before shipping.
- Money count transitions must never be the *only* signal — pair with the list/row state change so VoiceOver users get the update via the accessibility value, announced on change.

---

## 9. Where each animation is built (binds to phases)
- **Phase 1:** `Motion.swift` tokens; `GlassSurface` (incl. Reduce Transparency branch); the sheen overlay; `MoneyText` numeric transition; button press style; toggle/segmented styling.
- **Phase 2:** tab morph + active-indicator namespace; sheet present + scrim; symbol `.replace` on tab icons.
- **Phase 5:** scanning ring/count/pulse (A6); review stagger (A7); haptic on detection.
- **Phase 7:** money count on Dashboard/Insights updates; list entrances; pull-to-refresh count.
- **Phase 8:** confirmation check `.bounce` + savings count + row leave (C4); status timeline draw (C2); cancel-initiated warning haptic.
- **Phase 10:** none visual; ensure notification-driven navigation triggers the destination's normal entrance.
- **Phase 11:** verify all Reduce Motion / Reduce Transparency fallbacks; no inline durations (lint); no double ambient loops.
