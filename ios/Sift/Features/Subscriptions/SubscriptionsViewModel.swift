import Foundation
import Observation

enum SubscriptionSegment: CaseIterable, Equatable {
    case all
    case active
    case unused

    var title: String {
        switch self {
        case .all:
            "All"
        case .active:
            "Active"
        case .unused:
            "Unused"
        }
    }
}

struct SubscriptionCategorySection: Identifiable, Equatable {
    let id: String
    let title: String
    let subscriptions: [Subscription]
}

@MainActor
@Observable
final class SubscriptionsViewModel {
    private let repositories: RepositoryContainer
    private let refresher: any SubscriptionRefreshing
    private let referenceDateProvider: () -> Date

    var selectedSegment: SubscriptionSegment = .all
    var isLoading = false
    var isRefreshing = false
    var hasLoaded = false
    var errorMessage: String?
    var monthlyTotal = Money.zeroUSD
    var potentialSavings = Money.zeroUSD
    var subscriptions: [Subscription] = []
    var sections: [SubscriptionCategorySection] = []

    init(
        repositories: RepositoryContainer,
        refresher: any SubscriptionRefreshing,
        referenceDateProvider: @escaping () -> Date = { Date() }
    ) {
        self.repositories = repositories
        self.refresher = refresher
        self.referenceDateProvider = referenceDateProvider
    }

    var isEmpty: Bool {
        hasLoaded && filteredSubscriptions.isEmpty && errorMessage == nil
    }

    var allCount: Int {
        subscriptions.count
    }

    var activeCount: Int {
        subscriptions.filter { $0.status == .active }.count
    }

    var unusedCount: Int {
        subscriptions.filter { $0.status == .unused }.count
    }

    var segmentTitles: [String] {
        SubscriptionSegment.allCases.map { segment in
            "\(segment.title) \(count(for: segment))"
        }
    }

    var selectedSegmentTitle: String {
        "\(selectedSegment.title) \(count(for: selectedSegment))"
    }

    var filteredSubscriptions: [Subscription] {
        filter(subscriptions)
    }

    func load() {
        loadContent(showLoading: !hasLoaded)
    }

    func selectSegment(title: String) {
        guard let segment = SubscriptionSegment.allCases.first(where: { title.hasPrefix($0.title) }) else {
            return
        }

        selectedSegment = segment
        rebuildSections()
    }

    func refresh() async {
        isRefreshing = true
        defer { isRefreshing = false }

        do {
            _ = try await refresher.refresh(referenceDate: referenceDateProvider())
            loadContent(showLoading: false)
        } catch {
            errorMessage = userFacingMessage(for: error)
        }
    }

    private func loadContent(showLoading: Bool) {
        if showLoading {
            isLoading = true
        }

        defer {
            isLoading = false
            hasLoaded = true
        }

        do {
            subscriptions = try repositories.subscriptions.all()
                .filter { $0.status != .cancelled }
            monthlyTotal = try repositories.subscriptions.monthlyTotal()
            potentialSavings = try repositories.subscriptions.potentialSavings(
                referenceDate: referenceDateProvider(),
                staleAfterDays: 60
            )
            rebuildSections()
            errorMessage = nil
        } catch {
            errorMessage = userFacingMessage(for: error)
        }
    }

    private func rebuildSections() {
        do {
            sections = try repositories.subscriptions.byCategory()
                .compactMap { group in
                    let filtered = filter(group.subscriptions)
                        .sorted { $0.monthlyEquivalent.amountMinor > $1.monthlyEquivalent.amountMinor }

                    guard !filtered.isEmpty else {
                        return nil
                    }

                    return SubscriptionCategorySection(
                        id: group.categoryID ?? group.categoryName,
                        title: group.categoryName,
                        subscriptions: filtered
                    )
                }
            errorMessage = nil
        } catch {
            errorMessage = userFacingMessage(for: error)
        }
    }

    private func filter(_ subscriptions: [Subscription]) -> [Subscription] {
        switch selectedSegment {
        case .all:
            subscriptions
        case .active:
            subscriptions.filter { $0.status == .active }
        case .unused:
            subscriptions.filter { $0.status == .unused }
        }
    }

    private func count(for segment: SubscriptionSegment) -> Int {
        switch segment {
        case .all:
            allCount
        case .active:
            activeCount
        case .unused:
            unusedCount
        }
    }

    private func userFacingMessage(for error: Error) -> String {
        if let siftError = error as? SiftError {
            return siftError.errorDescription ?? "Something went wrong."
        }

        return error.localizedDescription
    }
}
