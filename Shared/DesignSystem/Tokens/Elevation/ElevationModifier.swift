//
//  ElevationModifier.swift
//  Swiftlet
//

import SwiftUI

struct ElevationModifier: ViewModifier {
    let token: ElevationToken

    func body(content: Content) -> some View {
        if let shadow = token.shadow {
            content.shadow(color: Color.ds(.ink).opacity(shadow.opacity), radius: shadow.radius, y: shadow.y)
        } else {
            content
        }
    }
}

extension View {
    func dsElevation(_ token: ElevationToken) -> some View {
        modifier(ElevationModifier(token: token))
    }
}
