import Foundation
import Testing

@testable import Swiftlet

struct TransactionFilterTests {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Jakarta")!
        return calendar
    }()

    private func row(
        _ title: String,
        _ type: TransactionType = .expense,
        amount: Decimal = 10000,
        category: String? = "Food",
        wallet: String? = "BCA",
        destination: String? = nil,
        note: String = "",
        date: Date = .now
    ) -> TransactionFilter.Row {
        TransactionFilter.Row(
            title: title, note: note, categoryName: category, walletName: wallet,
            destinationWalletName: destination, type: type, amount: amount, date: date
        )
    }

    @Test func emptyFilterMatchesEverything() {
        let filter = TransactionFilter()
        #expect(filter.isEmpty)
        #expect(filter.matches(row("Lunch")))
        #expect(filter.matches(row("Salary", .income, category: nil, wallet: nil)))
    }

    @Test func searchLooksAtTitleNoteCategoryAndWallet() {
        var filter = TransactionFilter()
        filter.searchText = "kopi"
        #expect(filter.matches(row("Kopi Kenangan")))
        #expect(filter.matches(row("Snack", note: "kopi susu")))
        #expect(!filter.matches(row("Snack")))
        filter.searchText = "bca"
        #expect(filter.matches(row("Snack")))
    }

    @Test func typeCategoryAndWalletFiltersCombine() {
        var filter = TransactionFilter()
        filter.types = [.expense]
        filter.categoryNames = ["food"]
        filter.walletNames = ["GoPay"]
        #expect(!filter.matches(row("Lunch")))
        #expect(filter.matches(row("Lunch", wallet: "GoPay")))
        #expect(!filter.matches(row("Lunch", .income, wallet: "GoPay")))
        #expect(!filter.matches(row("Lunch", category: "Transport", wallet: "GoPay")))
    }

    @Test func walletFilterMatchesTransferDestination() {
        var filter = TransactionFilter()
        filter.walletNames = ["GoPay"]
        #expect(filter.matches(row("Top up", .transfer, category: nil, wallet: "BCA", destination: "GoPay")))
    }

    @Test func amountBoundsAreInclusive() {
        var filter = TransactionFilter()
        filter.minimumAmount = 10000
        filter.maximumAmount = 50000
        #expect(filter.matches(row("A", amount: 10000)))
        #expect(filter.matches(row("B", amount: 50000)))
        #expect(!filter.matches(row("C", amount: 9999)))
        #expect(!filter.matches(row("D", amount: 50001)))
    }

    @Test func customPeriodUsesStoredRange() {
        let start = calendar.date(from: DateComponents(year: 2026, month: 11, day: 1))!
        let end = calendar.date(from: DateComponents(year: 2026, month: 11, day: 10))!
        var filter = TransactionFilter()
        filter.period = .custom
        filter.customStart = start
        filter.customEnd = end
        #expect(filter.matches(row("In", date: start.addingTimeInterval(3600)), calendar: calendar))
        #expect(!filter.matches(row("Out", date: end.addingTimeInterval(3600)), calendar: calendar))
    }

    @Test func roundTripsThroughData() {
        var filter = TransactionFilter()
        filter.searchText = "grab"
        filter.period = .thisMonth
        filter.types = [.income, .expense]
        filter.categoryNames = ["Transport"]
        filter.minimumAmount = 5000
        #expect(TransactionFilter.decoded(from: filter.encoded()) == filter)
        #expect(TransactionFilter.decoded(from: Data("junk".utf8)) == TransactionFilter())
    }

    @Test func applyKeepsOrderOfMatchingItems() {
        var filter = TransactionFilter()
        filter.types = [.income]
        let rows = [row("A", .income), row("B"), row("C", .income)]
        #expect(filter.apply(to: rows) { $0 }.map(\.title) == ["A", "C"])
    }
}

struct DashboardSummaryTests {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Jakarta")!
        return calendar
    }()

    private func date(_ day: Int, hour: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 11, day: day, hour: hour))!
    }

    private func row(_ type: TransactionType, _ amount: Decimal, category: String?, wallet: String?, day: Int) -> TransactionFilter.Row {
        TransactionFilter.Row(
            title: "x", note: "", categoryName: category, walletName: wallet,
            destinationWalletName: nil, type: type, amount: amount, date: date(day)
        )
    }

    @Test func sumsIncomeExpenseAndGroups() {
        let summary = DashboardSummary(rows: [
            row(.expense, 25000, category: "Food", wallet: "BCA", day: 1),
            row(.expense, 15000, category: "Food", wallet: "GoPay", day: 1),
            row(.expense, 30000, category: "Transport", wallet: "GoPay", day: 2),
            row(.expense, 5000, category: nil, wallet: nil, day: 2),
            row(.income, 1_000_000, category: "Salary", wallet: "BCA", day: 2),
            row(.transfer, 50000, category: nil, wallet: "BCA", day: 2),
        ], calendar: calendar)

        #expect(summary.expense == 75000)
        #expect(summary.income == 1_000_000)
        #expect(summary.net == 925_000)
        #expect(summary.byCategory.map(\.name) == ["Food", "Transport", DashboardSummary.uncategorized])
        #expect(summary.byCategory.map(\.amount) == [40000, 30000, 5000])
        #expect(summary.byWallet.map(\.name) == ["GoPay", "BCA", DashboardSummary.noWallet])
        #expect(summary.byDay.map(\.expense) == [40000, 35000])
        #expect(summary.byDay.map(\.income) == [0, 1_000_000])
        #expect(summary.byCategory.reduce(0) { $0 + $1.amount } == summary.expense)
    }

    @Test func roundsDecimalAmountsToWholeRupiah() {
        #expect(DashboardSummary.rupiah(Decimal(string: "1500.5")!) == 1501)
        #expect(DashboardSummary.rupiah(Decimal(string: "1500.4")!) == 1500)
    }
}

struct TransactionCSVTests {
    @Test func parsesQuotedFieldsWithCommasQuotesAndNewlines() {
        let rows = TransactionIOService.parseCSVRows("a,\"b, c\",\"say \"\"hi\"\"\"\r\n\"line\none\",2\n")
        #expect(rows == [["a", "b, c", "say \"hi\""], ["line\none", "2"]])
    }

    @Test func decodesExportedColumns() throws {
        let csv = """
        type,title,amount,source,date,description,category,wallet,destinationWallet
        expense,"Nasi, goreng",25000,bca,2026-11-01T05:00:00Z,,Food,BCA,
        transfer,Top up,100000,bca,2026-11-02T05:00:00Z,note,,BCA,GoPay
        expense,Broken,1,bca,not-a-date,,,,
        """
        let records = try TransactionIOService.decodeCSV(Data(csv.utf8))
        #expect(records.count == 2)
        #expect(records[0].title == "Nasi, goreng")
        #expect(records[0].category == "Food")
        #expect(records[0].destinationWallet == nil)
        #expect(records[1].type == "transfer")
        #expect(records[1].destinationWallet == "GoPay")
        #expect(records[1].description == "note")
    }

    @Test func rejectsCSVWithoutRequiredColumns() {
        #expect(throws: TransactionIOService.ImportError.self) {
            try TransactionIOService.decodeCSV(Data("name,value\na,1\n".utf8))
        }
    }
}
