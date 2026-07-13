import SwiftUI

struct SiftCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            content
        }
        .padding(Spacing.lg)
        .background(Palette.card, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                .stroke(Palette.line, lineWidth: 1)
        )
        .shadow(
            color: Elevation.card.color,
            radius: Elevation.card.radius,
            x: Elevation.card.offsetX,
            y: Elevation.card.offsetY
        )
    }
}

struct StateMessageCard: View {
    let title: String
    let message: String
    let systemImage: String
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        SiftCard {
            Image(systemName: systemImage)
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(Palette.goldDeep)
                .frame(width: 42, height: 42)
                .background(Palette.bone, in: RoundedRectangle(cornerRadius: Radius.tile, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.tile, style: .continuous)
                        .stroke(Palette.line, lineWidth: 1)
                )
                .accessibilityHidden(true)

            Text(title)
                .font(.cardTitle)
                .foregroundStyle(Palette.ink)

            Text(message)
                .font(.siftBody)
                .foregroundStyle(Palette.inkSoft)
                .fixedSize(horizontal: false, vertical: true)

            if let actionTitle, let action {
                SecondaryButton(title: actionTitle, action: action)
            }
        }
    }
}

struct MonogramTile: View {
    let letter: String
    var color: Color = Palette.ink
    var size: CGFloat = 38

    var body: some View {
        Text(letter.prefix(1).uppercased())
            .font(.custom(SiftFontPostScriptName.frauncesSemiBold.rawValue, size: size * 0.45))
            .foregroundStyle(Palette.bone)
            .frame(width: size, height: size)
            .background(color, in: RoundedRectangle(cornerRadius: Radius.tile, style: .continuous))
            .accessibilityHidden(true)
    }
}

enum PillVariant {
    case up
    case down
    case neutral

    var foreground: Color {
        switch self {
        case .up: Palette.clay
        case .down: Palette.green
        case .neutral: Palette.goldDeep
        }
    }

    var background: Color {
        foreground.opacity(0.12)
    }

    var symbol: String {
        switch self {
        case .up: SiftIcon.arrowUp
        case .down: SiftIcon.arrowDown
        case .neutral: SiftIcon.check
        }
    }
}

struct Pill: View {
    let text: String
    var variant: PillVariant = .neutral

    var body: some View {
        Label(text, systemImage: variant.symbol)
            .font(.siftLabel)
            .foregroundStyle(variant.foreground)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(variant.background, in: Capsule())
            .labelStyle(.titleAndIcon)
    }
}

struct SubscriptionRow: View {
    let letter: String
    let color: Color
    let name: String
    let meta: String
    let amount: String
    let cadence: String
    var warns: Bool = false

    var body: some View {
        HStack(spacing: Spacing.md) {
            MonogramTile(letter: letter, color: color)

            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.bodyEmphasis)
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1)

                Text(meta)
                    .font(.custom(SiftFontPostScriptName.plusJakartaMedium.rawValue, size: 12, relativeTo: .caption))
                    .foregroundStyle(warns ? Palette.clay : Palette.inkSoft)
                    .lineLimit(1)
            }

            Spacer(minLength: Spacing.sm)

            VStack(alignment: .trailing, spacing: 2) {
                MoneyText(value: amount, size: 16)
                Text(cadence.uppercased())
                    .font(.cadence)
                    .foregroundStyle(Palette.inkFaint)
            }
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 11)
        .background(Palette.card, in: RoundedRectangle(cornerRadius: Radius.row, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.row, style: .continuous)
                .stroke(Palette.line, lineWidth: 1)
        )
        .shadow(
            color: Elevation.row.color,
            radius: Elevation.row.radius,
            x: Elevation.row.offsetX,
            y: Elevation.row.offsetY
        )
    }
}

enum SiftButtonRole {
    case primary
    case gold
    case clay
    case secondary

    var foreground: Color {
        switch self {
        case .primary, .gold, .clay: Palette.bone
        case .secondary: Palette.ink
        }
    }

    var background: Color {
        switch self {
        case .primary: Palette.ink
        case .gold: Palette.gold
        case .clay: Palette.clay
        case .secondary: .clear
        }
    }

