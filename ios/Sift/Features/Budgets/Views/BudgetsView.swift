import SwiftUI

struct BudgetsView: View {
    @Environment(AppModel.self) private var appModel
    @State private var viewModel: BudgetsViewModel

    init(
        repositories: RepositoryContainer = .mock(),
        referenceDateProvider: @escaping () -> Date = { Date() }
    ) {
        _viewModel = State(initialValue: BudgetsViewModel(
            repositories: repositories,
            referenceDateProvider: referenceDateProvider
        ))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xl) {
                ScreenHeader(title: "Budgets")
                    .accessibilityIdentifier("budgets-title")

                content
            }
            .padding(.horizontal, Spacing.screenHorizontal)
            .padding(.top, Spacing.xl)
            .padding(.bottom, 84)
        }
        .background(Palette.ground)
        .navigationTitle("Budgets")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    appModel.present(.budgetEditor(budgetID: nil))
                } label: {
                    Image(systemName: SiftIcon.plus)
                }
                .accessibilityIdentifier("budgets-add")
            }
        }
        .task { viewModel.load() }
    }

    @ViewBuilder
    private var content: some View {
        if let errorMessage = viewModel.errorMessage {
            StateMessageCard(
                title: "Budgets unavailable",
                message: errorMessage,
                systemImage: SiftIcon.warning,
                actionTitle: "Try again"
            ) {
                viewModel.load()
            }
        } else if viewModel.isEmpty {
            StateMessageCard(
                title: "No budgets yet",
                message: "Set a monthly limit on a category and Sift will track it against your spending.",
                systemImage: SiftIcon.budget,
                actionTitle: "Add a budget"
            ) {
                appModel.present(.budgetEditor(budgetID: nil))
            }
        } else {
            summaryCard
            affordabilityButton

            SiftRowSection(data: viewModel.rows, id: \.id) { row in
                BudgetRow(categoryName: row.categoryName, progress: row.progress) {
                    appModel.present(.budgetEditor(budgetID: row.id))
                }
            }
        }
    }

    private var summaryCard: some View {
        SiftSection {
            HStack {
                StatCell(label: "SPENT", value: viewModel.totalSpent.formatted())
                Spacer()
                StatCell(label: "BUDGETED", value: viewModel.totalBudgeted.formatted())
            }
        }
    }

    private var affordabilityButton: some View {
        SecondaryButton(title: "Can I afford this?") {
            appModel.present(.affordabilityCheck)
        }
        .accessibilityIdentifier("budgets-affordability")
    }
}

/// Pushes `BudgetsView` wired to the live environment repositories, so the navigation
/// destination doesn't fall back to mock data.
struct BudgetsRouteView: View {
    @Environment(\.repositories) private var repositories

    var body: some View {
        BudgetsView(repositories: repositories)
    }
}

#Preview {
    NavigationStack {
        BudgetsView(
            repositories: .mock(),
            referenceDateProvider: { SeedData.referenceDate }
        )
    }
    .environment(AppModel())
}
