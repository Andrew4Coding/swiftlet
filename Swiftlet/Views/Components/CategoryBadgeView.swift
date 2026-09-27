//
//  CategoryBadgeView.swift
//  Swiftlet
//

import SwiftUI

struct CategoryBadgeView: View {
    let category: TransactionCategory?
    var size: CGFloat = 44

    var body: some View {
        if let category {
            IconBadge(
                iconType: category.iconType,
                iconValue: category.iconValue,
                colorHex: category.resolvedColorHex,
                size: size
            )
        } else {
            IconBadge(iconType: .system, iconValue: "questionmark", colorHex: "8E8E93", size: size)
        }
    }
}

/// Glossy coloured orb with an emoji or SF Symbol on top, shared by categories and wallets.
struct IconBadge: View {
    let iconType: CategoryIconType
    let iconValue: String
    let colorHex: String
    var size: CGFloat = 44

    private var color: Color {
        Color(hex: colorHex)
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [color.mix(with: .white, by: 0.35), color],
                        center: UnitPoint(x: 0.3, y: 0.25),
                        startRadius: 0,
                        endRadius: size * 0.75
                    )
                )
                .overlay(
                    Circle()
                        .strokeBorder(.white.opacity(0.35), lineWidth: max(1, size * 0.03))
                )
                .shadow(color: color.opacity(0.35), radius: size * 0.12, y: size * 0.06)

            switch iconType {
            case .emoji:
                Text(iconValue)
                    .font(.system(size: size * 0.5))
                    .shadow(color: .black.opacity(0.15), radius: 1, y: 1)
            case .system:
                Image(systemName: iconValue)
                    .font(.system(size: size * 0.42, weight: .semibold))
                    .foregroundStyle(.white)
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

#Preview {
    HStack(spacing: 16) {
        CategoryBadgeView(category: TransactionCategory(name: "Food", iconType: .emoji, iconValue: "🍜", colorHex: "FF3B30"))
        CategoryBadgeView(category: TransactionCategory(name: "Travel", iconType: .emoji, iconValue: "🧳", colorHex: "00C7BE"))
        CategoryBadgeView(category: TransactionCategory(name: "Salary", iconType: .system, iconValue: "banknote.fill"))
        CategoryBadgeView(category: nil)
    }
    .padding()
}
