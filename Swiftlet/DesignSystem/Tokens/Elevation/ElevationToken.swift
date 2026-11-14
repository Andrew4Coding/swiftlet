//
//  ElevationToken.swift
//  Swiftlet
//

import SwiftUI

/// The UI is plain, so most surfaces sit flat and separate with a hairline.
/// Shadows are reserved for things that float over content.
enum ElevationToken: CaseIterable {
    case flat
    case raised
    case floating
    case overlay

    struct Shadow {
        let opacity: Double
        let radius: CGFloat
        let y: CGFloat
    }

    var shadow: Shadow? {
        switch self {
        case .flat, .raised: nil
        case .floating: Shadow(opacity: 0.08, radius: 10, y: 4)
        case .overlay: Shadow(opacity: 0.16, radius: 24, y: 10)
        }
    }

    var showsBorder: Bool {
        self == .raised
    }
}
