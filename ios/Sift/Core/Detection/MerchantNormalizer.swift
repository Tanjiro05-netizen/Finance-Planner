import Foundation

struct NormalizedMerchant: Equatable, Sendable {
    let merchantKey: MerchantKey
    let displayName: String
    let isKnownAlias: Bool
}

struct MerchantNormalizer: Sendable {
    private struct Alias: Sendable {
        let canonicalName: String
        let patterns: [String]
    }

    private static let aliases: [Alias] = [
        Alias(canonicalName: "Netflix", patterns: ["netflix"]),
        Alias(canonicalName: "Spotify", patterns: ["spotify"]),
        Alias(canonicalName: "Hulu", patterns: ["hulu"]),
        Alias(canonicalName: "Disney+", patterns: ["disney plus", "disneyplus", "disney"]),
        Alias(canonicalName: "YouTube", patterns: ["youtube", "google youtube"]),
        Alias(canonicalName: "Apple", patterns: ["apple com bill", "apple bill"]),
        Alias(canonicalName: "Amazon Prime", patterns: ["amazon prime", "amzn prime"]),
        Alias(canonicalName: "Creative Cloud", patterns: ["adobe creative cloud", "creative cloud"]),
        Alias(canonicalName: "Figma", patterns: ["figma"]),
        Alias(canonicalName: "Readwise", patterns: ["readwise"]),
        Alias(canonicalName: "Tonebox", patterns: ["tonebox"]),
        Alias(canonicalName: "Streamline+", patterns: ["streamline plus", "streamline"]),
        Alias(canonicalName: "Notewell", patterns: ["notewell"]),
        Alias(canonicalName: "Atlas VPN", patterns: ["atlas vpn"]),
        Alias(canonicalName: "Cloudback", patterns: ["cloudback"]),
        Alias(canonicalName: "WorkoutLab", patterns: ["workoutlab", "workout lab"]),
        Alias(canonicalName: "Daybook Pro", patterns: ["daybook pro", "daybook"]),
        Alias(canonicalName: "Parcel Pro", patterns: ["parcel pro"]),
    ]

    private static let removableTokens: Set<String> = [
        "auth", "authorization", "card", "charge", "chkcard", "debit", "digital",
        "inc", "llc", "ltd", "monthly", "online", "payment", "pos", "purchase",
        "recurring", "services", "subscription", "usa", "visa", "web"
    ]

    private static let trailingLocationTokens: Set<String> = [
        "ca", "gatos", "los", "ny", "nyc", "new", "san", "seattle", "wa", "york"
    ]

    func normalize(_ merchantRaw: String) -> NormalizedMerchant {
        let folded = merchantRaw
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .lowercased()
        let tokenText = tokenizedText(from: folded)

        if let alias = Self.aliases.first(where: { alias in
            alias.patterns.contains { pattern in
                tokenText.contains(pattern)
            }
        }) {
            return NormalizedMerchant(
                merchantKey: MerchantKey(alias.canonicalName),
                displayName: alias.canonicalName,
                isKnownAlias: true
            )
        }

        let tokens = cleanedTokens(from: tokenText)
        let name = displayName(from: tokens, fallback: merchantRaw)
        return NormalizedMerchant(
            merchantKey: MerchantKey(name),
            displayName: name,
            isKnownAlias: false
        )
    }

    private func tokenizedText(from value: String) -> String {
        let normalizedSeparators = value
            .replacingOccurrences(of: "&", with: " and ")
            .replacingOccurrences(of: "+", with: " plus ")
            .replacingOccurrences(of: ".com", with: " com ")
            .replacingOccurrences(of: ".net", with: " net ")
            .replacingOccurrences(of: ".org", with: " org ")

        let allowed = CharacterSet.alphanumerics
        let characters = normalizedSeparators.unicodeScalars.map { scalar in
            allowed.contains(scalar) ? Character(scalar) : " "
        }

        return String(characters)
            .split(separator: " ")
            .joined(separator: " ")
    }

    private func cleanedTokens(from tokenText: String) -> [String] {
        var tokens = tokenText
            .split(separator: " ")
            .map(String.init)
            .filter { token in
                guard !token.isEmpty else {
                    return false
                }

                if token.allSatisfy(\.isNumber) {
                    return false
                }

                return !Self.removableTokens.contains(token)
            }

        while let last = tokens.last, Self.trailingLocationTokens.contains(last) {
            tokens.removeLast()
        }

        return tokens
    }

    private func displayName(from tokens: [String], fallback: String) -> String {
        let source = tokens.isEmpty
            ? fallback.split(whereSeparator: { !$0.isLetter && !$0.isNumber }).map(String.init)
            : tokens

        let words = source.prefix(4).map { token in
            if token.count <= 3, token == token.uppercased() {
                token
            } else {
                token.prefix(1).uppercased() + token.dropFirst().lowercased()
            }
        }

        let name = words.joined(separator: " ")
        return name.isEmpty ? "Unknown Merchant" : name
    }
}
