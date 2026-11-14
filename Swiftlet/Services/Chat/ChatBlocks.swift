import Foundation

nonisolated enum ChatBlocks {
    static func spendingChart(_ summary: SpendingSummary, type: TransactionType) -> ChatBlock? {
        guard summary.groups.count >= 2 else { return nil }
        let ordered = summary.grouping == .day ? summary.groups.reversed() : summary.groups
        let points = ordered.map { group in
            let label = group.date.map { ChatDates.shortDisplay($0) } ?? group.name
            return ChatChart.Point(label: label, value: group.total, valueText: ChatReport.rupiah(group.total))
        }
        let title = "\(type.displayName) by \(summary.grouping.rawValue)"
        return .chart(ChatChart(title: title, points: Array(points)))
    }

    static func transactions(_ rows: [ChatTransaction], title: String? = nil) -> ChatBlock? {
        guard !rows.isEmpty else { return nil }
        return .table(ChatTable(
            title: title,
            columns: [
                .init(title: "Date", isBold: true),
                .init(title: "Title", isBold: true, isFlexible: true),
                .init(title: "Category", isFlexible: true),
                .init(title: "Amount", isTrailing: true, isBold: true),
            ],
            rows: rows.map {
                .init(
                    cells: [ChatDates.display($0.date), $0.title, $0.category, ChatReport.rupiah($0.amount)],
                    transactionID: $0.id
                )
            }
        ))
    }

    static func upcoming(_ items: [ChatRecurring]) -> ChatBlock? {
        guard !items.isEmpty else { return nil }
        return .table(ChatTable(
            title: nil,
            columns: [
                .init(title: "Due", isBold: true),
                .init(title: "Bill", isBold: true, isFlexible: true),
                .init(title: "Repeats"),
                .init(title: "Amount", isTrailing: true, isBold: true),
            ],
            rows: items.map {
                .init(cells: [ChatDates.display($0.nextDue), $0.title, $0.frequency, ChatReport.rupiah($0.amount)])
            }
        ))
    }

    static func owed(_ summaries: [OwedSummary]) -> ChatBlock? {
        guard !summaries.isEmpty else { return nil }
        return .table(ChatTable(
            title: nil,
            columns: [
                .init(title: "Person", isBold: true, isFlexible: true),
                .init(title: "For", isFlexible: true),
                .init(title: "Owes", isTrailing: true, isBold: true),
            ],
            rows: summaries.map { .init(cells: [$0.person, $0.bills.joined(separator: ", "), ChatReport.rupiah($0.total)]) }
        ))
    }

    static func balances(_ wallets: [ChatWallet]) -> ChatBlock? {
        guard !wallets.isEmpty else { return nil }
        return .table(ChatTable(
            title: nil,
            columns: [.init(title: "Wallet", isBold: true, isFlexible: true), .init(title: "Balance", isTrailing: true, isBold: true)],
            rows: wallets.map { .init(cells: [$0.name, ChatReport.rupiah($0.balance)]) }
        ))
    }
}

nonisolated enum ChatMarkdown {
    private static let amount = #/Rp\s?-?\d[\d.,]*/#
    private static let dayFirstDate = #/\d{1,2}\s[A-Z][a-z]{2,8}\.?\s\d{4}/#
    private static let monthFirstDate = #/[A-Z][a-z]{2,8}\.?\s\d{1,2},\s\d{4}/#

    static func attributed(_ text: String) -> AttributedString {
        var result = (try? AttributedString(
            markdown: text,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        )) ?? AttributedString(text)
        let plain = String(result.characters)
        let ranges = plain.ranges(of: amount) + plain.ranges(of: dayFirstDate) + plain.ranges(of: monthFirstDate)
        for range in ranges {
            guard let lower = AttributedString.Index(range.lowerBound, within: result),
                  let upper = AttributedString.Index(range.upperBound, within: result)
            else { continue }
            result[lower ..< upper].inlinePresentationIntent = .stronglyEmphasized
        }
        return result
    }
}
