// swiftlint:disable file_length
// This file bundles five screens (Hub, Linked Accounts, Alert Settings, Categories,
// Privacy Data). It should be split into one file per screen under Features/Settings/
// to match the project's feature-first convention, but that move needs compiler
// verification to catch any `private`-scope boundary crossed by the split, so it's
// tracked as a follow-up rather than done blind.
import Foundation
import Observation
import SwiftUI

struct SettingsView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.apiClient) private var apiClient
    @Environment(\.detectionService) private var detectionService
    @Environment(\.notificationScheduler) private var notificationScheduler
    @Environment(\.onboardingStateStore) private var onboardingStateStore
    @Environment(\.plaidLinkPresenter) private var plaidLinkPresenter
    @Environment(\.repositories) private var repositories
    @Environment(\.tokenStore) private var tokenStore

    var body: some View {
        SettingsHubView(
            repositories: repositories,
            apiClient: apiClient,
            detectionService: detectionService,
            linkPresenter: plaidLinkPresenter,
            notificationScheduler: notificationScheduler,
            tokenStore: tokenStore,
            stateStore: onboardingStateStore
        )
        .environment(appModel)
    }
}

@MainActor
@Observable
final class SettingsHubViewModel {
    private let repositories: RepositoryContainer
    private let notificationScheduler: any NotificationScheduling
    private let tokenStore: any TokenStoring
    private let stateStore: any OnboardingStateStoring

    var accountCount = 0
    var cancellationRequestCount = 0
    var renewalReminderDetail = "On"
    var weeklySummaryDetail = "Off"
    var errorMessage: String?

    init(
        repositories: RepositoryContainer,
        notificationScheduler: any NotificationScheduling,
        tokenStore: any TokenStoring,
        stateStore: any OnboardingStateStoring
    ) {
        self.repositories = repositories
        self.notificationScheduler = notificationScheduler
        self.tokenStore = tokenStore
        self.stateStore = stateStore
    }

    func load() {
        do {
            let settings = try repositories.settings.settings()
            accountCount = try repositories.accounts.all().count
            cancellationRequestCount = try repositories.cancellations.all().count
            renewalReminderDetail = settings.renewalReminders ? "On" : "Off"
            weeklySummaryDetail = settings.weeklySummary ? "On" : "Off"
            errorMessage = nil
        } catch {
            errorMessage = userFacingMessage(for: error)
        }
    }

    func signOut() -> Bool {
        do {
            try tokenStore.deleteToken()
            try repositories.wipeLocalData()
            stateStore.setComplete(false)
            Task { [notificationScheduler] in
                await notificationScheduler.cancelAllSiftNotifications()
            }
            errorMessage = nil
            return true
        } catch {
            errorMessage = userFacingMessage(for: error)
            return false
        }
    }

    private func userFacingMessage(for error: Error) -> String {
        if let siftError = error as? SiftError {
            return siftError.errorDescription ?? "Something went wrong."
        }

        return error.localizedDescription
    }
}

