//
//  WalletCarousel.swift
//  Swiftlet
//

import SwiftUI

struct WalletCarousel: View {
    let wallets: [Wallet]
    let onAdd: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Wallets")
                    .font(.headline)
                Spacer()
                NavigationLink("See all") {
                    WalletsView()
                }
                .font(.subheadline)
            }
            .padding(.horizontal, 20)

            ScrollView(.horizontal) {
                HStack(spacing: 12) {
                    ForEach(wallets) { wallet in
                        card(for: wallet)
                    }
                    addCard
                }
                .scrollTargetLayout()
            }
            .scrollIndicators(.hidden)
            .scrollTargetBehavior(.viewAligned)
            .scrollClipDisabled()
        }
    }

    private func card(for wallet: Wallet) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            WalletBadgeView(wallet: wallet, size: 34)
            VStack(alignment: .leading, spacing: 2) {
                Text(wallet.name)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Text(CurrencyFormatter.rupiah(wallet.balance))
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .foregroundStyle(wallet.balance < 0 ? AppTheme.expense : .primary)
            }
        }
        .frame(width: 140, alignment: .leading)
        .padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(alignment: .topTrailing) {
            Circle()
                .fill(Color(hex: wallet.colorHex).opacity(0.25))
                .frame(width: 60, height: 60)
                .blur(radius: 20)
                .offset(x: 10, y: -10)
                .allowsHitTesting(false)
        }
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private var addCard: some View {
        Button(action: onAdd) {
            VStack(spacing: 8) {
                Image(systemName: "plus")
                    .font(.title3.weight(.semibold))
                Text("Add wallet")
                    .font(.caption.weight(.medium))
            }
            .foregroundStyle(Color.accentColor)
            .frame(width: 100, height: 100)
            .padding(.vertical, 2)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(Color.accentColor.opacity(0.4), style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
            )
        }
        .buttonStyle(.plain)
    }
}
