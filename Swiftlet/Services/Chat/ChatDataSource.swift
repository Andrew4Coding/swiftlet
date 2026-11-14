import Foundation
import SwiftData

@MainActor
final class ChatDataSource {
    private let context: ModelContext

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
                date: transaction.date
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

        return ChatSnapshot(transactions: transactions, wallets: wallets, debts: debts, recurring: recurring)
    }

    private static func whole(_ amount: Decimal) -> Int {
        NSDecimalNumber(decimal: amount).intValue
    }
}
