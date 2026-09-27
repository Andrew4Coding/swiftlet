//
//  RecurringScheduler.swift
//  Swiftlet
//

import Foundation
import SwiftData

enum RecurringScheduler {
    /// Guards against a stale `nextDueDate` (e.g. a weekly rule untouched for years) creating an
    /// unbounded burst of transactions in one pass.
    static let maxOccurrencesPerRun = 60

    /// Creates the transactions for every occurrence that has come due, then advances each rule.
    /// Returns how many transactions were created.
    @MainActor
    @discardableResult
    static func materializeDue(context: ModelContext, now: Date = .now) -> Int {
        let rules = (try? context.fetch(FetchDescriptor<RecurringTransaction>())) ?? []
        var created = 0

        for rule in rules where rule.isActive && rule.amount > 0 {
            var occurrences = 0
            while rule.nextDueDate <= now, occurrences < maxOccurrencesPerRun {
                let dueDate = rule.nextDueDate
                // Another device may already have created this occurrence and synced it over.
                let alreadyExists = (rule.generatedTransactions ?? []).contains {
                    Calendar.current.isDate($0.date, inSameDayAs: dueDate)
                }
                if !alreadyExists {
                    insertTransaction(for: rule, on: dueDate, context: context)
                    created += 1
                }
                rule.nextDueDate = rule.occurrence(after: dueDate)
                occurrences += 1
            }
        }

        if created > 0 || context.hasChanges {
            try? context.save()
        }
        return created
    }

    @MainActor
    private static func insertTransaction(for rule: RecurringTransaction, on date: Date, context: ModelContext) {
        let transaction = Transaction(
            type: rule.type,
            title: rule.title,
            amount: rule.amount,
            source: .bca,
            date: date,
            description: rule.note,
            category: rule.category
        )
        transaction.wallet = rule.wallet ?? WalletMigrator.ensureDefaultWallet(context: context)
        transaction.recurringSource = rule
        context.insert(transaction)
    }
}
