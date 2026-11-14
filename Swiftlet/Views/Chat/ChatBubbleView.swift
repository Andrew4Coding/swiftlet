import SwiftUI

struct ChatBubbleView: View {
    let message: ChatMessage
    var onRetry: (() -> Void)?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var isUser: Bool {
        message.role == .user
    }

    var body: some View {
        HStack(alignment: .bottom) {
            if isUser { Spacer(minLength: 48) }
            VStack(alignment: .leading, spacing: 8) {
                bubbleContent
                ForEach(Array(message.images.enumerated()), id: \.offset) { _, data in
                    ReceiptPreviewButton(imageData: data)
                        .frame(maxWidth: 260)
                }
                if message.state == .failed, let onRetry {
                    Button("Try again", systemImage: "arrow.clockwise", action: onRetry)
                        .font(TypographyToken.subheadlineEmphasized.font)
                        .foregroundStyle(Color.ds(.accent))
                        .frame(minHeight: 44)
                }
            }
            if !isUser { Spacer(minLength: 48) }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityText)
    }

    @ViewBuilder
    private var bubbleContent: some View {
        if message.state == .streaming, message.text.isEmpty {
            typingIndicator
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(Color.ds(.surface), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        } else {
            Text(message.text)
                .dsTextStyle(.body, color: isUser ? .onAccent : .textPrimary)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    isUser ? Color.ds(.accentFill) : Color.ds(.surface),
                    in: RoundedRectangle(cornerRadius: 20, style: .continuous)
                )
        }
    }

    @ViewBuilder
    private var typingIndicator: some View {
        if reduceMotion {
            Text("Thinking…").dsTextStyle(.subheadline, color: .textSecondary)
        } else {
            Image(systemName: "ellipsis")
                .font(TypographyToken.headline.font)
                .foregroundStyle(Color.ds(.textSecondary))
                .symbolEffect(.variableColor.iterative, isActive: true)
        }
    }

    private var accessibilityText: String {
        if message.state == .streaming, message.text.isEmpty {
            return String(localized: "Swiftlet is thinking")
        }
        let speaker = isUser ? String(localized: "You said") : String(localized: "Swiftlet said")
        return "\(speaker): \(message.text)"
    }
}
