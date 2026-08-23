import SwiftUI

extension SpendComparison {
    /// Honest labelling is the whole reason `SpendReportBuilder` truncates the previous month
    /// to the same day count. Saying so on screen is what stops "first 6 days vs a whole
    /// month" from reading as a collapse in spending.
    var windowLabel: String {
        isPartialMonth ? "First \(dayCount) days of each month" : "Full month"
    }

    /// `.up` is the clay/bad tint and `.down` the green one, which is the right way round for
    /// spending: more is worse.
    var deltaVariant: PillVariant {
        if delta.amountMinor > 0 {
            return .up
        }

        return delta.amountMinor < 0 ? .down : .neutral
    }

    var deltaLabel: String {
        let magnitude = Money(amountMinor: abs(delta.amountMinor), currency: delta.currency)

        guard delta.amountMinor != 0 else {
            return "No change"
        }

        let direction = delta.amountMinor > 0 ? "more" : "less"

        guard let fraction = fractionChange else {
            return "\(magnitude.formatted()) \(direction)"
        }

        return "\(magnitude.formatted()) \(direction) · \(percentLabel(fraction))"
    }
}

extension CategoryMover {
    var deltaVariant: PillVariant {
        isIncrease ? .up : .down
    }

    /// Dollars always; the percentage only when there was a base to compute it against.
    /// A percentage off zero is a lie dressed as precision.
    var deltaLabel: String {
        let magnitude = Money(amountMinor: abs(delta.amountMinor), currency: delta.currency)
        let sign = isIncrease ? "+" : "−"

        guard let fraction = fractionChange else {
            return "\(sign)\(magnitude.formatted()) · new"
        }

        return "\(sign)\(magnitude.formatted()) · \(percentLabel(fraction))"
    }
}

/// Shared so the comparison card and the mover rows can't drift on rounding or sign.
private func percentLabel(_ fraction: Double) -> String {
    let percent = (fraction * 100).rounded()
    let sign = percent > 0 ? "+" : ""
    return "\(sign)\(Int(percent))%"
}

/// This month against the same slice of last month.
struct SpendComparisonCard: View {
    let comparison: SpendComparison

    var body: some View {
        SiftSection {
            Text("This month vs last")
                .font(.siftLabel)
                .foregroundStyle(Palette.inkFaint)

            MoneyText(value: comparison.currentTotal.formatted(), role: .primary)

            HStack(spacing: Spacing.sm) {
                Pill(text: comparison.deltaLabel, variant: comparison.deltaVariant)
                Spacer(minLength: Spacing.sm)
            }

            Text("\(comparison.previousTotal.formatted()) over the same stretch last month")
                .font(.siftBody)
                .foregroundStyle(Palette.inkSoft)

            Text(comparison.windowLabel)
                .font(.siftLabel)
                .foregroundStyle(Palette.inkFaint)
        }
        .accessibilityIdentifier("spend-comparison-card")
    }
}

/// One category whose spend moved between the two windows.
struct CategoryMoverRow: View {
    let mover: CategoryMover

    var body: some View {
        HStack(spacing: Spacing.md) {
            VStack(alignment: .leading, spacing: 2) {
                Text(mover.categoryName)
                    .font(.bodyEmphasis)
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1)

                Text("\(mover.previous.formatted()) → \(mover.current.formatted())")
                    .font(.siftBody)
                    .foregroundStyle(Palette.inkSoft)
            }

            Spacer(minLength: Spacing.sm)

            Pill(text: mover.deltaLabel, variant: mover.deltaVariant)
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.md)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("mover-row-\(mover.id)")
    }
}
