import Foundation

nonisolated struct TransactionFilter: Codable, Equatable, Hashable, Sendable {
    nonisolated struct Row: Equatable, Sendable {
        var title: String
        var note: String
        var categoryName: String?
        var walletName: String?
        var destinationWalletName: String?
        var type: TransactionType
        var amount: Decimal
        var date: Date
    }

    var searchText: String = ""
    var periodRaw: String = PeriodOption.all.rawValue
    var customStart: Date?
    var customEnd: Date?
    var typeRaws: [String] = []
    var categoryNames: [String] = []
    var walletNames: [String] = []
    var minimumAmount: Decimal?
    var maximumAmount: Decimal?

    var period: PeriodOption {
        get { PeriodOption(rawValue: periodRaw) ?? .all }
        set { periodRaw = newValue.rawValue }
    }

    var types: Set<TransactionType> {
        get { Set(typeRaws.compactMap(TransactionType.init(rawValue:))) }
        set { typeRaws = TransactionType.allCases.filter(newValue.contains).map(\.rawValue) }
    }

    var customRange: ClosedRange<Date>? {
        guard let customStart, let customEnd, customStart <= customEnd else { return nil }
        return customStart ... customEnd
    }

    var isEmpty: Bool {
        self == TransactionFilter()
    }

    func dateRange(calendar: Calendar = .current) -> ClosedRange<Date>? {
        DateRangeProvider.range(for: period, customRange: customRange, calendar: calendar)
    }

    func matches(_ row: Row, calendar: Calendar = .current) -> Bool {
        matches(row, range: dateRange(calendar: calendar))
    }

    func apply<T>(to items: [T], calendar: Calendar = .current, row: (T) -> Row) -> [T] {
        let range = dateRange(calendar: calendar)
        return items.filter { matches(row($0), range: range) }
    }

    private func matches(_ row: Row, range: ClosedRange<Date>?) -> Bool {
        if let range, !range.contains(row.date) {
            return false
        }
        if !typeRaws.isEmpty, !types.contains(row.type) {
            return false
        }
        if !categoryNames.isEmpty, !Self.contains(categoryNames, row.categoryName) {
            return false
        }
        if !walletNames.isEmpty,
           !Self.contains(walletNames, row.walletName),
           !Self.contains(walletNames, row.destinationWalletName)
        {
            return false
        }
        if let minimumAmount, row.amount < minimumAmount {
            return false
        }
        if let maximumAmount, row.amount > maximumAmount {
            return false
        }
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return true }
        return row.title.localizedStandardContains(query)
            || row.note.localizedStandardContains(query)
            || (row.categoryName?.localizedStandardContains(query) ?? false)
            || (row.walletName?.localizedStandardContains(query) ?? false)
    }

    private static func contains(_ names: [String], _ name: String?) -> Bool {
        guard let name else { return false }
        return names.contains { $0.caseInsensitiveCompare(name) == .orderedSame }
    }

    func encoded() -> Data {
        (try? JSONEncoder().encode(self)) ?? Data()
    }

    static func decoded(from data: Data) -> TransactionFilter {
        (try? JSONDecoder().decode(TransactionFilter.self, from: data)) ?? TransactionFilter()
    }
}

extension Transaction {
    var filterRow: TransactionFilter.Row {
        TransactionFilter.Row(
            title: title,
            note: transactionDescription,
            categoryName: category?.name,
            walletName: wallet?.name,
            destinationWalletName: destinationWallet?.name,
            type: type,
            amount: amount,
            date: date
        )
    }

    var categoryName: String {
        category?.name ?? ""
    }
}
