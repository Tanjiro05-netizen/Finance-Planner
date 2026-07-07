import Foundation

enum Cents {
    static func dollars(_ dollars: Int, cents: Int = 0) -> Int {
        dollars * 100 + cents
    }
}

struct Money: Codable, Equatable, Hashable, Comparable {
    let amountMinor: Int
    let currency: String

    init(amountMinor: Int, currency: String = "USD") {
        self.amountMinor = amountMinor
        self.currency = currency
    }

    static var zeroUSD: Money {
        Money(amountMinor: 0)
    }

    static func usd(_ amountMinor: Int) -> Money {
        Money(amountMinor: amountMinor, currency: "USD")
    }

    static func < (lhs: Money, rhs: Money) -> Bool {
        precondition(lhs.currency == rhs.currency, "Cannot compare mixed currencies")
        return lhs.amountMinor < rhs.amountMinor
    }

    static func + (lhs: Money, rhs: Money) -> Money {
        precondition(lhs.currency == rhs.currency, "Cannot add mixed currencies")
        return Money(amountMinor: lhs.amountMinor + rhs.amountMinor, currency: lhs.currency)
    }

    static func - (lhs: Money, rhs: Money) -> Money {
        precondition(lhs.currency == rhs.currency, "Cannot subtract mixed currencies")
        return Money(amountMinor: lhs.amountMinor - rhs.amountMinor, currency: lhs.currency)
    }

    static func sum(_ values: [Money], currency: String = "USD") throws -> Money {
        try values.reduce(Money(amountMinor: 0, currency: currency)) { partial, value in
            guard partial.currency == value.currency else {
                throw SiftError.currencyMismatch
            }

            return partial + value
        }
    }

    func multiplied(by multiplier: Int) -> Money {
        Money(amountMinor: amountMinor * multiplier, currency: currency)
    }

    func divided(by divisor: Int) -> Money {
        precondition(divisor > 0, "Divisor must be positive")
        return Money(amountMinor: roundedQuotient(amountMinor, divisor: divisor), currency: currency)
    }

    func formatted(showZeroFraction: Bool = true) -> String {
        let absolute = abs(amountMinor)
        let major = absolute / 100
        let fraction = absolute % 100
        let sign = amountMinor < 0 ? "-" : ""
        let symbol = currency == "USD" ? "$" : "\(currency) "
        let majorText = groupedMajorDigits(major)

        if fraction == 0, !showZeroFraction {
            return "\(sign)\(symbol)\(majorText)"
        }

        return "\(sign)\(symbol)\(majorText).\(String(format: "%02d", fraction))"
    }
}

private func roundedQuotient(_ amount: Int, divisor: Int) -> Int {
    let sign = amount < 0 ? -1 : 1
    let absolute = abs(amount)
    return sign * ((absolute + divisor / 2) / divisor)
}

private func groupedMajorDigits(_ value: Int) -> String {
    let digits = Array(String(value).reversed())
    let grouped = digits.enumerated().reduce(into: [Character]()) { result, pair in
        let (index, character) = pair
        if index > 0, index.isMultiple(of: 3) {
            result.append(",")
        }
        result.append(character)
    }

    return String(grouped.reversed())
}
