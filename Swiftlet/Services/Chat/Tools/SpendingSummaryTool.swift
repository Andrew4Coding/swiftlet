import Foundation
import FoundationModels

nonisolated struct SpendingSummaryTool: Tool {
    let name = "spendingSummary"
    let description = "Total money spent or earned in a date range, optionally for one category or wallet, with a breakdown by category. Use for questions about how much was spent or earned."

    let source: ChatDataSource

    @Generable
    nonisolated struct Arguments {
        @Guide(description: "expense or income. Defaults to expense.")
        var type: String?
        @Guide(description: "First day included, formatted yyyy-MM-dd. Omit for no lower bound.")
        var startDate: String?
        @Guide(description: "Last day included, formatted yyyy-MM-dd. Omit for no upper bound.")
        var endDate: String?
        @Guide(description: "Category name such as Food. Omit for all categories.")
        var category: String?
        @Guide(description: "Wallet name. Omit for all wallets.")
        var wallet: String?
    }

    func call(arguments: Arguments) async throws -> String {
        let window: ChatWindow
        do {
            window = try ChatDates.window(from: arguments.startDate, to: arguments.endDate)
        } catch {
            return error.localizedDescription
        }
        let type = ChatQueries.transactionType(from: arguments.type) ?? .expense
        let snapshot = await source.snapshot()
        let summary = ChatQueries.summarize(
            snapshot.transactions, type: type, window: window, category: arguments.category, wallet: arguments.wallet
        )
        return ChatReport.spending(summary, type: type, window: window, category: arguments.category, wallet: arguments.wallet)
    }
}
