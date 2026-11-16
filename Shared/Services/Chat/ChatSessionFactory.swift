import Foundation
import FoundationModels

nonisolated enum ChatSessionFactory {
    static func instructions(today: Date = .now, history: String = "") -> String {
        var text = """
        You are Ask Swiftlet, the assistant inside a personal-finance app. All money is in Indonesian Rupiah.
        Today is \(ChatDates.format(today)). Resolve words like today, this week, last month and this year into explicit yyyy-MM-dd dates before calling a tool.
        Answer only from tool results. Never guess or invent amounts, names or dates, and never do arithmetic yourself: quote the totals the tools return.
        If the tools return nothing useful, say you could not find that in the user's data.
        Reply in the same language as the user's latest message.
        Tools attach tables, charts and photos to your reply on their own. Never repeat table rows or chart values: write one or two short sentences with the key figure and anything that stands out.
        Put names, amounts and dates in **bold**. Dates in tool results are already formatted for the user, so copy them as they are. Write amounts like Rp 20.000.
        To show a receipt or bill photo call showReceipt.
        When asked what you can do, or what the user can do in the app, call appInfo. You can only read data; you cannot add, change or delete anything.
        """
        if !history.isEmpty {
            text += "\nEarlier in this conversation:\n\(history)"
        }
        return text
    }

    @MainActor
    static func make(source: ChatDataSource, history: String = "") -> LanguageModelSession {
        LanguageModelSession(
            tools: [
                SpendingSummaryTool(source: source),
                FindTransactionsTool(source: source),
                WalletBalanceTool(source: source),
                SplitDebtsTool(source: source),
                UpcomingRecurringTool(source: source),
                ReceiptTool(source: source),
                AppInfoTool(source: source),
            ],
            instructions: instructions(history: history)
        )
    }
}
