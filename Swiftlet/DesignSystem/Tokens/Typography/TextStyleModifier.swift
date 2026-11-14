//
//  TextStyleModifier.swift
//  Swiftlet
//

import SwiftUI

struct TextStyleModifier: ViewModifier {
    let token: TypographyToken
    let color: ColorToken?

    @ScaledMetric private var size: CGFloat

    init(token: TypographyToken, color: ColorToken?) {
        self.token = token
        self.color = color
        _size = ScaledMetric(wrappedValue: token.spec.size, relativeTo: token.spec.relativeTo)
    }

    func body(content: Content) -> some View {
        let spec = token.spec
        let font = Font.system(size: size, weight: spec.weight, design: spec.design)
        content
            .font(spec.monospacedDigits ? font.monospacedDigit() : font)
            .foregroundStyle(color?.color ?? .primary)
    }
}

extension View {
    func dsTextStyle(_ token: TypographyToken, color: ColorToken? = nil) -> some View {
        modifier(TextStyleModifier(token: token, color: color))
    }
}
