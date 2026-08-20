import SwiftUI

struct TransactionsView: View {
    @Environment(AppModel.self) private var appModel
    @State private var viewModel: TransactionsViewModel

    init(
        repositories: RepositoryContainer = .mock(),
        referenceDateProvider: @escaping () -> Date = { Date() }
    ) {
        _viewModel = State(initialValue: TransactionsViewModel(
            repositories: repositories,
            referenceDateProvider: referenceDateProvider
        ))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xl) {
                ScreenHeader(title: "Transactions")
                    .accessibilityIdentifier("transactions-title")

                content
            }
            .padding(.horizontal, Spacing.screenHorizontal)
            .padding(.top, Spacing.xl)
            .padding(.bottom, 84)
        }
        .background(Palette.ground)
        .navigationTitle("Transactions")
        .refreshable { await viewModel.refresh() }
        .task { viewModel.load() }
        .onChange(of: appModel.sheet) { _, newValue in
            if newValue == nil {
                viewModel.load()
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    appModel.present(.manualTransactionEntry)
                } label: {
                    Image(systemName: SiftIcon.plus)
                }
                .accessibilityIdentifier("transactions-add-button")
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading {
            TransactionsLoadingView()
        } else if let errorMessage = viewModel.errorMessage {
            StateMessageCard(
                title: "Transactions unavailable",
                message: errorMessage,
                systemImage: SiftIcon.warning,
                actionTitle: "Try again"
            ) {
                viewModel.load()
            }
        } else {
            TransactionsContentView(viewModel: viewModel) { transactionID in
                appModel.present(.transactionDetail(id: transactionID))
            }
        }
    }
}

private struct TransactionsContentView: View {
    let viewModel: TransactionsViewModel
    let openDetail: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xl) {
            TransactionsTotalsCard(viewModel: viewModel)

            SegmentedControlGlass(
                segments: viewModel.segmentTitles,
                selection: Binding(
                    get: { viewModel.selectedSegmentTitle },
                    set: { viewModel.selectSegment(title: $0) }
                )
            )
            .accessibilityIdentifier("transactions-segmented-control")

            if viewModel.isEmpty {
                StateMessageCard(
                    title: "No transactions yet",
                    message: "Transactions will appear here after the next account sync.",
                    systemImage: SiftIcon.transactions
                )
            } else {
                ForEach(viewModel.filteredRows) { row in
                    Button {
                        openDetail(row.id)
                    } label: {
                        TransactionRow(
                            merchantName: row.merchantName,
                            categoryLabel: row.categoryLabel,
                            amount: row.amount,
                            direction: row.direction,
                            date: row.date,
                            isPending: row.isPending
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("transaction-row-\(row.id)")
                    .accessibilityLabel("\(row.merchantName), \(row.categoryLabel), \(row.amount)")
                }
            }
        }
    }
}

private struct TransactionsTotalsCard: View {
    let viewModel: TransactionsViewModel

    var body: some View {
        SiftSection {
            Text("LAST 30 DAYS")
                .font(.siftLabel)
                .foregroundStyle(Palette.inkFaint)

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Spent")
                        .font(.siftLabel)
                        .foregroundStyle(Palette.inkFaint)
                    MoneyText(value: viewModel.totalSpend.formatted(), size: 24)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("Income")
                        .font(.siftLabel)
                        .foregroundStyle(Palette.inkFaint)
                    MoneyText(value: viewModel.totalIncome.formatted(), size: 24, color: Palette.positive)
                }
            }
        }
    }
}

private struct TransactionsLoadingView: View {
    var body: some View {
        VStack(spacing: Spacing.xl) {
            SiftSection {
                Text("LAST 30 DAYS")
                    .font(.siftLabel)
                MoneyText(value: "$000.00", size: 24)
            }

            ForEach(0 ..< 5, id: \.self) { _ in
                TransactionRow(
                    merchantName: "Merchant",
                    categoryLabel: "Category",
                    amount: "$00.00",
                    direction: .debit,
                    date: "Jan 1"
                )
            }
        }
        .redacted(reason: .placeholder)
        .accessibilityLabel("Loading transactions")
    }
}

#Preview("Loaded") {
    NavigationStack {
        TransactionsView(repositories: .mock())
    }
    .environment(AppModel())
}

#Preview("Empty") {
    NavigationStack {
        TransactionsView(repositories: .emptyMock())
    }
    .environment(AppModel())
}
