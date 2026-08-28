import Foundation

/// Translates the card network's own merchant classification (ISO 18245, delivered by
/// FinanceKit as `MerchantCategoryCode.rawValue`) into the category hint text
/// `CategoryService` already knows how to match against `keywordRules`.
///
/// Deliberately narrow. Only codes independently confirmed against a published network
/// reference (Mastercard's Quick Reference Booklet) are mapped here -- digital-subscription
/// MCCs are inconsistent enough across issuers that guessing one would risk silently
/// miscategorising spend in a finance app. Streaming/audio/design/productivity/security/
/// health keep running on `CategoryService`'s existing merchant-name matching instead.
enum MerchantCategoryCodeMapper {
    private static let categoryNamesByCode: [Int16: String] = [
        5411: "Groceries", // Grocery Stores, Supermarkets
        5812: "Dining", // Eating Places, Restaurants
        5813: "Dining", // Bars, Cocktail Lounges, Taverns: Drinking Places
        5814: "Dining", // Fast Food Restaurants
    ]

    /// The category hint text to carry alongside a transaction, or `nil` when the code is
    /// absent or not one of the confirmed mappings.
    static func categoryHint(for code: Int16?) -> String? {
        guard let code else {
            return nil
        }
        return categoryNamesByCode[code]
    }
}
