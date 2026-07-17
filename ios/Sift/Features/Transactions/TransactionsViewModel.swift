import Foundation
import Observation

enum TransactionSegment: CaseIterable, Equatable {
    case all
    case spending
    case income

    var title: String {
        switch self {
        case .all:
            "All"
        case .spending:
            "Spending"
        case .income:
            "Income"
        }
    }
}

struct TransactionRowModel: Identifiable, Equatable {
    let id: String
    let merchantName: String
    let categoryLabel: String
    let amount: String
    let direction: TransactionDirection
    let date: String
    let isPending: Bool
}

@MainActor
@Observable
final class TransactionsViewModel {
    private let repositories: RepositoryContainer
    private let referenceDateProvider: () -> Date
    private var categoriesByID: [String: Category] = [:]

    var selectedSegment: TransactionSegment = .all
    var isLoading = false
    var isRefreshing = false
    var hasLoaded = false
    var errorMessage: String?
    var transactions: [Transaction] = []
    var totalSpend = Money.zeroUSD
    var totalIncome = Money.zeroUSD

    init(
        repositories: RepositoryContainer,
        referenceDateProvider: @escaping () -> Date = { Date() }
    ) {
        self.repositories = repositories
        self.referenceDateProvider = referenceDateProvider
    }

    var isEmpty: Bool {
        hasLoaded && filteredRows.isEmpty && errorMessage == nil
    }

    var segmentTitles: [String] {
        TransactionSegment.allCases.map(\.title)
    }

    var selectedSegmentTitle: String {
        selectedSegment.title
    }

    var filteredRows: [TransactionRowModel] {
        rows(for: filteredTransactions)
    }

    func load() {
        loadContent()
    }

    func refresh() async {
        isRefreshing = true
        defer { isRefreshing = false }
        loadContent()
    }

    func selectSegment(title: String) {
        guard let segment = TransactionSegment.allCases.first(where: { $0.title == title }) else {
            return
        }

        selectedSegment = segment
    }

    private func loadContent() {
        if !hasLoaded {
            isLoading = true
        }

        defer {
            isLoading = false
            hasLoaded = true
        }

        do {
            let now = referenceDateProvider()
            let start = Calendar.utc.date(byAdding: .month, value: -1, to: now) ?? now
            categoriesByID = Dictionary(uniqueKeysWithValues: try repositories.categories.all().map { ($0.id, $0) })
            transactions = try repositories.transactions.transactions(from: start, to: now)
            totalSpend = try repositories.transactions.totalSpend(from: start, to: now)
            totalIncome = try repositories.transactions.totalIncome(from: start, to: now)
            errorMessage = nil
        } catch {
            errorMessage = userFacingMessage(for: error)
        }
    }

    private var filteredTransactions: [Transaction] {
        switch selectedSegment {
        case .all:
            transactions
        case .spending:
            transactions.filter { $0.direction == .debit }
        case .income:
            transactions.filter { $0.direction == .credit }
        }
    }

    private func rows(for transactions: [Transaction]) -> [TransactionRowModel] {
        transactions.map { transaction in
            TransactionRowModel(
                id: transaction.id,
                merchantName: transaction.merchantRaw,
                categoryLabel: categoryLabel(for: transaction),
                amount: transaction.amount.formatted(),
                direction: transaction.direction,
                date: transaction.date.formatted(.dateTime.month(.abbreviated).day()),
                isPending: transaction.pending
            )
        }
    }

    private func categoryLabel(for transaction: Transaction) -> String {
        if let categoryID = transaction.categoryID, let category = categoriesByID[categoryID] {
            return category.name
        }

        return transaction.categoryHint ?? "Uncategorized"
    }

    private func userFacingMessage(for error: Error) -> String {
        if let siftError = error as? SiftError {
            return siftError.errorDescription ?? "Something went wrong."
        }

        return error.localizedDescription
    }
}
