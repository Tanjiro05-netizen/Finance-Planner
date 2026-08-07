import SwiftUI

struct GoalEditorSheetView: View {
    @Environment(AppModel.self) private var appModel
    @State private var viewModel: GoalEditorViewModel

    init(
        goalID: String? = nil,
        repositories: RepositoryContainer = .mock(),
        referenceDateProvider: @escaping () -> Date = { Date() }
    ) {
        _viewModel = State(initialValue: GoalEditorViewModel(
            goalID: goalID,
            repositories: repositories,
            referenceDateProvider: referenceDateProvider
        ))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.xl) {
                    nameField
                    targetField
                    targetDateField
                    monthlyContributionField

                    if viewModel.needsMoreForProjection {
                        // Said while editing rather than after saving: with only a target
                        // there is genuinely nothing to project.
                        Text("Add a target date or a monthly amount and Sift can tell you if you're on track.")
                            .font(.siftBody)
                            .foregroundStyle(Palette.inkSoft)
                    }

                    if let errorMessage = viewModel.errorMessage {
                        Text(errorMessage)
                            .font(.siftBody)
                            .foregroundStyle(Palette.clay)
                    }

                    PrimaryButton(title: "Save") {
                        if viewModel.save() {
                            appModel.dismissSheet()
                        }
                    }
                    .disabled(!viewModel.canSave)
                    .accessibilityIdentifier("goal-editor-save")

                    if viewModel.isEditing {
                        ClayButton(title: "Delete goal") {
                            if viewModel.delete() {
                                appModel.dismissSheet()
                            }
                        }
                        .accessibilityIdentifier("goal-editor-delete")
                    }
                }
                .padding(.horizontal, Spacing.screenHorizontal)
                .padding(.vertical, Spacing.xl)
            }
            .background(Palette.bone)
            .navigationTitle(viewModel.title)
            .task { viewModel.load() }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        appModel.dismissSheet()
                    }
                }
            }
        }
        .presentationDragIndicator(.visible)
        .presentationDetents([.large])
    }

    private var nameField: some View {
        SiftCard {
            Text("NAME")
                .font(.siftLabel)
                .foregroundStyle(Palette.inkFaint)
            TextField("e.g. Emergency fund", text: $viewModel.name)
                .font(.siftBody)
                .textInputAutocapitalization(.sentences)
                .accessibilityIdentifier("goal-editor-name")
        }
    }

    private var targetField: some View {
        SiftCard {
            Text("TARGET AMOUNT")
                .font(.siftLabel)
                .foregroundStyle(Palette.inkFaint)
            TextField("0.00", text: $viewModel.targetAmountText)
                .font(.siftBody)
                .keyboardType(.decimalPad)
                .accessibilityIdentifier("goal-editor-target")
        }
    }

    private var targetDateField: some View {
        SiftCard {
            Toggle("Target date", isOn: $viewModel.hasTargetDate)
                .toggleStyle(SiftToggleStyle())
                .font(.siftBody)
                .accessibilityIdentifier("goal-editor-has-date")

            if viewModel.hasTargetDate {
                DatePicker("By", selection: $viewModel.targetDate, displayedComponents: .date)
                    .font(.siftBody)
                    .accessibilityIdentifier("goal-editor-date")
            }
        }
    }

    private var monthlyContributionField: some View {
        SiftCard {
            Toggle("Monthly amount", isOn: $viewModel.hasMonthlyContribution)
                .toggleStyle(SiftToggleStyle())
                .font(.siftBody)
                .accessibilityIdentifier("goal-editor-has-monthly")

            if viewModel.hasMonthlyContribution {
                TextField("0.00", text: $viewModel.monthlyContributionText)
                    .font(.siftBody)
                    .keyboardType(.decimalPad)
                    .accessibilityIdentifier("goal-editor-monthly")
            }
        }
    }
}

#Preview {
    GoalEditorSheetView(repositories: .mock())
        .environment(AppModel())
}
