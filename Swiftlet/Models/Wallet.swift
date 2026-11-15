//
//  Wallet.swift
//  Swiftlet
//

import Foundation
import SwiftData

@Model
final class Wallet {
    var name: String = ""
    /// Legacy icon from before wallets used SF Symbols; read only to pick a fallback symbol.
    var emoji: String = "👛"
    var symbolName: String = ""
    var colorHex: String = "0A84FF"
    /// Asset-catalog logo for wallets migrated from a built-in `MoneySource`; empty for user-made ones.
    var logoAsset: String = ""
    var initialBalance: Decimal = 0
    var sortIndex: Int = 0
    var isArchived: Bool = false
    /// `MoneySource` raw value this wallet was migrated from, so legacy transactions can be linked.
    var legacySourceRaw: String = ""
    var createdAt: Date = Date.now

    @Relationship(deleteRule: .nullify, inverse: \Transaction.wallet)
    var transactions: [Transaction]? = []

    @Relationship(deleteRule: .nullify, inverse: \Transaction.destinationWallet)
    var incomingTransfers: [Transaction]? = []

    var recurringTransactions: [RecurringTransaction]? = []

    init(
        name: String,
        emoji: String = "👛",
        symbolName: String = "",
        colorHex: String = "0A84FF",
        logoAsset: String = "",
        initialBalance: Decimal = 0,
        sortIndex: Int = 0,
        legacySourceRaw: String = "",
        createdAt: Date = .now
    ) {
        self.name = name
        self.emoji = emoji
        self.symbolName = symbolName
        self.colorHex = colorHex
        self.logoAsset = logoAsset
        self.initialBalance = initialBalance
        self.sortIndex = sortIndex
        self.legacySourceRaw = legacySourceRaw
        self.createdAt = createdAt
    }

    var resolvedSymbolName: String {
        symbolName.isEmpty ? Self.symbol(forLegacyEmoji: emoji) : symbolName
    }

    static let defaultSymbolName = "wallet.bifold.fill"

    static let symbolChoices: [String] = [
        "wallet.bifold.fill", "banknote.fill", "creditcard.fill", "building.columns.fill", "iphone",
        "qrcode", "dollarsign.circle.fill", "chart.line.uptrend.xyaxis", "briefcase.fill", "house.fill",
        "giftcard.fill", "bag.fill", "cart.fill", "car.fill", "airplane",
        "person.2.fill", "graduationcap.fill", "heart.fill", "star.fill", "lock.fill",
    ]

    static func symbol(forLegacyEmoji emoji: String) -> String {
        switch emoji {
        case "💵", "💴", "💶", "💷", "💰", "💸": "banknote.fill"
        case "💳": "creditcard.fill"
        case "🏦", "🏛️": "building.columns.fill"
        case "📱", "📲": "iphone"
        case "🔳": "qrcode"
        case "🐷", "🪙": "dollarsign.circle.fill"
        case "📈": "chart.line.uptrend.xyaxis"
        case "💼": "briefcase.fill"
        case "🏠", "🏡": "house.fill"
        case "🎁": "giftcard.fill"
        default: defaultSymbolName
        }
    }

    var balance: Decimal {
        let outgoing = (transactions ?? []).reduce(Decimal(0)) { total, transaction in
            switch transaction.type {
            case .income: total + transaction.amount
            case .expense, .transfer: total - transaction.amount
            }
        }
        let incoming = (incomingTransfers ?? [])
            .filter { $0.type == .transfer }
            .reduce(Decimal(0)) { $0 + $1.amount }
        let recordedKeys = Set((transactions ?? []).compactMap { transaction -> String? in
            guard transaction.type == .income,
                  transaction.externalReference.hasPrefix(SplitReimbursement.referencePrefix) else { return nil }
            return String(transaction.externalReference.dropFirst(SplitReimbursement.referencePrefix.count))
        })
        let lentToOthers = (transactions ?? [])
            .compactMap(\.splitBill)
            .flatMap { $0.othersShares }
            .reduce(Decimal(0)) { total, share in
                let counted = recordedKeys.contains(share.key) ? share.amount : share.outstanding
                return total + Decimal(counted)
            }
        return initialBalance + outgoing + incoming - lentToOthers
    }
}
