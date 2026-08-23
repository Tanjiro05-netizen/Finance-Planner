import SwiftUI

struct AffordabilityCheckSheetView: View {
    @Environment(AppModel.self) private var appModel
    @State private var viewModel: AffordabilityCheckViewModel

    init(
        repositories: RepositoryContainer = .mock(),
        referenceDateProvider: @escaping () -> Date = { Date() }
    ) {
        _viewModel = State(initialValue: AffordabilityCheckViewModel(
            repositories: repositories,
            referenceDateProvider: referenceDateProvider
        ))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.xl) {
                    amountField
                    categoryField

                    PrimaryButton(title: "Check") {
                        viewModel.check()
                    }
                    .disabled(!viewModel.canCheck)
                    .accessibilityIdentifier("affordability-check-run")

                    if let errorMessage = viewModel.errorMessage {
                        Text(errorMessage)
                            .font(.siftBody)
                            .foregroundStyle(Palette.negative)
                    }

                    if let assessment = viewModel.assessment {
                        verdictCard(assessment)
                    }
                }
                .padding(.horizontal, Spacing.screenHorizontal)
                .padding(.vertical, Spacing.xl)
            }
            .background(Palette.ground)
            .navigationTitle("Can I afford this?")
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

    private var amountField: some View {
        SiftSection {
            Text("Amount")
                .font(.siftLabel)
                .foregroundStyle(Palette.inkFaint)
            TextField("0.00", text: $viewModel.amountText)
                .font(.siftBody)
                .keyboardType(.decimalPad)
                .accessibilityIdentifier("affordability-amount")
        }
    }

    @ViewBuilder
    private var categoryField: some View {
        if !viewModel.categories.isEmpty {
            SiftSection {
                Text("CATEGORY (OPTIONAL)")
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
                .accessibilityIdentifier("affordability-category")
            }
        }
    }

    private func verdictCard(_ assessment: AffordabilityAssessment) -> some View {
        SiftSection {
            Text(assessment.verdict.headline)
                .font(.cardTitle)
                .foregroundStyle(verdictColor(assessment.verdict))
                .accessibilityIdentifier("affordability-verdict")

            ForEach(assessment.reasons) { reason in
                HStack(alignment: .top, spacing: Spacing.sm) {
                    Image(systemName: SiftIcon.chevronRight)
                        .font(.siftBody)
                        .foregroundStyle(Palette.inkFaint)
                    Text(reason.text)
                        .font(.siftBody)
                        .foregroundStyle(Palette.inkSoft)
                }
            }
        }
    }

    private func verdictColor(_ verdict: AffordabilityVerdict) -> Color {
        switch verdict {
        case .comfortable:
            Palette.positive
        case .tight:
            Palette.accent
        case .notAdvisable:
            Palette.negative
        }
    }
}

#Preview {
    AffordabilityCheckSheetView(
        repositories: .mock(),
        referenceDateProvider: { SeedData.referenceDate }
    )
    .environment(AppModel())
}
