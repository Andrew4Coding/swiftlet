//
//  ComponentStubs.swift
//  Swiftlet
//

import SwiftUI

/// Components that will be mapped to Figma nodes. Until a Figma file is linked, `figmaNode`
/// holds the component name to look for, and the views are working but minimal.
protocol FigmaMappedComponent {
    static var figmaNode: String { get }
}

struct DSSectionHeader<Trailing: View>: View, FigmaMappedComponent {
    static var figmaNode: String { "Section Header" }

    let title: LocalizedStringKey
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack {
            Text(title)
                .dsTextStyle(.headline)
                .accessibilityAddTraits(.isHeader)
            Spacer()
            trailing
                .font(TypographyToken.subheadline.font)
        }
    }
}

extension DSSectionHeader where Trailing == EmptyView {
    init(_ title: LocalizedStringKey) {
        self.title = title
        trailing = EmptyView()
    }
}

struct DSChip<Leading: View>: View, FigmaMappedComponent {
    static var figmaNode: String { "Chip" }

    let title: String
    var isPlaceholder = false
    var showsDisclosure = true
    @ViewBuilder var leading: Leading

    var body: some View {
        HStack(spacing: 6) {
            leading
            Text(title)
                .dsTextStyle(.subheadlineEmphasized, color: isPlaceholder ? .textSecondary : .textPrimary)
            if showsDisclosure {
                Image(systemName: "chevron.down")
                    .font(TypographyToken.captionEmphasized.font)
                    .foregroundStyle(.ds(.textSecondary))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(Color.ds(.surfaceMuted), in: Capsule())
    }
}

extension DSChip where Leading == EmptyView {
    init(_ title: String, isPlaceholder: Bool = false, showsDisclosure: Bool = true) {
        self.title = title
        self.isPlaceholder = isPlaceholder
        self.showsDisclosure = showsDisclosure
        leading = EmptyView()
    }
}

struct DSIconCircle: View, FigmaMappedComponent {
    static var figmaNode: String { "Icon Circle" }

    let systemImage: String
    var tint: ColorToken = .accent
    var size: CGFloat = 28

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: size * 0.45, weight: .bold))
            .foregroundStyle(tint.color)
            .frame(width: size, height: size)
            .background(tint.color.opacity(0.14), in: Circle())
            .accessibilityHidden(true)
    }
}

struct DSAmountText: View, FigmaMappedComponent {
    static var figmaNode: String { "Amount" }

    let text: String
    var token: TypographyToken = .amountLarge
    var color: ColorToken = .textPrimary

    var body: some View {
        Text(text)
            .dsTextStyle(token, color: color)
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .contentTransition(.numericText())
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 16) {
        DSSectionHeader(title: "Wallets") { Button("See all") {} }
        DSChip("Select category", isPlaceholder: true)
        DSIconCircle(systemImage: "arrow.down.left")
        DSAmountText(text: "Rp 12.129.910")
    }
    .padding()
}
