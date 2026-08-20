import SwiftUI

struct BudgetEditorSheetView: View {
    @Environment(AppModel.self) private var appModel
    @State private var viewModel: BudgetEditorViewModel

    init(
        budgetID: String? = nil,
        repositories: RepositoryContainer = .mock(),
        referenceDateProvider: @escaping () -> Date = { Date() }
    ) {
        _viewModel = State(initialValue: BudgetEditorViewModel(
            budgetID: budgetID,
            repositories: repositories,
            referenceDateProvider: referenceDateProvider
        ))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.xl) {
                    periodField
                    categoryField
                    amountField
                    rolloverField

                    if let errorMessage = viewModel.errorMessage {
                        Text(errorMessage)
                            .font(.siftBody)
                            .foregroundStyle(Palette.negative)
                    }

                    PrimaryButton(title: "Save") {
                        if viewModel.save() {
                            appModel.dismissSheet()
                        }
                    }
                    .disabled(!viewModel.canSave)
                    .accessibilityIdentifier("budget-editor-save")

                    if viewModel.isEditing {
                        ClayButton(title: "Delete budget") {
                            if viewModel.delete() {
                                appModel.dismissSheet()
                            }
                        }
                        .accessibilityIdentifier("budget-editor-delete")
                    }
                }
                .padding(.horizontal, Spacing.screenHorizontal)
                .padding(.vertical, Spacing.xl)
            }
            .background(Palette.ground)
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

    private var periodField: some View {
        SegmentedControlGlass(
            segments: BudgetPeriod.allCases.map(\.displayName),
            selection: Binding(
                get: { viewModel.period.displayName },
                set: { name in
                    viewModel.period = BudgetPeriod.allCases.first { $0.displayName == name } ?? .monthly
                }
            )
        )
        .accessibilityIdentifier("budget-editor-period")
    }

    @ViewBuilder
    private var categoryField: some View {
        if !viewModel.categories.isEmpty {
            SiftSection {
                Text("Category")
                    .font(.siftLabel)
                    .foregroundStyle(Palette.inkFaint)
                Picker(
                    "Category",
                    selection: Binding(get: { viewModel.categoryID ?? "" }, set: { viewModel.categoryID = $0 })
                ) {
                    ForEach(viewModel.categories, id: \.id) { category in
                        Text(category.name).tag(category.id)
                    }
                }
                .labelsHidden()
                .accessibilityIdentifier("budget-editor-category")
            }
        }
    }

    private var amountField: some View {
        SiftSection {
            Text("Amount")
                .font(.siftLabel)
                .foregroundStyle(Palette.inkFaint)
            TextField("0.00", text: $viewModel.amountText)
                .font(.siftBody)
                .keyboardType(.decimalPad)
                .accessibilityIdentifier("budget-editor-amount")
        }
    }

    private var rolloverField: some View {
        SiftSection {
            Toggle("Roll over what's left", isOn: $viewModel.rolloverEnabled)
                .toggleStyle(SiftToggleStyle())
                .font(.siftBody)
                .accessibilityIdentifier("budget-editor-rollover")
            Text("Unspent money is added to next period's allowance.")
                .font(.siftBody)
                .foregroundStyle(Palette.inkSoft)
        }
    }
}

#Preview {
    BudgetEditorSheetView(repositories: .mock())
        .environment(AppModel())
}
