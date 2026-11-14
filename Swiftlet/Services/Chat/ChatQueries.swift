import Foundation

nonisolated enum ChatQueryError: LocalizedError {
    case invalidDate(String)

    var errorDescription: String? {
        switch self {
        case let .invalidDate(text): "“\(text)” is not a valid date. Use yyyy-MM-dd."
        }
    }
}

nonisolated struct ChatWindow: Equatable {
    var start: Date?
    var end: Date?

    func contains(_ date: Date) -> Bool {
        if let start, date < start { return false }
        if let end, date > end { return false }
        return true
    }
}

nonisolated enum ChatDates {
    static func parse(_ text: String, calendar: Calendar = .current) -> Date? {
        let parts = text.trimmingCharacters(in: .whitespaces).split(separator: "-", omittingEmptySubsequences: false)
        guard parts.count == 3,
              let year = Int(parts[0]), let month = Int(parts[1]), let day = Int(parts[2])
        else { return nil }
        let components = DateComponents(year: year, month: month, day: day)
        guard let date = calendar.date(from: components) else { return nil }
        let check = calendar.dateComponents([.year, .month, .day], from: date)
        guard check.year == year, check.month == month, check.day == day else { return nil }
        return date
    }

    static func window(from start: String?, to end: String?, calendar: Calendar = .current) throws -> ChatWindow {
        var window = ChatWindow()
        if let start = clean(start) {
            guard let date = parse(start, calendar: calendar) else { throw ChatQueryError.invalidDate(start) }
            window.start = date
        }
        if let end = clean(end) {
            guard let date = parse(end, calendar: calendar) else { throw ChatQueryError.invalidDate(end) }
            window.end = calendar.date(byAdding: .day, value: 1, to: date)?.addingTimeInterval(-1)
        }
        return window
    }

    static func format(_ date: Date, calendar: Calendar = .current) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    static func clean(_ text: String?) -> String? {
        guard let trimmed = text?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else { return nil }
        return trimmed
    }
}

nonisolated struct SpendingSummary: Equatable {
    var total: Int
    var count: Int
    var byCategory: [CategoryTotal]

    struct CategoryTotal: Equatable {
        var name: String
        var total: Int
    }
}

nonisolated struct OwedSummary: Equatable {
    var person: String
    var total: Int
    var bills: [String]
}

nonisolated enum ChatQueries {
    static let resultLimit = 10

    static func transactionType(from text: String?) -> TransactionType? {
        switch ChatDates.clean(text)?.lowercased() {
        case "expense", "expenses", "spending", "spent": .expense
        case "income", "earned", "earning": .income
        case "transfer", "transfers": .transfer
        default: nil
        }
    }

    static func summarize(
        _ transactions: [ChatTransaction],
        type: TransactionType,
        window: ChatWindow,
        category: String?,
        wallet: String?
    ) -> SpendingSummary {
        let matching = transactions.filter {
            $0.type == type && window.contains($0.date) && matches($0, category: category, wallet: wallet)
        }
        let grouped = Dictionary(grouping: matching, by: \.category)
            .map { SpendingSummary.CategoryTotal(name: $0.key, total: $0.value.reduce(0) { $0 + $1.amount }) }
            .sorted { ($1.total, $0.name) < ($0.total, $1.name) }
        return SpendingSummary(total: matching.reduce(0) { $0 + $1.amount }, count: matching.count, byCategory: grouped)
    }

    static func find(
        _ transactions: [ChatTransaction],
        query: String?,
        type: TransactionType?,
        category: String?,
        wallet: String?,
        minAmount: Int?,
        maxAmount: Int?,
        window: ChatWindow,
        limit: Int = resultLimit
    ) -> (rows: [ChatTransaction], totalMatches: Int) {
        let text = ChatDates.clean(query)
        let matching = transactions.filter { transaction in
            if let type, transaction.type != type { return false }
            if !window.contains(transaction.date) { return false }
            if !matches(transaction, category: category, wallet: wallet) { return false }
            if let minAmount, transaction.amount < minAmount { return false }
            if let maxAmount, transaction.amount > maxAmount { return false }
            if let text, !transaction.title.localizedCaseInsensitiveContains(text) { return false }
            return true
        }
        .sorted { $0.date > $1.date }
        return (Array(matching.prefix(limit)), matching.count)
    }

    static func owed(_ debts: [ChatDebt], person: String?) -> [OwedSummary] {
        let name = ChatDates.clean(person)
        let filtered = debts.filter { name == nil || $0.person.localizedCaseInsensitiveContains(name!) }
        return Dictionary(grouping: filtered, by: \.person)
            .map { entry in
                OwedSummary(
                    person: entry.key,
                    total: entry.value.reduce(0) { $0 + $1.amount },
                    bills: entry.value.sorted { $0.date > $1.date }.map(\.billTitle)
                )
            }
            .sorted { ($1.total, $0.person) < ($0.total, $1.person) }
    }

    static func upcoming(
        _ recurring: [ChatRecurring],
        withinDays days: Int?,
        now: Date = .now,
        calendar: Calendar = .current,
        limit: Int = resultLimit
    ) -> [ChatRecurring] {
        let horizon = days.flatMap { calendar.date(byAdding: .day, value: max($0, 0), to: now) }
        return recurring
            .filter { horizon == nil || $0.nextDue <= horizon! }
            .sorted { $0.nextDue < $1.nextDue }
            .prefix(limit)
            .map { $0 }
    }

    static func wallets(_ wallets: [ChatWallet], named name: String?) -> [ChatWallet] {
        guard let name = ChatDates.clean(name) else { return wallets }
        return wallets.filter { $0.name.localizedCaseInsensitiveContains(name) }
    }

    private static func matches(_ transaction: ChatTransaction, category: String?, wallet: String?) -> Bool {
        if let category = ChatDates.clean(category), !transaction.category.localizedCaseInsensitiveContains(category) {
            return false
        }
        if let wallet = ChatDates.clean(wallet), !transaction.wallet.localizedCaseInsensitiveContains(wallet) {
            return false
        }
        return true
    }
}
