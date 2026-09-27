//
//  ListAllTodayIntent.swift
//  Swiftlet
//
//  Created by Andrew Devito Aryo on 03/09/26.
//

import AppIntents
import Foundation
import SwiftData

struct TodayTransactionsIntent: AppIntent {
    static var title: LocalizedStringResource = "Show Today's Transactions"
    static var description = IntentDescription("Lists every transaction recorded today.")
    static var openAppWhenRun = false

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog & ReturnsValue<[TransactionEntity]> {
        let context = Persistance.container.mainContext

        let startOfDay = Calendar.current.startOfDay(for: .now)
        let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)!

        let descriptor = FetchDescriptor<Transaction>(
            predicate: #Predicate { $0.date >= startOfDay && $0.date < endOfDay },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        let txs = try context.fetch(descriptor)
        let entities = txs.map(TransactionEntity.init)

        let list = entities
            .map { "\($0.title): \(CurrencyFormatter.rupiah($0.amount))" }
            .joined(separator: "\n")

        let total = txs.reduce(Decimal(0)) { total, transaction in
            switch transaction.type {
            case .income: total + transaction.amount
            case .expense: total - transaction.amount
            case .transfer: total
            }
        }

        let dialog: IntentDialog = entities.isEmpty
            ? "No transactions today."
            : "\(entities.count) transactions today, \(CurrencyFormatter.rupiah(total)). Transaction List: \(list)"

        return .result(value: entities, dialog: dialog)
    }
}
