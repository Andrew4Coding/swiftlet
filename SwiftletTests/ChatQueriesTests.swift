import Foundation
import Testing

@testable import Swiftlet

struct ChatQueriesTests {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Jakarta")!
        return calendar
    }()

    private func date(_ text: String) -> Date {
        ChatDates.parse(text, calendar: calendar)!.addingTimeInterval(12 * 3600)
    }

    private func transaction(
        _ title: String, _ amount: Int, _ day: String, category: String = "Food", wallet: String = "BCA",
        type: TransactionType = .expense
    ) -> ChatTransaction {
        ChatTransaction(type: type, title: title, category: category, wallet: wallet, amount: amount, date: date(day))
    }

    @Test func parsesValidDatesAndRejectsInvalidOnes() {
        #expect(ChatDates.parse("2026-11-14", calendar: calendar) != nil)
        #expect(ChatDates.parse("2026-02-31", calendar: calendar) == nil)
        #expect(ChatDates.parse("14/11/2026", calendar: calendar) == nil)
        #expect(ChatDates.parse("", calendar: calendar) == nil)
    }

    @Test func windowEndsAtTheEndOfTheLastDay() throws {
        let window = try ChatDates.window(from: "2026-10-01", to: "2026-10-31", calendar: calendar)
        #expect(window.contains(date("2026-10-31")))
        #expect(!window.contains(date("2026-11-01")))
        #expect(!window.contains(date("2026-09-30")))
    }

    @Test func windowThrowsOnABadDate() {
        #expect(throws: ChatQueryError.self) {
            try ChatDates.window(from: "yesterday", to: nil, calendar: calendar)
        }
    }

    @Test func summarizeSumsMatchingExpensesInWholeRupiah() throws {
        let data = [
            transaction("Nasi goreng", 25000, "2026-10-03"),
            transaction("Kopi", 30000, "2026-10-10"),
            transaction("Bensin", 100_000, "2026-10-12", category: "Transport"),
            transaction("Gaji", 5_000_000, "2026-10-25", category: "Salary", type: .income),
            transaction("Kopi lama", 40000, "2026-09-10"),
        ]
        let window = try ChatDates.window(from: "2026-10-01", to: "2026-10-31", calendar: calendar)

        let all = ChatQueries.summarize(data, type: .expense, window: window, category: nil, wallet: nil)
        #expect(all.total == 155_000)
        #expect(all.count == 3)
        #expect(all.groups.first == .init(name: "Transport", total: 100_000, count: 1))
        #expect(all.largest.first?.title == "Bensin")
        #expect(all.largest.count == 3)

        let food = ChatQueries.summarize(data, type: .expense, window: window, category: "food", wallet: nil)
        #expect(food.total == 55000)

        let income = ChatQueries.summarize(data, type: .income, window: window, category: nil, wallet: nil)
        #expect(income.total == 5_000_000)
    }

    @Test func summarizeGroupsByDayNewestFirst() {
        let data = [
            transaction("A", 10000, "2026-10-03"),
            transaction("B", 20000, "2026-10-03"),
            transaction("C", 5000, "2026-10-05"),
        ]
        let result = ChatQueries.summarize(
            data, type: .expense, window: ChatWindow(), category: nil, wallet: nil, grouping: .day
        )
        #expect(result.groups.map(\.name) == ["2026-10-05", "2026-10-03"])
        #expect(result.groups.last == .init(name: "2026-10-03", total: 30000, count: 2))
        let text = ChatReport.spending(result, type: .expense, window: ChatWindow(), category: nil, wallet: nil)
        #expect(text.contains("By day: 2026-10-05"))
        #expect(text.contains("Largest: 2026-10-03 B [Food]"))
    }

    @Test func groupingFallsBackToCategory() {
        #expect(ChatGrouping("DAY") == .day)
        #expect(ChatGrouping("wallet") == .wallet)
        #expect(ChatGrouping("nonsense") == .category)
        #expect(ChatGrouping(nil) == .category)
    }

    @Test func appInfoListsCapabilitiesCategoriesAndWallets() {
        let wallets = [ChatWallet(name: "BCA", balance: 1000)]
        #expect(ChatReport.info(topic: nil, categories: [], wallets: wallets).contains("I only read your data"))
        #expect(ChatReport.info(topic: "categories", categories: ["Food", "Transport"], wallets: wallets) == "Categories: Food, Transport.")
        #expect(ChatReport.info(topic: "wallets", categories: [], wallets: wallets) == "Wallets: BCA.")
    }

    @Test func summarizeFiltersByWallet() {
        let data = [
            transaction("A", 10000, "2026-10-03", wallet: "BCA"),
            transaction("B", 20000, "2026-10-04", wallet: "Cash"),
        ]
        let result = ChatQueries.summarize(data, type: .expense, window: ChatWindow(), category: nil, wallet: "cash")
        #expect(result.total == 20000)
    }

    @Test func findReturnsAtMostTenNewestFirst() {
        let data = (1 ... 15).map { transaction("Item \($0)", $0 * 1000, String(format: "2026-10-%02d", $0)) }
        let result = ChatQueries.find(
            data, query: nil, type: nil, category: nil, wallet: nil, minAmount: nil, maxAmount: nil, window: ChatWindow()
        )
        #expect(result.rows.count == 10)
        #expect(result.totalMatches == 15)
        #expect(result.rows.first?.title == "Item 15")
        #expect(result.rows.last?.title == "Item 6")
    }

    @Test func findFiltersByTitleAndAmount() {
        let data = [
            transaction("Kopi Kenangan", 30000, "2026-10-03"),
            transaction("Kopi susu", 18000, "2026-10-04"),
            transaction("Bensin", 100_000, "2026-10-05"),
        ]
        let result = ChatQueries.find(
            data, query: "kopi", type: nil, category: nil, wallet: nil, minAmount: 20000, maxAmount: nil, window: ChatWindow()
        )
        #expect(result.rows.map(\.title) == ["Kopi Kenangan"])
    }

    @Test func owedGroupsByPersonAndSortsByAmount() {
        let debts = [
            ChatDebt(person: "Budi", billTitle: "Dinner", amount: 50000, date: date("2026-10-01")),
            ChatDebt(person: "Sari", billTitle: "Dinner", amount: 80000, date: date("2026-10-01")),
            ChatDebt(person: "Budi", billTitle: "Lunch", amount: 40000, date: date("2026-10-05")),
        ]
        let result = ChatQueries.owed(debts, person: nil)
        #expect(result.map(\.person) == ["Budi", "Sari"])
        #expect(result.first?.total == 90000)
        #expect(result.first?.bills == ["Lunch", "Dinner"])
        #expect(ChatQueries.owed(debts, person: "sari").count == 1)
    }

    @Test func upcomingIsSoonestFirstAndRespectsTheHorizon() {
        let now = date("2026-11-01")
        let items = [
            ChatRecurring(title: "Later", amount: 1, type: .expense, frequency: "Monthly", nextDue: date("2026-12-20"), category: "", wallet: ""),
            ChatRecurring(title: "Soon", amount: 1, type: .expense, frequency: "Monthly", nextDue: date("2026-11-05"), category: "", wallet: ""),
        ]
        #expect(ChatQueries.upcoming(items, withinDays: nil, now: now, calendar: calendar).map(\.title) == ["Soon", "Later"])
        #expect(ChatQueries.upcoming(items, withinDays: 30, now: now, calendar: calendar).map(\.title) == ["Soon"])
    }

    @Test func reportsSayWhenNothingMatches() {
        let empty = SpendingSummary(total: 0, count: 0, grouping: .category, groups: [], largest: [])
        #expect(ChatReport.spending(empty, type: .expense, window: ChatWindow(), category: nil, wallet: nil).contains("No expense"))
        #expect(ChatReport.owed([]).contains("Nobody owes"))
    }

    @Test func historySummaryKeepsTheLatestTurnsAndTruncates() {
        let turns = (1 ... 10).map { ChatHistorySummary.Turn(isUser: $0.isMultiple(of: 2), text: String(repeating: "x", count: 300) + "\($0)") }
        let summary = ChatHistorySummary.make(turns, maxTurns: 4, maxLength: 20)
        let lines = summary.split(separator: "\n")
        #expect(lines.count == 4)
        #expect(lines.allSatisfy { $0.count < 40 })
        #expect(ChatHistorySummary.make([]).isEmpty)
    }

    @Test func transactionTypeAcceptsCommonWords() {
        #expect(ChatQueries.transactionType(from: "Spending") == .expense)
        #expect(ChatQueries.transactionType(from: "income") == .income)
        #expect(ChatQueries.transactionType(from: nil) == nil)
    }
}
