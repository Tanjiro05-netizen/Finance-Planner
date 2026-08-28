import SwiftUI

/// A screen title, with an optional eyebrow above it.
///
/// The eyebrow used to be required, which meant every one of the 24 call sites had to
/// invent a category — "NAVIGATION", "LEDGER", "CONTROL", "DETAIL". A mandatory field
/// filled with taxonomy nobody asked for is how a template announces itself, and an
/// all-caps label above every single screen carries no information precisely because it
/// is above every single screen. It is now for the few places where a screen genuinely
/// belongs to a larger group.
///
/// The remaining six are also no longer set in tracked-out caps. Uppercasing was doing the
/// same job the mono face was — signalling "this is a label" rather than saying anything —
/// and "tracked-out caps subheadings" is itself a named item in the catalogue of
/// machine-generated design. A subscription's own name, in sentence case, is more
/// informative than the same name shouted.
struct ScreenHeader: View {
    let title: String
    var eyebrow: String?

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            if let eyebrow, !eyebrow.isEmpty {
                Text(eyebrow)
                    .font(.siftLabel)
                    .foregroundStyle(Palette.inkSoft)
            }

            Text(title)
                .font(.screenTitle)
                .foregroundStyle(Palette.ink)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
