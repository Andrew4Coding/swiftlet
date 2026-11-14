//
//  DSButton.swift
//  Swiftlet
//

import SwiftUI

struct DSButton: View {
    let title: LocalizedStringKey
    var systemImage: String?
    var variant: DSButtonVariant = .primary
    var size: DSButtonSize = .large
    var fillsWidth = true
    var role: ButtonRole?
    let action: () -> Void

    init(
        _ title: LocalizedStringKey,
        systemImage: String? = nil,
        variant: DSButtonVariant = .primary,
        size: DSButtonSize = .large,
        fillsWidth: Bool = true,
        role: ButtonRole? = nil,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.systemImage = systemImage
        self.variant = variant
        self.size = size
        self.fillsWidth = fillsWidth
        self.role = role
        self.action = action
    }

    var body: some View {
        Button(role: role, action: action) {
            if let systemImage {
                Label(title, systemImage: systemImage)
            } else {
                Text(title)
            }
        }
        .buttonStyle(.ds(variant, size: size, fillsWidth: fillsWidth))
    }
}

#Preview {
    VStack(spacing: 12) {
        DSButton("Next", systemImage: "arrow.right") {}
        DSButton("Secondary", variant: .secondary) {}
        DSButton("Tertiary", variant: .tertiary, size: .medium) {}
        DSButton("Delete", variant: .destructive, size: .small, fillsWidth: false) {}
        DSButton("Disabled") {}.disabled(true)
    }
    .padding()
}
