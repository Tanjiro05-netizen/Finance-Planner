import Foundation

/// Decides whether a detected recurring debit is a "bill" (rent, utilities, insurance,
/// loans) rather than a subscription. Bills are routed to their own model so they never
/// inherit subscription-only affordances (cancel flow, trial-ending, unused nudge).
///
/// Pure and keyword-based, co-located with `CategoryService`/`TransactionClassifier`.
enum BillClassifier {
    static let keywords: Set<String> = [
        "rent", "mortgage", "hoa", "landlord", "apartments", "apartment", "leasing",
        "utility", "utilities", "electric", "power", "energy", "gas company",
        "water", "sewer", "internet", "broadband", "fiber", "cable",
        "insurance", "loan", "wireless", "cellular", "mobile", "phone",
    ]

    static func isBill(merchantKey: MerchantKey, name: String) -> Bool {
        let searchable = "\(merchantKey.rawValue) \(name)".lowercased()
        return keywords.contains { searchable.contains($0) }
    }
}
