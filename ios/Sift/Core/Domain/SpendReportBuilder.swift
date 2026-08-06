import Foundation

/// Total spend for one calendar month.
struct MonthlySpendPoint: Identifiable, Equatable {
    /// Start of the month, in UTC.
    let monthStart: Date
    let total: Money

    var id: Date {
        monthStart
    }
}

/// Spend for one category within a comparison window.
struct CategorySpendTotal: Identifiable, Equatable {
    let categoryID: String?
    let categoryName: String
    let total: Money

    /// `categoryID` is optional (uncategorised spend is a real bucket), so the id falls back
    /// to a sentinel rather than colliding across every uncategorised row.
    var id: String {
        categoryID ?? "uncategorized"
    }
}

/// Current period against the equivalent earlier one.
struct SpendComparison: Equatable {
    let currentTotal: Money
    let previousTotal: Money
    let currentInterval: DateInterval
    let previousInterval: DateInterval
    /// True when the current month hasn't finished, meaning both windows were truncated to
    /// the same day count.
    let isPartialMonth: Bool
    /// Days covered by each window — equal by construction, and worth showing so a
    /// "1–6 of the month" comparison can be labelled honestly.
    let dayCount: Int
    let currentByCategory: [CategorySpendTotal]
    let previousByCategory: [CategorySpendTotal]

    var delta: Money {
        currentTotal - previousTotal
    }

    /// Change as a fraction of the previous total; nil when there's no base to compare against.
    var fractionChange: Double? {
        guard previousTotal.amountMinor > 0 else {
            return nil
        }
        return Double(delta.amountMinor) / Double(previousTotal.amountMinor)
    }
}

/// A category whose spend moved between the two windows.
struct CategoryMover: Identifiable, Equatable {
    let categoryID: String?
    let categoryName: String
    let current: Money
    let previous: Money
    let delta: Money
    /// nil when the previous window had no spend — an increase from nothing has no meaningful
    /// percentage, and rendering one would be a lie dressed as precision.
    let fractionChange: Double?

    var id: String {
        categoryID ?? "uncategorized"
    }

    var isIncrease: Bool {
        delta.amountMinor > 0
    }
}

/// Builds spending reports from the ledger. Pure and deterministic.
///
/// Everything here filters to settled debits explicitly rather than relying on
/// `TransactionRepository.totalSpend`/`byCategory`, which currently include pending rows and
/// (for `byCategory`) credits too. Reports and budgets should not disagree about what
/// "spending" means.
enum SpendReportBuilder {
    /// Default trailing window for the trend chart. Long enough to show a shape, short enough
    /// that a sparse ledger doesn't render as mostly-empty bars.
    static let defaultMonths = 6

    /// A category must have spent at least this much in the base window before a percentage
    /// change is worth ranking on. Without it, $2 → $6 tops the list at +200%.
    static let defaultMinimumMoverBase = Money.usd(2000)

    /// Total settled spend per calendar month, oldest first, **including months with no
    /// spend** so the chart shows real gaps instead of silently compressing time.
    static func monthlyTotals(
        transactions: [Transaction],
        months: Int = defaultMonths,
        endingAt referenceDate: Date,
        calendar: Calendar = .utc
    ) -> [MonthlySpendPoint] {
        let monthCount = max(1, months)
        let currentStart = calendar.dateInterval(of: .month, for: referenceDate)?.start ?? referenceDate

        let starts: [Date] = (0 ..< monthCount).reversed().compactMap { offset in
            calendar.date(byAdding: .month, value: -offset, to: currentStart)
        }

        let spend = settledDebits(transactions)
        let byMonth = Dictionary(grouping: spend) { transaction in
            calendar.dateInterval(of: .month, for: transaction.date)?.start ?? transaction.date
        }

        return starts.map { start in
            MonthlySpendPoint(monthStart: start, total: sum(byMonth[start] ?? []))
        }
    }

