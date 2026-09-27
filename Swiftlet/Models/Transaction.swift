//
//  Transaction.swift
//  Swiftlet
//

import Foundation
import SwiftData

@Model
final class Transaction {
    var typeRaw: String = TransactionType.expense.rawValue
    var title: String = ""
    var amount: Decimal = 0
    var sourceRaw: String = MoneySource.bca.rawValue
    var date: Date = Date.now
    var transactionDescription: String = ""
    var createdAt: Date = Date.now

    @Attribute(.externalStorage)
    var receiptImageData: Data?

    var category: TransactionCategory?
    var wallet: Wallet?
    /// Receiving wallet; only set for `.transfer` transactions.
    var destinationWallet: Wallet?

    var type: TransactionType {
        get { TransactionType(rawValue: typeRaw) ?? .expense }
        set { typeRaw = newValue.rawValue }
    }

    var source: MoneySource {
        get { MoneySource(rawValue: sourceRaw) ?? .bca }
        set { sourceRaw = newValue.rawValue }
    }

    var walletName: String {
        wallet?.name ?? source.displayName
    }

    init(
        type: TransactionType,
        title: String,
        amount: Decimal,
        source: MoneySource,
        date: Date,
        description: String = "",
        category: TransactionCategory?,
        receiptImageData: Data? = nil,
        createdAt: Date = .now
    ) {
        typeRaw = type.rawValue
        self.title = title
        self.amount = amount
        sourceRaw = source.rawValue
        self.date = date
        transactionDescription = description
        self.category = category
        self.receiptImageData = receiptImageData
        self.createdAt = createdAt
    }
}
