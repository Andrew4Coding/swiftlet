//
//  Environment+Theme.swift
//  Swiftlet
//

import SwiftUI

extension EnvironmentValues {
    @Entry var dsTheme: DesignSystemTheme = .mintInk
}

extension View {
    func designSystemTheme(_ theme: DesignSystemTheme = .mintInk) -> some View {
        environment(\.dsTheme, theme)
            .tint(theme.color(theme.tint))
    }
}
