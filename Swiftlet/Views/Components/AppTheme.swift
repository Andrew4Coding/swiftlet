//
//  AppTheme.swift
//  Swiftlet
//

import SwiftUI

enum AppTheme {
    static let accent = Color(hex: "0A84FF")
    static let categoryColor = accent

    static let income = Color(hex: "34C759")
    static let expense = Color(hex: "FF3B30")

    static let cornerRadius: CGFloat = 24

    /// Swatches offered in the category and wallet editors, in the order they are shown.
    static let palette: [String] = [
        "FF3B30", "FF9500", "D4C41A", "34C759", "00C7BE",
        "0A84FF", "3634E0", "C644FC", "FF2D78",
    ]

    static func paletteHex(at index: Int) -> String {
        palette[((index % palette.count) + palette.count) % palette.count]
    }

    static var skyGradient: LinearGradient {
        LinearGradient(
            colors: [Color(hex: "BFDDF7"), Color(hex: "E6F1FB"), Color(.systemGroupedBackground)],
            startPoint: .top,
            endPoint: .center
        )
    }
}

struct SkyBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Group {
            if colorScheme == .dark {
                LinearGradient(
                    colors: [Color(hex: "0B2A4A"), Color(.systemBackground)],
                    startPoint: .top,
                    endPoint: .center
                )
            } else {
                AppTheme.skyGradient
            }
        }
        .ignoresSafeArea()
    }
}

struct CardBackground: ViewModifier {
    var padding: CGFloat = 20

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: AppTheme.cornerRadius, style: .continuous))
    }
}

extension View {
    func card(padding: CGFloat = 20) -> some View {
        modifier(CardBackground(padding: padding))
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