struct SettingsHubView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.openURL) private var openURL
    @State private var viewModel: SettingsHubViewModel

    private let repositories: RepositoryContainer
    private let apiClient: any SiftAPIClient
    private let detectionService: any DetectionServing
    private let linkPresenter: any PlaidLinkPresenting
    private let notificationScheduler: any NotificationScheduling
    private let tokenStore: any TokenStoring
    private let stateStore: any OnboardingStateStoring
    private let supportMetadata: AppSupportMetadata

    init(
        repositories: RepositoryContainer = .mock(),
        apiClient: any SiftAPIClient = MockSiftAPIClient(),
        detectionService: any DetectionServing = MockDetectionService(),
        linkPresenter: any PlaidLinkPresenting = MockPlaidLinkPresenter(),
        notificationScheduler: any NotificationScheduling = NoopNotificationScheduler(),
        tokenStore: any TokenStoring = InMemoryTokenStore(),
        stateStore: any OnboardingStateStoring = InMemoryOnboardingStateStore(),
        supportMetadata: AppSupportMetadata = .current()
    ) {
        self.repositories = repositories
        self.apiClient = apiClient
        self.detectionService = detectionService
        self.linkPresenter = linkPresenter
        self.notificationScheduler = notificationScheduler
        self.tokenStore = tokenStore
        self.stateStore = stateStore
        self.supportMetadata = supportMetadata
        _viewModel = State(initialValue: SettingsHubViewModel(
            repositories: repositories,
            notificationScheduler: notificationScheduler,
            tokenStore: tokenStore,
            stateStore: stateStore
        ))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xl) {
                ScreenHeader(title: "Settings", eyebrow: "ACCOUNT")
                    .accessibilityIdentifier("settings-title")

                SettingsProfileCard()

                VStack(spacing: Spacing.sm) {
                    NavigationLink {
                        LinkedAccountsView(
                            repositories: repositories,
                            apiClient: apiClient,
                            detectionService: detectionService,
                            linkPresenter: linkPresenter,
                            notificationScheduler: notificationScheduler
                        )
                    } label: {
                        SettingsRow(icon: SiftIcon.bank, title: "Linked accounts", detail: "\(viewModel.accountCount)")
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("settings-linked-accounts")

                    NavigationLink {
                        AlertSettingsView(
                            repositories: repositories,
                            notificationScheduler: notificationScheduler
                        )
                    } label: {
                        SettingsRow(icon: SiftIcon.bell, title: "Notifications", detail: viewModel.renewalReminderDetail)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("settings-notifications")

                    NavigationLink {
                        CategoriesView(repositories: repositories)
                    } label: {
                        SettingsRow(icon: SiftIcon.list, title: "Categories & rules")
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("settings-categories")

                    Button {
                        appModel.present(.cancellationRequests)
                    } label: {
                        SettingsRow(
                            icon: SiftIcon.list,
                            title: "Cancellation requests",
                            detail: "\(viewModel.cancellationRequestCount)"
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("settings-cancellation-requests")

                    NavigationLink {
                        PrivacyDataView(
                            repositories: repositories,
                            apiClient: apiClient,
                            notificationScheduler: notificationScheduler,
                            tokenStore: tokenStore,
                            stateStore: stateStore
                        )
                    } label: {
                        SettingsRow(icon: SiftIcon.privacy, title: "Privacy & data")
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("settings-privacy-data")

                    Button {
                        openLegalURL("https://sift.app/privacy")
                    } label: {
                        SettingsRow(icon: SiftIcon.privacy, title: "Privacy Policy")
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("settings-privacy-policy")

                    Button {
                        openLegalURL("https://sift.app/terms")
                    } label: {
                        SettingsRow(icon: SiftIcon.list, title: "Terms of Service")
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("settings-terms")
                }

                SupportAboutSection(metadata: supportMetadata) { url in
                    openURL(url)
                }

                if let errorMessage = viewModel.errorMessage {
                    StateMessageCard(
                        title: "Settings unavailable",
                        message: errorMessage,
                        systemImage: SiftIcon.warning
                    )
                }

                SecondaryButton(title: "Sign out") {
                    if viewModel.signOut() {
                        appModel.returnToOnboarding()
                    }
                }
                .accessibilityIdentifier("settings-sign-out")
            }
            .padding(.horizontal, Spacing.screenHorizontal)
            .padding(.top, Spacing.xl)
            .padding(.bottom, 84)
        }
        .background(Palette.bone)
        .navigationTitle("Settings")
        .task { viewModel.load() }
        .onChange(of: appModel.sheet) { _, newValue in
            if newValue == nil {
                viewModel.load()
            }
        }
    }

    private func openLegalURL(_ rawValue: String) {
        guard let url = URL(string: rawValue) else {
            return
        }

        openURL(url)
    }
}

struct AppSupportMetadata: Equatable {
    let version: String
    let build: String
    let supportEmail: String

    var versionSummary: String {
        "Version \(version) (\(build))"
    }

    var feedbackURL: URL? {
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = supportEmail
        components.queryItems = [
            URLQueryItem(name: "subject", value: "Sift beta feedback"),
            URLQueryItem(
                name: "body",
                value: """
                \(versionSummary)

                Please do not include bank credentials, account numbers, or transaction details.
                """
            ),
        ]
        return components.url
    }

    static func current(
        bundle: Bundle = .main,
        supportEmail: String = "support@sift.app"
    ) -> AppSupportMetadata {
        AppSupportMetadata(
            version: bundleString("CFBundleShortVersionString", in: bundle, fallback: "1.0"),
            build: bundleString("CFBundleVersion", in: bundle, fallback: "1"),
            supportEmail: supportEmail
        )
    }

    private static func bundleString(
        _ key: String,
        in bundle: Bundle,
        fallback: String
    ) -> String {
        guard let value = bundle.object(forInfoDictionaryKey: key) as? String,
              !value.isEmpty
        else {
            return fallback
        }

        return value
    }
}

private struct SettingsProfileCard: View {
    var body: some View {
        SiftCard {
            HStack(spacing: Spacing.md) {
                MonogramTile(letter: "A", color: Palette.ink, size: 54)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Andreas")
                        .font(.cardTitle)
                        .foregroundStyle(Palette.ink)

                    Text("Sift Premium")
                        .font(.cadence)
                        .foregroundStyle(Palette.goldDeep)
                }

                Spacer()

                Pill(text: "ACTIVE", variant: .neutral)
            }
        }
    }
}

private struct SupportAboutSection: View {
    let metadata: AppSupportMetadata
    let openFeedback: (URL) -> Void

    var body: some View {
        SiftCard {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("SUPPORT")
                    .font(.siftLabel)
                    .foregroundStyle(Palette.inkFaint)

                Text(metadata.versionSummary)
                    .font(.siftBody)
                    .foregroundStyle(Palette.inkSoft)
                    .accessibilityIdentifier("settings-support-version")

                Button {
                    guard let feedbackURL = metadata.feedbackURL else {
                        return
                    }

                    openFeedback(feedbackURL)
                } label: {
                    Label("Send beta feedback", systemImage: SiftIcon.support)
                        .font(.buttonLabel)
                        .foregroundStyle(Palette.ink)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(
                            Palette.bone,
                            in: RoundedRectangle(cornerRadius: Radius.control, style: .continuous)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: Radius.control, style: .continuous)
                                .stroke(Palette.line, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("settings-support-feedback")
            }
        }
    }
}

struct LinkedAccountRowModel: Identifiable, Equatable {
    let id: String
    let institutionName: String
    let accountCount: Int
    let status: LinkedAccountStatus
    let lastSyncedAt: Date?

    var accountMeta: String {
        accountCount == 1 ? "1 account" : "\(accountCount) accounts"
    }

    var syncMeta: String {
        guard let lastSyncedAt else {
            return "Not synced yet"
        }

        return "Synced \(lastSyncedAt.formatted(.dateTime.month(.abbreviated).day().hour().minute()))"
    }
}

@MainActor
@Observable
final class LinkedAccountsViewModel {
    private let repositories: RepositoryContainer
    private let apiClient: any SiftAPIClient
    private let linkCoordinator: any OnboardingLinkCoordinating
    private let refresher: any SubscriptionRefreshing
    private let referenceDateProvider: () -> Date

    var rows: [LinkedAccountRowModel] = []
    var isLoading = false
    var isWorking = false
    var errorMessage: String?

    init(
        repositories: RepositoryContainer,
        apiClient: any SiftAPIClient,
        linkCoordinator: any OnboardingLinkCoordinating,
        refresher: any SubscriptionRefreshing,
        referenceDateProvider: @escaping () -> Date = { Date() }
    ) {
        self.repositories = repositories
        self.apiClient = apiClient
        self.linkCoordinator = linkCoordinator
        self.refresher = refresher
        self.referenceDateProvider = referenceDateProvider
    }

    func load() async {
        isLoading = rows.isEmpty
        defer { isLoading = false }

        do {
            let remoteAccounts = try await apiClient.listAccounts()
            try repositories.accounts.replaceAll(with: remoteAccounts.map(makeLinkedAccount))
            rebuildRows()
            errorMessage = nil
        } catch {
            rebuildRows()
            errorMessage = rows.isEmpty ? userFacingMessage(for: error) : nil
        }
    }

    func addAccount() async {
        await run {
            let outcome = try await linkCoordinator.linkAccount(institution: nil)

            guard outcome == .linked else {
                return
            }

            _ = try await refresher.refresh(referenceDate: referenceDateProvider())
            await load()
        }
    }

    func removePlaidItem(id: String) async {
        await run {
            _ = try await apiClient.deletePlaidItem(id: id)
            try repositories.removeLocalPlaidItem(id: id)
            _ = try await refresher.refresh(referenceDate: referenceDateProvider())
            await load()
        }
    }

    private func run(_ operation: () async throws -> Void) async {
        isWorking = true
        errorMessage = nil

        do {
            try await operation()
        } catch {
            errorMessage = userFacingMessage(for: error)
        }

        isWorking = false
    }

    private func rebuildRows() {
        do {
            rows = try makeRows(from: repositories.accounts.all())
        } catch {
            errorMessage = userFacingMessage(for: error)
        }
    }

    private func makeLinkedAccount(from remote: RemoteAccount) -> LinkedAccount {
        LinkedAccount(
            id: remote.id,
            userID: SeedData.defaultUserID,
            plaidItemID: remote.plaidItemId,
            institutionName: remote.institutionName,
            mask: remote.mask ?? "----",
            type: remote.type.capitalized,
            status: LinkedAccountStatus(remoteStatus: remote.status),
            lastSyncedAt: Date()
        )
    }

    private func makeRows(from accounts: [LinkedAccount]) -> [LinkedAccountRowModel] {
        Dictionary(grouping: accounts) { account in
            account.plaidItemID ?? account.id
        }
        .map { itemID, accounts in
            let status = accounts.contains(where: { $0.status == .needsAttention })
                ? LinkedAccountStatus.needsAttention
                : accounts.contains(where: { $0.status == .disconnected }) ? .disconnected : .connected
            return LinkedAccountRowModel(
                id: itemID,
                institutionName: accounts.first?.institutionName ?? "Linked institution",
                accountCount: accounts.count,
                status: status,
                lastSyncedAt: accounts.compactMap(\.lastSyncedAt).max()
            )
        }
        .sorted { $0.institutionName.localizedStandardCompare($1.institutionName) == .orderedAscending }
    }

    private func userFacingMessage(for error: Error) -> String {
        if let siftError = error as? SiftError {
            return siftError.errorDescription ?? "Something went wrong."
        }

        return error.localizedDescription
    }
}

struct LinkedAccountsView: View {
    @State private var viewModel: LinkedAccountsViewModel
    @State private var accountPendingRemoval: LinkedAccountRowModel?

    init(
        repositories: RepositoryContainer = .mock(),
        apiClient: any SiftAPIClient = MockSiftAPIClient(),
        detectionService: any DetectionServing = MockDetectionService(),
        linkPresenter: any PlaidLinkPresenting = MockPlaidLinkPresenter(),
        notificationScheduler: any NotificationScheduling = NoopNotificationScheduler(),
        referenceDateProvider: @escaping () -> Date = { Date() }
    ) {
        let coordinator = PlaidLinkCoordinator(apiClient: apiClient, presenter: linkPresenter)
        let refresher = DefaultSubscriptionRefreshService(
            apiClient: apiClient,
            detectionService: detectionService,
            repositories: repositories,
            notificationScheduler: notificationScheduler
        )
        _viewModel = State(initialValue: LinkedAccountsViewModel(
            repositories: repositories,
            apiClient: apiClient,
            linkCoordinator: coordinator,
            refresher: refresher,
            referenceDateProvider: referenceDateProvider
        ))
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.xl) {
                    ScreenHeader(title: "Linked accounts", eyebrow: "BANKS")
                        .accessibilityIdentifier("linked-accounts-title")

                    linkedAccountsContent
                }
                .padding(.horizontal, Spacing.screenHorizontal)
                .padding(.top, Spacing.xl)
                .padding(.bottom, 112)
            }

            FloatingActionBar {
                Button {
                    Task { await viewModel.addAccount() }
                } label: {
                    Label("Add account", systemImage: SiftIcon.plus)
                        .font(.buttonLabel)
                        .foregroundStyle(Palette.ink)
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.plain)
                .disabled(viewModel.isWorking)
                .accessibilityIdentifier("linked-accounts-add")
            }
            .padding(.horizontal, Spacing.screenHorizontal)
            .padding(.bottom, Spacing.md)
        }
        .background(Palette.bone)
        .navigationTitle("Linked accounts")
        .task { await viewModel.load() }
        .alert("Remove linked account?", isPresented: removeConfirmationBinding) {
            Button("Remove", role: .destructive) {
                guard let row = accountPendingRemoval else {
                    return
                }
                Task { await viewModel.removePlaidItem(id: row.id) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Sift will disconnect \(accountPendingRemoval?.institutionName ?? "this institution") and re-run detection from your remaining accounts.")
        }
    }

    private var removeConfirmationBinding: Binding<Bool> {
        Binding(
            get: { accountPendingRemoval != nil },
            set: { isPresented in
                if !isPresented {
                    accountPendingRemoval = nil
                }
            }
        )
    }

    @ViewBuilder
    private var linkedAccountsContent: some View {
        if viewModel.isLoading {
            LinkedAccountsLoadingView()
        } else if let errorMessage = viewModel.errorMessage, viewModel.rows.isEmpty {
            StateMessageCard(
                title: "Accounts unavailable",
                message: errorMessage,
                systemImage: SiftIcon.warning
            )
        } else if viewModel.rows.isEmpty {
            StateMessageCard(
                title: "No accounts linked",
                message: "Connect a bank account to start subscription detection.",
                systemImage: SiftIcon.bank
            )
        } else {
            VStack(spacing: Spacing.sm) {
                ForEach(viewModel.rows) { row in
                    LinkedAccountRow(row: row) {
                        accountPendingRemoval = row
                    }
                }
            }

            if let errorMessage = viewModel.errorMessage {
                StateMessageCard(
                    title: "Sync paused",
                    message: errorMessage,
                    systemImage: SiftIcon.warning
                )
            }
        }
    }
}

private struct LinkedAccountRow: View {
    let row: LinkedAccountRowModel
    let remove: () -> Void

    var body: some View {
        HStack(spacing: Spacing.md) {
            Circle()
                .fill(statusColor)
                .frame(width: 10, height: 10)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(row.institutionName)
                    .font(.bodyEmphasis)
                    .foregroundStyle(Palette.ink)
                Text("\(row.accountMeta) - \(row.syncMeta)")
                    .font(.custom(SiftFontPostScriptName.plusJakartaMedium.rawValue, size: 12, relativeTo: .caption))
                    .foregroundStyle(Palette.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: Spacing.sm)

            Button("Remove", role: .destructive, action: remove)
                .font(.custom(SiftFontPostScriptName.plusJakartaSemiBold.rawValue, size: 12, relativeTo: .caption))
                .foregroundStyle(Palette.clay)
                .frame(minHeight: 44)
        }
        .padding(Spacing.md)
        .background(Palette.card, in: RoundedRectangle(cornerRadius: Radius.row, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.row, style: .continuous)
                .stroke(Palette.line, lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(row.institutionName), \(row.accountMeta), \(statusLabel)")
    }

    private var statusColor: Color {
        switch row.status {
        case .connected:
            Palette.green
        case .needsAttention:
            Palette.gold
        case .disconnected:
            Palette.clay
        }
    }

    private var statusLabel: String {
        switch row.status {
        case .connected:
            "Connected"
        case .needsAttention:
            "Needs attention"
        case .disconnected:
            "Disconnected"
        }
    }
}

private struct LinkedAccountsLoadingView: View {
    var body: some View {
        VStack(spacing: Spacing.sm) {
            ForEach(0 ..< 2, id: \.self) { _ in
                LinkedAccountRow(
                    row: LinkedAccountRowModel(
                        id: UUID().uuidString,
                        institutionName: "Linked institution",
                        accountCount: 2,
                        status: .connected,
                        lastSyncedAt: SeedData.referenceDate
                    ),
                    remove: {}
                )
            }
        }
        .redacted(reason: .placeholder)
        .accessibilityLabel("Loading linked accounts")
    }
}

@MainActor
@Observable
final class AlertSettingsViewModel {
    private let repository: any SettingsRepository
    private let notificationScheduler: any NotificationScheduling

    var renewalReminders = true
    var priceChanges = true
    var trialEndings = true
    var unusedNudges = true
    var weeklySummary = false
    var errorMessage: String?

    init(
        repository: any SettingsRepository,
        notificationScheduler: any NotificationScheduling = NoopNotificationScheduler()
    ) {
        self.repository = repository
        self.notificationScheduler = notificationScheduler
    }

    func load() {
        do {
            let settings = try repository.settings()
            renewalReminders = settings.renewalReminders
            priceChanges = settings.priceChanges
            trialEndings = settings.trialEndings
            unusedNudges = settings.unusedNudges
            weeklySummary = settings.weeklySummary
            errorMessage = nil
        } catch {
            errorMessage = userFacingMessage(for: error)
        }
    }

    func setRenewalReminders(_ value: Bool) {
        update { $0.renewalReminders = value }
    }

    func setPriceChanges(_ value: Bool) {
        update { $0.priceChanges = value }
    }

    func setTrialEndings(_ value: Bool) {
        update { $0.trialEndings = value }
    }

    func setUnusedNudges(_ value: Bool) {
        update { $0.unusedNudges = value }
    }

    func setWeeklySummary(_ value: Bool) {
        update { $0.weeklySummary = value }
    }

    private func update(_ mutation: (AlertSettings) -> Void) {
        do {
            let settings = try repository.settings()
            mutation(settings)
            try repository.update(settings)
            load()
            reconcileNotifications()
        } catch {
            errorMessage = userFacingMessage(for: error)
        }
    }

    private func reconcileNotifications() {
        Task { [notificationScheduler] in
            try? await notificationScheduler.reconcile()
        }
    }

    private func userFacingMessage(for error: Error) -> String {
        if let siftError = error as? SiftError {
            return siftError.errorDescription ?? "Something went wrong."
        }

        return error.localizedDescription
    }
}

struct AlertSettingsView: View {
    @State private var viewModel: AlertSettingsViewModel

    init(
        repositories: RepositoryContainer = .mock(),
        notificationScheduler: any NotificationScheduling = NoopNotificationScheduler()
    ) {
        _viewModel = State(initialValue: AlertSettingsViewModel(
            repository: repositories.settings,
            notificationScheduler: notificationScheduler
        ))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xl) {
                ScreenHeader(title: "Notifications", eyebrow: "ALERTS")
                    .accessibilityIdentifier("alert-settings-title")

                VStack(spacing: Spacing.sm) {
                    AlertToggleRow(
                        title: "Renewal reminders",
                        detail: "Upcoming renewals",
                        isOn: Binding(
                            get: { viewModel.renewalReminders },
                            set: { viewModel.setRenewalReminders($0) }
                        )
                    )
                    .accessibilityIdentifier("alert-renewal-reminders-toggle")

                    AlertToggleRow(
                        title: "Price-change alerts",
                        detail: "Amount increases or drops",
                        isOn: Binding(
                            get: { viewModel.priceChanges },
                            set: { viewModel.setPriceChanges($0) }
                        )
                    )

                    AlertToggleRow(
                        title: "Free-trial endings",
                        detail: "Trial charges before they begin",
                        isOn: Binding(
                            get: { viewModel.trialEndings },
                            set: { viewModel.setTrialEndings($0) }
                        )
                    )

                    AlertToggleRow(
                        title: "Unused nudges",
                        detail: "Subscriptions not seen recently",
                        isOn: Binding(
                            get: { viewModel.unusedNudges },
                            set: { viewModel.setUnusedNudges($0) }
                        )
                    )

                    AlertToggleRow(
                        title: "Weekly summary",
                        detail: "One calm digest",
                        isOn: Binding(
                            get: { viewModel.weeklySummary },
                            set: { viewModel.setWeeklySummary($0) }
                        )
                    )
                    .accessibilityIdentifier("alert-weekly-summary-toggle")
                }

                if let errorMessage = viewModel.errorMessage {
                    StateMessageCard(
                        title: "Alerts unavailable",
                        message: errorMessage,
                        systemImage: SiftIcon.warning
                    )
                }
            }
            .padding(.horizontal, Spacing.screenHorizontal)
            .padding(.top, Spacing.xl)
            .padding(.bottom, 84)
        }
        .background(Palette.bone)
        .navigationTitle("Notifications")
        .task { viewModel.load() }
    }
}

private struct AlertToggleRow: View {
    let title: String
    let detail: String
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.bodyEmphasis)
                    .foregroundStyle(Palette.ink)
                Text(detail)
                    .font(.custom(SiftFontPostScriptName.plusJakartaMedium.rawValue, size: 12, relativeTo: .caption))
                    .foregroundStyle(Palette.inkSoft)
            }
        }
        .toggleStyle(SiftToggleStyle())
        .padding(Spacing.md)
        .background(Palette.card, in: RoundedRectangle(cornerRadius: Radius.row, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.row, style: .continuous)
                .stroke(Palette.line, lineWidth: 1)
        )
    }
}

