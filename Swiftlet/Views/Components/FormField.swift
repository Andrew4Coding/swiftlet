//
//  FormField.swift
//  Swiftlet
//

import SwiftUI

struct FormField<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.medium))
            content
        }
    }
}

struct FieldBoxStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 14)
            .frame(minHeight: 48)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color(.separator).opacity(0.5), lineWidth: 1)
            )
    }
}

extension View {
    func fieldBox() -> some View {
        modifier(FieldBoxStyle())
    }
}

/// Dropdown-looking field backed by a `Menu`, matching the text fields around it.
struct MenuField<Value: Hashable & Identifiable>: View {
    let placeholder: String
    @Binding var selection: Value?
    let options: [Value]
    let label: (Value) -> String
    var allowsNone = false

    var body: some View {
        Menu {
            if allowsNone {
                Button("None") { selection = nil }
            }
            ForEach(options) { option in
                Button {
                    selection = option
                } label: {
                    if option == selection {
                        Label(label(option), systemImage: "checkmark")
                    } else {
                        Text(label(option))
                    }
                }
            }
        } label: {
            HStack {
                Text(selection.map(label) ?? placeholder)
                    .foregroundStyle(selection == nil ? .secondary : .primary)
                Spacer()
                Image(systemName: "chevron.down")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .contentShape(Rectangle())
            .fieldBox()
        }
        .buttonStyle(.plain)
    }
}

struct ColorSwatchRow: View {
    @Binding var selectionHex: String

    var body: some View {
        HStack(spacing: 0) {
            ForEach(AppTheme.palette, id: \.self) { hex in
                let isSelected = hex.caseInsensitiveCompare(selectionHex) == .orderedSame
                Button {
                    selectionHex = hex
                } label: {
                    Circle()
                        .fill(Color(hex: hex).gradient)
                        .frame(width: 28, height: 28)
                        .padding(3)
                        .overlay(
                            Circle().strokeBorder(isSelected ? Color(hex: hex) : .clear, lineWidth: 2)
                        )
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Color \(hex)")
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
    }
}

struct PrimaryActionButton: View {
    let title: String
    var isEnabled = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
        }
        .buttonStyle(.glassProminent)
        .disabled(!isEnabled)
    }
}
