import Foundation
@testable import Sift
import SwiftData
import Testing

@MainActor
struct SubscriptionRepositoryTests {
    @Test func monthlyTotalSumsMixedCadences() throws {
        let fixture = try makeFixture()

        let total = try fixture.repository.monthlyTotal()

        #expect(total == Money.usd(24783))
        #expect(total.formatted() == "$247.83")
    }

    @Test func unusedFiltersByLastUsedAge() throws {
        let fixture = try makeFixture()

        let unused = try fixture.repository.unused(referenceDate: SeedData.referenceDate, staleAfterDays: 60)

        #expect(unused.count == 5)
        #expect(unused.map(\.id).contains(SeedData.ID.creativeCloud))
        #expect(unused.allSatisfy { subscription in
            guard let lastUsed = subscription.lastUsed else {
                return false
            }
            return lastUsed <= Calendar.utc.date(byAdding: .day, value: -60, to: SeedData.referenceDate)!
        })
    }

    @Test func upcomingRenewalsSortByDate() throws {
        let fixture = try makeFixture()

        let renewals = try fixture.repository.upcomingRenewals(limit: 4)

        #expect(renewals.map(\.id) == [
            SeedData.ID.tonebox,
            SeedData.ID.cloudback,
            SeedData.ID.readwise,
            SeedData.ID.reelhouse,
        ])
    }

    @Test func potentialSavingsSumsUnusedMonthlyEquivalent() throws {
        let fixture = try makeFixture()

        let savings = try fixture.repository.potentialSavings(referenceDate: SeedData.referenceDate, staleAfterDays: 60)

        #expect(savings == Money.usd(14600))
        #expect(savings.formatted(showZeroFraction: false) == "$146")
    }

    @Test func noArgumentConveniencesForwardToSeedDataDefaults() throws {
        let fixture = try makeFixture()

        let unusedViaConvenience = try fixture.repository.unused()
        let unusedExplicit = try fixture.repository.unused(referenceDate: SeedData.referenceDate, staleAfterDays: 60)
        #expect(unusedViaConvenience.map(\.id) == unusedExplicit.map(\.id))

        let savingsViaConvenience = try fixture.repository.potentialSavings()
        let savingsExplicit = try fixture.repository.potentialSavings(referenceDate: SeedData.referenceDate, staleAfterDays: 60)
        #expect(savingsViaConvenience == savingsExplicit)
    }

    private func makeFixture() throws -> Fixture {
        let container = try SiftModelContainerFactory.makeSeededInMemoryContainer()
        return Fixture(
            container: container,
            repository: LiveSubscriptionRepository(modelContext: container.mainContext)
        )
    }

    private struct Fixture {
        let container: ModelContainer
        let repository: LiveSubscriptionRepository
    }
}
