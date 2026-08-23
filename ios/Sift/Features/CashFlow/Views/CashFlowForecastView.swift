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
                ScreenHeader(title: "Cash Flow", eyebrow: "Next 30 days")
                    .accessibilityIdentifier("cash-flow-title")

                content
            }
            .padding(.horizontal, Spacing.screenHorizontal)
            .padding(.top, Spacing.xl)
            .padding(.bottom, 84)
        }
        .background(Palette.ground)
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
        SiftSection {
            HStack {
                stat(label: "TODAY", value: forecast.startingBalance, color: Palette.ink)
                Spacer()
                stat(label: "IN 30 DAYS", value: forecast.endingBalance, color: endingColor)
            }
            Text("Lowest point \(forecast.lowestPoint.projectedBalance.formatted()) on \(dateText(forecast.lowestPoint.date))")
                .font(.system(.caption, design: .default).weight(.medium))
                .foregroundStyle(forecast.lowestPoint.projectedBalance.amountMinor < 0 ? Palette.negative : Palette.inkFaint)
        }
    }

    private var endingColor: Color {
        forecast.endingBalance.amountMinor < forecast.startingBalance.amountMinor ? Palette.negative : Palette.positive
    }

    private func stat(label: String, value: Money, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.siftLabel)
                .foregroundStyle(Palette.inkFaint)
            MoneyText(value: value.formatted(), role: .primary, color: color)
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
        SiftSection {
            Text("Projected balance")
                .font(.siftLabel)
                .foregroundStyle(Palette.inkFaint)

            Chart {
                ForEach(forecast.points) { point in
                    AreaMark(
                        x: .value("Date", point.date),
                        y: .value("Balance", dollars(point.projectedBalance))
                    )
                    .interpolationMethod(.stepEnd)
                    .foregroundStyle(Palette.accent.opacity(0.18))

                    LineMark(
                        x: .value("Date", point.date),
                        y: .value("Balance", dollars(point.projectedBalance))
                    )
                    .interpolationMethod(.stepEnd)
                    .foregroundStyle(Palette.accent)
                }

                RuleMark(y: .value("Zero", 0))
                    .foregroundStyle(Palette.negative.opacity(0.5))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))

                ForEach(forecast.events) { event in
                    PointMark(
                        x: .value("Date", event.date),
                        y: .value("Balance", balance(at: event.date))
                    )
                    .symbolSize(event.kind == .income ? 70 : 34)
                    .foregroundStyle(event.direction == .credit ? Palette.positive : Palette.negative)
                }
            }
            .chartYAxis {
                // Same reasoning as the spend trend: own the label font rather than
                // inheriting SF Pro at system grey, and read for shape not lookup.
                AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { value in
                    AxisGridLine()
                        .foregroundStyle(Palette.separator)
                    AxisValueLabel {
                        Text(shortDollars(value.as(Double.self) ?? 0))
                            .font(.siftLabel)
                            .foregroundStyle(Palette.inkFaint)
                    }
                }
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

    /// Balances can go negative here, so the sign is kept and the cents dropped.
    private func shortDollars(_ value: Double) -> String {
        let sign = value < 0 ? "-" : ""
        let magnitude = abs(value)
        return magnitude >= 1000
            ? "\(sign)$\(Int((magnitude / 1000).rounded()))k"
            : "\(sign)$\(Int(magnitude.rounded()))"
    }
}

private struct CashFlowEventList: View {
    let events: [CashFlowEvent]

    var body: some View {
        if events.isEmpty {
            SiftSection(header: "Upcoming") {
                Text("No scheduled charges or deposits in the next 30 days.")
                    .font(.siftBody)
                    .foregroundStyle(Palette.inkSoft)
            }
        } else {
            SiftRowSection(header: "Upcoming", data: events, id: \.id) { event in
                CashFlowEventRow(event: event)
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
                    .font(.system(.caption, design: .default).weight(.medium))
                    .foregroundStyle(Palette.inkSoft)
            }

            Spacer(minLength: Spacing.sm)

            MoneyText(
                value: "\(event.direction == .credit ? "+" : "-")\(event.amount.formatted())",
                role: .row,
                color: event.direction == .credit ? Palette.positive : Palette.ink
            )
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.md)
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
