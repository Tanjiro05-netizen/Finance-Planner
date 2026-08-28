@testable import Sift
import Testing

struct MoneyTests {
    @Test func arithmeticUsesMinorUnits() throws {
        let first = Money.usd(Cents.dollars(15, cents: 49))
        let second = Money.usd(Cents.dollars(12, cents: 99))

        #expect((first + second).amountMinor == 2848)
        #expect((first - second).amountMinor == 250)
        #expect(try Money.sum([first, second]) == Money.usd(2848))
    }

    @Test func compoundAssignmentMatchesOperators() {
        var running = Money.usd(1000)
        running += .usd(250)
        #expect(running == .usd(1250))
        running -= .usd(500)
        #expect(running == .usd(750))
    }

    @Test func cadenceMonthlyEquivalentRoundsInCents() {
        #expect(Cadence.monthly.monthlyEquivalent(for: .usd(1549)) == .usd(1549))
        #expect(Cadence.quarterly.monthlyEquivalent(for: .usd(3597)) == .usd(1199))
        #expect(Cadence.yearly.monthlyEquivalent(for: .usd(11988)) == .usd(999))
        #expect(Cadence.weekly.monthlyEquivalent(for: .usd(400)) == .usd(1733))
    }

    @Test func formattingUsesStoredCents() {
        #expect(Money.usd(24783).formatted() == "$247.83")
        #expect(Money.usd(14600).formatted(showZeroFraction: false) == "$146")
        #expect(Money(amountMinor: -1500, currency: "USD").formatted() == "-$15.00")
    }

    @Test func merchantKeysNormalizeRawNames() {
        #expect(MerchantKey("Creative Cloud, Inc.").rawValue == "creative-cloud-inc")
        #expect(MerchantKey("STREAMLINE+").rawValue == "streamline")
    }
}
