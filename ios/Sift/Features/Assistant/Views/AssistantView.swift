import SwiftUI

struct AssistantView: View {
    @State private var viewModel: AssistantViewModel

    init(
        repositories: RepositoryContainer = .mock(),
        conversation: any InsightConversing = MockInsightConversation(),
        referenceDateProvider: @escaping () -> Date = { Date() },
        featureFlags: SiftFeatureFlags = .launchDefault
    ) {
        _viewModel = State(initialValue: AssistantViewModel(
            repositories: repositories,
            conversation: conversation,
            referenceDateProvider: referenceDateProvider,
            featureFlags: featureFlags
        ))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xl) {
                ScreenHeader(title: "Ask", eyebrow: "ON THIS IPHONE")
                    .accessibilityIdentifier("assistant-title")

                content
            }
            .padding(.horizontal, Spacing.screenHorizontal)
            .padding(.top, Spacing.xl)
            .padding(.bottom, 84)
        }
        .background(Palette.bone)
        .navigationTitle("Ask")
        .safeAreaInset(edge: .bottom) {
            if viewModel.isAvailable {
                composer
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if let unavailableMessage = viewModel.unavailableMessage {
            StateMessageCard(
                title: "Not available here",
                message: unavailableMessage,
                systemImage: SiftIcon.assistant
            )
            .accessibilityIdentifier("assistant-unavailable")
        } else if !viewModel.isAvailable {
            StateMessageCard(
                title: "Coming soon",
                message: "Ask Sift about your money in plain language, answered on your iPhone.",
                systemImage: SiftIcon.assistant
            )
            .accessibilityIdentifier("assistant-disabled")
        } else {
            if viewModel.isEmpty {
                emptyState
            }

            transcript

            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .font(.siftBody)
                    .foregroundStyle(Palette.clay)
            }

            privacyNote
        }
    }

    private var emptyState: some View {
        SiftCard {
            Text("TRY ASKING")
                .font(.siftLabel)
                .foregroundStyle(Palette.inkFaint)

            ForEach(viewModel.suggestions, id: \.self) { suggestion in
                Button {
                    Task { await viewModel.ask(suggestion) }
                } label: {
                    Text(suggestion)
                        .font(.siftBody)
                        .foregroundStyle(Palette.goldDeep)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
            }
        }
        .accessibilityIdentifier("assistant-suggestions")
    }

    private var transcript: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            ForEach(viewModel.messages) { message in
                ChatBubble(message: message)
            }

            if viewModel.isReplying {
                Text("Thinking…")
                    .font(.siftBody)
                    .foregroundStyle(Palette.inkFaint)
                    .accessibilityIdentifier("assistant-thinking")
            }
        }
    }

    private var privacyNote: some View {
        Text("Answers are generated on your iPhone. Your financial data never leaves the device.")
            .font(.siftLabel)
            .foregroundStyle(Palette.inkFaint)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var composer: some View {
        HStack(spacing: Spacing.sm) {
            TextField("Ask about your money", text: $viewModel.draft, axis: .vertical)
                .font(.siftBody)
                .lineLimit(1 ... 4)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Palette.card, in: Capsule())
                .overlay(Capsule().stroke(Palette.line, lineWidth: 1))
                .accessibilityIdentifier("assistant-input")

            Button {
                Task { await viewModel.send() }
            } label: {
                Image(systemName: SiftIcon.arrowUp)
                    .font(.siftBody)
                    .foregroundStyle(viewModel.canSend ? Palette.goldDeep : Palette.inkFaint)
                    .frame(width: 42, height: 42)
                    .background(Palette.card, in: Circle())
                    .overlay(Circle().stroke(Palette.line, lineWidth: 1))
            }
            .buttonStyle(.plain)
            .disabled(!viewModel.canSend)
            .accessibilityIdentifier("assistant-send")
            .accessibilityLabel("Send")
        }
        .padding(.horizontal, Spacing.screenHorizontal)
        .padding(.vertical, Spacing.md)
        .background(Palette.bone)
    }
}

private struct ChatBubble: View {
    let message: ChatMessage

    private var isPerson: Bool {
        message.author == .person
    }

    var body: some View {
        HStack {
            if isPerson {
                Spacer(minLength: 40)
            }

            Text(message.text)
                .font(.siftBody)
                .foregroundStyle(Palette.ink)
                .padding(.horizontal, 14)
                .padding(.vertical, 11)
                .background(
                    isPerson ? Palette.sand : Palette.card,
                    in: RoundedRectangle(cornerRadius: Radius.row, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.row, style: .continuous)
                        .stroke(Palette.line, lineWidth: 1)
                )
                .frame(maxWidth: .infinity, alignment: isPerson ? .trailing : .leading)

            if !isPerson {
                Spacer(minLength: 40)
            }
        }
        .accessibilityIdentifier(isPerson ? "assistant-message-person" : "assistant-message-reply")
    }
}

#Preview {
    NavigationStack {
        AssistantView(
            repositories: .mock(),
            referenceDateProvider: { SeedData.referenceDate },
            featureFlags: SiftFeatureFlags(assistantEnabled: true)
        )
    }
}
