import Charts
import SwiftUI

struct CashFlowForecastView: View {
    @State private var viewModel: CashFlowForecastViewModel

    init(
        repositories: RepositoryContainer = .mock(),
        referenceDateProvider: @escaping () -> Date = { Date() }
    ) {
        _viewModel = State(initialValue: CashFlowForecastViewModel(
            repositories: repositories,
            referenceDateProvider: referenceDateProvider
        ))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xl) {
                ScreenHeader(title: "Cash Flow", eyebrow: "NEXT 30 DAYS")
                    .accessibilityIdentifier("cash-flow-title")

                content
            }
            .padding(.horizontal, Spacing.screenHorizontal)
            .padding(.top, Spacing.xl)
            .padding(.bottom, 84)
        }
        .background(Palette.bone)
        .navigationTitle("Cash Flow")
        .task { viewModel.load() }
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isUnavailable {
            StateMessageCard(
                title: "No balance to project",
                message: "Connect an account so Sift can forecast your balance over the next month.",
                systemImage: SiftIcon.bank
            )
        } else if let errorMessage = viewModel.errorMessage {
            StateMessageCard(
                title: "Forecast unavailable",
                message: errorMessage,
                systemImage: SiftIcon.warning,
                actionTitle: "Try again"
            ) {
                viewModel.load()
            }
        } else if let forecast = viewModel.forecast {
            CashFlowSummaryCard(forecast: forecast)
            CashFlowChartCard(forecast: forecast)
            CashFlowEventList(events: forecast.events)
        }
    }
}

private struct CashFlowSummaryCard: View {
    let forecast: CashFlowForecast

    var body: some View {
        SiftCard {
            HStack {
                stat(label: "TODAY", value: forecast.startingBalance, color: Palette.ink)
                Spacer()
                stat(label: "IN 30 DAYS", value: forecast.endingBalance, color: endingColor)
            }
            Text("Lowest point \(forecast.lowestPoint.projectedBalance.formatted()) on \(dateText(forecast.lowestPoint.date))")
                .font(.custom(SiftFontPostScriptName.plusJakartaMedium.rawValue, size: 12, relativeTo: .caption))
                .foregroundStyle(forecast.lowestPoint.projectedBalance.amountMinor < 0 ? Palette.clay : Palette.inkFaint)
        }
    }

    private var endingColor: Color {
        forecast.endingBalance.amountMinor < forecast.startingBalance.amountMinor ? Palette.clay : Palette.green
    }

    private func stat(label: String, value: Money, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.siftLabel)
                .foregroundStyle(Palette.inkFaint)
            MoneyText(value: value.formatted(), size: 24, color: color)
        }
    }

    private func dateText(_ date: Date) -> String {
        date.formatted(.dateTime.month(.abbreviated).day())
    }
}

private struct CashFlowChartCard: View {
    let forecast: CashFlowForecast

    private var balancesByDay: [Date: Double] {
        Dictionary(
            forecast.points.map { (Calendar.utc.startOfDay(for: $0.date), dollars($0.projectedBalance)) },
            uniquingKeysWith: { _, latest in latest }
        )
    }

    var body: some View {
        SiftCard {
            Text("PROJECTED BALANCE")
                .font(.siftLabel)
                .foregroundStyle(Palette.inkFaint)

            Chart {
                ForEach(forecast.points) { point in
                    AreaMark(
                        x: .value("Date", point.date),
                        y: .value("Balance", dollars(point.projectedBalance))
                    )
                    .interpolationMethod(.stepEnd)
                    .foregroundStyle(Palette.gold.opacity(0.18))

                    LineMark(
                        x: .value("Date", point.date),
                        y: .value("Balance", dollars(point.projectedBalance))
                    )
                    .interpolationMethod(.stepEnd)
                    .foregroundStyle(Palette.goldDeep)
                }

                RuleMark(y: .value("Zero", 0))
                    .foregroundStyle(Palette.clay.opacity(0.5))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))

                ForEach(forecast.events) { event in
                    PointMark(
                        x: .value("Date", event.date),
                        y: .value("Balance", balance(at: event.date))
                    )
                    .symbolSize(event.kind == .income ? 70 : 34)
                    .foregroundStyle(event.direction == .credit ? Palette.green : Palette.clay)
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading)
            }
            .frame(height: 220)
            .accessibilityIdentifier("cash-flow-chart")
        }
    }

    private func balance(at date: Date) -> Double {
        balancesByDay[Calendar.utc.startOfDay(for: date)] ?? dollars(forecast.startingBalance)
    }

    private func dollars(_ money: Money) -> Double {
        Double(money.amountMinor) / 100
    }
}

private struct CashFlowEventList: View {
    let events: [CashFlowEvent]

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("UPCOMING")
                .font(.siftLabel)
                .foregroundStyle(Palette.inkFaint)

            if events.isEmpty {
                Text("No scheduled charges or deposits in the next 30 days.")
                    .font(.siftBody)
                    .foregroundStyle(Palette.inkSoft)
            } else {
                ForEach(events) { event in
                    CashFlowEventRow(event: event)
                }
            }
        }
    }
}

private struct CashFlowEventRow: View {
    let event: CashFlowEvent

    var body: some View {
        HStack(spacing: Spacing.md) {
            VStack(alignment: .leading, spacing: 2) {
                Text(event.label)
                    .font(.bodyEmphasis)
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1)
                Text(event.date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()))
                    .font(.custom(SiftFontPostScriptName.plusJakartaMedium.rawValue, size: 12, relativeTo: .caption))
                    .foregroundStyle(Palette.inkSoft)
            }

            Spacer(minLength: Spacing.sm)

            MoneyText(
                value: "\(event.direction == .credit ? "+" : "-")\(event.amount.formatted())",
                size: 16,
                color: event.direction == .credit ? Palette.green : Palette.ink
            )
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 11)
        .background(Palette.card, in: RoundedRectangle(cornerRadius: Radius.row, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.row, style: .continuous)
                .stroke(Palette.line, lineWidth: 1)
        )
    }
}

/// Pushes `CashFlowForecastView` wired to the live environment repositories, so a
/// navigation destination doesn't fall back to mock data.
struct CashFlowForecastRouteView: View {
    @Environment(\.repositories) private var repositories

    var body: some View {
        CashFlowForecastView(repositories: repositories)
    }
}

#Preview {
    NavigationStack {
        CashFlowForecastView(
            repositories: .mock(),
            referenceDateProvider: { SeedData.referenceDate }
        )
    }
}
