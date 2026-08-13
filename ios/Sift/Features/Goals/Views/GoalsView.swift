import SwiftUI

struct GoalsView: View {
    @Environment(AppModel.self) private var appModel
    @State private var viewModel: GoalsViewModel

    init(
        repositories: RepositoryContainer = .mock(),
        referenceDateProvider: @escaping () -> Date = { Date() }
    ) {
        _viewModel = State(initialValue: GoalsViewModel(
            repositories: repositories,
            referenceDateProvider: referenceDateProvider
        ))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xl) {
                ScreenHeader(title: "Goals")
                    .accessibilityIdentifier("goals-title")

                content
            }
            .padding(.horizontal, Spacing.screenHorizontal)
            .padding(.top, Spacing.xl)
            .padding(.bottom, 84)
        }
        .background(Palette.bone)
        .navigationTitle("Goals")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    appModel.present(.goalEditor(goalID: nil))
                } label: {
                    Image(systemName: SiftIcon.plus)
                }
                .accessibilityIdentifier("goals-add")
            }
        }
        .task { viewModel.load() }
        .onChange(of: appModel.sheet) { _, sheet in
            // Reload once an editor or contribution sheet closes, so the list reflects it.
            if sheet == nil {
                viewModel.load()
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if let errorMessage = viewModel.errorMessage {
            StateMessageCard(
                title: "Goals unavailable",
                message: errorMessage,
                systemImage: SiftIcon.warning,
                actionTitle: "Try again"
            ) {
                viewModel.load()
            }
        } else if viewModel.isEmpty {
            StateMessageCard(
                title: "No goals yet",
                message: "Set something aside for — a trip, a new laptop, a rainy day — and track what you've saved.",
                systemImage: SiftIcon.goal,
                actionTitle: "Add a goal"
            ) {
                appModel.present(.goalEditor(goalID: nil))
            }
        } else {
            summaryCard

            VStack(alignment: .leading, spacing: Spacing.md) {
                ForEach(viewModel.rows) { row in
                    GoalRow(model: row) {
                        appModel.present(.goalContribution(goalID: row.id))
                    }
                }
            }
        }
    }

    private var summaryCard: some View {
        SiftCard {
            // Saved leads; the target is context. Progress made is what keeps people coming back.
            Text("SAVED SO FAR")
                .font(.siftLabel)
                .foregroundStyle(Palette.inkFaint)
            MoneyText(value: viewModel.totalSaved.formatted(), size: 42, color: Palette.goldDeep)
            Text("of \(viewModel.totalTarget.formatted()) across \(viewModel.rows.count) goals")
                .font(.siftBody)
                .foregroundStyle(Palette.inkSoft)
        }
    }
}

/// Pushes `GoalsView` wired to the live environment repositories, so the navigation
/// destination doesn't fall back to mock data.
struct GoalsRouteView: View {
    @Environment(\.repositories) private var repositories

    var body: some View {
        GoalsView(repositories: repositories)
    }
}

#Preview {
    NavigationStack {
        GoalsView(
            repositories: .mock(),
            referenceDateProvider: { SeedData.referenceDate }
        )
    }
    .environment(AppModel())
}
