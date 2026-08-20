import SwiftUI

struct SplashView: View {
    let isWorking: Bool
    let errorMessage: String?
    let onRetry: () -> Void

    var body: some View {
        OnboardingScreen {
            Spacer()
            VStack(spacing: 18) {
                Text("S")
                    .font(.system(.largeTitle, design: .default).weight(.bold))
                    .foregroundStyle(Palette.ground)
                    .frame(width: 74, height: 74)
                    .background(Palette.ink, in: RoundedRectangle(cornerRadius: 22, style: .continuous))

                VStack(spacing: Spacing.sm) {
                    Text("Sift")
                        .font(.system(.largeTitle, design: .default).weight(.bold))
                        .foregroundStyle(Palette.ink)
                    Text("EVERY RECURRING CHARGE, SURFACED")
                        .font(.siftLabel)
                        .foregroundStyle(Palette.inkFaint)
                }
            }
            .frame(maxWidth: .infinity)

            if let errorMessage {
                ErrorCallout(message: errorMessage, actionTitle: "Try again", action: onRetry)
            } else if isWorking {
                ProgressView()
                    .tint(Palette.accent)
                    .accessibilityLabel("Preparing secure session")
            }
            Spacer()
        }
        .accessibilityIdentifier("onboarding-splash")
    }
}

struct WelcomeView: View {
    let onContinue: () -> Void

    var body: some View {
        OnboardingScreen {
            SubscriptionMotif()
                .padding(.top, Spacing.xxl)

            OnboardingHeadline(
                title: "See every subscription you forgot about.",
                subtitle: "Sift reads your Apple Wallet and finds the charges that quietly repeat, so nothing renews behind your back."
            )

            Spacer()
            PageDots(currentIndex: 0, count: 3)
            PrimaryButton(title: "Get started", action: onContinue)
                .accessibilityIdentifier("onboarding-get-started")
        }
    }
}

struct ConnectIntroView: View {
    let errorMessage: String?
    let onConnect: () -> Void

    var body: some View {
        OnboardingScreen {
            OnboardingHeadline(
                title: "Connect Apple Wallet.",
                subtitle: "Sift reads your Apple Card, Apple Cash, and Apple Pay transactions right on your iPhone — "
                    + "read-only — and finds your subscriptions automatically. No spreadsheets."
            )

            WalletSourceCloud()
            Spacer()

            if let errorMessage {
                ErrorCallout(message: errorMessage)
            }

            PrimaryButton(title: "Connect Apple Wallet", action: onConnect)
                .accessibilityIdentifier("onboarding-connect-account")
            TrustText()
        }
    }
}

struct BankPickerView: View {
    let institutions: [BankInstitution]
    let onSelect: (BankInstitution) -> Void

    @State private var searchText = ""

    var body: some View {
        OnboardingScreen {
            Text("Choose your bank")
                .font(.screenTitle)
                .foregroundStyle(Palette.ink)
                .padding(.top, Spacing.md)

            SearchField(text: $searchText)

            Text("Popular")
                .font(.siftLabel)
                .foregroundStyle(Palette.inkFaint)
                .padding(.top, Spacing.lg)

            VStack(spacing: Spacing.md) {
                ForEach(filteredInstitutions) { institution in
                    Button {
                        onSelect(institution)
                    } label: {
                        BankRow(institution: institution)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("bank-\(institution.id)")
                }
            }
            Spacer()
        }
    }

    private var filteredInstitutions: [BankInstitution] {
        guard !searchText.isEmpty else {
            return institutions
        }

        return institutions.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }
}

struct SecureLeadInView: View {
    let institution: BankInstitution?
    let isWorking: Bool
    let errorMessage: String?
    let onContinue: () -> Void

