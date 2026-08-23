import SwiftUI

struct IncomeEditorSheetView: View {
    @Environment(AppModel.self) private var appModel
    @State private var viewModel: IncomeEditorViewModel

    init(
        incomeID: String? = nil,
        repositories: RepositoryContainer = .mock(),
        referenceDateProvider: @escaping () -> Date = { Date() }
    ) {
        _viewModel = State(initialValue: IncomeEditorViewModel(
            incomeID: incomeID,
            repositories: repositories,
            referenceDateProvider: referenceDateProvider
        ))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.xl) {
                    sourceField
                    amountField
                    cadenceField
                    nextExpectedField
                    categoryField

                    if viewModel.needsDateToAffectSafeToSpend {
                        // Said while editing: the next expected date is what safe-to-spend
                        // counts down to, so without it this income changes nothing.
                        Text("Add the next payday and Sift can work out what's safe to spend until then.")
                            .font(.siftBody)
                            .foregroundStyle(Palette.inkSoft)
                    }

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
                    .accessibilityIdentifier("income-editor-save")

                    if viewModel.isEditing {
                        ClayButton(title: "Delete income") {
                            if viewModel.delete() {
                                appModel.dismissSheet()
                            }
                        }
                        .accessibilityIdentifier("income-editor-delete")
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

    private var sourceField: some View {
        SiftSection {
            Text("Source")
                .font(.siftLabel)
                .foregroundStyle(Palette.inkFaint)
            TextField("e.g. Northwind Labs", text: $viewModel.sourceName)
                .font(.siftBody)
                .textInputAutocapitalization(.words)
                .accessibilityIdentifier("income-editor-source")
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
                .accessibilityIdentifier("income-editor-amount")
        }
    }

    private var cadenceField: some View {
        SiftSection {
            Text("How often")
                .font(.siftLabel)
                .foregroundStyle(Palette.inkFaint)
            Picker("How often", selection: $viewModel.cadence) {
                ForEach(IncomeEditorViewModel.selectableCadences, id: \.self) { cadence in
                    Text(cadence.displayName).tag(cadence)
                }
            }
            .labelsHidden()
            .accessibilityIdentifier("income-editor-cadence")
        }
    }

    private var nextExpectedField: some View {
        SiftSection {
            Toggle("Next expected", isOn: $viewModel.hasNextExpected)
                .toggleStyle(SiftToggleStyle())
                .font(.siftBody)
                .accessibilityIdentifier("income-editor-has-expected")

            if viewModel.hasNextExpected {
                DatePicker("Expected", selection: $viewModel.nextExpected, displayedComponents: .date)
                    .font(.siftBody)
                    .accessibilityIdentifier("income-editor-expected")
            }
        }
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
                    selection: Binding(
                        get: { viewModel.categoryID ?? "" },
                        set: { viewModel.categoryID = $0.isEmpty ? nil : $0 }
                    )
                ) {
                    Text("None").tag("")
                    ForEach(viewModel.categories, id: \.id) { category in
                        Text(category.name).tag(category.id)
                    }
                }
                .labelsHidden()
                .accessibilityIdentifier("income-editor-category")
            }
        }
    }
}

#Preview {
    IncomeEditorSheetView(repositories: .mock())
        .environment(AppModel())
}
