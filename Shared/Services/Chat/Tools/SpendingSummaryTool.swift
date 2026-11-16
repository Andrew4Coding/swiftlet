import Foundation
import FoundationModels

nonisolated struct SpendingSummaryTool: Tool {
    let name = "spendingSummary"
    let description = "Total spent or earned in a date range, optionally for one category or wallet, with a breakdown and the 3 largest transactions with date, category and title."

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
        @Guide(description: "How to break the total down: category, day or wallet. Defaults to category. Use day when asked about dates.")
        var groupBy: String?
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
            snapshot.transactions,
            type: type,
            window: window,
            category: arguments.category,
            wallet: arguments.wallet,
            grouping: ChatGrouping(arguments.groupBy)
        )
        let text = ChatReport.spending(summary, type: type, window: window, category: arguments.category, wallet: arguments.wallet)
        guard summary.count > 0 else { return text }
        await source.attach([
            ChatBlocks.spendingChart(summary, type: type),
            ChatBlocks.transactions(summary.largest, title: "Largest"),
        ])
        return text + "\n" + ChatReport.attachedHint
    }
}
