//
//  WalletMenuRow.swift
//  Swiftlet
//

import SwiftData
import SwiftUI

struct WalletMenuRow: View {
    let title: String
    @Binding var selection: Wallet?
    let wallets: [Wallet]
    var excluding: Wallet?
    var onCreateNew: () -> Void = {}

    private var options: [Wallet] {
        wallets.filter { $0.persistentModelID != excluding?.persistentModelID }
    }

    var body: some View {
        HStack {
            Text(title)
                .foregroundStyle(.secondary)
            Spacer()
            Menu {
                ForEach(options) { wallet in
                    Button {
                        selection = wallet
                    } label: {
                        Text(wallet.name)
                        Text(CurrencyFormatter.rupiah(wallet.balance))
                        if wallet.persistentModelID == selection?.persistentModelID {
                            Image(systemName: "checkmark")
                        }
                    }
                }
                Divider()
                Button("New Wallet", systemImage: "plus", action: onCreateNew)
            } label: {
                HStack(spacing: 6) {
                    WalletBadgeView(wallet: selection, size: 22)
                    Text(selection?.name ?? "Choose wallet")
                        .foregroundStyle(.primary)
                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .tint(.primary)
        }
        .font(.subheadline)
    }
}
