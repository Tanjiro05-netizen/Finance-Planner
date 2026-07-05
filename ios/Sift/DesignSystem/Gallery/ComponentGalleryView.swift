import SwiftUI

struct ComponentGalleryView: View {
    @State private var selectedSegment = "All 14"
    @State private var renewalAlerts = true

    private let sampleTimelineMarks = [
        RenewalMark(position: 0.08, color: Palette.inkFaint),
        RenewalMark(position: 0.20, color: Palette.inkFaint),
        RenewalMark(position: 0.34, color: Palette.gold, label: "Tomorrow"),
        RenewalMark(position: 0.58, color: Palette.clay),
        RenewalMark(position: 0.82, color: Palette.inkFaint),
        RenewalMark(position: 0.94, color: Palette.inkFaint),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xl) {
                galleryHeader
                moneyAndCards
                subscriptions
                controls
                settingsAndStatus
                glassControls
            }
            .padding(.horizontal, Spacing.screenHorizontal)
            .padding(.top, 62)
            .padding(.bottom, 48)
        }
        .background(Palette.bone)
    }

    private var galleryHeader: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("SIFT")
                .font(.siftLabel)
                .foregroundStyle(Palette.goldDeep)

            Text("Component Gallery")
                .font(.screenTitle)
                .foregroundStyle(Palette.ink)

            Text("Design-system foundation for subscription detection and cancellation flows.")
                .font(.siftBody)
                .foregroundStyle(Palette.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var moneyAndCards: some View {
        SiftCard {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("RECURRING THIS MONTH")
                        .font(.siftLabel)
                        .foregroundStyle(Palette.inkFaint)
                    MoneyText(value: "$247.83")
                    Text("Across 14 subscriptions · 3 renew this week")
                        .font(.siftBody)
                        .foregroundStyle(Palette.inkSoft)
                }
                Spacer()
                Pill(text: "$18.49", variant: .up)
            }

            RenewalTimelineStrip(marks: sampleTimelineMarks)
        }
    }

    private var subscriptions: some View {
        GallerySection(title: "Rows & Stats") {
            VStack(spacing: Spacing.sm) {
                SubscriptionRow(
                    letter: "S",
                    color: Palette.clay,
                    name: "Streamline+",
                    meta: "Used yesterday",
                    amount: "$15.49",
                    cadence: "Monthly"
                )
                SubscriptionRow(
                    letter: "C",
                    color: Palette.gold,
                    name: "Creative Cloud",
                    meta: "Unused · 3 months",
                    amount: "$59.99",
                    cadence: "Monthly",
                    warns: true
                )
                HStack(spacing: Spacing.sm) {
                    StatCell(label: "Per month", value: "$15.49")
                    StatCell(label: "Annual cost", value: "$185.88", warns: true)
                }
            }
        }
    }

    private var controls: some View {
        GallerySection(title: "Buttons & Choices") {
            VStack(spacing: Spacing.sm) {
                PrimaryButton(title: "Connect an account") {}
                GoldButton(title: "Confirm 13 subscriptions") {}
                ClayButton(title: "Cancel subscription") {}
                SecondaryButton(title: "Maybe later") {}

                OptionCard(
                    title: "Cancel for me",
                    detail: "Sift's team contacts the provider and emails you confirmation.",
                    recommended: true
                )
                OptionCard(
                    title: "Show me how",
                    detail: "Step-by-step instructions tailored to this provider."
                )
            }
        }
    }

    private var settingsAndStatus: some View {
        GallerySection(title: "Settings & Progress") {
            VStack(spacing: Spacing.sm) {
                Toggle(isOn: $renewalAlerts) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Renewal reminders")
                            .font(.bodyEmphasis)
                            .foregroundStyle(Palette.ink)
                        Text("2 days before a charge.")
                            .font(.custom(SiftFontPostScriptName.plusJakartaMedium.rawValue, size: 12, relativeTo: .caption))
                            .foregroundStyle(Palette.inkSoft)
                    }
                }
                .toggleStyle(SiftToggleStyle())
                .padding(Spacing.md)
                .background(Palette.card, in: RoundedRectangle(cornerRadius: Radius.control, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.control, style: .continuous)
                        .stroke(Palette.line, lineWidth: 1)
                )

                SettingsRow(icon: SiftIcon.bank, title: "Linked accounts", detail: "2")
                SettingsRow(icon: SiftIcon.privacy, title: "Privacy & data")

                SiftCard {
                    StatusTimeline(items: [
                        StatusTimelineItem(id: "received", title: "Request received", subtitle: "Just now", state: .done),
                        StatusTimelineItem(id: "contacting", title: "Contacting Streamline+", subtitle: "In progress", state: .current),
                        StatusTimelineItem(id: "confirmed", title: "Confirmed cancelled", subtitle: "We'll email you", state: .pending),
                    ])
                }

                NumberedStep(number: 1, text: "Open Account > Membership on the provider site.")
                NumberedStep(number: 2, text: "Choose Cancel plan, then skip retention offers.")
            }
        }
    }

    private var glassControls: some View {
        GallerySection(title: "Liquid Glass Controls") {
            VStack(spacing: Spacing.lg) {
                SegmentedControlGlass(
                    segments: ["All 14", "Active", "Unused 3"],
                    selection: $selectedSegment
                )

                FloatingActionBar {
                    ClayButton(title: "Cancel subscription") {}
                }

                GlassTabBar(selectedID: "home")
            }
        }
    }
}

private struct GallerySection<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text(title.uppercased())
                .font(.siftLabel)
                .foregroundStyle(Palette.inkFaint)

            content
        }
    }
}

#Preview {
    ComponentGalleryView()
}