struct CategoryRowModel: Identifiable, Equatable {
    let id: String
    let name: String
    let count: Int
    let monthlyTotal: Money
}

@MainActor
@Observable
final class CategoriesViewModel {
    private let repositories: RepositoryContainer
    private let service: CategoryService

    var autoCategorize = true
    var rows: [CategoryRowModel] = []
    var categories: [Category] = []
    var subscriptions: [Subscription] = []
    var errorMessage: String?

    init(repositories: RepositoryContainer, service: CategoryService? = nil) {
        self.repositories = repositories
        self.service = service ?? CategoryService(repositories: repositories)
    }

    func load() {
        do {
            let settings = try repositories.settings.settings()
            autoCategorize = settings.autoCategorizeSubscriptions
            try service.applyAutoCategorizationIfEnabled()
            try service.applyAutoCategorizationForTransactions()
            categories = try repositories.categories.all()
            subscriptions = try repositories.subscriptions.all()
            rows = makeRows()
            errorMessage = nil
        } catch {
            errorMessage = userFacingMessage(for: error)
        }
    }

    func setAutoCategorize(_ value: Bool) {
        do {
            let settings = try repositories.settings.settings()
            settings.autoCategorizeSubscriptions = value
            try repositories.settings.update(settings)
            load()
        } catch {
            errorMessage = userFacingMessage(for: error)
        }
    }

