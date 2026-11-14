import SwiftUI

struct ChatInputBar: View {
    @Binding var text: String
    let isEnabled: Bool
    let canSend: Bool
    let onSend: () -> Void

    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            TextField("Ask about your money", text: $text, axis: .vertical)
                .lineLimit(1 ... 4)
                .focused($isFocused)
                .submitLabel(.send)
                .onSubmit(send)
                .disabled(!isEnabled)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.ds(.surface), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(Color.ds(.border)))

            Button(action: send) {
                Image(systemName: "arrow.up")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Color.ds(.onAccent))
                    .frame(width: 44, height: 44)
                    .background(Color.ds(.accentFill).opacity(canSend ? 1 : 0.4), in: Circle())
            }
            .buttonStyle(.plain)
            .disabled(!canSend)
            .accessibilityLabel("Send")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private func send() {
        guard canSend else { return }
        onSend()
    }
}
