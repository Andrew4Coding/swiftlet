import Foundation
import SwiftData

/// Bulk edits from the Mac table. Each call is one undo step on the context's undo manager,
/// and wallet balances stay right because they are derived from the transactions.
enum BulkTransactionActions {
    @discardableResult
    static func setCategory(_ category: TransactionCategory, on transactions: [Transaction], context: ModelContext) -> Int {
        let eligible = transactions.filter { $0.type != .transfer && category.appliesTo.allows($0.type) }
        perform("Change Category", context: context) {
            for transaction in eligible {
                transaction.category = category
            }
        }
        return eligible.count
    }

    @discardableResult
    static func move(_ transactions: [Transaction], to wallet: Wallet, context: ModelContext) -> Int {
        let eligible = transactions.filter { $0.destinationWallet?.persistentModelID != wallet.persistentModelID }
        perform("Move to Wallet", context: context) {
            for transaction in eligible {
                transaction.wallet = wallet
            }
        }
        return eligible.count
    }

    static func delete(_ transactions: [Transaction], context: ModelContext) {
        perform(transactions.count == 1 ? "Delete Transaction" : "Delete Transactions", context: context) {
            for transaction in transactions {
                context.delete(transaction)
            }
        }
    }

    private static func perform(_ actionName: String, context: ModelContext, changes: () -> Void) {
        let undoManager = context.undoManager
        undoManager?.beginUndoGrouping()
        changes()
        try? context.save()
        undoManager?.endUndoGrouping()
        undoManager?.setActionName(actionName)
    }
}
