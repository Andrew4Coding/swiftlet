//
//  BudgetCalculator.swift
//  Swiftlet
//

import Foundation
import SwiftData

struct BudgetProgress: Identifiable {
    let category: TransactionCategory
    let spent: Decimal
    let limit: Decimal

    var id: String {
        category.name
    }

    var fraction: Double {
        guard limit > 0 else { return 0 }
        return (spent as NSDecimalNumber).doubleValue / (limit as NSDecimalNumber).doubleValue
    }

    var remaining: Decimal {
        limit - spent
    }

    var status: Status {
        switch fraction {
        case 1...: .over
        case BudgetCalculator.warningThreshold...: .warning
        default: .onTrack
        }
    }

    enum Status {
        case onTrack, warning, over
    }
}

enum BudgetCalculator {
    static let warningThreshold = 0.8

    static func monthRange(containing date: Date = .now, calendar: Calendar = .current) -> ClosedRange<Date> {
        let interval = calendar.dateInterval(of: .month, for: date)!
        return interval.start ... interval.end.addingTimeInterval(-1)
    }

    static func progress(
        for categories: [TransactionCategory],
        transactions: [Transaction],
        in range: ClosedRange<Date> = monthRange()
    ) -> [BudgetProgress] {
        let spentByCategory = spending(in: range, transactions: transactions)
        return categories
            .filter(\.hasBudget)
            .map { category in
                BudgetProgress(
                    category: category,
                    spent: spentByCategory[category.persistentModelID] ?? 0,
                    limit: category.monthlyBudget
                )
            }
            .sorted { $0.fraction > $1.fraction }
    }

    static func progress(for category: TransactionCategory, transactions: [Transaction]) -> BudgetProgress? {
        progress(for: [category], transactions: transactions).first
    }

    static func spending(
        in range: ClosedRange<Date>,
        transactions: [Transaction]
    ) -> [TransactionCategory.ID: Decimal] {
        transactions
            .filter { $0.type == .expense && range.contains($0.date) }
            .reduce(into: [:]) { totals, transaction in
                guard let id = transaction.category?.persistentModelID else { return }
                totals[id, default: 0] += transaction.amount
            }
    }
}
