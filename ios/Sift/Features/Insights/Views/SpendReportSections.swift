import Charts
import SwiftUI

/// The ledger-backed half of Insights: where money went over time, how this month compares,
/// and which categories actually moved. Kept out of `InsightsView.swift` so neither file
/// drifts toward the file-length limit.
struct SpendReportSections: View {
    let monthlySpend: [MonthlySpendPoint]
    let maxMonthlySpend: Money
    let comparison: SpendComparison?
    let movers: [CategoryMover]

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xl) {
            SpendTrendCard(points: monthlySpend, maxSpend: maxMonthlySpend)

            if let comparison {
                SpendComparisonCard(comparison: comparison)
            }

            TopMoversSection(movers: movers)
        }
    }
}

private struct SpendTrendCard: View {
    let points: [MonthlySpendPoint]
    let maxSpend: Money

    var body: some View {
        SiftSection {
            Text("Spend over time")
                .font(.siftLabel)
                .foregroundStyle(Palette.inkFaint)

            Chart(points) { point in
                BarMark(
                    x: .value("Month", point.monthStart, unit: .month),
                    y: .value("Spend", dollars(point.total))
                )
                .foregroundStyle(Palette.accent)
                .cornerRadius(6)
                .accessibilityLabel(point.monthStart.formatted(.dateTime.month(.wide).year()))
                .accessibilityValue(point.total.formatted())
            }
            // Swift Charts' default axis renders labels in SF Pro at system grey — a
            // fourth typeface, appearing only inside charts, in an app with three chosen
            // ones. Owning the label font is the single most visible chart fix.
            .chartXAxis {
                // The value has to be named: `$0` inside the nested `AxisValueLabel`
                // closure does not reach the enclosing one, which left the label's
                // argument unresolved and sent the compiler to `AxisValueLabel`'s
                // `StringProtocol` overload instead of its ViewBuilder one.
                AxisMarks(values: .stride(by: .month)) { value in
                    AxisValueLabel {
                        // Spelled out rather than leaning on `.dateTime`, so the generic
                        // `FormatStyle` has nothing to infer.
                        Text(Date.FormatStyle.dateTime.month(.narrow).format(value.as(Date.self) ?? Date()))
                            .font(.siftLabel)
                            .foregroundStyle(Palette.inkFaint)
                    }
                }
            }
            .chartYAxis {
                // Three values, not the default five to seven: this chart is read for
                // shape, not for lookup. No AxisTick — gridlines already mark position.
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
            .chartYScale(domain: 0 ... domainMax)
            .frame(height: 180)
            .accessibilityIdentifier("spend-trend-chart")

            Text("Settled spending, last \(points.count) months.")
                .font(.siftBody)
                .foregroundStyle(Palette.inkSoft)
        }
    }

    private func dollars(_ money: Money) -> Double {
        Double(money.amountMinor) / 100
    }

    /// Axis labels are read at a glance, so they drop the cents and abbreviate thousands.
    private func shortDollars(_ value: Double) -> String {
        value >= 1000
            ? "$\(Int((value / 1000).rounded()))k"
            : "$\(Int(value.rounded()))"
    }

    private var domainMax: Double {
        max(1, dollars(maxSpend) * 1.18)
    }
}

private struct TopMoversSection: View {
    let movers: [CategoryMover]

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("Top movers")
                .font(.siftLabel)
                .foregroundStyle(Palette.inkFaint)

            if movers.isEmpty {
                // Small wobbles are filtered out upstream, so "nothing moved" is a real and
                // useful answer rather than a gap in the data.
                Text("No category moved much between these two stretches.")
                    .font(.siftBody)
                    .foregroundStyle(Palette.inkSoft)
            } else {
                ForEach(movers) { mover in
                    CategoryMoverRow(mover: mover)
                }
            }
        }
    }
}

private struct SpendReportSectionsPreview: View {
    private let transactions = SeedData.snapshot().transactions

    private var comparison: SpendComparison {
        SpendReportBuilder.comparison(
            transactions: transactions,
            referenceDate: SeedData.referenceDate
        )
    }

    private var points: [MonthlySpendPoint] {
        SpendReportBuilder.monthlyTotals(
            transactions: transactions,
            endingAt: SeedData.referenceDate
        )
    }

    var body: some View {
        ScrollView {
            SpendReportSections(
                monthlySpend: points,
                maxMonthlySpend: points.map(\.total).max() ?? .zeroUSD,
                comparison: comparison,
                movers: SpendReportBuilder.topMovers(comparison: comparison)
            )
            .padding(Spacing.screenHorizontal)
        }
        .background(Palette.ground)
    }
}

#Preview {
    SpendReportSectionsPreview()
}
