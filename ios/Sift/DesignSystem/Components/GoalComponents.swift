import SwiftUI

extension GoalOutcome {
    /// Short status label. Deliberately phrased around progress rather than shortfall —
    /// building-oriented framing sustains engagement where restriction framing drives
    /// people away from the app entirely.
    var label: String {
        switch self {
        case .reached:
            "REACHED"
        case .overdue:
            "PAST DUE"
        case .insufficientData:
            "NEEDS A PLAN"
        case .onTrack:
            "ON TRACK"
        case .behind:
            "BEHIND"
        case .ahead:
            "AHEAD"
        }
    }

    var tint: Color {
        switch self {
        case .reached, .ahead:
            Palette.positive
        case .onTrack:
            Palette.accent
        case .behind, .overdue:
            Palette.negative
        case .insufficientData:
            Palette.inkFaint
        }
    }

    var pillVariant: PillVariant {
        switch self {
        case .reached, .ahead:
            .down
        case .onTrack, .insufficientData:
            .neutral
        case .behind, .overdue:
            .up
        }
    }

    /// One line explaining the status, carrying the figure that makes it actionable.
    var detail: String {
        switch self {
        case let .reached(_, surplus):
            surplus.amountMinor > 0 ? "Target met, \(surplus.formatted()) over" : "Target met"
        case let .overdue(_, remaining, monthsPast):
            "\(remaining.formatted()) short, \(monthsPast) \(monthsPast == 1 ? "month" : "months") past the date"
        case .insufficientData:
            "Add a target date or a monthly amount"
        case let .onTrack(_, remaining, requiredMonthly, _):
            "\(remaining.formatted()) to go at \(requiredMonthly.formatted())/mo"
        case let .behind(_, _, requiredMonthly, shortfall):
            "Needs \(requiredMonthly.formatted())/mo — \(shortfall.formatted()) more than planned"
        case let .ahead(_, _, requiredMonthly, surplus):
            "Only needs \(requiredMonthly.formatted())/mo — \(surplus.formatted()) ahead"
        }
    }
}

/// Circular progress indicator for a goal.
///
/// The only existing ring in the app is onboarding's `ScanRing`, which is hardcoded to
/// "subscriptions found" and carries a continuous spin, so it isn't reusable here. This
/// mirrors its geometry — trimmed circle, rounded cap, rotated so 0 starts at the top.
struct GoalProgressRing: View {
    let fractionComplete: Double
    let tint: Color
    var lineWidth: CGFloat = 10
    var diameter: CGFloat = 96

    private var clamped: Double {
        min(max(fractionComplete, 0), 1)
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Palette.surfaceSunken, lineWidth: lineWidth)

            Circle()
                .trim(from: 0, to: clamped)
                .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))

            Text("\(Int((clamped * 100).rounded()))%")
                .font(.bodyEmphasis)
                .foregroundStyle(Palette.ink)
                .monospacedDigit()
        }
        .frame(width: diameter, height: diameter)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Goal progress")
        .accessibilityValue("\(Int((clamped * 100).rounded())) percent")
    }
}

/// One goal in the list.
struct GoalRow: View {
    let model: GoalRowModel
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: Spacing.md) {
                GoalProgressRing(
                    fractionComplete: model.fractionComplete,
                    tint: model.outcome.tint,
                    lineWidth: 7,
                    diameter: 62
                )

                VStack(alignment: .leading, spacing: 4) {
                    Text(model.name)
                        .font(.bodyEmphasis)
                        .foregroundStyle(Palette.ink)
                        .lineLimit(1)

                    // Progress first: what's been saved, then the target.
                    Text("\(model.outcome.saved.formatted()) of \(model.targetAmount.formatted())")
                        .font(.siftBody)
                        .foregroundStyle(Palette.inkSoft)

                    Text(model.outcome.detail)
                        .font(.siftBody)
                        .foregroundStyle(Palette.inkFaint)
                        .lineLimit(2)
                }

                Spacer(minLength: Spacing.sm)
            }
            .padding(.horizontal, 13)
            .padding(.vertical, 12)
            .background(Palette.surface, in: RoundedRectangle(cornerRadius: Radius.row, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("goal-row-\(model.id)")
    }
}

/// One contribution or withdrawal in a goal's history.
struct GoalContributionRow: View {
    let contribution: GoalContribution

    private var isWithdrawal: Bool {
        contribution.amount.amountMinor < 0
    }

    private var magnitude: Money {
        Money(amountMinor: abs(contribution.amount.amountMinor), currency: contribution.amount.currency)
    }

    var body: some View {
        HStack(spacing: Spacing.md) {
            Image(systemName: isWithdrawal ? SiftIcon.arrowDown : SiftIcon.arrowUp)
                .font(.siftBody)
                .foregroundStyle(isWithdrawal ? Palette.negative : Palette.positive)

            VStack(alignment: .leading, spacing: 2) {
                Text(contribution.date.formatted(.dateTime.month(.abbreviated).day().year()))
                    .font(.siftBody)
                    .foregroundStyle(Palette.ink)

                if let note = contribution.note, !note.isEmpty {
                    Text(note)
                        .font(.siftBody)
                        .foregroundStyle(Palette.inkFaint)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: Spacing.sm)

            MoneyText(
                value: "\(isWithdrawal ? "-" : "+")\(magnitude.formatted())",
                size: 16,
                color: isWithdrawal ? Palette.negative : Palette.ink
            )
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 11)
        .background(Palette.surface, in: RoundedRectangle(cornerRadius: Radius.row, style: .continuous))
    }
}
