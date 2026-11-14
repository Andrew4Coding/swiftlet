//
//  DSSurface.swift
//  Swiftlet
//

import SwiftUI

struct DSSurface<Content: View>: View {
    var padding: CGFloat = 20
    var elevation: ElevationToken = .raised
    var fill: ColorToken = .surface
    @ViewBuilder var content: Content

    var body: some View {
        content.dsSurface(padding: padding, elevation: elevation, fill: fill)
    }
}

struct DSSurfaceModifier: ViewModifier {
    var padding: CGFloat
    var elevation: ElevationToken
    var fill: ColorToken

    @Environment(\.dsTheme) private var theme

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: theme.radii.large, style: .continuous)
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(fill.color, in: shape)
            .overlay {
                if elevation.showsBorder {
                    shape.strokeBorder(Color.ds(.border).opacity(0.6), lineWidth: 0.5)
                }
            }
            .dsElevation(elevation)
    }
}

extension View {
    func dsSurface(padding: CGFloat = 20, elevation: ElevationToken = .raised, fill: ColorToken = .surface) -> some View {
        modifier(DSSurfaceModifier(padding: padding, elevation: elevation, fill: fill))
    }
}

#Preview {
    VStack(spacing: 16) {
        DSSurface {
            Text("Raised surface").dsTextStyle(.headline)
        }
        DSSurface(elevation: .floating) {
            Text("Floating surface").dsTextStyle(.headline)
        }
    }
    .padding()
    .background(Color.ds(.canvas))
}