    /// Current month against the previous one.
    ///
    /// When the current month is still running, the previous month is truncated to the same
    /// day of month — comparing 1–6 June against the whole of May would show a "decrease"
    /// every time, which is the most common way these charts mislead.
    /// `categoryNames` maps category id to display name. Passed in rather than looked up
    /// here so the builder stays pure, and so names come from the `Category` store rather
    /// than from `TransactionRepository.byCategory`, whose mock returns the raw id as the name.
    static func comparison(
        transactions: [Transaction],
        referenceDate: Date,
        categoryNames: [String: String] = [:],
        calendar: Calendar = .utc
    ) -> SpendComparison {
        let currentMonth = calendar.dateInterval(of: .month, for: referenceDate)
            ?? DateInterval(start: referenceDate, end: referenceDate)
        let previousMonthAnchor = calendar.date(byAdding: .month, value: -1, to: currentMonth.start) ?? currentMonth.start
        let previousMonth = calendar.dateInterval(of: .month, for: previousMonthAnchor)
            ?? DateInterval(start: previousMonthAnchor, end: previousMonthAnchor)

        let daysInCurrentMonth = calendar.dateComponents([.day], from: currentMonth.start, to: currentMonth.end).day ?? 0
        let elapsedDays = (calendar.dateComponents([.day], from: currentMonth.start, to: referenceDate).day ?? 0) + 1
        let isPartial = elapsedDays < daysInCurrentMonth

        // Clamp to the shorter month so 31 Mar vs Feb doesn't run past the end of February.
        let daysInPreviousMonth = calendar.dateComponents([.day], from: previousMonth.start, to: previousMonth.end).day ?? 0
        let alignedDays = isPartial ? min(elapsedDays, daysInPreviousMonth) : daysInCurrentMonth

        let currentEnd = calendar.date(byAdding: .day, value: alignedDays, to: currentMonth.start) ?? currentMonth.end
        let previousEnd = calendar.date(byAdding: .day, value: alignedDays, to: previousMonth.start) ?? previousMonth.end

        let currentInterval = DateInterval(start: currentMonth.start, end: min(currentEnd, currentMonth.end))
        let previousInterval = DateInterval(start: previousMonth.start, end: min(previousEnd, previousMonth.end))

        let currentSpend = settledDebits(transactions).filter { currentInterval.contains($0.date) }
        let previousSpend = settledDebits(transactions).filter { previousInterval.contains($0.date) }

        return SpendComparison(
            currentTotal: sum(currentSpend),
            previousTotal: sum(previousSpend),
            currentInterval: currentInterval,
            previousInterval: previousInterval,
            isPartialMonth: isPartial,
            dayCount: alignedDays,
            currentByCategory: categoryTotals(currentSpend, names: categoryNames),
            previousByCategory: categoryTotals(previousSpend, names: categoryNames)
        )
    }

    /// Categories that moved most, largest absolute change first.
    ///
    /// Ranked on absolute money rather than percentage, because a percentage on a small base
    /// is noise. `fractionChange` is still reported so the UI can show both.
    static func topMovers(
        comparison: SpendComparison,
        minimumBase: Money = defaultMinimumMoverBase,
        limit: Int = 5
    ) -> [CategoryMover] {
        var previousByID: [String: CategorySpendTotal] = [:]
        for total in comparison.previousByCategory {
            previousByID[total.id] = total
        }

        var currentByID: [String: CategorySpendTotal] = [:]
        for total in comparison.currentByCategory {
            currentByID[total.id] = total
        }

        let allIDs = Set(previousByID.keys).union(currentByID.keys)

        let movers = allIDs.compactMap { id -> CategoryMover? in
            let current = currentByID[id]
            let previous = previousByID[id]
            guard let sample = current ?? previous else {
                return nil
            }

            let currentTotal = current?.total ?? .zeroUSD
            let previousTotal = previous?.total ?? .zeroUSD
            let delta = currentTotal - previousTotal

            guard delta.amountMinor != 0 else {
                return nil
            }

            // Either side must clear the floor, so a category that appeared from nothing still
            // ranks if it's material — it just won't carry a percentage.
            guard max(currentTotal.amountMinor, previousTotal.amountMinor) >= minimumBase.amountMinor else {
                return nil
            }

            let fraction = previousTotal.amountMinor > 0
                ? Double(delta.amountMinor) / Double(previousTotal.amountMinor)
                : nil

            return CategoryMover(
                categoryID: sample.categoryID,
                categoryName: sample.categoryName,
                current: currentTotal,
                previous: previousTotal,
                delta: delta,
                fractionChange: fraction
            )
        }
        .sorted { abs($0.delta.amountMinor) > abs($1.delta.amountMinor) }

        return Array(movers.prefix(max(0, limit)))
    }

    /// Settled debits only — pending charges can still vanish, and credits aren't spending.
    private static func settledDebits(_ transactions: [Transaction]) -> [Transaction] {
        transactions.filter { $0.direction == .debit && !$0.pending }
    }

    private static func categoryTotals(
        _ transactions: [Transaction],
        names: [String: String]
    ) -> [CategorySpendTotal] {
        Dictionary(grouping: transactions, by: \.categoryID)
            .map { categoryID, rows in
                CategorySpendTotal(
                    categoryID: categoryID,
                    categoryName: categoryID.flatMap { names[$0] } ?? "Uncategorized",
                    total: sum(rows)
                )
            }
            .sorted { $0.total.amountMinor > $1.total.amountMinor }
    }

    private static func sum(_ transactions: [Transaction]) -> Money {
        guard let currency = transactions.first?.amount.currency else {
            return .zeroUSD
        }

        return (try? Money.sum(transactions.map(\.amount), currency: currency))
            ?? Money(amountMinor: 0, currency: currency)
    }
}
