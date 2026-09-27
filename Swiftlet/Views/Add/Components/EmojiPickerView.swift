//
//  EmojiPickerView.swift
//  Swiftlet
//

import SwiftUI

struct EmojiPickerView: View {
    @Binding var selection: String
    let tintHex: String

    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var pending: String

    private let columns = [GridItem(.adaptive(minimum: 40), spacing: 6)]

    init(selection: Binding<String>, tintHex: String) {
        _selection = selection
        self.tintHex = tintHex
        _pending = State(initialValue: selection.wrappedValue)
    }

    var body: some View {
        ScrollView {
            if query.isEmpty {
                LazyVGrid(columns: columns, spacing: 6, pinnedViews: .sectionHeaders) {
                    ForEach(EmojiCatalog.sections) { section in
                        Section {
                            ForEach(section.entries) { cell(for: $0.emoji) }
                        } header: {
                            sectionHeader(section.title)
                        }
                    }
                }
                .padding(.horizontal)
            } else {
                let results = EmojiCatalog.search(query)
                if results.isEmpty {
                    ContentUnavailableView.search(text: query)
                        .padding(.top, 40)
                } else {
                    LazyVGrid(columns: columns, spacing: 6) {
                        ForEach(results) { cell(for: $0.emoji) }
                    }
                    .padding(.horizontal)
                }
            }
        }
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search")
        .safeAreaInset(edge: .bottom) {
            Button {
                selection = pending
                dismiss()
            } label: {
                Text("Done")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
            }
            .buttonStyle(.glassProminent)
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
        .navigationTitle("Select Emoji")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.footnote.weight(.semibold))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 6)
            .background(.background)
    }

    private func cell(for emoji: String) -> some View {
        let isSelected = pending == emoji
        return Button {
            pending = emoji
        } label: {
            Text(emoji)
                .font(.system(size: 28))
                .frame(width: 44, height: 44)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(isSelected ? Color(hex: tintHex).opacity(0.25) : .clear)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(isSelected ? Color(hex: tintHex) : .clear, lineWidth: 2)
                )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

#Preview {
    @Previewable @State var emoji = "🍜"
    NavigationStack {
        EmojiPickerView(selection: $emoji, tintHex: "FF3B30")
    }
}
