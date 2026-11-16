import Foundation
import SwiftData

nonisolated struct ChatReceiptPhoto: Sendable {
    var id: PersistentIdentifier
    var data: Data
}

@MainActor
final class ChatDataSource {
    private let context: ModelContext
    private(set) var pendingBlocks: [ChatBlock] = []

    init(context: ModelContext) {
        self.context = context
    }

    func snapshot() -> ChatSnapshot {
        let transactions = ((try? context.fetch(FetchDescriptor<Transaction>())) ?? []).map { transaction in
            ChatTransaction(
                type: transaction.type,
                title: transaction.title,
                category: transaction.category?.name ?? "Uncategorised",
                wallet: transaction.walletName,
                amount: Self.whole(transaction.amount),
                date: transaction.date,
                id: transaction.persistentModelID
            )
        }

        let wallets = ((try? context.fetch(FetchDescriptor<Wallet>())) ?? [])
            .filter { !$0.isArchived }
            .sorted { $0.sortIndex < $1.sortIndex }
            .map { ChatWallet(name: $0.name, balance: Self.whole($0.balance)) }

        let debts = ((try? context.fetch(FetchDescriptor<SplitBill>())) ?? []).flatMap { bill in
            bill.othersShares.filter { $0.outstanding > 0 }.map {
                ChatDebt(person: $0.name, billTitle: bill.title, amount: $0.outstanding, date: bill.date)
            }
        }

        let recurring = ((try? context.fetch(FetchDescriptor<RecurringTransaction>())) ?? [])
            .filter(\.isActive)
            .map {
                ChatRecurring(
                    title: $0.title,
                    amount: Self.whole($0.amount),
                    type: $0.type,
                    frequency: $0.frequency.displayName,
                    nextDue: $0.nextDueDate,
                    category: $0.category?.name ?? "Uncategorised",
                    wallet: $0.wallet?.name ?? "No wallet"
                )
            }

        let categories = ((try? context.fetch(FetchDescriptor<TransactionCategory>())) ?? [])
            .sorted { ($0.sortIndex, $0.name) < ($1.sortIndex, $1.name) }
            .map(\.name)

        return ChatSnapshot(
            transactions: transactions, wallets: wallets, debts: debts, recurring: recurring, categories: categories
        )
    }

    func receiptPhotos(for ids: [PersistentIdentifier], limit: Int) -> [ChatReceiptPhoto] {
        var photos: [ChatReceiptPhoto] = []
        for id in ids where photos.count < limit {
            guard let transaction = context.model(for: id) as? Transaction,
                  let data = transaction.splitBill?.receiptData ?? transaction.receiptImageData
            else { continue }
            photos.append(ChatReceiptPhoto(id: id, data: data))
        }
        return photos
    }

    func attach(_ blocks: [ChatBlock?]) {
        pendingBlocks.append(contentsOf: blocks.compactMap { $0 })
    }

    func takeBlocks() -> [ChatBlock] {
        defer { pendingBlocks = [] }
        return pendingBlocks
    }

    private static func whole(_ amount: Decimal) -> Int {
        NSDecimalNumber(decimal: amount).intValue
    }
}
