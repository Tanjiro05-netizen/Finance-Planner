import Foundation
@testable import Sift
import Testing

@MainActor
struct GoalEditorViewModelTests {
    private static var referenceDate: Date {
        SeedData.referenceDate
    }

    private func makeViewModel(
        goalID: String? = nil,
        repositories: RepositoryContainer = .mock()
    ) -> GoalEditorViewModel {
        GoalEditorViewModel(
            goalID: goalID,
            repositories: repositories,
            referenceDateProvider: { Self.referenceDate }
        )
    }

    @Test func newGoalStartsEmptyWithADefaultDate() {
        let viewModel = makeViewModel()

        viewModel.load()

        #expect(viewModel.isEditing == false)
        #expect(viewModel.title == "New Goal")
        #expect(viewModel.name.isEmpty)
        #expect(viewModel.hasTargetDate == false)
        #expect(viewModel.hasMonthlyContribution == false)
        #expect(viewModel.targetDate > Self.referenceDate)
    }

    @Test func loadingAnExistingGoalPopulatesEveryField() {
        let viewModel = makeViewModel(goalID: SeedData.ID.emergencyGoal)

        viewModel.load()

        #expect(viewModel.isEditing)
        #expect(viewModel.title == "Edit Goal")
        #expect(viewModel.name == "Emergency fund")
        #expect(viewModel.targetAmountText == "3000.00")
        #expect(viewModel.hasTargetDate)
        #expect(viewModel.hasMonthlyContribution)
        #expect(viewModel.monthlyContributionText == "250.00")
    }

    @Test func aGoalWithoutADateLoadsWithTheToggleOff() {
        let viewModel = makeViewModel(goalID: SeedData.ID.laptopGoal)

        viewModel.load()

        #expect(viewModel.hasTargetDate == false)
        #expect(viewModel.hasMonthlyContribution)
    }

    @Test func canSaveRequiresANameAndAPositiveTarget() {
        let viewModel = makeViewModel()
        viewModel.load()

        #expect(viewModel.canSave == false)

        viewModel.name = "Trip"
        #expect(viewModel.canSave == false)

        viewModel.targetAmountText = "0"
        #expect(viewModel.canSave == false)

        viewModel.targetAmountText = "1200.50"
        #expect(viewModel.canSave)

        viewModel.name = "   "
        #expect(viewModel.canSave == false)
    }

    @Test func needsMoreForProjectionUntilADateOrAmountIsGiven() {
        let viewModel = makeViewModel()
        viewModel.load()
        viewModel.name = "Trip"
        viewModel.targetAmountText = "1200"

        #expect(viewModel.needsMoreForProjection)

        viewModel.hasTargetDate = true
        #expect(viewModel.needsMoreForProjection == false)

        viewModel.hasTargetDate = false
        viewModel.hasMonthlyContribution = true
        viewModel.monthlyContributionText = "100"
        #expect(viewModel.needsMoreForProjection == false)
    }

    @Test func savingANewGoalInsertsIt() throws {
        let repositories = RepositoryContainer.mock()
        let viewModel = GoalEditorViewModel(
            repositories: repositories,
            referenceDateProvider: { Self.referenceDate }
        )
        viewModel.load()
        let before = try repositories.goals.all().count

        viewModel.name = "Trip to Lisbon"
        viewModel.targetAmountText = "2400.00"
        viewModel.hasMonthlyContribution = true
        viewModel.monthlyContributionText = "200"

        #expect(viewModel.save())

        let all = try repositories.goals.all()
        #expect(all.count == before + 1)
        let inserted = try #require(all.first { $0.name == "Trip to Lisbon" })
        #expect(inserted.targetAmount == .usd(240_000))
        #expect(inserted.monthlyContribution == .usd(20000))
        #expect(inserted.targetDate == nil)
        #expect(inserted.status == .active)
    }

    @Test func savingTrimsWhitespaceFromTheName() throws {
        let repositories = RepositoryContainer.mock()
        let viewModel = GoalEditorViewModel(
            repositories: repositories,
            referenceDateProvider: { Self.referenceDate }
        )
        viewModel.load()
        viewModel.name = "  Padded  "
        viewModel.targetAmountText = "100"

        #expect(viewModel.save())
        #expect(try repositories.goals.all().contains { $0.name == "Padded" })
    }

    @Test func savingAnExistingGoalUpdatesItInPlace() throws {
        let repositories = RepositoryContainer.mock()
        let viewModel = GoalEditorViewModel(
            goalID: SeedData.ID.emergencyGoal,
            repositories: repositories,
            referenceDateProvider: { Self.referenceDate }
        )
        viewModel.load()
        let before = try repositories.goals.all().count

        viewModel.targetAmountText = "3500.00"
        viewModel.hasMonthlyContribution = false

        #expect(viewModel.save())

        #expect(try repositories.goals.all().count == before)
        let updated = try #require(try repositories.goals.goal(id: SeedData.ID.emergencyGoal))
        #expect(updated.targetAmount == .usd(350_000))
        // Turning the toggle off must actually clear the stored amount.
        #expect(updated.monthlyContribution == nil)
    }

    @Test func savingWithoutValidInputReportsAnError() throws {
        let repositories = RepositoryContainer.mock()
        let viewModel = GoalEditorViewModel(
            repositories: repositories,
            referenceDateProvider: { Self.referenceDate }
        )
        viewModel.load()
        let before = try repositories.goals.all().count

        #expect(viewModel.save() == false)
        #expect(viewModel.errorMessage != nil)
        #expect(try repositories.goals.all().count == before)
    }

    @Test func deletingRemovesTheGoal() throws {
        let repositories = RepositoryContainer.mock()
        let viewModel = GoalEditorViewModel(
            goalID: SeedData.ID.emergencyGoal,
            repositories: repositories,
            referenceDateProvider: { Self.referenceDate }
        )
        viewModel.load()

        #expect(viewModel.delete())
        #expect(try repositories.goals.goal(id: SeedData.ID.emergencyGoal) == nil)
    }

    @Test func deletingAnUnsavedGoalIsANoOp() {
        let viewModel = makeViewModel()
        viewModel.load()

        #expect(viewModel.delete() == false)
    }
}
