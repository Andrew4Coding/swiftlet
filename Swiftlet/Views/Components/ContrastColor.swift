//
//  ContrastColor.swift
//  Swiftlet
//

import SwiftUI

enum ContrastColor {
    static func foreground(onHex hexString: String) -> Color {
        let hex = hexString.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        guard hex.count == 6, let value = UInt32(hex, radix: 16) else { return .white }
        func channel(_ shift: UInt32) -> Double {
            let c = Double((value >> shift) & 0xFF) / 255
            return c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
        }
        let luminance = 0.2126 * channel(16) + 0.7152 * channel(8) + 0.0722 * channel(0)
        return luminance > 0.35 ? Color.ds(.onAccent) : .white
    }
}

extension Image {
    static func swipeIcon(_ systemName: String, color: Color = Color.ds(.onAccent)) -> Image {
        guard let image = UIImage(systemName: systemName)?
            .withTintColor(UIColor(color), renderingMode: .alwaysOriginal)
        else { return Image(systemName: systemName) }
        return Image(uiImage: image)
    }
}
