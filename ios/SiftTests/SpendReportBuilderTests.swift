import Foundation
@testable import Sift
import Testing

struct SpendReportBuilderTests {
    private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 12) -> Date {
        Calendar.utc.date(from: DateComponents(year: year, month: month, day: day, hour: hour)) ?? Date()
    }

    private func transaction(
        id: String,
        cents: Int,
        year: Int = 2026,
        month: Int,
        day: Int,
        category: String? = nil,
        direction: TransactionDirection = .debit,
        pending: Bool = false
    ) -> Transaction {
        Transaction(
            id: id,
            userID: SeedData.defaultUserID,
            accountID: SeedData.ID.checking,
            merchantRaw: "Merchant",
            merchantKey: MerchantKey("Merchant"),
            amount: .usd(cents),
            date: date(year, month, day),
            pending: pending,
            direction: direction,
            categoryID: category
        )
    }

    // MARK: - monthlyTotals

    @Test func monthlyTotalsBucketByCalendarMonthOldestFirst() {
        let points = SpendReportBuilder.monthlyTotals(
            transactions: [
                transaction(id: "a", cents: 1000, month: 4, day: 5),
                transaction(id: "b", cents: 2000, month: 5, day: 5),
                transaction(id: "c", cents: 500, month: 5, day: 20),
                transaction(id: "d", cents: 3000, month: 6, day: 5),
            ],
            months: 3,
            endingAt: date(2026, 6, 29)
        )

        #expect(points.count == 3)
        #expect(points.map(\.total) == [.usd(1000), .usd(2500), .usd(3000)])
        #expect(points.map(\.monthStart) == points.map(\.monthStart).sorted())
    }

    @Test func monthlyTotalsEmitEmptyMonthsSoTheChartHasNoGaps() {
        let points = SpendReportBuilder.monthlyTotals(
            transactions: [transaction(id: "a", cents: 1000, month: 6, day: 5)],
            months: 4,
            endingAt: date(2026, 6, 29)
        )

        #expect(points.count == 4)
        #expect(points.dropLast().allSatisfy { $0.total == .zeroUSD })
        #expect(points.last?.total == .usd(1000))
    }

    @Test func monthlyTotalsExcludeCreditsAndPending() {
        let points = SpendReportBuilder.monthlyTotals(
            transactions: [
                transaction(id: "spend", cents: 1000, month: 6, day: 5),
                transaction(id: "credit", cents: 9999, month: 6, day: 6, direction: .credit),
                transaction(id: "pending", cents: 9999, month: 6, day: 7, pending: true),
            ],
            months: 1,
            endingAt: date(2026, 6, 29)
        )

        #expect(points.last?.total == .usd(1000))
    }

    @Test func monthlyTotalsHaveUniqueIdentifiers() {
        // Duplicate ids in a Chart's ForEach shipped as a real bug in Phase 2.
        let points = SpendReportBuilder.monthlyTotals(
            transactions: [],
            months: 6,
            endingAt: date(2026, 6, 29)
        )

        #expect(Set(points.map(\.id)).count == points.count)
    }

    // MARK: - comparison

    @Test func partialMonthComparisonAlignsTheDayRange() {
        // On 6 June, the previous month must be truncated to 1–6 May. Comparing against all
        // of May would report a fake decrease every single time.
        let comparison = SpendReportBuilder.comparison(
            transactions: [
                transaction(id: "jun-early", cents: 3000, month: 6, day: 3),
                transaction(id: "may-early", cents: 2000, month: 5, day: 3),
                transaction(id: "may-late", cents: 50000, month: 5, day: 25),
            ],
            referenceDate: date(2026, 6, 6)
        )

        #expect(comparison.isPartialMonth)
        #expect(comparison.currentTotal == .usd(3000))
        // The 25 May charge is excluded because it falls outside the aligned window.
        #expect(comparison.previousTotal == .usd(2000))
        #expect(comparison.delta == .usd(1000))
    }

    @Test func completeMonthComparisonUsesTheWholePreviousMonth() {
        let comparison = SpendReportBuilder.comparison(
            transactions: [
                transaction(id: "jun-late", cents: 3000, month: 6, day: 30),
                transaction(id: "may-late", cents: 5000, month: 5, day: 28),
            ],
            referenceDate: date(2026, 6, 30)
        )

        #expect(comparison.isPartialMonth == false)
        #expect(comparison.previousTotal == .usd(5000))
    }

    @Test func comparisonClampsToTheShorterPreviousMonth() {
        // 30 March against February: February has only 28 days in 2026, so the aligned
        // window must not run past its end.
        let comparison = SpendReportBuilder.comparison(
            transactions: [transaction(id: "feb", cents: 1000, month: 2, day: 27)],
            referenceDate: date(2026, 3, 30)
        )

        #expect(comparison.previousInterval.end <= date(2026, 3, 1, hour: 0))
        #expect(comparison.dayCount <= 28)
    }

    @Test func comparisonResolvesCategoryNamesFromTheSuppliedMap() throws {
        let comparison = SpendReportBuilder.comparison(
            transactions: [transaction(id: "a", cents: 1000, month: 6, day: 3, category: "cat-groceries")],
            referenceDate: date(2026, 6, 6),
            categoryNames: ["cat-groceries": "Groceries"]
        )

        let groceries = try #require(comparison.currentByCategory.first)
        #expect(groceries.categoryName == "Groceries")
    }

    @Test func uncategorisedSpendIsItsOwnBucket() throws {
        let comparison = SpendReportBuilder.comparison(
            transactions: [transaction(id: "a", cents: 1000, month: 6, day: 3)],
            referenceDate: date(2026, 6, 6)
        )

        let bucket = try #require(comparison.currentByCategory.first)
        #expect(bucket.categoryID == nil)
        #expect(bucket.categoryName == "Uncategorized")
        #expect(bucket.id == "uncategorized")
    }

    @Test func fractionChangeIsNilWithoutABase() {
        let comparison = SpendReportBuilder.comparison(
            transactions: [transaction(id: "a", cents: 1000, month: 6, day: 3)],
            referenceDate: date(2026, 6, 6)
        )

        #expect(comparison.previousTotal == .zeroUSD)
        #expect(comparison.fractionChange == nil)
    }

    // MARK: - topMovers

    private func comparisonForMovers() -> SpendComparison {
        SpendReportBuilder.comparison(
            transactions: [
                // Groceries up $50 on a $100 base — material.
                transaction(id: "g-now", cents: 15000, month: 6, day: 3, category: "groceries"),
                transaction(id: "g-then", cents: 10000, month: 5, day: 3, category: "groceries"),
                // Sweets up 500% on a $2 base. The $10 move clears the delta floor, so this
                // isolates the base guard rather than being caught by both.
                transaction(id: "s-now", cents: 1200, month: 6, day: 4, category: "sweets"),
                transaction(id: "s-then", cents: 200, month: 5, day: 4, category: "sweets"),
                // Dining down $30.
                transaction(id: "d-now", cents: 2000, month: 6, day: 5, category: "dining"),
                transaction(id: "d-then", cents: 5000, month: 5, day: 5, category: "dining"),
            ],
            referenceDate: date(2026, 6, 6)
        )
    }

    @Test func topMoversRankByAbsoluteMoneyNotPercentage() throws {
        let movers = SpendReportBuilder.topMovers(comparison: comparisonForMovers())

        #expect(movers.first?.categoryID == "groceries")
        let groceries = try #require(movers.first)
        #expect(groceries.delta == .usd(5000))
        #expect(groceries.isIncrease)
    }

    @Test func smallBaseCategoriesAreExcludedDespiteALargePercentage() {
        let movers = SpendReportBuilder.topMovers(comparison: comparisonForMovers())

        // +200% on a $2 base must not outrank a $50 move.
        #expect(movers.contains { $0.categoryID == "sweets" } == false)
    }

    @Test func topMoversIncludeDecreases() throws {
        let movers = SpendReportBuilder.topMovers(comparison: comparisonForMovers())

        let dining = try #require(movers.first { $0.categoryID == "dining" })
        #expect(dining.delta == .usd(-3000))
        #expect(dining.isIncrease == false)
    }

    @Test func moverFractionChangeIsNilWhenTheCategoryIsNew() throws {
        let comparison = SpendReportBuilder.comparison(
            transactions: [transaction(id: "new", cents: 8000, month: 6, day: 3, category: "travel")],
            referenceDate: date(2026, 6, 6)
        )
        let movers = SpendReportBuilder.topMovers(comparison: comparison)

        let travel = try #require(movers.first { $0.categoryID == "travel" })
        #expect(travel.fractionChange == nil)
        #expect(travel.previous == .zeroUSD)
    }

    @Test func topMoversRespectTheLimit() {
        let movers = SpendReportBuilder.topMovers(comparison: comparisonForMovers(), limit: 1)

        #expect(movers.count == 1)
    }

    @Test func largeCategoriesThatBarelyMovedAreExcluded() {
        let comparison = SpendReportBuilder.comparison(
            transactions: [
                // Well clear of the base floor, but a 25-cent movement.
                transaction(id: "steady-now", cents: 4605, month: 6, day: 3, category: "dining"),
                transaction(id: "steady-then", cents: 4580, month: 5, day: 3, category: "dining"),
            ],
            referenceDate: date(2026, 6, 6)
        )

        #expect(SpendReportBuilder.topMovers(comparison: comparison).isEmpty)
    }

    @Test func theDeltaFloorIsIndependentOfTheBaseFloor() {
        // Groceries clear both floors; sweets clears neither; dining clears base but not delta.
        let comparison = SpendReportBuilder.comparison(
            transactions: [
                transaction(id: "g-now", cents: 15000, month: 6, day: 3, category: "groceries"),
                transaction(id: "g-then", cents: 10000, month: 5, day: 3, category: "groceries"),
                transaction(id: "d-now", cents: 4605, month: 6, day: 5, category: "dining"),
                transaction(id: "d-then", cents: 4580, month: 5, day: 5, category: "dining"),
            ],
            referenceDate: date(2026, 6, 6)
        )

        let movers = SpendReportBuilder.topMovers(comparison: comparison)
        #expect(movers.map(\.categoryID) == ["groceries"])

        // Lowering the delta floor lets the quiet category back in, so the two guards are
        // genuinely separate rather than one dressed as two.
        let relaxed = SpendReportBuilder.topMovers(comparison: comparison, minimumDelta: .usd(1))
        #expect(relaxed.contains { $0.categoryID == "dining" })
    }

    @Test func aZeroDeltaFloorStillExcludesCategoriesThatDidNotMove() {
        let comparison = SpendReportBuilder.comparison(
            transactions: [
                transaction(id: "a", cents: 5000, month: 6, day: 3, category: "same"),
                transaction(id: "b", cents: 5000, month: 5, day: 3, category: "same"),
            ],
            referenceDate: date(2026, 6, 6)
        )

        #expect(SpendReportBuilder.topMovers(comparison: comparison, minimumDelta: .zeroUSD).isEmpty)
    }

    @Test func unchangedCategoriesAreNotMovers() {
        let comparison = SpendReportBuilder.comparison(
            transactions: [
                transaction(id: "a", cents: 5000, month: 6, day: 3, category: "same"),
                transaction(id: "b", cents: 5000, month: 5, day: 3, category: "same"),
            ],
            referenceDate: date(2026, 6, 6)
        )

        #expect(SpendReportBuilder.topMovers(comparison: comparison).isEmpty)
    }
}
