import SwiftUI

struct ScreenHeader: View {
    let title: String
    let eyebrow: String

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text(eyebrow.uppercased())
                .font(.siftLabel)
                .foregroundStyle(Palette.goldDeep)

            Text(title)
                .font(.screenTitle)
                .foregroundStyle(Palette.ink)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