    var border: Color {
        switch self {
        case .secondary: Palette.line
        default: .clear
        }
    }
}

struct SiftButtonStyle: ButtonStyle {
    let role: SiftButtonRole

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.buttonLabel)
            .foregroundStyle(role.foreground)
            .frame(maxWidth: .infinity, minHeight: 48)
            .padding(.horizontal, Spacing.lg)
            .background(role.background, in: RoundedRectangle(cornerRadius: Radius.control, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.control, style: .continuous)
                    .stroke(role.border, lineWidth: 1)
            )
            .opacity(configuration.isPressed && reduceMotion ? 0.85 : 1)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.97 : 1)
            .animation(Motion.reduced(Motion.press, reduceMotion: reduceMotion), value: configuration.isPressed)
            .sensoryFeedback(.impact(weight: .medium), trigger: configuration.isPressed) { _, isPressed in
                isPressed
            }
    }
}

struct PrimaryButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(title, action: action)
            .buttonStyle(SiftButtonStyle(role: .primary))
    }
}

struct GoldButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(title, action: action)
            .buttonStyle(SiftButtonStyle(role: .gold))
    }
}

struct ClayButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(title, action: action)
            .buttonStyle(SiftButtonStyle(role: .clay))
    }
}

struct SecondaryButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(title, action: action)
            .buttonStyle(SiftButtonStyle(role: .secondary))
    }
}

struct GlassTabItem: Identifiable, Equatable {
    let id: String
    let title: String
    let symbol: String
}

struct GlassTabBar: View {
    var selectedID: String = "home"

    @Namespace private var namespace
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let tabs = [
        GlassTabItem(id: "home", title: "Home", symbol: SiftIcon.home),
        GlassTabItem(id: "subscriptions", title: "Subs", symbol: SiftIcon.subscriptions),
        GlassTabItem(id: "insights", title: "Insights", symbol: SiftIcon.insights),
    ]

    var body: some View {
        GlassEffectContainer(spacing: 20) {
            HStack(spacing: Spacing.sm) {
                ForEach(tabs) { tab in
                    ZStack {
                        if tab.id == selectedID {
                            RoundedRectangle(cornerRadius: Radius.pill, style: .continuous)
                                .fill(Palette.card.opacity(0.78))
                                .glassEffectID("activeTab", in: namespace)
                        }

                        VStack(spacing: 3) {
                            Image(systemName: tab.symbol)
                                .font(.system(size: 20, weight: .regular))
                                .contentTransition(.symbolEffect(.replace))
                            Text(tab.title)
                                .font(.custom(SiftFontPostScriptName.plusJakartaSemiBold.rawValue, size: 9, relativeTo: .caption2))
                        }
                    }
                    .foregroundStyle(tab.id == selectedID ? Palette.goldDeep : Palette.inkSoft)
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .accessibilityLabel(tab.title)
                }
            }
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, 5)
            .glassSurface(radius: Radius.tabBar, interactive: true, showsSheen: true)
        }
        .animation(Motion.reduced(Motion.glassMorph, reduceMotion: reduceMotion), value: selectedID)
    }
}

struct SegmentedControlGlass: View {
    let segments: [String]
    @Binding var selection: String
    @Namespace private var namespace

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GlassEffectContainer(spacing: 8) {
            HStack(spacing: 4) {
                ForEach(segments, id: \.self) { segment in
                    Button {
                        withAnimation(Motion.reduced(Motion.snappy, reduceMotion: reduceMotion)) {
                            selection = segment
                        }
                    } label: {
                        Text(segment)
                            .font(.custom(SiftFontPostScriptName.plusJakartaSemiBold.rawValue, size: 12, relativeTo: .caption))
                            .foregroundStyle(selection == segment ? Palette.ink : Palette.inkSoft)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 9)
                            .background {
                                if selection == segment {
                                    RoundedRectangle(cornerRadius: Radius.tile, style: .continuous)
                                        .fill(Palette.card)
                                        .glassEffectID("selected-segment", in: namespace)
                                }
                            }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(4)
            .glassSurface(radius: Radius.segmented, interactive: true)
        }
    }
}

struct FloatingActionBar<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        HStack(spacing: Spacing.sm) {
            content
        }
        .padding(Spacing.md)
        .glassSurface(radius: Radius.actionBar, interactive: true, showsSheen: true)
    }
}

