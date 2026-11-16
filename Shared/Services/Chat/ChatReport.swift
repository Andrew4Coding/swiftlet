import Foundation

nonisolated enum ChatReport {
    static let attachedHint = "A table or chart with this data is attached to your reply. Do not repeat it; add one or two short sentences."

    static func rupiah(_ amount: Int) -> String {
        CurrencyFormatter.rupiah(Decimal(amount))
    }

    static func spending(
        _ summary: SpendingSummary,
        type: TransactionType,
        window: ChatWindow,
        category: String?,
        wallet: String?
    ) -> String {
        let scope = scopeText(window: window, category: category, wallet: wallet)
        guard summary.count > 0 else {
            return "No \(type.rawValue) transactions found\(scope)."
        }
        var lines = ["Total \(type.rawValue)\(scope): \(rupiah(summary.total)) across \(summary.count) transactions."]
        let showsGroups = summary.groups.count > 1 || summary.grouping == .day
        if showsGroups {
            let items = summary.groups.map { "\($0.date.map { ChatDates.display($0) } ?? $0.name) \(rupiah($0.total)) (\($0.count))" }
            lines.append("By \(summary.grouping.rawValue): " + items.joined(separator: "; ") + ".")
        }
        if !summary.largest.isEmpty {
            let items = summary.largest.map {
                "\(ChatDates.display($0.date)) \($0.title) [\($0.category)] \(rupiah($0.amount))"
            }
            lines.append("Largest: " + items.joined(separator: "; ") + ".")
        }
        return lines.joined(separator: "\n")
    }

    static func found(_ result: (rows: [ChatTransaction], totalMatches: Int)) -> String {
        guard !result.rows.isEmpty else { return "No matching transactions found." }
        var lines = result.rows.map {
            "\(ChatDates.display($0.date)) | \($0.title) | \($0.category) | \($0.wallet) | \($0.type.rawValue) \(rupiah($0.amount))"
        }
        if result.totalMatches > result.rows.count {
            lines.append("Showing the newest \(result.rows.count) of \(result.totalMatches) matches.")
        }
        return lines.joined(separator: "\n")
    }

    static func receipts(_ rows: [ChatTransaction]) -> String {
        let items = rows.map { "\(ChatDates.display($0.date)) \($0.title) \(rupiah($0.amount))" }
        return "Attached \(rows.count) receipt photo(s): " + items.joined(separator: "; ") + "."
    }

    static func balances(_ wallets: [ChatWallet]) -> String {
        guard !wallets.isEmpty else { return "No matching wallets found." }
        let lines = wallets.map { "\($0.name): \(rupiah($0.balance))" }
        guard wallets.count > 1 else { return lines[0] }
        return (lines + ["Combined: \(rupiah(wallets.reduce(0) { $0 + $1.balance }))"]).joined(separator: "\n")
    }

    static func owed(_ summaries: [OwedSummary]) -> String {
        guard !summaries.isEmpty else { return "Nobody owes you anything right now." }
        var lines = summaries.map { "\($0.person) owes \(rupiah($0.total)) for \($0.bills.joined(separator: ", "))" }
        lines.append("Total owed to you: \(rupiah(summaries.reduce(0) { $0 + $1.total })).")
        return lines.joined(separator: "\n")
    }

    static func upcoming(_ items: [ChatRecurring]) -> String {
        guard !items.isEmpty else { return "No upcoming recurring transactions found." }
        return items.map {
            "\(ChatDates.display($0.nextDue)) | \($0.title) | \($0.type.rawValue) \(rupiah($0.amount)) | \($0.frequency) | \($0.wallet)"
        }.joined(separator: "\n")
    }

    static func info(topic: String?, categories: [String], wallets: [ChatWallet]) -> String {
        switch ChatDates.clean(topic)?.lowercased() {
        case "categories":
            return categories.isEmpty ? "There are no categories yet." : "Categories: " + categories.joined(separator: ", ") + "."
        case "wallets":
            return wallets.isEmpty ? "There are no wallets yet." : "Wallets: " + wallets.map(\.name).joined(separator: ", ") + "."
        default:
            return capabilities
        }
    }

    static let capabilities = """
    I can answer from your data: spending and income totals by category, day or wallet for any period; individual transactions by title, category, wallet, amount or date; wallet balances; who still owes you from split bills; upcoming recurring bills; and show receipt or bill photos.
    In the app you can: add a transaction (plus button on Home), split a bill by photo or typed text (Splits tab), set up recurring transactions and subscriptions (Account, Recurring), manage wallets and categories (Account), import transactions (Account) and export them (Transactions tab).
    I only read your data, so I cannot add or change anything for you.
    """

    private static func scopeText(window: ChatWindow, category: String?, wallet: String?) -> String {
        var parts: [String] = []
        switch (window.start, window.end) {
        case let (start?, end?): parts.append("from \(ChatDates.display(start)) to \(ChatDates.display(end))")
        case let (start?, nil): parts.append("since \(ChatDates.display(start))")
        case let (nil, end?): parts.append("until \(ChatDates.display(end))")
        case (nil, nil): break
        }
        if let category = ChatDates.clean(category) { parts.append("in category \(category)") }
        if let wallet = ChatDates.clean(wallet) { parts.append("from wallet \(wallet)") }
        return parts.isEmpty ? "" : " " + parts.joined(separator: " ")
    }
}

nonisolated enum ChatHistorySummary {
    struct Turn: Equatable {
        var isUser: Bool
        var text: String
    }

    static func make(_ turns: [Turn], maxTurns: Int = 6, maxLength: Int = 160) -> String {
        let recent = turns.filter { !$0.text.isEmpty }.suffix(maxTurns)
        guard !recent.isEmpty else { return "" }
        return recent.map { turn in
            let text = turn.text.count > maxLength ? String(turn.text.prefix(maxLength)) + "…" : turn.text
            return (turn.isUser ? "User: " : "Assistant: ") + text.replacingOccurrences(of: "\n", with: " ")
        }.joined(separator: "\n")
    }
}
