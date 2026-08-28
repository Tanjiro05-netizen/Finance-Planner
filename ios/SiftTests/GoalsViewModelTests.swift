import Foundation
@testable import Sift
import Testing

@MainActor
struct GoalsViewModelTests {
    private static var referenceDate: Date {
        SeedData.referenceDate
    }

    private func makeViewModel(repositories: RepositoryContainer = .mock()) -> GoalsViewModel {
        GoalsViewModel(repositories: repositories, referenceDateProvider: { Self.referenceDate })
    }

    @Test func loadsSeededGoalsNewestFirst() {
        let viewModel = makeViewModel()

        viewModel.load()

        #expect(viewModel.errorMessage == nil)
        #expect(viewModel.rows.count == 2)
        // The laptop goal was created in March, the emergency fund in January.
        #expect(viewModel.rows.map(\.id) == [SeedData.ID.laptopGoal, SeedData.ID.emergencyGoal])
    }

    @Test func savedReflectsSignedContributions() throws {
        let viewModel = makeViewModel()

        viewModel.load()

        let laptop = try #require(viewModel.rows.first { $0.id == SeedData.ID.laptopGoal })
        // Two $150 deposits less a $60 withdrawal.
        #expect(laptop.outcome.saved == .usd(24000))

        let emergency = try #require(viewModel.rows.first { $0.id == SeedData.ID.emergencyGoal })
        #expect(emergency.outcome.saved == .usd(125_000))
    }

    @Test func totalsSumAcrossGoals() {
        let viewModel = makeViewModel()

        viewModel.load()

        #expect(viewModel.totalSaved == .usd(149_000))
        #expect(viewModel.totalTarget == .usd(480_000))
    }

    @Test func fractionCompleteIsDerivedPerGoal() throws {
        let viewModel = makeViewModel()

        viewModel.load()

        let emergency = try #require(viewModel.rows.first { $0.id == SeedData.ID.emergencyGoal })
        // $1250 of $3000.
        #expect(abs(emergency.fractionComplete - 125_000.0 / 300_000.0) < 0.0001)
    }

    @Test func seededGoalsAreNotBehind() {
        // Demo data is deliberately healthy, so the Home nudge stays hidden for it.
        let viewModel = makeViewModel()

        viewModel.load()

        #expect(viewModel.behindRows.isEmpty)
    }

    @Test func emptyStoreReportsEmptyRatherThanFailing() {
        let viewModel = makeViewModel(repositories: .emptyMock())

        viewModel.load()

        #expect(viewModel.rows.isEmpty)
        #expect(viewModel.isEmpty)
        #expect(viewModel.errorMessage == nil)
        #expect(viewModel.totalSaved == .zeroUSD)
    }
}
