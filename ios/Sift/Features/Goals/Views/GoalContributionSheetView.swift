import SwiftUI

struct GoalContributionSheetView: View {
    @Environment(AppModel.self) private var appModel
    @State private var viewModel: GoalContributionViewModel
    private let goalID: String

    init(
        goalID: String,
        repositories: RepositoryContainer = .mock(),
        referenceDateProvider: @escaping () -> Date = { Date() }
    ) {
        self.goalID = goalID
        _viewModel = State(initialValue: GoalContributionViewModel(
            goalID: goalID,
            repositories: repositories,
            referenceDateProvider: referenceDateProvider
        ))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.xl) {
                    savedCard
                    directionField
                    amountField
                    dateField
                    noteField

                    if let errorMessage = viewModel.errorMessage {
                        Text(errorMessage)
                            .font(.siftBody)
                            .foregroundStyle(Palette.negative)
                    }

                    PrimaryButton(title: "Record") {
                        if viewModel.save() {
                            appModel.dismissSheet()
                        }
                    }
                    .disabled(!viewModel.canSave)
                    .accessibilityIdentifier("goal-contribution-save")

                    editGoalButton
                    history
                }
                .padding(.horizontal, Spacing.screenHorizontal)
                .padding(.vertical, Spacing.xl)
            }
            .background(Palette.ground)
            .navigationTitle(viewModel.goalName.isEmpty ? "Goal" : viewModel.goalName)
            .task { viewModel.load() }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        appModel.dismissSheet()
                    }
                }
            }
        }
        .presentationDragIndicator(.visible)
        .presentationDetents([.large])
    }

    private var savedCard: some View {
        SiftSection {
            Text("Saved so far")
                .font(.siftLabel)
                .foregroundStyle(Palette.inkFaint)
            MoneyText(value: viewModel.savedSoFar.formatted(), size: 34, color: Palette.accent)
        }
    }

    private var directionField: some View {
        SegmentedControlGlass(
            segments: GoalContributionDirection.allCases.map(\.displayName),
            selection: Binding(
                get: { viewModel.direction.displayName },
                set: { name in
                    viewModel.direction = GoalContributionDirection.allCases
                        .first { $0.displayName == name } ?? .deposit
                }
            )
        )
        .accessibilityIdentifier("goal-contribution-direction")
    }

    private var amountField: some View {
        SiftSection {
            Text("Amount")
                .font(.siftLabel)
                .foregroundStyle(Palette.inkFaint)
            TextField("0.00", text: $viewModel.amountText)
                .font(.siftBody)
                .keyboardType(.decimalPad)
                .accessibilityIdentifier("goal-contribution-amount")
        }
    }

    private var dateField: some View {
        SiftSection {
            DatePicker("Date", selection: $viewModel.date, displayedComponents: .date)
                .font(.siftBody)
                .accessibilityIdentifier("goal-contribution-date")
        }
    }

    private var noteField: some View {
        SiftSection {
            Text("NOTE (OPTIONAL)")
                .font(.siftLabel)
                .foregroundStyle(Palette.inkFaint)
            TextField("e.g. Borrowed for a repair", text: $viewModel.note)
                .font(.siftBody)
                .accessibilityIdentifier("goal-contribution-note")
        }
    }

    private var editGoalButton: some View {
        SecondaryButton(title: "Edit goal") {
            appModel.present(.goalEditor(goalID: goalID))
        }
        .accessibilityIdentifier("goal-contribution-edit")
    }

    @ViewBuilder
    private var history: some View {
        if !viewModel.contributions.isEmpty {
            VStack(alignment: .leading, spacing: Spacing.md) {
                Text("History")
                    .font(.siftLabel)
                    .foregroundStyle(Palette.inkFaint)

                ForEach(viewModel.contributions, id: \.id) { contribution in
                    GoalContributionRow(contribution: contribution)
                }
            }
        }
    }
}

#Preview {
    GoalContributionSheetView(
        goalID: SeedData.ID.emergencyGoal,
        repositories: .mock(),
        referenceDateProvider: { SeedData.referenceDate }
    )
    .environment(AppModel())
}
