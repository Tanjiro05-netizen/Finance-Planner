import SwiftUI

struct BillEditorSheetView: View {
    @Environment(AppModel.self) private var appModel
    @State private var viewModel: BillEditorViewModel

    init(
        billID: String? = nil,
        repositories: RepositoryContainer = .mock(),
        referenceDateProvider: @escaping () -> Date = { Date() }
    ) {
        _viewModel = State(initialValue: BillEditorViewModel(
            billID: billID,
            repositories: repositories,
            referenceDateProvider: referenceDateProvider
        ))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.xl) {
                    nameField
                    amountField
                    cadenceField
                    nextDueField
                    categoryField

                    if viewModel.needsDateToAffectSafeToSpend {
                        // Said while editing rather than after saving: with no due date the
                        // bill never lands in the window safe-to-spend measures.
                        Text("Add a due date and Sift can hold this back from what's safe to spend.")
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
                    .accessibilityIdentifier("bill-editor-save")

                    if viewModel.isEditing {
                        ClayButton(title: "Delete bill") {
                            if viewModel.delete() {
                                appModel.dismissSheet()
                            }
                        }
                        .accessibilityIdentifier("bill-editor-delete")
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

    private var nameField: some View {
        SiftSection {
            Text("Name")
                .font(.siftLabel)
                .foregroundStyle(Palette.inkFaint)
            TextField("e.g. Rent", text: $viewModel.name)
                .font(.siftBody)
                .textInputAutocapitalization(.sentences)
                .accessibilityIdentifier("bill-editor-name")
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
                .accessibilityIdentifier("bill-editor-amount")
        }
    }

    private var cadenceField: some View {
        SiftSection {
            Text("How often")
                .font(.siftLabel)
                .foregroundStyle(Palette.inkFaint)
            Picker("How often", selection: $viewModel.cadence) {
                ForEach(BillEditorViewModel.selectableCadences, id: \.self) { cadence in
                    Text(cadence.displayName).tag(cadence)
                }
            }
            .labelsHidden()
            .accessibilityIdentifier("bill-editor-cadence")
        }
    }

    private var nextDueField: some View {
        SiftSection {
            Toggle("Next due", isOn: $viewModel.hasNextDue)
                .toggleStyle(SiftToggleStyle())
                .font(.siftBody)
                .accessibilityIdentifier("bill-editor-has-due")

            if viewModel.hasNextDue {
                DatePicker("Due", selection: $viewModel.nextDue, displayedComponents: .date)
                    .font(.siftBody)
                    .accessibilityIdentifier("bill-editor-due")
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
                .accessibilityIdentifier("bill-editor-category")
            }
        }
    }
}

#Preview {
    BillEditorSheetView(repositories: .mock())
        .environment(AppModel())
}