    func subscriptions(for categoryID: String) -> [Subscription] {
        subscriptions
            .filter { $0.status != .cancelled && $0.categoryID == categoryID }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    func recategorize(subscriptionID: String, categoryID: String?) {
        do {
            try service.manuallyAssign(subscriptionID: subscriptionID, categoryID: categoryID)
            load()
        } catch {
            errorMessage = userFacingMessage(for: error)
        }
    }

    func mergeCategory(id sourceID: String, into targetID: String) {
        do {
            try service.mergeCategory(id: sourceID, into: targetID)
            load()
        } catch {
            errorMessage = userFacingMessage(for: error)
        }
    }

    private func makeRows() -> [CategoryRowModel] {
        let groups = Dictionary(grouping: subscriptions.filter { $0.status != .cancelled }) { $0.categoryID }

        return categories.map { category in
            let categorySubscriptions = groups[category.id] ?? []
            let total = (try? Money.sum(categorySubscriptions.map(\.monthlyEquivalent))) ?? .zeroUSD
            return CategoryRowModel(
                id: category.id,
                name: category.name,
                count: categorySubscriptions.count,
                monthlyTotal: total
            )
        }
        .sorted { left, right in
            if left.count != right.count {
                return left.count > right.count
            }
            return left.name.localizedStandardCompare(right.name) == .orderedAscending
        }
    }

    private func userFacingMessage(for error: Error) -> String {
        if let siftError = error as? SiftError {
            return siftError.errorDescription ?? "Something went wrong."
        }

        return error.localizedDescription
    }
}

struct CategoriesView: View {
    @State private var viewModel: CategoriesViewModel

