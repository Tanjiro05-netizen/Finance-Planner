import SwiftUI

/// A grouped section, in the shape iOS uses for `insetGrouped` content.
///
/// This replaces the card. The card had a fill *and* a 1px border *and* a 30pt shadow, all
/// unconditional, on 77 instances — the combination the design literature calls a "ghost
/// card", and the rule it breaks is "declare elevation once, border or shadow." It carried
/// all three because it had to: `card` #FFFDF8 against `bone` #F6F2EA measured 1.10:1, so
/// fill alone could not make a surface read as a surface.
///
/// The palette now puts a real value step between `surface` and `ground`, which means the
/// scaffolding can go. What is left is what iOS itself does: a filled, rounded group
/// sitting on a slightly darker ground, with an optional sentence-case header outside it.
struct SiftSection<Content: View>: View {
    var header: String?
    var footer: String?
    /// Rows manage their own horizontal insets, so a row list turns this off.
    var padded = true
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            if let header, !header.isEmpty {
                Text(header)
                    .font(.sectionHeader)
                    .foregroundStyle(Palette.inkSoft)
                    .padding(.horizontal, Spacing.xs)
            }

            VStack(alignment: .leading, spacing: padded ? Spacing.md : 0) {
                content
            }
            .padding(padded ? Spacing.lg : 0)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Palette.surface, in: RoundedRectangle(cornerRadius: Radius.standard, style: .continuous))

            if let footer, !footer.isEmpty {
                Text(footer)
                    .font(.cadence)
                    .foregroundStyle(Palette.inkFaint)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, Spacing.xs)
            }
        }
    }
}

/// The hairline between rows, inset from the leading edge the way iOS insets it — so the
/// line starts under the text rather than under the icon.
struct SiftSeparator: View {
    var leadingInset: CGFloat = Spacing.lg

    var body: some View {
        Rectangle()
            .fill(Palette.separator)
            .frame(height: 1)
            .padding(.leading, leadingInset)
            .accessibilityHidden(true)
    }
}

/// A section of rows with separators drawn between them, but not after the last one.
///
/// Interleaving separators by hand is where row lists usually go wrong — a trailing
/// hairline sitting on the section's rounded corner is the giveaway. Taking the collection
/// means the component knows which row is last.
/// Takes an explicit id key path rather than requiring `Identifiable`, the way `ForEach`
/// does. The SwiftData models here carry both a `String` id of their own and the
/// `PersistentIdentifier` that `PersistentModel` supplies, so leaving the choice implicit
/// picks the wrong one.
struct SiftRowSection<Data: RandomAccessCollection, ID: Hashable, Row: View>: View {
    var header: String?
    var footer: String?
    let data: Data
    let id: KeyPath<Data.Element, ID>
    var separatorInset: CGFloat = Spacing.lg
    @ViewBuilder var row: (Data.Element) -> Row

    var body: some View {
        SiftSection(header: header, footer: footer, padded: false) {
            ForEach(data, id: id) { element in
                row(element)

                if element[keyPath: id] != data.last?[keyPath: id] {
                    SiftSeparator(leadingInset: separatorInset)
                }
            }
        }
    }
}

/// How much room a state message deserves.
///
/// One component served first-run invitations, filter-returned-nothing, empty sub-sections
/// and errors — 36 times, identically. An invitation and an apology should not look the
/// same, and a section that happens to be empty should not shout as loudly as a screen
/// that has nothing in it at all.
enum StateMessageProminence {
    /// A whole screen with nothing in it yet. Icon, title, message.
    case full
    /// A section inside an otherwise-populated screen. One quiet line.
    case inline
}

struct StateMessageCard: View {
    let title: String
    let message: String
    let systemImage: String
    var prominence: StateMessageProminence = .full
    var tone: StateMessageTone = .neutral
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        switch prominence {
        case .full:
            fullBody
        case .inline:
            inlineBody
        }
    }

    private var fullBody: some View {
        SiftSection {
            Image(systemName: systemImage)
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(tone.accent)
                .frame(width: 42, height: 42)
                .background(tone.wash, in: RoundedRectangle(cornerRadius: Radius.tight, style: .continuous))
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

    private var inlineBody: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text(message)
                .font(.siftBody)
                .foregroundStyle(Palette.inkSoft)
                .fixedSize(horizontal: false, vertical: true)

            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .font(.bodyEmphasis)
                    .foregroundStyle(Palette.accent)
                    .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Whether an empty state is an invitation or a failure. They used to look identical.
enum StateMessageTone {
    case neutral
    case problem

    var accent: Color {
        switch self {
        case .neutral: Palette.accent
        case .problem: Palette.negative
        }
    }

    var wash: Color {
        switch self {
        case .neutral: Palette.accentSoft
        case .problem: Palette.negative.opacity(0.12)
        }
    }
}

struct MonogramTile: View {
    let letter: String
    var color: Color = Palette.ink
    var size: CGFloat = 38

    var body: some View {
        Text(letter.prefix(1).uppercased())
            .font(.system(size: size * 0.45, weight: .semibold, design: .default))
            .foregroundStyle(Palette.ground)
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
        case .up: Palette.negative
        case .down: Palette.positive
        case .neutral: Palette.accent
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
                    .font(.system(.caption, design: .default).weight(.medium))
                    .foregroundStyle(warns ? Palette.negative : Palette.inkSoft)
                    .lineLimit(1)
            }

            Spacer(minLength: Spacing.sm)

            VStack(alignment: .trailing, spacing: 2) {
                MoneyText(value: amount, role: .row)
                Text(cadence)
                    .font(.cadence)
                    .foregroundStyle(Palette.inkFaint)
            }
        }
        // No fill or radius of its own: the section it sits in already carries both, and a
        // filled row inside a filled section is the card-inside-a-card this layout was
        // full of.
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.md)
        .contentShape(Rectangle())
    }
}

