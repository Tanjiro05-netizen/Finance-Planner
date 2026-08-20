import SwiftUI

struct OnboardingScreen<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            content
        }
        .padding(.horizontal, Spacing.screenHorizontal)
        .padding(.top, Spacing.xl)
        .padding(.bottom, Spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Palette.ground)
    }
}

struct OnboardingHeadline: View {
    let title: String
    let subtitle: String
    var alignment: TextAlignment = .leading

    var body: some View {
        VStack(alignment: stackAlignment, spacing: Spacing.sm) {
            Text(title)
                .font(.screenTitle)
                .foregroundStyle(Palette.ink)
                .multilineTextAlignment(alignment)
                .fixedSize(horizontal: false, vertical: true)

            Text(subtitle)
                .font(.siftBody)
                .foregroundStyle(Palette.inkSoft)
                .multilineTextAlignment(alignment)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: frameAlignment)
    }

    private var stackAlignment: HorizontalAlignment {
        alignment == .center ? .center : .leading
    }

    private var frameAlignment: Alignment {
        alignment == .center ? .center : .leading
    }
}

struct SubscriptionMotif: View {
    var body: some View {
        ZStack {
            MonogramTile(letter: "R", color: Palette.negative, size: 76)
                .offset(x: -42, y: 12)
                .rotationEffect(.degrees(-8))
            MonogramTile(letter: "S", color: Palette.ink, size: 88)
                .zIndex(1)
            MonogramTile(letter: "T", color: Palette.accent, size: 76)
                .offset(x: 44, y: -8)
                .rotationEffect(.degrees(8))
        }
        .frame(maxWidth: .infinity, minHeight: 128)
    }
}

struct PageDots: View {
    let currentIndex: Int
    let count: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0 ..< count, id: \.self) { index in
                Capsule()
                    .fill(index == currentIndex ? Palette.ink : Palette.surfaceSunken)
                    .frame(width: index == currentIndex ? 18 : 7, height: 7)
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityHidden(true)
    }
}

struct TrustText: View {
    var body: some View {
        Text("READ-ONLY · ON DEVICE\nPOWERED BY APPLE WALLET · NOTHING LEAVES YOUR IPHONE")
            .font(.siftLabel)
            .foregroundStyle(Palette.inkFaint)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .accessibilityLabel("Read-only. On device. Powered by Apple Wallet. Nothing leaves your iPhone.")
    }
}

/// Chips for the Apple Wallet data sources Sift reads through FinanceKit.
struct WalletSourceCloud: View {
    private let sources = ["Apple Card", "Apple Cash", "Apple Pay"]

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 128), spacing: Spacing.sm)], spacing: Spacing.sm) {
            ForEach(sources, id: \.self) { source in
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "wallet.pass")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Palette.accent)
                    Text(source)
                        .font(.system(.caption, design: .default).weight(.semibold))
                        .foregroundStyle(Palette.ink)
                        .lineLimit(1)
                }
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, 10)
                .background(Palette.surface, in: Capsule())
            }
        }
    }
}

/// Retained for a future Android/Plaid port.
struct BankChipCloud: View {
    private let chips = BankInstitution.popular

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 128), spacing: Spacing.sm)], spacing: Spacing.sm) {
            ForEach(chips) { chip in
                HStack(spacing: Spacing.sm) {
                    Circle()
                        .fill(chip.colorToken.color)
                        .frame(width: 10, height: 10)
                    Text(chip.name)
                        .font(.system(.caption, design: .default).weight(.semibold))
                        .foregroundStyle(Palette.ink)
                        .lineLimit(1)
                }
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, 10)
                .background(Palette.surface, in: Capsule())
            }
        }
    }
}

struct SearchField: View {
    @Binding var text: String

    var body: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Palette.inkFaint)
            TextField("Search 12,000+ institutions", text: $text)
                .font(.siftBody)
                .textInputAutocapitalization(.words)
        }
        .padding(.horizontal, Spacing.md)
        .frame(minHeight: 48)
        .background(Palette.surface, in: RoundedRectangle(cornerRadius: Radius.control, style: .continuous))
    }
}

struct BankRow: View {
    let institution: BankInstitution

    var body: some View {
        HStack(spacing: Spacing.md) {
            MonogramTile(letter: institution.monogram, color: institution.colorToken.color, size: 42)
            Text(institution.name)
                .font(.bodyEmphasis)
                .foregroundStyle(Palette.ink)
            Spacer()
            Image(systemName: SiftIcon.chevronRight)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Palette.inkFaint)
        }
        .padding(Spacing.md)
        .background(Palette.surface, in: RoundedRectangle(cornerRadius: Radius.row, style: .continuous))
    }
}