    init(repositories: RepositoryContainer = .mock()) {
        _viewModel = State(initialValue: CategoriesViewModel(repositories: repositories))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xl) {
                ScreenHeader(title: "Categories & rules", eyebrow: "GROUPS")
                    .accessibilityIdentifier("categories-title")

                AlertToggleRow(
                    title: "Auto-categorise",
                    detail: "Keyword rules apply unless you change a category",
                    isOn: Binding(
                        get: { viewModel.autoCategorize },
                        set: { viewModel.setAutoCategorize($0) }
                    )
                )
                .accessibilityIdentifier("categories-auto-toggle")

                VStack(spacing: Spacing.sm) {
                    ForEach(viewModel.rows) { row in
                        NavigationLink {
                            CategorySubscriptionsView(category: row, viewModel: viewModel)
                        } label: {
                            CategoryRow(row: row)
                        }
                        .buttonStyle(.plain)
                    }
                }

                if let errorMessage = viewModel.errorMessage {
                    StateMessageCard(
                        title: "Categories unavailable",
                        message: errorMessage,
                        systemImage: SiftIcon.warning
                    )
                }
            }
            .padding(.horizontal, Spacing.screenHorizontal)
            .padding(.top, Spacing.xl)
            .padding(.bottom, 84)
        }
        .background(Palette.bone)
        .navigationTitle("Categories")
        .task { viewModel.load() }
    }
}