enum SiftButtonRole {
    case primary
    case gold
    case clay
    case secondary

    var foreground: Color {
        switch self {
        case .primary, .gold, .clay: Palette.ground
        case .secondary: Palette.ink
        }
    }

    var background: Color {
        switch self {
        case .primary: Palette.ink
        case .gold: Palette.accent
        case .clay: Palette.negative
        case .secondary: .clear
        }
    }

    var border: Color {
        switch self {
        case .secondary: Palette.separator
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
                                .fill(Palette.surface.opacity(0.78))
                                .glassEffectID("activeTab", in: namespace)
                        }

                        VStack(spacing: 3) {
                            Image(systemName: tab.symbol)
                                .font(.system(size: 20, weight: .regular))
                                .contentTransition(.symbolEffect(.replace))
                            Text(tab.title)
                                .font(.system(.caption2, design: .default).weight(.semibold))
                        }
                    }
                    .foregroundStyle(tab.id == selectedID ? Palette.accent : Palette.inkSoft)
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
                            .font(.system(.caption, design: .default).weight(.semibold))
                            .foregroundStyle(selection == segment ? Palette.ink : Palette.inkSoft)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 9)
                            .background {
                                if selection == segment {
                                    RoundedRectangle(cornerRadius: Radius.tile, style: .continuous)
                                        .fill(Palette.surface)
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
            Text(label)
                .font(.siftLabel)
                .foregroundStyle(Palette.inkFaint)
            Text(value)
                .font(.cardTitle)
                .foregroundStyle(warns ? Palette.negative : Palette.ink)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.md)
        .background(Palette.surface, in: RoundedRectangle(cornerRadius: Radius.control, style: .continuous))
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
                    .fill(configuration.isOn ? Palette.accent : Palette.surfaceSunken)
                    .frame(width: 44, height: 27)
                    .overlay(alignment: configuration.isOn ? .trailing : .leading) {
                        Circle()
                            .fill(Palette.surface)
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
                .foregroundStyle(Palette.accent)
                .frame(width: 32, height: 32)
                .background(Palette.ground, in: RoundedRectangle(cornerRadius: 9, style: .continuous))

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
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Palette.inkFaint)
        }
        // A row inside a section does not carry its own fill or its own corner radius.
        // Every settings row used to be a separate rounded slab, which is what made a
        // list of eight options read as a deck of eight cards.
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.md)
        .contentShape(Rectangle())
    }
}

enum StatusTimelineState: Equatable {
    case done
    case current
    case pending

    var color: Color {
        switch self {
        case .done: Palette.positive
        case .current: Palette.accent
        case .pending: Palette.surfaceSunken
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
                                .foregroundStyle(Palette.surface)
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
                    .font(.system(.caption, design: .default).weight(.medium))
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
                .fill(Palette.surfaceSunken)
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
            Palette.positive
        case .current:
            Palette.accent
        case .pending:
            Palette.surfaceSunken
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
                .font(.system(size: 14, weight: .semibold, design: .default))
                .foregroundStyle(Palette.ground)
                .frame(width: 26, height: 26)
                .background(Palette.ink, in: Circle())

            Text(text)
                .font(.siftBody)
                .foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Spacing.md)
        .background(Palette.surface, in: RoundedRectangle(cornerRadius: Radius.control, style: .continuous))
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
                    .foregroundStyle(recommended ? Palette.surface : Palette.inkSoft)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(recommended ? Palette.accent : Palette.surfaceSunken, in: Capsule())
                    .offset(y: -Spacing.md)
                    .padding(.bottom, -Spacing.md)
            }

            HStack(spacing: Spacing.md) {
                Image(systemName: recommended ? SiftIcon.check : SiftIcon.list)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Palette.accent)
                    .frame(width: 34, height: 34)
                    .background(Palette.ground, in: RoundedRectangle(cornerRadius: Radius.tile, style: .continuous))

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
        .background(recommended ? Palette.accent.opacity(0.08) : Palette.surface, in: RoundedRectangle(cornerRadius: Radius.pill, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.pill, style: .continuous)
                .stroke(recommended ? Palette.accent : Palette.separator, lineWidth: recommended ? 1.5 : 1)
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
                Text("Renewal timeline")
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
                        .fill(Palette.surfaceSunken)
                        .frame(height: 2)
                        .position(x: proxy.size.width / 2, y: 18)

                    ForEach(marks) { mark in
                        Circle()
                            .fill(mark.color)
                            .frame(width: mark.label == nil ? 7 : 11, height: mark.label == nil ? 7 : 11)
                            .shadow(color: mark.color.opacity(0.22), radius: mark.label == nil ? 0 : 8)
                            .position(x: proxy.size.width * mark.position, y: 18)

                        if let label = mark.label {
                            Text(label)
                                .font(.cadence)
                                .foregroundStyle(Palette.accent)
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
