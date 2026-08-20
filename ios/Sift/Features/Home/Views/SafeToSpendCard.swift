import SwiftUI

/// The daily-glance "safe to spend" figure on Home. Tappable to open the full cash-flow
/// forecast. Renders a distinct, honest empty state when no balance is available rather
/// than fabricating a number.
struct SafeToSpendCard: View {
    let outcome: SafeToSpendOutcome
    var onTap: (() -> Void)?

    var body: some View {
        Button {
            onTap?()
        } label: {
            SiftSection {
                switch outcome {
                case .unavailable:
                    unavailableContent
                case let .available(result):
                    availableContent(result)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(onTap == nil)
        .accessibilityIdentifier("safe-to-spend-card")
    }

    private var unavailableContent: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Safe to spend")
                .font(.siftLabel)
                .foregroundStyle(Palette.inkFaint)
            Text("Connect an account to see how much you can safely spend each day.")
                .font(.siftBody)
                .foregroundStyle(Palette.inkSoft)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func availableContent(_ result: SafeToSpendResult) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                Text(result.isOverspent ? "OVER BUDGET" : "SAFE TO SPEND")
                    .font(.siftLabel)
                    .foregroundStyle(Palette.inkFaint)
                Spacer()
                Image(systemName: SiftIcon.chevronRight)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Palette.inkFaint)
            }

            MoneyText(
                value: "\(magnitude(of: result.dailyAmount).formatted())/day",
                role: .hero,
                color: result.isOverspent ? Palette.negative : Palette.ink
            )
            .minimumScaleFactor(0.7)
            .accessibilityLabel(accessibilityLabel(result))

            Text(subtitle(result))
                .font(.siftBody)
                .foregroundStyle(Palette.inkSoft)

            Text("You've been averaging \(result.recentDailySpend.formatted())/day recently.")
                .font(.system(.caption, design: .default).weight(.medium))
                .foregroundStyle(Palette.inkFaint)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func magnitude(of money: Money) -> Money {
        Money(amountMinor: abs(money.amountMinor), currency: money.currency)
    }

    private func subtitle(_ result: SafeToSpendResult) -> String {
        if result.isOverspent {
            return "You're committed beyond your balance before \(dateText(result))."
        }
        if result.usedFallbackWindow {
            return "For the next \(result.daysRemaining) days · no regular income detected"
        }
        return "For \(result.daysRemaining) days, until \(dateText(result))"
    }

    private func dateText(_ result: SafeToSpendResult) -> String {
        result.horizonEndDate.formatted(.dateTime.month(.abbreviated).day())
    }

    private func accessibilityLabel(_ result: SafeToSpendResult) -> String {
        let amount = magnitude(of: result.dailyAmount).formatted()
        if result.isOverspent {
            return "Over budget by \(amount) per day"
        }
        return "Safe to spend \(amount) per day"
    }
}

#Preview {
    VStack(spacing: Spacing.lg) {
        SafeToSpendCard(
            outcome: .available(SafeToSpendResult(
                dailyAmount: .usd(1842),
                netAvailable: .usd(16578),
                horizonEndDate: Date().addingTimeInterval(9 * 86400),
                daysRemaining: 9,
                isOverspent: false,
                usedFallbackWindow: false,
                recentDailySpend: .usd(2310)
            )),
            onTap: {}
        )
        SafeToSpendCard(outcome: .unavailable(.noBalanceData))
    }
    .padding()
    .background(Palette.ground)
}