    var body: some View {
        OnboardingScreen {
            Spacer()

            VStack(spacing: Spacing.lg) {
                Image(systemName: "lock.shield")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(Palette.ground)
                    .frame(width: 54, height: 54)
                    .background(Palette.accent, in: RoundedRectangle(cornerRadius: Radius.control, style: .continuous))

                OnboardingHeadline(title: headline, subtitle: subtitle, alignment: .center)
            }

            Spacer()

            if let errorMessage {
                ErrorCallout(message: errorMessage)
            }

            PrimaryButton(title: buttonTitle, action: onContinue)
                .disabled(isWorking)
                .accessibilityIdentifier("onboarding-continue-plaid")

            Text(footer)
                .font(.siftLabel)
                .foregroundStyle(Palette.inkFaint)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
        }
    }

    /// Apple Wallet flow when no institution is selected; Plaid copy is kept for the
    /// retained bank-picker path.
    private var isAppleWallet: Bool {
        institution == nil
    }

    private var headline: String {
        isAppleWallet ? "Connect Apple Wallet" : "Continue with \(institution?.name ?? "your bank")"
    }

    private var subtitle: String {
        isAppleWallet
            ? "Apple asks your permission next. Sift only reads your transactions on this iPhone — never your passwords or card numbers."
            : "Plaid opens next for secure sign-in. Sift never sees or stores your username or password."
    }

    private var buttonTitle: String {
        if isAppleWallet {
            return isWorking ? "Connecting" : "Continue"
        }
        return isWorking ? "Opening Plaid" : "Continue to Plaid"
    }

    private var footer: String {
        isAppleWallet
            ? "Your financial data stays on your iPhone.\nSift only reads Wallet transactions."
            : "Plaid encrypts and verifies your login.\nSift only receives a read-only confirmation."
    }
}

struct ScanningView: View {
    let scanState: ScanState

    var body: some View {
        OnboardingScreen {
            Spacer()
            VStack(spacing: Spacing.lg) {
                ScanRing(progress: scanState.progress, count: scanState.foundCount)
                OnboardingHeadline(
                    title: "Finding your subscriptions",
                    subtitle: "Scanning your recent Apple Wallet transactions for charges that repeat.",
                    alignment: .center
                )
                ProgressView(value: scanState.progress)
                    .tint(Palette.accent)
                    .accessibilityLabel("Scanning progress")
                Text(scanState.status)
                    .font(.siftLabel)
                    .foregroundStyle(Palette.inkFaint)
            }
            Spacer()
        }
        .accessibilityIdentifier("onboarding-scanning")
    }
}

struct ReviewFoundView: View {
    let items: [ReviewSubscriptionItem]
    let errorMessage: String?
    let onToggle: (String) -> Void
    let onConfirm: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    OnboardingHeadline(
                        title: "We found \(items.count) recurring charges",
                        subtitle: "Toggle off anything that isn't a subscription."
                    )
                    Text("Detected")
                        .font(.siftLabel)
                        .foregroundStyle(Palette.inkFaint)

                    VStack(spacing: Spacing.md) {
                        ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                            ReviewSubscriptionRow(item: item) {
                                onToggle(item.id)
                            }
                            .opacity(item.isSelected ? 1 : 0.42)
                            .transition(Motion.rowTransition(reduceMotion: reduceMotion))
                            .animation(Motion.staggered(index: index, reduceMotion: reduceMotion), value: items.count)
                            .animation(Motion.reduced(Motion.snappy, reduceMotion: reduceMotion), value: item.isSelected)
                        }
                    }

                    if let errorMessage {
                        ErrorCallout(message: errorMessage)
                    }
                }
                .padding(.horizontal, Spacing.screenHorizontal)
                .padding(.top, Spacing.xl)
                .padding(.bottom, 116)
            }

            FloatingActionBar {
                GoldButton(title: "Confirm \(selectedCount) subscriptions", action: onConfirm)
                    .accessibilityIdentifier("onboarding-confirm-subscriptions")
            }
            .padding(.horizontal, Spacing.screenHorizontal)
            .padding(.bottom, Spacing.lg)
        }
        .background(Palette.ground)
    }

    private var selectedCount: Int {
        items.filter(\.isSelected).count
    }
}