struct StatCell: View {
    let label: String
    let value: String
    var warns: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label.uppercased())
                .font(.siftLabel)
                .foregroundStyle(Palette.inkFaint)
            Text(value)
                .font(.cardTitle)
                .foregroundStyle(warns ? Palette.clay : Palette.ink)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.md)
        .background(Palette.card, in: RoundedRectangle(cornerRadius: Radius.control, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.control, style: .continuous)
                .stroke(Palette.line, lineWidth: 1)
        )
    }
}

struct SiftToggleStyle: ToggleStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        Button {
            withAnimation(Motion.reduced(Motion.snappy, reduceMotion: reduceMotion)) {
                configuration.isOn.toggle()
            }
        } label: {
            HStack {
                configuration.label
                Spacer()
                Capsule()
                    .fill(configuration.isOn ? Palette.gold : Palette.sand)
                    .frame(width: 44, height: 27)
                    .overlay(alignment: configuration.isOn ? .trailing : .leading) {
                        Circle()
                            .fill(Palette.card)
                            .frame(width: 23, height: 23)
                            .padding(2)
                            .shadow(color: Palette.ink.opacity(0.16), radius: 3, x: 0, y: 1)
                    }
            }
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.impact(weight: .light), trigger: configuration.isOn)
        .accessibilityValue(configuration.isOn ? "On" : "Off")
    }
}

struct SettingsRow: View {
    let icon: String
    let title: String
    var detail: String?

    var body: some View {
        HStack(spacing: Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(Palette.goldDeep)
                .frame(width: 32, height: 32)
                .background(Palette.bone, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .stroke(Palette.line, lineWidth: 1)
                )

            Text(title)
                .font(.bodyEmphasis)
                .foregroundStyle(Palette.ink)

            Spacer()

            if let detail {
                Text(detail)
                    .font(.cadence)
                    .foregroundStyle(Palette.inkFaint)
            }

            Image(systemName: SiftIcon.chevronRight)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Palette.inkFaint)
        }
        .padding(Spacing.md)
        .background(Palette.card, in: RoundedRectangle(cornerRadius: Radius.control, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.control, style: .continuous)
                .stroke(Palette.line, lineWidth: 1)
        )
    }
}

enum StatusTimelineState: Equatable {
    case done
    case current
    case pending

    var color: Color {
        switch self {
        case .done: Palette.green
        case .current: Palette.gold
        case .pending: Palette.sand
        }
    }
}

struct StatusTimelineItem: Identifiable, Equatable {
    let id: String
    let title: String
    let subtitle: String
    let state: StatusTimelineState
}

struct StatusTimeline: View {
    let items: [StatusTimelineItem]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                StatusTimelineRow(item: item, isLast: index == items.count - 1)
            }
        }
    }
}

private struct StatusTimelineRow: View {
    let item: StatusTimelineItem
    let isLast: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.md) {
            VStack(spacing: 0) {
                Circle()
                    .fill(item.state.color)
                    .frame(width: 20, height: 20)
                    .scaleEffect(item.state == .current && !reduceMotion ? 1.08 : 1)
                    .overlay {
                        if item.state == .done {
                            Image(systemName: SiftIcon.check)
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(Palette.card)
                                .transition(.opacity)
                        }
                    }
                    .animation(Motion.reduced(Motion.snappy, reduceMotion: reduceMotion), value: item.state)

                if !isLast {
                    TimelineConnector(state: item.state)
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.bodyEmphasis)
                    .foregroundStyle(item.state == .pending ? Palette.inkFaint : Palette.ink)
                Text(item.subtitle)
                    .font(.custom(SiftFontPostScriptName.plusJakartaMedium.rawValue, size: 12, relativeTo: .caption))
                    .foregroundStyle(Palette.inkSoft)
            }
        }
    }
}

