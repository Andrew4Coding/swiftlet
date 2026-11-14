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

/// Flat coloured circle with an emoji or SF Symbol on top, shared by categories and wallets.
struct IconBadge: View {
    let iconType: CategoryIconType
    let iconValue: String
    let colorHex: String
    var size: CGFloat = 44

    private var color: Color {
        Color(hex: colorHex)
    }

    private var symbolColor: Color {
        let hex = colorHex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        guard hex.count == 6, let value = UInt32(hex, radix: 16) else { return .white }
        func channel(_ shift: UInt32) -> Double {
            let c = Double((value >> shift) & 0xFF) / 255
            return c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
        }
        let luminance = 0.2126 * channel(16) + 0.7152 * channel(8) + 0.0722 * channel(0)
        return luminance > 0.35 ? Color.ds(.onAccent) : .white
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(iconType == .emoji ? color.opacity(0.2) : color)

            switch iconType {
            case .emoji:
                Text(iconValue)
                    .font(.system(size: size * 0.5))
            case .system:
                Image(systemName: iconValue)
                    .font(.system(size: size * 0.42, weight: .semibold))
                    .foregroundStyle(symbolColor)
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
