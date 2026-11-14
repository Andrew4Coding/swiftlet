//
//  AppTheme.swift
//  Swiftlet
//

import SwiftUI

enum AppTheme {
    static var accent: Color { ColorToken.accent.color }

    static var income: Color { ColorToken.income.color }
    static var expense: Color { ColorToken.expense.color }

    static let cornerRadius: CGFloat = 24

    /// Swatches offered in the category and wallet editors, in the order they are shown.
    static let palette: [String] = [
        "FF3B30", "FF9500", "D4C41A", "34C759", "00C7BE",
        "0A84FF", "3634E0", "C644FC", "FF2D78",
    ]

    static func paletteHex(at index: Int) -> String {
        palette[((index % palette.count) + palette.count) % palette.count]
    }
}

extension Color {
    /// Creates a color from a hex string like "FF9500" or "#FF9500".
    init(hex: String) {
        var hexString = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexString = hexString.replacingOccurrences(of: "#", with: "")

        var rgbValue: UInt64 = 0
        Scanner(string: hexString).scanHexInt64(&rgbValue)

        let r = Double((rgbValue & 0xFF0000) >> 16) / 255
        let g = Double((rgbValue & 0x00FF00) >> 8) / 255
        let b = Double(rgbValue & 0x0000FF) / 255

        self.init(red: r, green: g, blue: b)
    }
}
