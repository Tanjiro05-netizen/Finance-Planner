import SwiftUI

struct NotificationPermissionBanner: View {
    let openSettings: () -> Void
    let dismiss: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.md) {
            Image(systemName: SiftIcon.bell)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Palette.goldDeep)
                .frame(width: 34, height: 34)
                .background(Palette.card.opacity(0.72), in: RoundedRectangle(cornerRadius: Radius.tile, style: .continuous))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 5) {
                Text("Notifications are off")
                    .font(.bodyEmphasis)
                    .foregroundStyle(Palette.ink)

                Text("Sift cannot remind you before renewals, trial endings, or price changes.")
                    .font(.custom(SiftFontPostScriptName.plusJakartaMedium.rawValue, size: 12, relativeTo: .caption))
                    .foregroundStyle(Palette.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)

                Button {
                    openSettings()
                } label: {
                    Label("Open Settings", systemImage: SiftIcon.externalLink)
                        .font(.custom(SiftFontPostScriptName.plusJakartaSemiBold.rawValue, size: 12, relativeTo: .caption))
                        .foregroundStyle(Palette.goldDeep)
                }
                .buttonStyle(.plain)
                .frame(minHeight: 32)
            }

            Spacer(minLength: Spacing.sm)

            Button(action: dismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Palette.inkSoft)
                    .frame(width: 34, height: 34)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Dismiss notification warning")
        }
        .padding(Spacing.md)
        .glassSurface(radius: Radius.row, interactive: true, showsSheen: false)
        .padding(.horizontal, Spacing.screenHorizontal)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("notification-permission-banner")
    }
}
