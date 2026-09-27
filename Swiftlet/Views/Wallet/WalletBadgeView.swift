//
//  WalletBadgeView.swift
//  Swiftlet
//

import SwiftUI

struct WalletBadgeView: View {
    let wallet: Wallet?
    var size: CGFloat = 44

    var body: some View {
        if let wallet, !wallet.logoAsset.isEmpty {
            Image(wallet.logoAsset)
                .resizable()
                .scaledToFit()
                .padding(size * 0.18)
                .frame(width: size, height: size)
                .background(.white, in: Circle())
                .overlay(Circle().strokeBorder(Color(hex: wallet.colorHex).opacity(0.4), lineWidth: 1.5))
                .shadow(color: Color(hex: wallet.colorHex).opacity(0.25), radius: size * 0.1, y: size * 0.05)
                .accessibilityHidden(true)
        } else {
            IconBadge(
                iconType: .emoji,
                iconValue: wallet?.emoji ?? "👛",
                colorHex: wallet?.colorHex ?? "8E8E93",
                size: size
            )
        }
    }
}

/// Compact capsule naming the wallet a transaction used, shown under transaction titles.
struct WalletChip: View {
    let transaction: Transaction

    var body: some View {
        HStack(spacing: 4) {
            WalletBadgeView(wallet: transaction.wallet, size: 14)
            Text(label)
                .lineLimit(1)
        }
        .font(.caption2.weight(.semibold))
        .foregroundStyle(.secondary)
        .padding(.leading, 3)
        .padding(.trailing, 8)
        .padding(.vertical, 3)
        .background(Color(.tertiarySystemFill), in: Capsule())
    }

    private var label: String {
        if transaction.type == .transfer, let destination = transaction.destinationWallet {
            return "\(transaction.walletName) → \(destination.name)"
        }
        return transaction.walletName
    }
}

#Preview {
    HStack {
        WalletBadgeView(wallet: Wallet(name: "BCA", colorHex: "0066AE", logoAsset: "bca"))
        WalletBadgeView(wallet: Wallet(name: "Cash", emoji: "💵", colorHex: "34C759"))
        WalletBadgeView(wallet: nil)
    }
    .padding()
}
