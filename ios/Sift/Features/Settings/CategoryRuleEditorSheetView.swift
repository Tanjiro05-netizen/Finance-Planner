import SwiftUI

struct CategoryRuleEditorSheetView: View {
    @Environment(AppModel.self) private var appModel
    @State private var viewModel: CategoryRuleEditorViewModel

    init(ruleID: String? = nil, repositories: RepositoryContainer = .mock()) {
        _viewModel = State(initialValue: CategoryRuleEditorViewModel(
            ruleID: ruleID,
            repositories: repositories
        ))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.xl) {
                    kindField
                    patternField
                    categoryField
                    enabledField

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
                    .accessibilityIdentifier("category-rule-editor-save")

                    if viewModel.isEditing {
                        ClayButton(title: "Delete rule") {
                            if viewModel.delete() {
                                appModel.dismissSheet()
                            }
                        }
                        .accessibilityIdentifier("category-rule-editor-delete")
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

    private var kindField: some View {
        SegmentedControlGlass(
            segments: CategoryRuleKind.allCases.map(\.label),
            selection: Binding(
                get: { viewModel.kind.label },
                set: { label in
                    viewModel.kind = CategoryRuleKind.allCases.first { $0.label == label } ?? .merchantContains
                }
            )
        )
        .accessibilityIdentifier("category-rule-editor-kind")
    }

    private var patternField: some View {
        SiftSection {
            Text("Matches")
                .font(.siftLabel)
                .foregroundStyle(Palette.inkFaint)
            TextField(viewModel.patternPrompt, text: $viewModel.pattern)
                .font(.siftBody)
                .keyboardType(viewModel.kind == .merchantCategoryCode ? .numberPad : .default)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.characters)
                .accessibilityIdentifier("category-rule-editor-pattern")
            Text(viewModel.patternHelp)
                .font(.siftBody)
                .foregroundStyle(Palette.inkSoft)
        }
    }

    @ViewBuilder
    private var categoryField: some View {
        if !viewModel.categories.isEmpty {
            SiftSection {
                Text("File it under")
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
                .accessibilityIdentifier("category-rule-editor-category")
            }
        }
    }

    private var enabledField: some View {
        SiftSection {
            Toggle("Rule is on", isOn: $viewModel.isEnabled)
                .toggleStyle(SiftToggleStyle())
                .font(.siftBody)
                .accessibilityIdentifier("category-rule-editor-enabled")
            Text("Turn a rule off to stop it applying without deleting it.")
                .font(.siftBody)
                .foregroundStyle(Palette.inkSoft)
        }
    }
}

#Preview {
    CategoryRuleEditorSheetView(repositories: .mock())
        .environment(AppModel())
}
