import Foundation

nonisolated struct ChatTransaction: Sendable, Equatable {
    var type: TransactionType
    var title: String
    var category: String
    var wallet: String
    var amount: Int
    var date: Date
}

nonisolated struct ChatWallet: Sendable, Equatable {
    var name: String
    var balance: Int
}

nonisolated struct ChatDebt: Sendable, Equatable {
    var person: String
    var billTitle: String
    var amount: Int
    var date: Date
}

nonisolated struct ChatRecurring: Sendable, Equatable {
    var title: String
    var amount: Int
    var type: TransactionType
    var frequency: String
    var nextDue: Date
    var category: String
    var wallet: String
}

nonisolated struct ChatSnapshot: Sendable {
    var transactions: [ChatTransaction] = []
    var wallets: [ChatWallet] = []
    var debts: [ChatDebt] = []
    var recurring: [ChatRecurring] = []
}
