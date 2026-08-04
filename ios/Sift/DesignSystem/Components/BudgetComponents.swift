import SwiftUI

extension BudgetPace {
    var label: String {
        switch self {
        case .under:
            "UNDER"
        case .onTrack:
            "ON TRACK"
        case .over:
            "OVER"
        }
    }

    var tint: Color {
        switch self {
        case .under:
            Palette.green
        case .onTrack:
            Palette.goldDeep
        case .over:
            Palette.clay
        }
    }

    /// Reuses the existing pill semantics: `.down` already reads as the good direction and
    /// `.up` as the bad one, which is exactly how under- and over-pace should land.
    var pillVariant: PillVariant {
        switch self {
        case .under:
            .down
        case .onTrack:
            .neutral
        case .over:
            .up
        }
    }
}

/// A horizontal burn-down bar. Draws the spent share of a budget, plus a hairline marker at
/// the point an even spend would have reached by now — the marker is what makes "ahead of
/// pace" legible at a glance rather than requiring the reader to do the arithmetic.
struct BudgetProgressBar: View {
    let fractionUsed: Double
    let fractionElapsed: Double
    let tint: Color

    private var clampedUsed: Double {
        min(max(fractionUsed, 0), 1)
    }

    private var clampedElapsed: Double {
        min(max(fractionElapsed, 0), 1)
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Palette.sand)

                Capsule()
                    .fill(tint)
                    .frame(width: proxy.size.width * clampedUsed)

                Rectangle()
                    .fill(Palette.ink.opacity(0.35))
                    .frame(width: 2)
                    .offset(x: proxy.size.width * clampedElapsed)
            }
        }
        .frame(height: 8)
        .accessibilityElement()
        .accessibilityLabel("Budget used")
        .accessibilityValue("\(Int((clampedUsed * 100).rounded())) percent")
    }
}

/// One budget in the list: what it's for, how much is left, and whether spending is on pace.
struct BudgetRow: View {
    let categoryName: String
    let progress: BudgetProgress
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                HStack {
                    Text(categoryName)
                        .font(.bodyEmphasis)
                        .foregroundStyle(Palette.ink)
                        .lineLimit(1)

                    Spacer(minLength: Spacing.sm)

                    Pill(text: progress.pace.label, variant: progress.pace.pillVariant)
                }

                BudgetProgressBar(
                    fractionUsed: progress.fractionUsed,
                    fractionElapsed: progress.cycle.fractionElapsed,
                    tint: progress.pace.tint
                )

                HStack {
                    Text("\(progress.spent.formatted()) of \(progress.budgeted.formatted())")
                        .font(.siftBody)
                        .foregroundStyle(Palette.inkSoft)

                    Spacer(minLength: Spacing.sm)

                    Text(remainderText)
                        .font(.siftBody)
                        .foregroundStyle(progress.isOverspent ? Palette.clay : Palette.inkSoft)
                }
            }
            .padding(.horizontal, 13)
            .padding(.vertical, 12)
            .background(Palette.card, in: RoundedRectangle(cornerRadius: Radius.row, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.row, style: .continuous)
                    .stroke(Palette.line, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("budget-row-\(categoryName)")
    }

    private var remainderText: String {
        if progress.isOverspent {
            let over = Money(amountMinor: abs(progress.remaining.amountMinor), currency: progress.remaining.currency)
            return "\(over.formatted()) over"
        }

        return "\(progress.remaining.formatted()) left"
    }
}

/// Home-screen nudge naming the budgets that are running ahead of pace. Only shown when
/// there's something to act on — a card that always says "all good" trains people to ignore it.
struct BudgetNudgeCard: View {
    let rows: [BudgetRowModel]
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            SiftCard {
                HStack {
                    Text(title)
                        .font(.cardTitle)
                        .foregroundStyle(Palette.ink)
                    Spacer(minLength: Spacing.sm)
                    Image(systemName: SiftIcon.chevronRight)
                        .font(.siftBody)
                        .foregroundStyle(Palette.inkFaint)
                }

                Text(detail)
                    .font(.siftBody)
                    .foregroundStyle(Palette.inkSoft)
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("home-budget-nudge")
    }

    private var title: String {
        rows.count == 1 ? "1 budget over pace" : "\(rows.count) budgets over pace"
    }

    private var detail: String {
        rows
            .prefix(3)
            .map { "\($0.categoryName) · \($0.progress.spent.formatted()) of \($0.progress.budgeted.formatted())" }
            .joined(separator: "\n")
    }
}