private struct CategoryRow: View {
    let row: CategoryRowModel

    var body: some View {
        HStack(spacing: Spacing.md) {
            Image(systemName: SiftIcon.list)
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(Palette.goldDeep)
                .frame(width: 32, height: 32)
                .background(Palette.bone, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .stroke(Palette.line, lineWidth: 1)
                )

            VStack(alignment: .leading, spacing: 3) {
                Text(row.name)
                    .font(.bodyEmphasis)
                    .foregroundStyle(Palette.ink)
                Text(row.count == 1 ? "1 subscription" : "\(row.count) subscriptions")
                    .font(.custom(SiftFontPostScriptName.plusJakartaMedium.rawValue, size: 12, relativeTo: .caption))
                    .foregroundStyle(Palette.inkSoft)
            }

            Spacer()

            MoneyText(value: row.monthlyTotal.formatted(), size: 16)

            Image(systemName: SiftIcon.chevronRight)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Palette.inkFaint)
        }
        .padding(Spacing.md)
        .background(Palette.card, in: RoundedRectangle(cornerRadius: Radius.row, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.row, style: .continuous)
                .stroke(Palette.line, lineWidth: 1)
        )
    }
}

private struct CategorySubscriptionsView: View {
    let category: CategoryRowModel
    let viewModel: CategoriesViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xl) {
                ScreenHeader(title: category.name, eyebrow: "CATEGORY")

                if viewModel.subscriptions(for: category.id).isEmpty {
                    StateMessageCard(
                        title: "No subscriptions",
                        message: "Subscriptions assigned here will appear after detection or manual changes.",
                        systemImage: SiftIcon.list
                    )
                } else {
                    VStack(spacing: Spacing.sm) {
                        ForEach(viewModel.subscriptions(for: category.id), id: \.id) { subscription in
                            CategorySubscriptionRow(
                                subscription: subscription,
                                categories: viewModel.categories,
                                currentCategoryID: category.id,
                                recategorize: { targetID in
                                    viewModel.recategorize(subscriptionID: subscription.id, categoryID: targetID)
                                }
                            )
                        }
                    }
                }

                MergeCategorySection(category: category, viewModel: viewModel)
            }
            .padding(.horizontal, Spacing.screenHorizontal)
            .padding(.top, Spacing.xl)
            .padding(.bottom, 84)
        }
        .background(Palette.bone)
        .navigationTitle(category.name)
    }
}

