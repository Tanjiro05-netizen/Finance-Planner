import SwiftUI

struct OnboardingFlowView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var viewModel: OnboardingViewModel
    @State private var linkKitPresenter: LinkKitPlaidLinkPresenter?

    private let onComplete: @MainActor () -> Void

    init(
        apiClient: any SiftAPIClient,
        linkPresenter: any PlaidLinkPresenting,
        detectionService: any DetectionServing,
        notificationAuthorizer: any NotificationAuthorizing,
        notificationScheduler: any NotificationScheduling = NoopNotificationScheduler(),
        repositories: RepositoryContainer,
        stateStore: any OnboardingStateStoring,
        onComplete: @escaping @MainActor () -> Void
    ) {
        let coordinator = PlaidLinkCoordinator(apiClient: apiClient, presenter: linkPresenter)
        _viewModel = State(initialValue: OnboardingViewModel(
            apiClient: apiClient,
            linkCoordinator: coordinator,
            detectionService: detectionService,
            notificationAuthorizer: notificationAuthorizer,
            notificationScheduler: notificationScheduler,
            repositories: repositories,
            stateStore: stateStore
        ))
        _linkKitPresenter = State(initialValue: linkPresenter as? LinkKitPlaidLinkPresenter)
        self.onComplete = onComplete
    }

    init(viewModel: OnboardingViewModel, onComplete: @escaping @MainActor () -> Void = {}) {
        _viewModel = State(initialValue: viewModel)
        _linkKitPresenter = State(initialValue: nil)
        self.onComplete = onComplete
    }

    var body: some View {
        ZStack {
            Palette.ground.ignoresSafeArea()
            content
                .transition(Motion.stepTransition(reduceMotion: reduceMotion))
        }
        .animation(Motion.reduced(Motion.gentle, reduceMotion: reduceMotion), value: viewModel.step)
        .task {
            await viewModel.bootstrapIfNeeded()
        }
        .sheet(isPresented: linkSheetBinding) {
            linkKitPresenter?.sheet()
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.step {
        case .splash:
            SplashView(isWorking: viewModel.isWorking, errorMessage: viewModel.errorMessage) {
                Task { await viewModel.bootstrapIfNeeded() }
            }
        case .welcome:
            WelcomeView {
                viewModel.showConnectIntro()
            }
        case .connectIntro:
            ConnectIntroView(errorMessage: viewModel.errorMessage) {
                viewModel.showConnectLeadIn()
            }
        case .bankPicker:
            // Retained for a future Android/Plaid port; not reached in the Apple Wallet flow.
            BankPickerView(institutions: BankInstitution.popular) { institution in
                viewModel.selectInstitution(institution)
            }
        case .secureLeadIn:
            SecureLeadInView(
                institution: viewModel.selectedInstitution,
                isWorking: viewModel.isWorking,
                errorMessage: viewModel.errorMessage
            ) {
                Task { await viewModel.connectAppleWallet() }
            }
        case .scanning:
            ScanningView(scanState: viewModel.scanState)
        case .reviewFound:
            ReviewFoundView(
                items: viewModel.reviewItems,
                errorMessage: viewModel.errorMessage,
                onToggle: viewModel.toggleReviewItem(id:),
                onConfirm: viewModel.confirmSubscriptions
            )
        case .notifications:
            NotificationsOptInView {
                Task { await viewModel.requestNotifications() }
            } onSkip: {
                viewModel.skipNotifications()
            }
        case .allSet:
            AllSetView(
                count: viewModel.confirmedCount,
                monthlyTotal: viewModel.confirmedMonthlyTotal
            ) {
                viewModel.completeOnboarding()
                onComplete()
            }
        case .connectUnavailable:
            ConnectUnavailableView(
                reason: viewModel.unavailableReason ?? .accessDenied,
                onRetry: { viewModel.retryConnect() },
                onSkip: { viewModel.skipConnect() }
            )
        }
    }

    private var linkSheetBinding: Binding<Bool> {
        Binding {
            linkKitPresenter?.isPresentingLink ?? false
        } set: { isPresented in
            linkKitPresenter?.isPresentingLink = isPresented
        }
    }
}

#Preview("Welcome") {
    OnboardingFlowView(
        viewModel: OnboardingPreviewFactory.viewModel(step: .welcome)
    )
}

#Preview("Review") {
    OnboardingFlowView(
        viewModel: OnboardingPreviewFactory.viewModel(step: .reviewFound)
    )
}
