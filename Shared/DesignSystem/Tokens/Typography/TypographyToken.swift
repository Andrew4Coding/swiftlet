//
//  TypographyToken.swift
//  Swiftlet
//

import SwiftUI

/// Type scale. Every size is anchored to a system text style so it grows with Dynamic Type.
enum TypographyToken: CaseIterable {
    case amountDisplay
    case amountLarge
    case title
    case title3
    case headline
    case body
    case bodyEmphasized
    case subheadline
    case subheadlineEmphasized
    case footnote
    case caption
    case captionEmphasized

    struct Spec {
        let size: CGFloat
        let relativeTo: Font.TextStyle
        let weight: Font.Weight
        var design: Font.Design = .default
        var monospacedDigits = false
    }

    var spec: Spec {
        switch self {
        case .amountDisplay: Spec(size: 52, relativeTo: .largeTitle, weight: .bold, design: .rounded, monospacedDigits: true)
        case .amountLarge: Spec(size: 34, relativeTo: .largeTitle, weight: .bold, design: .rounded, monospacedDigits: true)
        case .title: Spec(size: 28, relativeTo: .title, weight: .bold, design: .rounded)
        case .title3: Spec(size: 20, relativeTo: .title3, weight: .semibold)
        case .headline: Spec(size: 17, relativeTo: .headline, weight: .semibold)
        case .body: Spec(size: 17, relativeTo: .body, weight: .regular)
        case .bodyEmphasized: Spec(size: 17, relativeTo: .body, weight: .semibold)
        case .subheadline: Spec(size: 15, relativeTo: .subheadline, weight: .regular)
        case .subheadlineEmphasized: Spec(size: 15, relativeTo: .subheadline, weight: .semibold)
        case .footnote: Spec(size: 13, relativeTo: .footnote, weight: .regular)
        case .caption: Spec(size: 12, relativeTo: .caption, weight: .regular)
        case .captionEmphasized: Spec(size: 12, relativeTo: .caption, weight: .semibold)
        }
    }

    /// Scales with Dynamic Type through the matching text style. Use `.dsTextStyle(_:)`
    /// when the exact pixel size matters (e.g. the amount display).
    var font: Font {
        let font = Font.system(spec.relativeTo, design: spec.design, weight: spec.weight)
        return spec.monospacedDigits ? font.monospacedDigit() : font
    }
}
