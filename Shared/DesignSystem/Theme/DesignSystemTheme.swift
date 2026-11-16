//
//  DesignSystemTheme.swift
//  Swiftlet
//

import SwiftUI

struct DesignSystemTheme {
    struct Radii {
        var small: CGFloat = 10
        var medium: CGFloat = 16
        var large: CGFloat = 24
    }

    struct Spacing {
        var xxs: CGFloat = 4
        var xs: CGFloat = 8
        var sm: CGFloat = 12
        var md: CGFloat = 16
        var lg: CGFloat = 20
        var xl: CGFloat = 24
        var xxl: CGFloat = 32
    }

    var radii = Radii()
    var spacing = Spacing()
    var tint: ColorToken = .accent
    var surfaceElevation: ElevationToken = .raised

    func color(_ token: ColorToken) -> Color {
        token.color
    }

    static let mintInk = DesignSystemTheme()
}
