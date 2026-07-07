@testable import Sift
import Testing

struct CancellationGuideProviderTests {
    @Test func knownMerchantReturnsSpecificGuide() {
        let guide = CancellationGuideProvider().guide(
            for: MerchantKey("Streamline Plus"),
            merchantName: "Streamline+"
        )

        #expect(!guide.isGeneric)
        #expect(guide.title == "Streamline+ guide")
        #expect(guide.steps.contains("Choose Plan and billing."))
    }

    @Test func unknownMerchantReturnsLabeledGenericFallback() {
        let guide = CancellationGuideProvider().guide(
            for: MerchantKey("Unknown Provider"),
            merchantName: "Unknown Provider"
        )

        #expect(guide.isGeneric)
        #expect(guide.title == "Generic cancellation guide")
        #expect(guide.steps == [
            "Open the provider's account or billing page.",
            "Find Subscription, Membership, Plan, or Billing.",
            "Choose Cancel, End membership, or Manage plan.",
            "Confirm the final prompt and save any confirmation email or number.",
        ])
    }
}
