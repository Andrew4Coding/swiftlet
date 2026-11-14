//
//  ColorToken.swift
//  Swiftlet
//

import SwiftUI

/// Semantic colours. Backgrounds and text follow the system so lists, sheets and
/// Increase Contrast keep working; the brand shows up through the mint accent and ink.
enum ColorToken: CaseIterable {
    case canvas
    case surface
    case surfaceMuted
    case border

    case textPrimary
    case textSecondary
    case textTertiary

    /// Mint for text, icons and tint. Dark enough on white to pass 4.5:1.
    case accent
    /// The icon's mint, for filled controls. Always paired with `onAccent`.
    case accentFill
    case onAccent
    case accentSubtle

    case ink

    case income
    case expense
    case expenseSubtle
    case warning

    var color: Color {
        switch self {
        case .canvas: Self.system(.canvas)
        case .surface: Self.system(.surface)
        case .surfaceMuted: Self.system(.surfaceMuted)
        case .border: Self.system(.border)
        case .textPrimary: .primary
        case .textSecondary: .secondary
        case .textTertiary: Self.system(.tertiaryLabel)
        case .accent: ColorPalette.adaptive(light: ColorPalette.mint700, dark: ColorPalette.mint400)
        case .accentFill: Color(hex: ColorPalette.mint400)
        case .onAccent: Color(hex: ColorPalette.ink900)
        case .accentSubtle: ColorPalette.adaptive(light: ColorPalette.mint50, dark: ColorPalette.mint900)
        case .ink: Color(hex: ColorPalette.ink900)
        case .income: ColorPalette.adaptive(light: ColorPalette.mint700, dark: ColorPalette.mint400)
        case .expense: ColorPalette.adaptive(light: ColorPalette.red600, dark: ColorPalette.red400)
        case .expenseSubtle: ColorPalette.adaptive(light: "FEF0EE", dark: "3A1A17")
        case .warning: ColorPalette.adaptive(light: ColorPalette.amber700, dark: ColorPalette.amber400)
        }
    }

    private enum SystemRole {
        case canvas, surface, surfaceMuted, border, tertiaryLabel
    }

    private static func system(_ role: SystemRole) -> Color {
        #if os(iOS)
        switch role {
        case .canvas: Color(.systemGroupedBackground)
        case .surface: Color(.secondarySystemGroupedBackground)
        case .surfaceMuted: Color(.tertiarySystemFill)
        case .border: Color(.separator)
        case .tertiaryLabel: Color(.tertiaryLabel)
        }
        #else
        switch role {
        case .canvas: Color(nsColor: .windowBackgroundColor)
        case .surface: Color(nsColor: .controlBackgroundColor)
        case .surfaceMuted: Color(nsColor: .quaternaryLabelColor)
        case .border: Color(nsColor: .separatorColor)
        case .tertiaryLabel: Color(nsColor: .tertiaryLabelColor)
        }
        #endif
    }
}

extension Color {
    static func ds(_ token: ColorToken) -> Color {
        token.color
    }
}

extension ShapeStyle where Self == Color {
    static func ds(_ token: ColorToken) -> Color {
        token.color
    }
}
