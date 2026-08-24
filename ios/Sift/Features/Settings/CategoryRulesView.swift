import SwiftUI

/// The rule list. Lives in its own file rather than in `SettingsView.swift`, which is
/// already 1,400+ lines and carries the repo's only `swiftlint:disable file_length`.
struct CategoryRulesView: View {
    @Environment(AppModel.self) private var appModel
    @State private var viewModel: CategoryRulesViewModel

    init(repositories: RepositoryContainer = .mock()) {
        _viewModel = State(initialValue: CategoryRulesViewModel(repositories: repositories))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xl) {
                ScreenHeader(title: "Rules")
                    .accessibilityIdentifier("category-rules-title")

                content

                if let errorMessage = viewModel.errorMessage {
                    StateMessageCard(
                        title: "Rules unavailable",
                        message: errorMessage,
                        systemImage: SiftIcon.warning,
                        actionTitle: "Try again"
                    ) {
                        viewModel.load()
                    }
                }
            }
            .padding(.horizontal, Spacing.screenHorizontal)
            .padding(.top, Spacing.xl)
            .padding(.bottom, 84)
        }
        .background(Palette.ground)
        .navigationTitle("Rules")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    appModel.present(.categoryRuleEditor(ruleID: nil))
                } label: {
                    Image(systemName: SiftIcon.plus)
                }
                .accessibilityIdentifier("category-rules-add")
            }
        }
        .task { viewModel.load() }
        .onChange(of: appModel.sheet) { _, newValue in
            if newValue == nil {
                viewModel.load()
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isEmpty {
            StateMessageCard(
                title: "No rules yet",
                message: "A rule files matching transactions into a category automatically, "
                    + "overriding what Sift would have guessed.",
                systemImage: SiftIcon.list,
                actionTitle: "Add a rule"
            ) {
                appModel.present(.categoryRuleEditor(ruleID: nil))
            }
        } else {
            if let summary = viewModel.lastRunSummary {
                Text(summary)
                    .font(.siftBody)
                    .foregroundStyle(Palette.inkSoft)
                    .accessibilityIdentifier("category-rules-summary")
            }

            SiftRowSection(
                header: "Checked in order",
                footer: "The first rule that matches wins. Drag to reorder.",
                data: viewModel.rules,
                id: \.id
            ) { rule in
                Button {
                    appModel.present(.categoryRuleEditor(ruleID: rule.id))
                } label: {
                    CategoryRuleRow(
                        summary: viewModel.summary(for: rule),
                        categoryName: viewModel.categoryName(for: rule),
                        isEnabled: rule.isEnabled
                    )
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("category-rule-row-\(rule.id)")
            }
        }
    }
}

private struct CategoryRuleRow: View {
    let summary: String
    let categoryName: String
    let isEnabled: Bool

    var body: some View {
        HStack(spacing: Spacing.md) {
            VStack(alignment: .leading, spacing: 3) {
                Text(summary)
                    .font(.bodyEmphasis)
                    .foregroundStyle(isEnabled ? Palette.ink : Palette.inkFaint)
                Text(categoryName)
                    .font(.siftBody)
                    .foregroundStyle(Palette.inkSoft)
            }

            Spacer()

            if !isEnabled {
                Pill(text: "Off", variant: .neutral)
            }

            Image(systemName: SiftIcon.chevronRight)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Palette.inkFaint)
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.md)
    }
}

/// Pushes the list wired to the live environment repositories, so the navigation
/// destination doesn't fall back to mock data.
struct CategoryRulesRouteView: View {
    @Environment(\.repositories) private var repositories

    var body: some View {
        CategoryRulesView(repositories: repositories)
    }
}

#Preview("Empty") {
    NavigationStack {
        CategoryRulesView(repositories: .emptyMock())
    }
    .environment(AppModel())
}
