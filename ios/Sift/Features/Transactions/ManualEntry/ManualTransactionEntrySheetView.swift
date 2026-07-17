import SwiftUI

struct ManualTransactionEntrySheetView: View {
    @Environment(AppModel.self) private var appModel
    @State private var viewModel: ManualTransactionEntryViewModel

    init(
        repositories: RepositoryContainer = .mock(),
        referenceDateProvider: @escaping () -> Date = { Date() }
    ) {
        _viewModel = State(initialValue: ManualTransactionEntryViewModel(
            repositories: repositories,
            referenceDateProvider: referenceDateProvider
        ))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.xl) {
                    directionField
                    merchantField
                    amountField
                    dateField
                    accountField
                    categoryField
                    noteField

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
                    .accessibilityIdentifier("manual-entry-save")
                }
                .padding(.horizontal, Spacing.screenHorizontal)
                .padding(.vertical, Spacing.xl)
            }
            .background(Palette.bone)
            .navigationTitle("Add Transaction")
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

    private var directionField: some View {
        SegmentedControlGlass(
            segments: ["Spending", "Income"],
            selection: Binding(
                get: { viewModel.direction == .credit ? "Income" : "Spending" },
                set: { viewModel.direction = $0 == "Income" ? .credit : .debit }
            )
        )
        .accessibilityIdentifier("manual-entry-direction")
    }

    private var merchantField: some View {
        SiftCard {
            Text("MERCHANT")
                .font(.siftLabel)
                .foregroundStyle(Palette.inkFaint)
            TextField("e.g. Corner Market", text: $viewModel.merchantName)
                .font(.siftBody)
                .textInputAutocapitalization(.words)
                .accessibilityIdentifier("manual-entry-merchant")
        }
    }

    private var amountField: some View {
        SiftCard {
            Text("AMOUNT")
                .font(.siftLabel)
                .foregroundStyle(Palette.inkFaint)
            TextField("0.00", text: $viewModel.amountText)
                .font(.siftBody)
                .keyboardType(.decimalPad)
                .accessibilityIdentifier("manual-entry-amount")
        }
    }

    private var dateField: some View {
        SiftCard {
            DatePicker("Date", selection: $viewModel.date, displayedComponents: .date)
                .font(.siftBody)
                .accessibilityIdentifier("manual-entry-date")
        }
    }

    @ViewBuilder
    private var accountField: some View {
        if !viewModel.accounts.isEmpty {
            SiftCard {
                Text("ACCOUNT")
                    .font(.siftLabel)
                    .foregroundStyle(Palette.inkFaint)
                Picker(
                    "Account",
                    selection: Binding(get: { viewModel.accountID ?? "" }, set: { viewModel.accountID = $0 })
                ) {
                    ForEach(viewModel.accounts, id: \.id) { account in
                        Text(account.institutionName).tag(account.id)
                    }
                }
                .labelsHidden()
                .accessibilityIdentifier("manual-entry-account")
            }
        }
    }

    @ViewBuilder
    private var categoryField: some View {
        if !viewModel.categories.isEmpty {
            SiftCard {
                Text("CATEGORY")
                    .font(.siftLabel)
                    .foregroundStyle(Palette.inkFaint)
                Picker(
                    "Category",
                    selection: Binding(get: { viewModel.categoryID ?? "" }, set: { viewModel.categoryID = $0.isEmpty ? nil : $0 })
                ) {
                    Text("None").tag("")
                    ForEach(viewModel.categories, id: \.id) { category in
                        Text(category.name).tag(category.id)
                    }
                }
                .labelsHidden()
                .accessibilityIdentifier("manual-entry-category")
            }
        }
    }

    private var noteField: some View {
        SiftCard {
            Text("NOTE")
                .font(.siftLabel)
                .foregroundStyle(Palette.inkFaint)
            TextField("Optional", text: $viewModel.note)
                .font(.siftBody)
                .accessibilityIdentifier("manual-entry-note")
        }
    }
}

#Preview {
    ManualTransactionEntrySheetView(repositories: .mock())
        .environment(AppModel())
}
