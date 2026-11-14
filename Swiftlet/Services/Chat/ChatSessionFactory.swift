import Foundation
import FoundationModels

nonisolated enum ChatSessionFactory {
    static func instructions(today: Date = .now, history: String = "") -> String {
        var text = """
        You are Ask Swiftlet, the assistant inside a personal-finance app. The user is Indonesian and all money is in Indonesian Rupiah.
        Today is \(ChatDates.format(today)). Resolve words like today, this week, last month and this year into explicit yyyy-MM-dd dates before calling a tool.
        Answer only from tool results. Never guess or invent amounts, names or dates, and never do arithmetic yourself: quote the totals the tools return.
        If the tools return nothing useful, say you could not find that in the user's data.
        You can only read data. You cannot add, change or delete anything.
        Reply in the language the user wrote in, in one to three short sentences. Write amounts like Rp 20.000.
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
            ],
            instructions: instructions(history: history)
        )
    }
}
