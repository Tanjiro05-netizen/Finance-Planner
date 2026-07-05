import SwiftUI

struct CancelFlowSheetView: View {
    @Environment(AppModel.self) private var appModel
    @State private var viewModel: CancellationViewModel

    let subscriptionID: String

    init(
        subscriptionID: String,
        repositories: RepositoryContainer = .mock(),
        apiClient: any SiftAPIClient = MockSiftAPIClient(),
        notificationScheduler: any NotificationScheduling = NoopNotificationScheduler(),
        featureFlags: SiftFeatureFlags = .launchDefault,
        analyticsRecorder: any AnalyticsRecording = NoopAnalyticsRecorder()
    ) {
        self.subscriptionID = subscriptionID
        _viewModel = State(initialValue: CancellationViewModel(
            subscriptionID: subscriptionID,
            repositories: repositories,
            apiClient: apiClient,
            notificationScheduler: notificationScheduler,
            featureFlags: featureFlags,
            analyticsRecorder: analyticsRecorder
        ))
    }

    var body: some View {
        NavigationStack {
            content
                .background(Palette.bone)
                .navigationTitle(navigationTitle)
                .task(id: subscriptionID) {
                    viewModel.load()
                }
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") {
                            appModel.dismissSheet()
                        }
                    }
                }
        }
        .presentationDragIndicator(.visible)
        .presentationDetents([.large])
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.stage {
        case .options:
            CancelOptionsView(viewModel: viewModel)
        case .concierge:
            ConciergeStatusView(viewModel: viewModel)
        case .guided:
            GuidedStepsView(viewModel: viewModel)
        case .confirmed:
            CancelConfirmedView(viewModel: viewModel) {
                appModel.dismissSheet()
            }
        case .requests:
            CancellationRequestsView(viewModel: viewModel)
        }
    }

    private var navigationTitle: String {
        switch viewModel.stage {
        case .options:
            "Cancel"
        case .concierge:
            "Concierge"
        case .guided:
            "Guide"
        case .confirmed:
            "Confirmed"
        case .requests:
            "Requests"
        }
    }
}

#Preview {
    CancelFlowSheetView(subscriptionID: SampleRouteID.subscription)
        .environment(AppModel())
        .environment(\.repositories, .mock())
}
