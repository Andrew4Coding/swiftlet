import Foundation

nonisolated struct DashboardSummary: Equatable, Sendable {
    nonisolated struct Slice: Equatable, Identifiable, Sendable {
        var name: String
        var amount: Int
        var id: String { name }
    }

    nonisolated struct DayTotal: Equatable, Identifiable, Sendable {
        var day: Date
        var expense: Int
        var income: Int
        var id: Date { day }
    }

    static let uncategorized = "Uncategorized"
    static let noWallet = "No wallet"

    var income: Int = 0
    var expense: Int = 0
    var byCategory: [Slice] = []
    var byWallet: [Slice] = []
    var byDay: [DayTotal] = []

    var net: Int {
        income - expense
    }

    init(rows: [TransactionFilter.Row], calendar: Calendar = .current) {
        var categories: [String: Int] = [:]
        var wallets: [String: Int] = [:]
        var days: [Date: DayTotal] = [:]

        for row in rows {
            let amount = Self.rupiah(row.amount)
            let day = calendar.startOfDay(for: row.date)
            switch row.type {
            case .expense:
                expense += amount
                categories[row.categoryName ?? Self.uncategorized, default: 0] += amount
                wallets[row.walletName ?? Self.noWallet, default: 0] += amount
                days[day, default: DayTotal(day: day, expense: 0, income: 0)].expense += amount
            case .income:
                income += amount
                days[day, default: DayTotal(day: day, expense: 0, income: 0)].income += amount
            case .transfer:
                continue
            }
        }

        byCategory = Self.sorted(categories)
        byWallet = Self.sorted(wallets)
        byDay = days.values.sorted { $0.day < $1.day }
    }

    static func rupiah(_ amount: Decimal) -> Int {
        var input = amount
        var rounded = Decimal()
        NSDecimalRound(&rounded, &input, 0, .plain)
        return NSDecimalNumber(decimal: rounded).intValue
    }

    private static func sorted(_ totals: [String: Int]) -> [Slice] {
        totals.map { Slice(name: $0.key, amount: $0.value) }
            .sorted { $0.amount == $1.amount ? $0.name < $1.name : $0.amount > $1.amount }
    }
}
