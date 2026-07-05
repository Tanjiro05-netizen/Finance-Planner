import Testing
@testable import Sift

struct MoneyTests {
    @Test func arithmeticUsesMinorUnits() throws {
        let first = Money.usd(Cents.dollars(15, cents: 49))
        let second = Money.usd(Cents.dollars(12, cents: 99))

        #expect((first + second).amountMinor == 2_848)
        #expect((first - second).amountMinor == 250)
        #expect(try Money.sum([first, second]) == Money.usd(2_848))
    }

    @Test func cadenceMonthlyEquivalentRoundsInCents() {
        #expect(Cadence.monthly.monthlyEquivalent(for: .usd(1_549)) == .usd(1_549))
        #expect(Cadence.quarterly.monthlyEquivalent(for: .usd(3_597)) == .usd(1_199))
        #expect(Cadence.yearly.monthlyEquivalent(for: .usd(11_988)) == .usd(999))
        #expect(Cadence.weekly.monthlyEquivalent(for: .usd(400)) == .usd(1_733))
    }

    @Test func formattingUsesStoredCents() {
        #expect(Money.usd(24_783).formatted() == "$247.83")
        #expect(Money.usd(14_600).formatted(showZeroFraction: false) == "$146")
        #expect(Money(amountMinor: -1_500, currency: "USD").formatted() == "-$15.00")
    }

    @Test func merchantKeysNormalizeRawNames() {
        #expect(MerchantKey("Creative Cloud, Inc.").rawValue == "creative-cloud-inc")
        #expect(MerchantKey("STREAMLINE+").rawValue == "streamline")
    }
}

