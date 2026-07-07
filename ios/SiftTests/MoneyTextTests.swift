@testable import Sift
import Testing

struct MoneyTextTests {
    @Test(arguments: [
        ("$0", MoneyTextParts(symbol: "$", major: "0", fractional: nil, suffix: nil)),
        ("$15.49", MoneyTextParts(symbol: "$", major: "15", fractional: ".49", suffix: nil)),
        ("$1,247.83", MoneyTextParts(symbol: "$", major: "1,247", fractional: ".83", suffix: nil)),
        ("$146/mo", MoneyTextParts(symbol: "$", major: "146", fractional: nil, suffix: "/mo")),
        ("$185.88/yr", MoneyTextParts(symbol: "$", major: "185", fractional: ".88", suffix: "/yr")),
    ])
    func formatsMoneyParts(input: String, expected: MoneyTextParts) {
        #expect(MoneyTextFormatter.parts(from: input) == expected)
    }
}