private struct CategorySubscriptionRow: View {
    let subscription: Subscription
    let categories: [Category]
    let currentCategoryID: String
    let recategorize: (String?) -> Void

    var body: some View {
        HStack(spacing: Spacing.md) {
            MonogramTile(letter: subscription.monogramLetter, color: subscription.tileColorToken.color)

            VStack(alignment: .leading, spacing: 3) {
                Text(subscription.name)
                    .font(.bodyEmphasis)
                    .foregroundStyle(Palette.ink)
                Text(subscription.amount.formatted())
                    .font(.custom(SiftFontPostScriptName.plusJakartaMedium.rawValue, size: 12, relativeTo: .caption))
                    .foregroundStyle(Palette.inkSoft)
            }

            Spacer()

            Menu {
                ForEach(categories, id: \.id) { category in
                    Button(category.name) {
                        recategorize(category.id)
                    }
                    .disabled(category.id == currentCategoryID)
                }

                Button("Other") {
                    recategorize(nil)
                }
            } label: {
                Label("Move", systemImage: SiftIcon.chevronRight)
                    .font(.custom(SiftFontPostScriptName.plusJakartaSemiBold.rawValue, size: 12, relativeTo: .caption))
                    .foregroundStyle(Palette.goldDeep)
                    .frame(minHeight: 44)
            }
        }
        .padding(Spacing.md)
        .background(Palette.card, in: RoundedRectangle(cornerRadius: Radius.row, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.row, style: .continuous)
                .stroke(Palette.line, lineWidth: 1)
        )
    }
}

private struct MergeCategorySection: View {
    let category: CategoryRowModel
    let viewModel: CategoriesViewModel

    var body: some View {
        SiftCard {
            Text("MERGE DUPLICATES")
                .font(.siftLabel)
                .foregroundStyle(Palette.inkFaint)

            Text("Move this category into another one.")
                .font(.siftBody)
                .foregroundStyle(Palette.inkSoft)

            Menu {
                ForEach(viewModel.categories.filter { $0.id != category.id }, id: \.id) { target in
                    Button(target.name) {
                        viewModel.mergeCategory(id: category.id, into: target.id)
                    }
                }
            } label: {
                Label("Merge into", systemImage: SiftIcon.list)
                    .font(.buttonLabel)
                    .foregroundStyle(Palette.ink)
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .background(Palette.card, in: RoundedRectangle(cornerRadius: Radius.control, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: Radius.control, style: .continuous)
                            .stroke(Palette.line, lineWidth: 1)
                    )
            }
        }
    }
}

@MainActor
@Observable
final class PrivacyDataViewModel {
    private let repositories: RepositoryContainer
    private let apiClient: any SiftAPIClient
    private let notificationScheduler: any NotificationScheduling
    private let tokenStore: any TokenStoring
    private let stateStore: any OnboardingStateStoring

    var isDeleting = false
    var errorMessage: String?

