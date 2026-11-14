import SwiftData
import SwiftUI

struct ChatView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase

    @State private var viewModel = ChatViewModel()
    @State private var isConfirmingNewChat = false

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.availability != .available {
                    unavailable
                } else if viewModel.messages.isEmpty {
                    emptyState
                } else {
                    conversation
                }
            }
            .background(Color.ds(.canvas))
            .navigationTitle("Ask Swiftlet")
            .toolbar {
                if !viewModel.messages.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("New chat", systemImage: "square.and.pencil") { isConfirmingNewChat = true }
                    }
                }
            }
            .safeAreaBar(edge: .bottom) {
                VStack(spacing: 4) {
                    if !viewModel.messages.isEmpty, viewModel.availability == .available {
                        ChatSuggestionStrip(isEnabled: !viewModel.isResponding) { viewModel.send($0) }
                    }
                    ChatInputBar(
                        text: $viewModel.input,
                        isEnabled: viewModel.availability == .available,
                        canSend: viewModel.canSend
                    ) { viewModel.send() }
                }
            }
            .confirmationDialog("Start a new chat?", isPresented: $isConfirmingNewChat, titleVisibility: .visible) {
                Button("New chat", role: .destructive) { viewModel.newChat() }
            } message: {
                Text("This clears the current conversation.")
            }
        }
        .task { viewModel.configure(context: modelContext) }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { viewModel.refreshAvailability() }
        }
    }

    private var conversation: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(viewModel.messages) { message in
                        ChatBubbleView(message: message, onRetry: viewModel.canRetry ? { viewModel.retry() } : nil)
                            .id(message.id)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: viewModel.messages.last?.text) {
                scrollToEnd(proxy)
            }
            .onChange(of: viewModel.messages.count) {
                scrollToEnd(proxy)
            }
        }
    }

    private func scrollToEnd(_ proxy: ScrollViewProxy) {
        guard let id = viewModel.messages.last?.id else { return }
        proxy.scrollTo(id, anchor: .bottom)
    }

    private var emptyState: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 36))
                        .foregroundStyle(Color.ds(.accent))
                        .accessibilityHidden(true)
                    Text("Ask about your money")
                        .dsTextStyle(.title3)
                    Text("Spending, balances, who owes you and upcoming bills. Everything stays on this iPhone.")
                        .dsTextStyle(.subheadline, color: .textSecondary)
                        .multilineTextAlignment(.center)
                }
                VStack(spacing: 10) {
                    ForEach(ChatSuggestions.prompts, id: \.self) { prompt in
                        Button { viewModel.send(prompt) } label: {
                            Text(LocalizedStringKey(prompt))
                                .dsTextStyle(.subheadlineEmphasized)
                                .multilineTextAlignment(.leading)
                                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 4)
                                .background(Color.ds(.surfaceMuted), in: Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 40)
            .frame(maxWidth: .infinity)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private var unavailable: some View {
        EmptyStateView(
            systemImage: "sparkles",
            title: "Ask Swiftlet isn't available",
            message: viewModel.availability.explanation
        )
    }
}

#Preview {
    ChatView()
        .modelContainer(for: [Transaction.self, TransactionCategory.self, Wallet.self], inMemory: true)
}