private struct TimelineConnector: View {
    let state: StatusTimelineState

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack(alignment: .top) {
            Rectangle()
                .fill(Palette.sand)
            Rectangle()
                .fill(connectorColor)
                .scaleEffect(y: connectorProgress, anchor: .top)
        }
        .frame(width: 2, height: 26)
        .animation(Motion.reduced(Motion.gentle, reduceMotion: reduceMotion), value: state)
    }

    private var connectorColor: Color {
        switch state {
        case .done:
            Palette.green
        case .current:
            Palette.gold
        case .pending:
            Palette.sand
        }
    }

    private var connectorProgress: CGFloat {
        switch state {
        case .done:
            1
        case .current:
            0.5
        case .pending:
            0
        }
    }
}

struct NumberedStep: View {
    let number: Int
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.md) {
            Text("\(number)")
                .font(.custom(SiftFontPostScriptName.frauncesSemiBold.rawValue, size: 14))
                .foregroundStyle(Palette.bone)
                .frame(width: 26, height: 26)
                .background(Palette.ink, in: Circle())

            Text(text)
                .font(.siftBody)
                .foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Spacing.md)
        .background(Palette.card, in: RoundedRectangle(cornerRadius: Radius.control, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.control, style: .continuous)
                .stroke(Palette.line, lineWidth: 1)
        )
    }
}

struct OptionCard: View {
    let title: String
    let detail: String
    var recommended: Bool = false
    var badgeText: String?

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            if recommended || badgeText != nil {
                Text(badgeText ?? "RECOMMENDED")
                    .font(.siftLabel)
                    .foregroundStyle(recommended ? Palette.card : Palette.inkSoft)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(recommended ? Palette.gold : Palette.sand, in: Capsule())
                    .offset(y: -Spacing.md)
                    .padding(.bottom, -Spacing.md)
            }

            HStack(spacing: Spacing.md) {
                Image(systemName: recommended ? SiftIcon.check : SiftIcon.list)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Palette.goldDeep)
                    .frame(width: 34, height: 34)
                    .background(Palette.bone, in: RoundedRectangle(cornerRadius: Radius.tile, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: Radius.tile, style: .continuous)
                            .stroke(Palette.line, lineWidth: 1)
                    )

                Text(title)
                    .font(.cardTitle)
                    .foregroundStyle(Palette.ink)
            }

            Text(detail)
                .font(.siftBody)
                .foregroundStyle(Palette.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Spacing.lg)
        .background(recommended ? Palette.gold.opacity(0.08) : Palette.card, in: RoundedRectangle(cornerRadius: Radius.pill, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.pill, style: .continuous)
                .stroke(recommended ? Palette.gold : Palette.line, lineWidth: recommended ? 1.5 : 1)
        )
    }
}

struct RenewalMark: Identifiable {
    let id = UUID()
    let position: CGFloat
    let color: Color
    var label: String?
}

struct RenewalTimelineStrip: View {
    let marks: [RenewalMark]
    var monthLabel = "JUNE"

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                Text("RENEWAL TIMELINE")
                    .font(.siftLabel)
                    .foregroundStyle(Palette.inkSoft)
                Spacer()
                Text(monthLabel)
                    .font(.cadence)
                    .foregroundStyle(Palette.inkFaint)
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Palette.sand)
                        .frame(height: 2)
                        .position(x: proxy.size.width / 2, y: 18)

                    ForEach(marks) { mark in
                        Circle()
                            .fill(mark.color)
                            .frame(width: mark.label == nil ? 7 : 11, height: mark.label == nil ? 7 : 11)
                            .shadow(color: mark.color.opacity(0.22), radius: mark.label == nil ? 0 : 8)
                            .position(x: proxy.size.width * mark.position, y: 18)

                        if let label = mark.label {
                            Text(label.uppercased())
                                .font(.cadence)
                                .foregroundStyle(Palette.goldDeep)
                                .position(x: proxy.size.width * mark.position, y: 0)
                        }
                    }
                }
            }
            .frame(height: 30)

            HStack {
                Text("1")
                Spacer()
                Text("15")
                Spacer()
                Text("30")
            }
            .font(.cadence)
            .foregroundStyle(Palette.inkFaint)
        }
    }
}
