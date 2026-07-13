import SwiftUI

struct GlassSurfaceModifier: ViewModifier {
    let radius: CGFloat
    let interactive: Bool
    let showsSheen: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    func body(content: Content) -> some View {
        if reduceTransparency {
            fallback(content)
        } else {
            nativeGlass(content)
        }
    }

    @ViewBuilder
    private func nativeGlass(_ content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .glassEffect(
                    interactive ? .regular.interactive() : .regular,
                    in: RoundedRectangle(cornerRadius: radius, style: .continuous)
                )
                .overlay(alignment: .top) {
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .stroke(Palette.card.opacity(0.62), lineWidth: 1)
                        .blendMode(.screen)
                        .allowsHitTesting(false)
                }
                .overlay {
                    if showsSheen, !reduceMotion {
                        SpecularSheen(cornerRadius: radius)
                    }
                }
                .shadow(
                    color: Elevation.control.color,
                    radius: Elevation.control.radius,
                    x: Elevation.control.offsetX,
                    y: Elevation.control.offsetY
                )
        } else {
            fallback(content)
        }
    }

    private func fallback(_ content: Content) -> some View {
        content
            .background(Palette.card, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(Palette.line, lineWidth: 1)
            )
            .shadow(
                color: Elevation.control.color,
                radius: Elevation.control.radius,
                x: Elevation.control.offsetX,
                y: Elevation.control.offsetY
            )
    }
}

extension View {
    func glassSurface(
        radius: CGFloat = Radius.actionBar,
        interactive: Bool = false,
        showsSheen: Bool = false
    ) -> some View {
        modifier(GlassSurfaceModifier(radius: radius, interactive: interactive, showsSheen: showsSheen))
    }
}

private struct SpecularSheen: View {
    let cornerRadius: CGFloat

    var body: some View {
        TimelineView(.animation) { timeline in
            GeometryReader { proxy in
                let progress = sheenProgress(at: timeline.date)
                let width = proxy.size.width

                LinearGradient(
                    colors: [
                        .clear,
                        Palette.card.opacity(0.55),
                        .clear,
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(width: width * 0.46)
                .rotationEffect(.degrees(16))
                .offset(x: -width * 0.72 + (width * 2.12 * progress))
                .opacity(progress == 0 ? 0 : 1)
            }
        }
        .mask(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .allowsHitTesting(false)
    }

    private func sheenProgress(at date: Date) -> CGFloat {
        let elapsed = date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: Motion.sheenPeriod)
        let normalized = elapsed / Motion.sheenPeriod
        let start = 0.72
        let end = 0.88

        guard normalized >= start, normalized <= end else {
            return 0
        }

        return CGFloat((normalized - start) / (end - start))
    }
}