struct NotificationsOptInView: View {
    let onAllow: () -> Void
    let onSkip: () -> Void

    var body: some View {
        OnboardingScreen {
            Spacer()
            VStack(spacing: Spacing.lg) {
                Image(systemName: "bell.badge")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(Palette.ground)
                    .frame(width: 56, height: 56)
                    .background(Palette.accent, in: RoundedRectangle(cornerRadius: Radius.control, style: .continuous))

                OnboardingHeadline(
                    title: "Stay ahead of renewals",
                    subtitle: "We'll warn you before charges hit, when prices rise, and when free trials are about to convert.",
                    alignment: .center
                )
                NotificationPreviewBanner()
            }
            Spacer()
            PrimaryButton(title: "Allow notifications", action: onAllow)
                .accessibilityIdentifier("onboarding-allow-notifications")
            SecondaryButton(title: "Maybe later", action: onSkip)
        }
    }
}

struct AllSetView: View {
    let count: Int
    let monthlyTotal: Money
    let onDashboard: () -> Void

    var body: some View {
        OnboardingScreen {
            Spacer()
            VStack(spacing: Spacing.lg) {
                Image(systemName: SiftIcon.check)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(Palette.ground)
                    .frame(width: 64, height: 64)
                    .background(Palette.positive, in: RoundedRectangle(cornerRadius: Radius.control, style: .continuous))

                OnboardingHeadline(
                    title: "You're all set.",
                    subtitle: "Sift will keep watch from here.",
                    alignment: .center
                )

                SiftSection {
                    Text("Now tracking")
                        .font(.siftLabel)
                        .foregroundStyle(Palette.inkFaint)
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text("\(count) subs")
                            .font(.cardTitle)
                            .foregroundStyle(Palette.ink)
                        Text("·")
                            .foregroundStyle(Palette.inkFaint)
                        MoneyText(value: "\(monthlyTotal.formatted())/mo", role: .primary)
                    }
                }
            }
            Spacer()
            PrimaryButton(title: "Go to dashboard", action: onDashboard)
                .accessibilityIdentifier("onboarding-go-dashboard")
        }
    }
}

struct ConnectUnavailableView: View {
    let reason: ConnectUnavailableReason
    let onRetry: () -> Void
    let onSkip: () -> Void

    var body: some View {
        OnboardingScreen {
            Spacer()

            VStack(spacing: Spacing.lg) {
                Image(systemName: iconName)
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(Palette.ground)
                    .frame(width: 56, height: 56)
                    .background(Palette.negative, in: RoundedRectangle(cornerRadius: Radius.control, style: .continuous))

                OnboardingHeadline(title: title, subtitle: message, alignment: .center)
            }

            Spacer()

            PrimaryButton(title: "Try again", action: onRetry)
                .accessibilityIdentifier("onboarding-connect-retry")
            SecondaryButton(title: "Skip for now", action: onSkip)
                .accessibilityIdentifier("onboarding-connect-skip")
        }
        .accessibilityIdentifier("onboarding-connect-unavailable")
    }

    private var iconName: String {
        switch reason {
        case .accessDenied:
            "lock.slash"
        case .noWalletData:
            "creditcard"
        }
    }

    private var title: String {
        switch reason {
        case .accessDenied:
            "Apple Wallet access is off"
        case .noWalletData:
            "No Wallet transactions yet"
        }
    }

    private var message: String {
        switch reason {
        case .accessDenied:
            "Sift needs permission to read your Apple Card, Apple Cash, and Apple Pay "
                + "transactions. You can allow it in Settings › Privacy & Security › Wallet, or try again."
        case .noWalletData:
            "We couldn't find Apple Card, Apple Cash, or Apple Pay activity to scan. Once you've "
                + "spent with Apple Pay, come back and Sift will find your subscriptions."
        }
    }
}
