@testable import Sift
import Testing

struct MerchantCategoryCodeMapperTests {
    @Test func knownCodesMapToTheirCategory() {
        #expect(MerchantCategoryCodeMapper.categoryHint(for: 5411) == "Groceries")
        #expect(MerchantCategoryCodeMapper.categoryHint(for: 5812) == "Dining")
        #expect(MerchantCategoryCodeMapper.categoryHint(for: 5813) == "Dining")
        #expect(MerchantCategoryCodeMapper.categoryHint(for: 5814) == "Dining")
    }

    @Test func nilCodeYieldsNoHint() {
        #expect(MerchantCategoryCodeMapper.categoryHint(for: nil) == nil)
    }

    @Test func unmappedCodeYieldsNoHint() {
        // 7392 (Management/Consulting Services) is real but deliberately outside the
        // narrow, verified set this mapper covers.
        #expect(MerchantCategoryCodeMapper.categoryHint(for: 7392) == nil)
    }
}
