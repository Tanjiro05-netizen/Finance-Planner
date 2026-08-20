import Foundation
import Observation
import SwiftUI

/// One recurring row — a bill or an income — flattened so the list renders both the same way.
struct RecurringRowModel: Identifiable, Equatable {
    let id: String
    let name: String
    let amount: Money
    let cadence: Cadence
    let nextDate: Date?
}

@MainActor
@Observable
final class BillsAndIncomeViewModel {
    private let repositories: RepositoryContainer

    var bills: [RecurringRowModel] = []
    var income: [RecurringRowModel] = []
    var hasLoaded = false
    var errorMessage: String?

    init(repositories: RepositoryContainer) {
        self.repositories = repositories
    }

    var isEmpty: Bool {
        hasLoaded && bills.isEmpty && income.isEmpty && errorMessage == nil
    }

    /// Normalised to a month so a weekly bill and a yearly one can be compared and summed.
    var monthlyBillTotal: Money {
        monthlyTotal(of: bills)
    }

    var monthlyIncomeTotal: Money {
        monthlyTotal(of: income)
    }

    func load() {
        defer { hasLoaded = true }

        do {
            bills = try repositories.bills.all()
                .filter { $0.status == .active }
                .map { bill in
                    RecurringRowModel(
                        id: bill.id,
                        name: bill.name,
                        amount: bill.amount,
                        cadence: bill.cadence,
                        nextDate: bill.nextDue
                    )
                }
            income = try repositories.recurringIncome.all()
                .filter { $0.status == .active }
                .map { source in
                    RecurringRowModel(
                        id: source.id,
                        name: source.sourceName,
                        amount: source.amount,
                        cadence: source.cadence,
                        nextDate: source.nextExpected
                    )
                }
            errorMessage = nil
        } catch {
            errorMessage = userFacingMessage(for: error)
        }
    }

    private func monthlyTotal(of rows: [RecurringRowModel]) -> Money {
        let values = rows.map { $0.cadence.monthlyEquivalent(for: $0.amount) }
        return (try? Money.sum(values)) ?? .zeroUSD
    }

    private func userFacingMessage(for error: Error) -> String {
        if let siftError = error as? SiftError {
            return siftError.errorDescription ?? "Something went wrong."
        }

        return error.localizedDescription
    }
}

/// The manual way into bills and recurring income.
///
/// Placed under Settings rather than on the Transactions screen on purpose. Transactions is
/// a ledger of things that already happened; a bill is a standing commitment, closer to
/// linked accounts and categories than to any single charge. Settings is also already the
/// screen people open when something Sift decided for them is wrong, which is exactly the
/// job here — detection missed the rent and the safe-to-spend number needs correcting.
/// Reached through Home → Settings → Bills & income, so it is normal navigation rather than
/// a deep link.
struct BillsAndIncomeView: View {
    @Environment(AppModel.self) private var appModel
    @State private var viewModel: BillsAndIncomeViewModel

    init(repositories: RepositoryContainer = .mock()) {
        _viewModel = State(initialValue: BillsAndIncomeViewModel(repositories: repositories))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xl) {
                ScreenHeader(title: "Bills & income")
                    .accessibilityIdentifier("bills-income-title")

                content
            }
            .padding(.horizontal, Spacing.screenHorizontal)
            .padding(.top, Spacing.xl)
            .padding(.bottom, 84)
        }
        .background(Palette.ground)
        .navigationTitle("Bills & income")
        .task { viewModel.load() }
        .onChange(of: appModel.sheet) { _, sheet in
            // Reload once an editor sheet closes, so the list reflects it.
            if sheet == nil {
                viewModel.load()
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if let errorMessage = viewModel.errorMessage {
            StateMessageCard(
                title: "Bills unavailable",
                message: errorMessage,
                systemImage: SiftIcon.warning,
                actionTitle: "Try again"
            ) {
                viewModel.load()
            }
        } else {
            if viewModel.isEmpty {
                StateMessageCard(
                    title: "Nothing recurring yet",
                    message: """
                    Sift finds most bills and paydays on its own. Add the ones it missed \
                    and the safe-to-spend number will follow.
                    """,
                    systemImage: SiftIcon.calendar
                )
            }

            section(
                title: "Bills",
                total: viewModel.monthlyBillTotal,
                rows: viewModel.bills,
                addTitle: "Add a bill"
            ) { id in
                appModel.present(.billEditor(billID: id))
            }

            section(
                title: "Income",
                total: viewModel.monthlyIncomeTotal,
                rows: viewModel.income,
                addTitle: "Add income"
            ) { id in
                appModel.present(.incomeEditor(incomeID: id))
            }
        }
    }

    private func section(
        title: String,
        total: Money,
        rows: [RecurringRowModel],
        addTitle: String,
        edit: @escaping (String?) -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            if rows.isEmpty {
                SiftSection(header: title) {
                    StateMessageCard(
                        title: title,
                        message: "Nothing here yet.",
                        systemImage: SiftIcon.calendar,
                        prominence: .inline
                    )
                }
            } else {
                // The separator starts under the text rather than under the monogram, which
                // is where iOS puts it: tile width plus the gap after it.
                SiftRowSection(
                    header: title,
                    footer: "\(total.formatted()) a month",
                    data: rows,
                    separatorInset: Spacing.lg + 38 + Spacing.md
                ) { row in
                    Button {
                        edit(row.id)
                    } label: {
                        RecurringRow(row: row)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("recurring-row-\(row.id)")
                }
            }

            SecondaryButton(title: addTitle) {
                edit(nil)
            }
            .accessibilityIdentifier("recurring-add-\(title.lowercased())")
        }
    }
}

private struct RecurringRow: View {
    let row: RecurringRowModel

    var body: some View {
        HStack(spacing: Spacing.md) {
            MonogramTile(letter: row.name, color: Palette.ink)

            VStack(alignment: .leading, spacing: 3) {
                Text(row.name)
                    .font(.bodyEmphasis)
                    .foregroundStyle(Palette.ink)
                Text("\(row.cadence.displayName) - \(dateLabel)")
                    .font(.cadence)
                    .foregroundStyle(Palette.inkSoft)
            }

            Spacer(minLength: Spacing.sm)

            MoneyText(value: row.amount.formatted(), role: .row)

            Image(systemName: SiftIcon.chevronRight)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Palette.inkFaint)
        }
        // No fill of its own: the row sits inside a section that already carries the
        // surface, and a filled row inside a filled section is the card-inside-a-card the
        // old layout was full of.
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.md)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(row.name), \(row.amount.formatted()), \(row.cadence.displayName), \(dateLabel)")
    }

    private var dateLabel: String {
        guard let nextDate = row.nextDate else {
            return "No date set"
        }

        return nextDate.formatted(.dateTime.month(.abbreviated).day())
    }
}

#Preview {
    NavigationStack {
        BillsAndIncomeView(repositories: .mock())
    }
    .environment(AppModel())
}
