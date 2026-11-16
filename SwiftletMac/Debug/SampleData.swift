#if DEBUG
import Foundation
import SwiftData

/// `-sampleData` launches against an in-memory store so screens can be checked without
/// touching the iCloud data. `-section <name>` opens a sidebar section.
enum SampleData {
    static var isEnabled: Bool {
        ProcessInfo.processInfo.arguments.contains("-sampleData")
    }

    static var initialSection: SidebarItem? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "-section"), index + 1 < arguments.count else { return nil }
        return SidebarItem.sections.first { $0.title.lowercased() == arguments[index + 1].lowercased() }
    }

    static func makeContainer() -> ModelContainer {
        let schema = Schema([
            Transaction.self, TransactionCategory.self, Wallet.self, RecurringTransaction.self,
            SplitBill.self, SplitItem.self, SplitShare.self, SplitPerson.self, SavedFilter.self,
        ])
        let container = try! ModelContainer(
            for: schema,
            configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)]
        )
        let context = container.mainContext
        CategorySeeder.seedIfNeeded(context: context)
        let categories = (try? context.fetch(FetchDescriptor<TransactionCategory>())) ?? []
        func category(_ name: String) -> TransactionCategory? {
            categories.first { $0.name == name }
        }

        let bca = Wallet(name: "BCA", symbolName: "building.columns.fill", colorHex: "0A84FF", initialBalance: 5_000_000, sortIndex: 0)
        let gopay = Wallet(name: "GoPay", symbolName: "iphone", colorHex: "00C7BE", initialBalance: 300_000, sortIndex: 1)
        let cash = Wallet(name: "Cash", symbolName: "banknote.fill", colorHex: "34C759", initialBalance: 200_000, sortIndex: 2)
        [bca, gopay, cash].forEach(context.insert)

        let calendar = Calendar.current
        let samples: [(Int, String, Int, String, Wallet, TransactionType)] = [
            (0, "Kopi Kenangan", 28000, "Food", gopay, .expense),
            (0, "GrabCar to office", 54000, "Transport", gopay, .expense),
            (1, "Nasi goreng", 25000, "Food", cash, .expense),
            (1, "Tokopedia order", 189_000, "Shopping", bca, .expense),
            (2, "PLN token", 200_000, "Bills", bca, .expense),
            (3, "Salary", 12_000_000, "Salary", bca, .income),
            (4, "Netflix", 186_000, "Entertainment", bca, .expense),
            (5, "Gojek ride", 32000, "Transport", gopay, .expense),
            (6, "Apotek K-24", 76000, "Health", cash, .expense),
            (8, "Indomaret", 143_500, "Shopping", gopay, .expense),
            (10, "Dinner with friends", 320_000, "Food", bca, .expense),
            (12, "Reksa dana", 1_000_000, "Savings", bca, .expense),
        ]
        for (daysAgo, title, amount, categoryName, wallet, type) in samples {
            let date = calendar.date(byAdding: .day, value: -daysAgo, to: .now) ?? .now
            let transaction = Transaction(
                type: type, title: title, amount: Decimal(amount), source: .bca, date: date,
                category: category(categoryName)
            )
            transaction.wallet = wallet
            context.insert(transaction)
        }
        let topUp = Transaction(type: .transfer, title: "Top up GoPay", amount: 250_000, source: .bca, date: .now, category: nil)
        topUp.wallet = bca
        topUp.destinationWallet = gopay
        context.insert(topUp)

        let dinner = Transaction(type: .expense, title: "Sushi Tei", amount: 150_000, source: .bca, date: .now, category: category("Food"))
        dinner.wallet = bca
        context.insert(dinner)
        let bill = SplitBill(title: "Sushi Tei", total: 450_000)
        bill.transaction = dinner
        context.insert(bill)
        for (index, (name, isMine)) in [("You", true), ("Rina", false), ("Budi", false)].enumerated() {
            let share = SplitShare(name: name, amount: 150_000, isMine: isMine, sortIndex: index)
            share.bill = bill
            context.insert(share)
        }

        let rule = RecurringTransaction(
            title: "Spotify", amount: 54990, type: .expense, frequency: .monthly,
            startDate: calendar.date(byAdding: .day, value: 5, to: .now) ?? .now,
            category: category("Entertainment"), wallet: bca
        )
        context.insert(rule)

        var filter = TransactionFilter()
        filter.categoryNames = ["Food"]
        filter.period = .thisMonth
        context.insert(SavedFilter(name: "Food this month", filter: filter))
        try? context.save()
        return container
    }
}
#endif
