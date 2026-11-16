//
//  WalletMigrator.swift
//  Swiftlet
//

import Foundation
import SwiftData

/// Moves transactions recorded against the old fixed `MoneySource` list onto real `Wallet`s.
/// Idempotent — safe to run on every launch and foreground, which also catches transactions that
/// arrive later through CloudKit sync.
enum WalletMigrator {
    static let defaultWalletName = "Main Wallet"

    @MainActor
    static func run(context: ModelContext) {
        mergeDuplicates(context: context)
        linkLegacyTransactions(context: context)
    }

    /// Wallets are created lazily rather than seeded at launch: seeding before CloudKit finishes
    /// its first sync would duplicate wallets that already exist on another device.
    @MainActor
    static func ensureDefaultWallet(context: ModelContext) -> Wallet {
        let wallets = activeWallets(context: context)
        if let first = wallets.first {
            return first
        }
        let wallet = Wallet(name: defaultWalletName, emoji: "👛", colorHex: "0A84FF")
        context.insert(wallet)
        try? context.save()
        return wallet
    }

    @MainActor
    static func activeWallets(context: ModelContext) -> [Wallet] {
        let descriptor = FetchDescriptor<Wallet>(sortBy: [SortDescriptor(\.sortIndex), SortDescriptor(\.createdAt)])
        return ((try? context.fetch(descriptor)) ?? []).filter { !$0.isArchived }
    }

    @MainActor
    private static func linkLegacyTransactions(context: ModelContext) {
        let unlinked = (try? context.fetch(FetchDescriptor<Transaction>(predicate: #Predicate { $0.wallet == nil }))) ?? []
        guard !unlinked.isEmpty else { return }

        var wallets = (try? context.fetch(FetchDescriptor<Wallet>())) ?? []
        var nextIndex = (wallets.map(\.sortIndex).max() ?? -1) + 1

        for transaction in unlinked {
            let source = transaction.source
            let wallet: Wallet
            if let existing = wallets.first(where: { $0.legacySourceRaw == source.rawValue }) {
                wallet = existing
            } else {
                wallet = Wallet(
                    name: source.displayName,
                    emoji: source.fallbackEmoji,
                    colorHex: source.walletColorHex,
                    logoAsset: source.imageName ?? "",
                    sortIndex: nextIndex,
                    legacySourceRaw: source.rawValue
                )
                context.insert(wallet)
                wallets.append(wallet)
                nextIndex += 1
            }
            transaction.wallet = wallet
        }

        try? context.save()
    }

    @MainActor
    private static func mergeDuplicates(context: ModelContext) {
        guard let all = try? context.fetch(FetchDescriptor<Wallet>()), all.count > 1 else { return }

        let groups = Dictionary(grouping: all) { wallet in
            wallet.legacySourceRaw.isEmpty ? "name:\(wallet.name.lowercased())" : "legacy:\(wallet.legacySourceRaw)"
        }

        var didDelete = false
        for group in groups.values where group.count > 1 {
            let sorted = group.sorted { $0.createdAt < $1.createdAt }
            guard let keeper = sorted.first else { continue }
            for duplicate in sorted.dropFirst() {
                for transaction in duplicate.transactions ?? [] {
                    transaction.wallet = keeper
                }
                for transaction in duplicate.incomingTransfers ?? [] {
                    transaction.destinationWallet = keeper
                }
                keeper.initialBalance = max(keeper.initialBalance, duplicate.initialBalance)
                context.delete(duplicate)
                didDelete = true
            }
        }

        if didDelete {
            try? context.save()
        }
    }
}

private extension MoneySource {
    var fallbackEmoji: String {
        switch self {
        case .qris: "🔳"
        case .grab, .gopay, .ovo: "📱"
        case .bca, .bni: "🏦"
        }
    }

    /// GoPay's brand colour is white, which disappears on a light badge.
    var walletColorHex: String {
        self == .gopay ? "00AED6" : colorHex
    }
}
