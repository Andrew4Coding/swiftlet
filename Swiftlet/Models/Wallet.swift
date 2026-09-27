//
//  Wallet.swift
//  Swiftlet
//

import Foundation
import SwiftData

@Model
final class Wallet {
    var name: String = ""
    var emoji: String = "👛"
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
        colorHex: String = "0A84FF",
        logoAsset: String = "",
        initialBalance: Decimal = 0,
        sortIndex: Int = 0,
        legacySourceRaw: String = "",
        createdAt: Date = .now
    ) {
        self.name = name
        self.emoji = emoji
        self.colorHex = colorHex
        self.logoAsset = logoAsset
        self.initialBalance = initialBalance
        self.sortIndex = sortIndex
        self.legacySourceRaw = legacySourceRaw
        self.createdAt = createdAt
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
        return initialBalance + outgoing + incoming
    }
}
