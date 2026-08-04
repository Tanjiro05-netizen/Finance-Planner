@testable import Sift
import SwiftUI
import Testing
import UIKit

@MainActor
struct CoreScreensRenderTests {
    @Test func dashboardRendersAtDefaultAndLargeDynamicType() {
        assertRenders {
            HomeView(
                repositories: .mock(),
                referenceDateProvider: { Self.referenceDate }
            )
        }
    }

    @Test func subscriptionsRendersAtDefaultAndLargeDynamicType() {
        assertRenders {
            SubscriptionsView(
                repositories: .mock(),
                referenceDateProvider: { Self.referenceDate }
            )
        }
    }

    @Test func detailRendersAtDefaultAndLargeDynamicType() {
        assertRenders {
            DetailSheetView(
                subscriptionID: SeedData.ID.streamline,
                repositories: .mock()
            )
        }
    }

    @Test func insightsRendersAtDefaultAndLargeDynamicType() {
        assertRenders {
            InsightsView(
                repositories: .mock(),
                referenceDateProvider: { Self.referenceDate }
            )
        }
    }

    @Test func transactionsRendersAtDefaultAndLargeDynamicType() {
        assertRenders {
            TransactionsView(
                repositories: .mock(),
                referenceDateProvider: { Self.referenceDate }
            )
        }
    }

    @Test func transactionsEmptyStateRenders() {
        assertRenders {
            TransactionsView(
                repositories: .emptyMock(),
                referenceDateProvider: { Self.referenceDate }
            )
        }
    }

    @Test func cashFlowForecastRenders() {
        assertRenders {
            CashFlowForecastView(
                repositories: .mock(),
                referenceDateProvider: { Self.referenceDate }
            )
        }
    }

    @Test func cashFlowForecastUnavailableStateRenders() {
        assertRenders {
            CashFlowForecastView(
                repositories: .emptyMock(),
                referenceDateProvider: { Self.referenceDate }
            )
        }
    }

    @Test func budgetsRendersAtDefaultAndLargeDynamicType() {
        assertRenders {
            BudgetsView(
                repositories: .mock(),
                referenceDateProvider: { Self.referenceDate }
            )
        }
    }

    @Test func budgetsEmptyStateRenders() {
        assertRenders {
            BudgetsView(
                repositories: .emptyMock(),
                referenceDateProvider: { Self.referenceDate }
            )
        }
    }

    @Test func budgetEditorRenders() {
        assertRenders {
            BudgetEditorSheetView(
                budgetID: SeedData.ID.groceriesBudget,
                repositories: .mock(),
                referenceDateProvider: { Self.referenceDate }
            )
        }
    }

    @Test func affordabilityCheckRenders() {
        assertRenders {
            AffordabilityCheckSheetView(
                repositories: .mock(),
                referenceDateProvider: { Self.referenceDate }
            )
        }
    }

    private func assertRenders(@ViewBuilder content: () -> some View) {
        render(content(), dynamicTypeSize: .large)
        render(content(), dynamicTypeSize: .accessibility2)
    }

    private func render(_ content: some View, dynamicTypeSize: DynamicTypeSize) {
        let controller = UIHostingController(
            rootView: NavigationStack {
                content
            }
            .environment(AppModel())
            .environment(\.colorScheme, .light)
            .environment(\.dynamicTypeSize, dynamicTypeSize)
        )
        controller.view.frame = CGRect(x: 0, y: 0, width: 393, height: 852)
        controller.loadViewIfNeeded()
        controller.view.setNeedsLayout()
        controller.view.layoutIfNeeded()

        #expect(controller.view != nil)
        #expect(controller.view.bounds.size != .zero)
    }

    private static var referenceDate: Date {
        Calendar.utc.date(from: DateComponents(year: 2026, month: 7, day: 1, hour: 10)) ?? Date()
    }
}
