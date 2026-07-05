import SwiftUI

struct SettingsView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.repositories) private var repositories

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xl) {
                ScreenHeader(title: "Settings", eyebrow: "ACCOUNT")
                    .accessibilityIdentifier("settings-title")

                VStack(spacing: Spacing.sm) {
                    SettingsRow(icon: SiftIcon.bank, title: "Linked accounts", detail: "\(linkedAccountCount)")
                    SettingsRow(icon: SiftIcon.bell, title: "Renewal reminders", detail: renewalReminderDetail)
                    Button {
                        appModel.present(.cancellationRequests)
                    } label: {
                        SettingsRow(icon: SiftIcon.list, title: "Cancellation requests", detail: "\(cancellationRequestCount)")
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("settings-cancellation-requests")
                    SettingsRow(icon: SiftIcon.privacy, title: "Privacy & data")
                }
            }
            .padding(.horizontal, Spacing.screenHorizontal)
            .padding(.top, Spacing.xl)
            .padding(.bottom, 84)
        }
        .background(Palette.bone)
        .navigationTitle("Settings")
    }

    private var linkedAccountCount: Int {
        ((try? repositories.accounts.all()) ?? []).count
    }

    private var renewalReminderDetail: String {
        ((try? repositories.settings.settings())?.renewalReminders ?? true) ? "On" : "Off"
    }

    private var cancellationRequestCount: Int {
        ((try? repositories.cancellations.all()) ?? []).count
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
    .environment(AppModel())
    .environment(\.repositories, .mock())
}
