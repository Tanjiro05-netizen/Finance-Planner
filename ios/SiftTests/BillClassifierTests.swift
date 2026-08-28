import Foundation
@testable import Sift
import Testing

struct BillClassifierTests {
    @Test func classifiesRecurringObligationsAsBills() {
        #expect(BillClassifier.isBill(merchantKey: MerchantKey("Northgate Apartments Rent"), name: "Northgate Apartments"))
        #expect(BillClassifier.isBill(merchantKey: MerchantKey("City Water Utility"), name: "City Water"))
        #expect(BillClassifier.isBill(merchantKey: MerchantKey("Statewide Insurance"), name: "Statewide Insurance"))
        #expect(BillClassifier.isBill(merchantKey: MerchantKey("Verizon Wireless"), name: "Verizon Wireless"))
    }

    @Test func doesNotClassifySubscriptionsAsBills() {
        #expect(!BillClassifier.isBill(merchantKey: MerchantKey("Netflix"), name: "Netflix"))
        #expect(!BillClassifier.isBill(merchantKey: MerchantKey("Streamline Plus"), name: "Streamline+"))
        #expect(!BillClassifier.isBill(merchantKey: MerchantKey("Creative Cloud"), name: "Adobe Creative Cloud"))
        #expect(!BillClassifier.isBill(merchantKey: MerchantKey("Tonebox"), name: "Tonebox"))
    }
}
