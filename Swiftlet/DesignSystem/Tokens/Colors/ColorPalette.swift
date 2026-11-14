//
//  ColorPalette.swift
//  Swiftlet
//

import SwiftUI

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

/// Raw brand colours taken from the app icon: mint lenses on an ink tile.
/// Views never use these directly; they go through `ColorToken`.
enum ColorPalette {
    static let mint50 = "EEFCF5"
    static let mint100 = "D3F8E6"
    static let mint200 = "A9F1CE"
    static let mint400 = "5EEAA8"
    static let mint600 = "1FA971"
    static let mint700 = "0B7A50"
    static let mint900 = "0A3D2A"

    static let ink900 = "111827"
    static let ink800 = "1F2937"
    static let ink700 = "374151"
    static let ink500 = "6B7280"
    static let ink400 = "9CA3AF"
    static let ink200 = "E5E7EB"
    static let ink50 = "F9FAFB"

    static let red600 = "D92D20"
    static let red400 = "FF6B5E"
    static let amber700 = "B45309"
    static let amber400 = "FBBF24"

    static func adaptive(light: String, dark: String) -> Color {
        #if os(iOS)
        Color(UIColor { traits in
            UIColor(Color(hex: traits.userInterfaceStyle == .dark ? dark : light))
        })
        #elseif os(macOS)
        Color(NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            return NSColor(Color(hex: isDark ? dark : light))
        })
        #endif
    }
}
