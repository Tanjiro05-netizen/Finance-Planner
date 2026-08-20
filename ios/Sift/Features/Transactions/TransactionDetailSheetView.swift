import SwiftUI

/// Read-only transaction detail plus a category reassignment picker, presented as a
/// sheet from a `TransactionRow` tap -- mirrors how `SubscriptionsView` opens
/// `AppSheet.subscriptionDetail` rather than pushing a nav destination.
struct TransactionDetailSheetView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.repositories) private var repositories

    let transactionID: String

    @State private var categories: [Category] = []
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.xl) {
                    if let transaction {
                        SiftSection {
                            Text(transaction.merchantRaw)
                                .font(.bodyEmphasis)
                                .foregroundStyle(Palette.ink)

                            MoneyText(
                                value: transaction.amount.formatted(),
                                size: 32,
                                color: transaction.direction == .credit ? Palette.positive : Palette.ink
                            )

                            Text(transaction.date.formatted(.dateTime.month(.abbreviated).day().year()))
                                .font(.siftBody)
                                .foregroundStyle(Palette.inkSoft)

                            if let note = transaction.note, !note.isEmpty {
                                Text(note)
                                    .font(.siftBody)
                                    .foregroundStyle(Palette.inkSoft)
                            }
                        }

                        categoryPicker(for: transaction)

                        if let errorMessage {
                            Text(errorMessage)
                                .font(.siftBody)
                                .foregroundStyle(Palette.negative)
                        }
                    } else {
                        StateMessageCard(
                            title: "Transaction not found",
                            message: "This transaction is no longer available.",
                            systemImage: SiftIcon.transactions
                        )
                    }
                }
                .padding(.horizontal, Spacing.screenHorizontal)
                .padding(.vertical, Spacing.xl)
            }
            .background(Palette.ground)
            .navigationTitle("Transaction")
            .task { load() }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        appModel.dismissSheet()
                    }
                }
            }
        }
        .presentationDragIndicator(.visible)
        .presentationDetents([.medium, .large])
    }

    private var transaction: Transaction? {
        try? repositories.transactions.transaction(id: transactionID)
    }

    @ViewBuilder
    private func categoryPicker(for transaction: Transaction) -> some View {
        if !categories.isEmpty {
            SiftSection {
                Text("Category")
                    .font(.siftLabel)
                    .foregroundStyle(Palette.inkFaint)
                Picker(
                    "Category",
                    selection: Binding(
                        get: { transaction.categoryID ?? "" },
                        set: { assignCategory($0.isEmpty ? nil : $0) }
                    )
                ) {
                    Text("None").tag("")
                    ForEach(categories, id: \.id) { category in
                        Text(category.name).tag(category.id)
                    }
                }
                .labelsHidden()
                .accessibilityIdentifier("transaction-detail-category")
            }
        }
    }

    private func load() {
        do {
            categories = try repositories.categories.all()
            errorMessage = nil
        } catch {
            errorMessage = (error as? SiftError)?.errorDescription ?? error.localizedDescription
        }
    }

    private func assignCategory(_ categoryID: String?) {
        do {
            try CategoryService(repositories: repositories).manuallyAssign(
                transactionID: transactionID,
                categoryID: categoryID
            )
        } catch {
            errorMessage = (error as? SiftError)?.errorDescription ?? error.localizedDescription
        }
    }
}

#Preview {
    TransactionDetailSheetView(transactionID: SampleRouteID.transaction)
        .environment(AppModel())
        .environment(\.repositories, .mock())
}
