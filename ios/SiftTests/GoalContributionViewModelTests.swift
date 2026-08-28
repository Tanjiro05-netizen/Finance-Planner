import Foundation
@testable import Sift
import Testing

@MainActor
struct GoalContributionViewModelTests {
    private static var referenceDate: Date {
        SeedData.referenceDate
    }

    private func makeViewModel(
        goalID: String = SeedData.ID.emergencyGoal,
        repositories: RepositoryContainer = .mock()
    ) -> GoalContributionViewModel {
        GoalContributionViewModel(
            goalID: goalID,
            repositories: repositories,
            referenceDateProvider: { Self.referenceDate }
        )
    }

    @Test func loadBringsTheGoalNameAndHistory() {
        let viewModel = makeViewModel()

        viewModel.load()

        #expect(viewModel.goalName == "Emergency fund")
        #expect(viewModel.contributions.count == 5)
        #expect(viewModel.savedSoFar == .usd(125_000))
        #expect(viewModel.errorMessage == nil)
    }

    @Test func historyIncludesWithdrawalsInTheRunningTotal() {
        let viewModel = makeViewModel(goalID: SeedData.ID.laptopGoal)

        viewModel.load()

        #expect(viewModel.contributions.count == 3)
        // $150 + $150 - $60.
        #expect(viewModel.savedSoFar == .usd(24000))
    }

    @Test func canSaveRequiresAPositiveAmount() {
        let viewModel = makeViewModel()
        viewModel.load()

        #expect(viewModel.canSave == false)

        viewModel.amountText = "0"
        #expect(viewModel.canSave == false)

        viewModel.amountText = "abc"
        #expect(viewModel.canSave == false)

        viewModel.amountText = "75.25"
        #expect(viewModel.canSave)
    }

    @Test func recordingADepositAddsAPositiveEntry() throws {
        let repositories = RepositoryContainer.mock()
        let viewModel = GoalContributionViewModel(
            goalID: SeedData.ID.emergencyGoal,
            repositories: repositories,
            referenceDateProvider: { Self.referenceDate }
        )
        viewModel.load()

        viewModel.amountText = "300.00"
        viewModel.direction = .deposit

        #expect(viewModel.save())

        let contributions = try repositories.goals.contributions(forGoal: SeedData.ID.emergencyGoal)
        #expect(contributions.count == 6)
        #expect(GoalProjector.saved(from: contributions) == .usd(155_000))
    }

    @Test func recordingAWithdrawalStoresANegativeAmount() throws {
        let repositories = RepositoryContainer.mock()
        let viewModel = GoalContributionViewModel(
            goalID: SeedData.ID.emergencyGoal,
            repositories: repositories,
            referenceDateProvider: { Self.referenceDate }
        )
        viewModel.load()

        viewModel.amountText = "200.00"
        viewModel.direction = .withdrawal

        #expect(viewModel.save())

        let contributions = try repositories.goals.contributions(forGoal: SeedData.ID.emergencyGoal)
        // The sign lives on the stored amount, so the total is a plain sum.
        #expect(contributions.contains { $0.amount == .usd(-20000) })
        #expect(GoalProjector.saved(from: contributions) == .usd(105_000))
    }

    @Test func savingWithoutAnAmountReportsAnError() throws {
        let repositories = RepositoryContainer.mock()
        let viewModel = GoalContributionViewModel(
            goalID: SeedData.ID.emergencyGoal,
            repositories: repositories,
            referenceDateProvider: { Self.referenceDate }
        )
        viewModel.load()
        let before = try repositories.goals.contributions(forGoal: SeedData.ID.emergencyGoal).count

        #expect(viewModel.save() == false)
        #expect(viewModel.errorMessage != nil)
        #expect(try repositories.goals.contributions(forGoal: SeedData.ID.emergencyGoal).count == before)
    }

    @Test func anEmptyNoteIsNotStored() throws {
        let repositories = RepositoryContainer.mock()
        let viewModel = GoalContributionViewModel(
            goalID: SeedData.ID.emergencyGoal,
            repositories: repositories,
            referenceDateProvider: { Self.referenceDate }
        )
        viewModel.load()
        viewModel.amountText = "50"
        viewModel.note = "   "

        #expect(viewModel.save())

        let contributions = try repositories.goals.contributions(forGoal: SeedData.ID.emergencyGoal)
        let added = try #require(contributions.first { $0.amount == .usd(5000) })
        #expect(added.note == nil)
    }

    @Test func deletingAContributionRemovesItAndReloads() throws {
        let repositories = RepositoryContainer.mock()
        let viewModel = GoalContributionViewModel(
            goalID: SeedData.ID.emergencyGoal,
            repositories: repositories,
            referenceDateProvider: { Self.referenceDate }
        )
        viewModel.load()
        let target = try #require(viewModel.contributions.first)

        viewModel.delete(contributionID: target.id)

        #expect(viewModel.contributions.count == 4)
        #expect(viewModel.contributions.contains { $0.id == target.id } == false)
    }

    @Test func anUnknownGoalLoadsEmptyRatherThanFailing() {
        let viewModel = makeViewModel(goalID: "goal-does-not-exist")

        viewModel.load()

        #expect(viewModel.goalName.isEmpty)
        #expect(viewModel.contributions.isEmpty)
        #expect(viewModel.savedSoFar == .zeroUSD)
    }
}
