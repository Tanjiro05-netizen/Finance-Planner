import SwiftUI

/// A single ledger row: merchant, category, date, and a signed amount colored by
/// direction. Mirrors `SubscriptionRow`'s layout so the two lists read as one family.
struct TransactionRow: View {
    let merchantName: String
    let categoryLabel: String
    let amount: String
    let direction: TransactionDirection
    let date: String
    var isPending: Bool = false

    var body: some View {
        HStack(spacing: Spacing.md) {
            MonogramTile(letter: monogram, color: direction == .credit ? Palette.positive : Palette.ink)

            VStack(alignment: .leading, spacing: 2) {
                Text(merchantName)
                    .font(.bodyEmphasis)
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1)

                Text(isPending ? "Pending · \(categoryLabel)" : categoryLabel)
                    .font(.system(.caption, design: .default).weight(.medium))
                    .foregroundStyle(Palette.inkSoft)
                    .lineLimit(1)
            }

            Spacer(minLength: Spacing.sm)

            VStack(alignment: .trailing, spacing: 2) {
                MoneyText(
                    value: signedAmount,
                    role: .row,
                    color: direction == .credit ? Palette.positive : Palette.ink
                )
                Text(date)
                    .font(.cadence)
                    .foregroundStyle(Palette.inkFaint)
            }
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 11)
        .background(Palette.surface, in: RoundedRectangle(cornerRadius: Radius.row, style: .continuous))
    }

    private var monogram: String {
        String(merchantName.first ?? "?").uppercased()
    }

    private var signedAmount: String {
        direction == .credit ? "+\(amount)" : amount
    }
}