struct ErrorCallout: View {
    let message: String
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text(message)
                .font(.siftBody)
                .foregroundStyle(Palette.negative)
                .fixedSize(horizontal: false, vertical: true)

            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .font(.buttonLabel)
                    .foregroundStyle(Palette.negative)
            }
        }
        .padding(Spacing.md)
        .background(Palette.negative.opacity(0.08), in: RoundedRectangle(cornerRadius: Radius.control, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.control, style: .continuous)
                .stroke(Palette.negative.opacity(0.24), lineWidth: 1)
        )
    }
}

struct ScanRing: View {
    let progress: Double
    let count: Int

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var rotation: Double = 0

    var body: some View {
        ZStack {
            Circle()
                .stroke(Palette.surfaceSunken, lineWidth: 12)
            Circle()
                .trim(from: 0, to: max(0.08, progress))
                .stroke(Palette.accent, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                .rotationEffect(.degrees(-90 + rotation))
            Text("\(count)")
                .font(.system(.largeTitle, design: .default).weight(.bold))
                .foregroundStyle(Palette.ink)
                .contentTransition(.numericText(value: Double(count)))
        }
        .frame(width: 132, height: 132)
        .onAppear {
            guard let animation = Motion.reduced(Motion.scanSpin, reduceMotion: reduceMotion) else {
                return
            }
            withAnimation(animation) {
                rotation = 360
            }
        }
        .animation(Motion.reduced(Motion.gentle, reduceMotion: reduceMotion), value: progress)
        .animation(Motion.reduced(Motion.count, reduceMotion: reduceMotion), value: count)
        .sensoryFeedback(.increase, trigger: count) { oldValue, newValue in
            newValue > oldValue
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(count) subscriptions found")
    }
}

struct ReviewSubscriptionRow: View {
    let item: ReviewSubscriptionItem
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: Spacing.md) {
                Image(systemName: item.isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(item.isSelected ? Palette.accent : Palette.inkFaint)
                    .frame(width: 30)

                MonogramTile(
                    letter: item.detection.monogramLetter,
                    color: item.detection.tileColorToken.color,
                    size: 36
                )

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.detection.name)
                        .font(.bodyEmphasis)
                        .foregroundStyle(Palette.ink)
                    Text(item.detection.cadence.displayName)
                        .font(.cadence)
                        .foregroundStyle(Palette.inkFaint)
                }

                Spacer()
                MoneyText(value: item.detection.amount.formatted(), role: .row)
            }
            .padding(Spacing.md)
            .background(Palette.surface, in: RoundedRectangle(cornerRadius: Radius.row, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(item.detection.name), \(item.detection.amount.formatted())")
        .accessibilityValue(item.isSelected ? "Selected" : "Not selected")
    }
}

struct NotificationPreviewBanner: View {
    var body: some View {
        HStack(spacing: Spacing.md) {
            MonogramTile(letter: "S", color: Palette.ink, size: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text("Streamline+ renews tomorrow")
                    .font(.bodyEmphasis)
                    .foregroundStyle(Palette.ink)
                Text("$15.49 · tap to cancel first")
                    .font(.system(.caption, design: .default).weight(.medium))
                    .foregroundStyle(Palette.inkSoft)
            }
            Spacer()
        }
        .padding(Spacing.md)
        .glassSurface(radius: Radius.control, interactive: false, showsSheen: true)
        .accessibilityElement(children: .combine)
    }
}

enum OnboardingPreviewFactory {
    @MainActor
    static func viewModel(step: OnboardingStep) -> OnboardingViewModel {
        let stateStore = InMemoryOnboardingStateStore()
        let apiClient = MockSiftAPIClient()
        let presenter = MockPlaidLinkPresenter()
        let coordinator = PlaidLinkCoordinator(apiClient: apiClient, presenter: presenter)
        let detections = SeedData.snapshot().subscriptions
            .filter { $0.status != .cancelled }
            .map(DetectedSubscription.init(subscription:))
        let viewModel = OnboardingViewModel(
            apiClient: apiClient,
            linkCoordinator: coordinator,
            detectionService: MockDetectionService(detections: detections),
            notificationAuthorizer: MockNotificationAuthorizer(),
            repositories: .emptyMock(),
            stateStore: stateStore
        )
        viewModel.step = step
        viewModel.reviewItems = detections.map { ReviewSubscriptionItem(detection: $0, isSelected: true) }
        viewModel.confirmedCount = detections.count
        viewModel.confirmedMonthlyTotal = (try? Money.sum(detections.map { $0.cadence.monthlyEquivalent(for: $0.amount) })) ?? .zeroUSD
        return viewModel
    }
}
