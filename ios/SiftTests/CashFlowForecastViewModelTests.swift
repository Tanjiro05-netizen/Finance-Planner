import Foundation
@testable import Sift
import Testing

@MainActor
struct CashFlowForecastViewModelTests {
    private static var referenceDate: Date {
        SeedData.referenceDate
    }

    @Test func loadsForecastFromSeededRepositories() {
        let viewModel = CashFlowForecastViewModel(
            repositories: .mock(),
            referenceDateProvider: { Self.referenceDate }
        )

        viewModel.load()

        #expect(viewModel.isUnavailable == false)
        #expect(viewModel.errorMessage == nil)
        let forecast = viewModel.forecast
        #expect(forecast != nil)
        #expect(forecast?.startingBalance == .usd(245_018))
        // Seeded rent bill and payroll income both recur within 30 days of the reference date.
        #expect(forecast?.events.contains { $0.kind == .income } == true)
        #expect(forecast?.events.contains { $0.kind == .billCharge } == true)
    }

    @Test func unavailableWithoutBalance() {
        let viewModel = CashFlowForecastViewModel(
            repositories: .emptyMock(),
            referenceDateProvider: { Self.referenceDate }
        )

        viewModel.load()

        #expect(viewModel.isUnavailable)
        #expect(viewModel.forecast == nil)
    }
}
