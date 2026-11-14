import SwiftUI

struct ChatSuggestionStrip: View {
    let isEnabled: Bool
    let onSelect: (String) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(ChatSuggestions.prompts, id: \.self) { prompt in
                    Button { onSelect(prompt) } label: {
                        Text(LocalizedStringKey(prompt))
                            .dsTextStyle(.subheadlineEmphasized)
                            .padding(.horizontal, 14)
                            .frame(minHeight: 44)
                            .background(Color.ds(.surfaceMuted), in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .disabled(!isEnabled)
                }
            }
            .padding(.horizontal, 16)
        }
        .scrollClipDisabled()
    }
}