    init(
        repositories: RepositoryContainer,
        apiClient: any SiftAPIClient,
        notificationScheduler: any NotificationScheduling = NoopNotificationScheduler(),
        tokenStore: any TokenStoring,
        stateStore: any OnboardingStateStoring
    ) {
        self.repositories = repositories
        self.apiClient = apiClient
        self.notificationScheduler = notificationScheduler
        self.tokenStore = tokenStore
        self.stateStore = stateStore
    }

    func disconnectAndDelete() async -> Bool {
        isDeleting = true
        defer { isDeleting = false }

        do {
            _ = try await apiClient.deleteUserData()
            try repositories.wipeLocalData()
            await notificationScheduler.cancelAllSiftNotifications()
            try tokenStore.deleteToken()
            stateStore.setComplete(false)
            errorMessage = nil
            return true
        } catch {
            errorMessage = userFacingMessage(for: error)
            return false
        }
    }

    private func userFacingMessage(for error: Error) -> String {
        if let siftError = error as? SiftError {
            return siftError.errorDescription ?? "Something went wrong."
        }

        return error.localizedDescription
    }
}

private enum PrivacyConfirmation: Identifiable {
    case first
    case second

    var id: String {
        switch self {
        case .first:
            "first"
        case .second:
            "second"
        }
    }
}

struct PrivacyDataView: View {
    @Environment(AppModel.self) private var appModel
    @State private var viewModel: PrivacyDataViewModel
    @State private var confirmation: PrivacyConfirmation?

    init(
        repositories: RepositoryContainer = .mock(),
        apiClient: any SiftAPIClient = MockSiftAPIClient(),
        notificationScheduler: any NotificationScheduling = NoopNotificationScheduler(),
        tokenStore: any TokenStoring = InMemoryTokenStore(),
        stateStore: any OnboardingStateStoring = InMemoryOnboardingStateStore()
    ) {
        _viewModel = State(initialValue: PrivacyDataViewModel(
            repositories: repositories,
            apiClient: apiClient,
            notificationScheduler: notificationScheduler,
            tokenStore: tokenStore,
            stateStore: stateStore
        ))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xl) {
                ScreenHeader(title: "Privacy & data", eyebrow: "CONTROL")
                    .accessibilityIdentifier("privacy-data-title")

                SiftCard {
                    Text("WHAT SIFT STORES")
                        .font(.siftLabel)
                        .foregroundStyle(Palette.inkFaint)

                    Text("Sift keeps linked account metadata, transactions, detected subscriptions, alert settings, and cancellation requests for your account.")
                        .font(.siftBody)
                        .foregroundStyle(Palette.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                }

                ClayButton(title: viewModel.isDeleting ? "Deleting..." : "Disconnect & delete") {
                    confirmation = .first
                }
                .disabled(viewModel.isDeleting)
                .accessibilityIdentifier("privacy-delete-button")

                if let errorMessage = viewModel.errorMessage {
                    StateMessageCard(
                        title: "Delete paused",
                        message: errorMessage,
                        systemImage: SiftIcon.warning
                    )
                }
            }
            .padding(.horizontal, Spacing.screenHorizontal)
            .padding(.top, Spacing.xl)
            .padding(.bottom, 84)
        }
        .background(Palette.bone)
        .navigationTitle("Privacy")
        .alert("Disconnect all accounts?", isPresented: confirmationBinding) {
            switch confirmation {
            case .some(.first):
                Button("Continue", role: .destructive) {
                    confirmation = .second
                }
                Button("Cancel", role: .cancel) {}
            case .some(.second):
                Button("Delete my data", role: .destructive) {
                    Task {
                        guard await viewModel.disconnectAndDelete() else {
                            return
                        }
                        appModel.returnToOnboarding()
                    }
                }
                Button("Cancel", role: .cancel) {}
            case nil:
                Button("Cancel", role: .cancel) {}
            }
        } message: {
            switch confirmation {
            case .some(.first):
                Text("Sift will revoke Plaid access for every linked bank.")
            case .some(.second):
                Text("This clears your local store and returns Sift to onboarding.")
            case nil:
                Text("")
            }
        }
    }

    private var confirmationBinding: Binding<Bool> {
        Binding(
            get: { confirmation != nil },
            set: { isPresented in
                if !isPresented {
                    confirmation = nil
                }
            }
        )
    }
}

#Preview("Settings") {
    NavigationStack {
        SettingsView()
    }
    .environment(AppModel(isOnboardingComplete: true))
    .environment(\.repositories, .mock())
    .environment(\.tokenStore, InMemoryTokenStore(token: "preview-token"))
    .environment(\.onboardingStateStore, InMemoryOnboardingStateStore(isComplete: true))
}

#Preview("Linked Accounts") {
    NavigationStack {
        LinkedAccountsView(repositories: .mock(), referenceDateProvider: { SeedData.referenceDate })
    }
}

#Preview("Alerts") {
    NavigationStack {
        AlertSettingsView(repositories: .mock())
    }
}

#Preview("Categories") {
    NavigationStack {
        CategoriesView(repositories: .mock())
    }
}
