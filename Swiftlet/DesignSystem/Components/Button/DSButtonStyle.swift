//
//  DSButtonStyle.swift
//  Swiftlet
//

import SwiftUI

enum DSButtonVariant {
    case primary
    case secondary
    case tertiary
    case destructive

    var background: ColorToken {
        switch self {
        case .primary: .accentFill
        case .secondary: .accentSubtle
        case .tertiary: .surfaceMuted
        case .destructive: .expenseSubtle
        }
    }

    var foreground: ColorToken {
        switch self {
        case .primary: .onAccent
        case .secondary: .accent
        case .tertiary: .textPrimary
        case .destructive: .expense
        }
    }
}

enum DSButtonSize {
    case small
    case medium
    case large

    var height: CGFloat {
        switch self {
        case .small: 36
        case .medium: 44
        case .large: 52
        }
    }

    var typography: TypographyToken {
        switch self {
        case .small: .subheadlineEmphasized
        case .medium, .large: .headline
        }
    }

    var horizontalPadding: CGFloat {
        switch self {
        case .small: 14
        case .medium: 18
        case .large: 22
        }
    }
}

struct DSButtonStyle: ButtonStyle {
    var variant: DSButtonVariant = .primary
    var size: DSButtonSize = .large
    var fillsWidth = true

    func makeBody(configuration: Configuration) -> some View {
        DSButtonBody(configuration: configuration, variant: variant, size: size, fillsWidth: fillsWidth)
    }
}

private struct DSButtonBody: View {
    let configuration: ButtonStyleConfiguration
    let variant: DSButtonVariant
    let size: DSButtonSize
    let fillsWidth: Bool

    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric private var height: CGFloat

    init(configuration: ButtonStyleConfiguration, variant: DSButtonVariant, size: DSButtonSize, fillsWidth: Bool) {
        self.configuration = configuration
        self.variant = variant
        self.size = size
        self.fillsWidth = fillsWidth
        _height = ScaledMetric(wrappedValue: size.height, relativeTo: .body)
    }

    var body: some View {
        configuration.label
            .font(size.typography.font)
            .foregroundStyle(variant.foreground.color)
            .lineLimit(dynamicTypeSize.isAccessibilitySize ? 3 : 1)
            .multilineTextAlignment(.center)
            .padding(.horizontal, size.horizontalPadding)
            .padding(.vertical, dynamicTypeSize.isAccessibilitySize ? 10 : 0)
            .frame(maxWidth: fillsWidth ? .infinity : nil)
            .frame(minHeight: height)
            .background(variant.background.color, in: Capsule())
            .contentShape(Capsule())
            .opacity(isEnabled ? (configuration.isPressed ? 0.8 : 1) : 0.45)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.snappy(duration: 0.15), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == DSButtonStyle {
    static func ds(_ variant: DSButtonVariant = .primary, size: DSButtonSize = .large, fillsWidth: Bool = true) -> DSButtonStyle {
        DSButtonStyle(variant: variant, size: size, fillsWidth: fillsWidth)
    }
}
