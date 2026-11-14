import Foundation
import FoundationModels

nonisolated struct FindTransactionsTool: Tool {
    let name = "findTransactions"
    let description = "List individual transactions, newest first, at most 10, with date, title, category, wallet and amount. Filter by title text, category, wallet, amount or dates."

    let source: ChatDataSource

    @Generable
    nonisolated struct Arguments {
        @Guide(description: "Text the transaction title contains, such as coffee or Grab.")
        var query: String?
        @Guide(description: "expense, income or transfer. Omit for all types.")
        var type: String?
        @Guide(description: "Category name. Omit for all categories.")
        var category: String?
        @Guide(description: "Wallet name. Omit for all wallets.")
        var wallet: String?
        @Guide(description: "Smallest amount in whole rupiah.")
        var minAmount: Int?
        @Guide(description: "Largest amount in whole rupiah.")
        var maxAmount: Int?
        @Guide(description: "First day included, formatted yyyy-MM-dd.")
        var startDate: String?
        @Guide(description: "Last day included, formatted yyyy-MM-dd.")
        var endDate: String?
    }

    func call(arguments: Arguments) async throws -> String {
        let window: ChatWindow
        do {
            window = try ChatDates.window(from: arguments.startDate, to: arguments.endDate)
        } catch {
            return error.localizedDescription
        }
        let snapshot = await source.snapshot()
        let result = ChatQueries.find(
            snapshot.transactions,
            query: arguments.query,
            type: ChatQueries.transactionType(from: arguments.type),
            category: arguments.category,
            wallet: arguments.wallet,
            minAmount: arguments.minAmount,
            maxAmount: arguments.maxAmount,
            window: window
        )
        guard !result.rows.isEmpty else { return ChatReport.found(result) }
        await source.attach([ChatBlocks.transactions(result.rows)])
        return ChatReport.found(result) + "\n" + ChatReport.attachedHint
    }
}
