import SwiftUI

/// A screen title, with an optional eyebrow above it.
///
/// The eyebrow used to be required, which meant every one of the 24 call sites had to
/// invent a category — "NAVIGATION", "LEDGER", "CONTROL", "DETAIL". A mandatory field
/// filled with taxonomy nobody asked for is how a template announces itself, and an
/// all-caps label above every single screen carries no information precisely because it
/// is above every single screen. It is now for the few places where a screen genuinely
/// belongs to a larger group.
struct ScreenHeader: View {
    let title: String
    var eyebrow: String?

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            if let eyebrow, !eyebrow.isEmpty {
                Text(eyebrow.uppercased())
                    .font(.siftLabel)
                    // Tracking only now that these are rare. Applied to all 82 of them it
                    // would have moved toward the generic look, not away from it.
                    .tracking(0.8)
                    .foregroundStyle(Palette.goldDeep)
            }

            Text(title)
                .font(.screenTitle)
                .foregroundStyle(Palette.ink)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
