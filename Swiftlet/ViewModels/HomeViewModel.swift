//
//  HomeViewModel.swift
//  Swiftlet
//

import Foundation
import Observation

struct CategorySlice: Identifiable {
    var name: String
    var amount: Decimal
    var fraction: Double
    var icon: TransactionCategory?

    var id: String {
        name
    }

    var colorHex: String {
        icon?.resolvedColorHex ?? "8E8E93"
    }
}

struct PurposeSlice: Identifiable {
    var purpose: CategoryPurpose?
    var amount: Decimal
    var fraction: Double

    var id: String {
        purpose?.rawValue ?? "unassigned"
    }
}

@Observable
final class HomeViewModel {
    var selectedPeriod: PeriodOption = .today
    var customRange: ClosedRange<Date>?

    private func periodTransactions(from transactions: [Transaction]) -> [Transaction] {
        guard let range = DateRangeProvider.range(for: selectedPeriod, customRange: customRange) else {
            return transactions
        }
        return transactions.filter { range.contains($0.date) }
    }

    func totalIncome(from transactions: [Transaction]) -> Decimal {
        sum(of: .income, in: periodTransactions(from: transactions))
    }

    func totalExpense(from transactions: [Transaction]) -> Decimal {
        sum(of: .expense, in: periodTransactions(from: transactions))
    }

    /// Fractional change versus the previous equally long period, or `nil` when there is nothing
    /// to compare against.
    func change(of type: TransactionType, from transactions: [Transaction]) -> Double? {
        guard let previousRange = DateRangeProvider.previousRange(for: selectedPeriod) else { return nil }
        let previous = sum(of: type, in: transactions.filter { previousRange.contains($0.date) })
        guard previous > 0 else { return nil }
        let current = sum(of: type, in: periodTransactions(from: transactions))
        return ((current - previous) as NSDecimalNumber).doubleValue / (previous as NSDecimalNumber).doubleValue
    }

    /// Spending split into Needs / Wants / Savings (plus unassigned) for the 50/30/20 card.
    func purposeBreakdown(from transactions: [Transaction]) -> [PurposeSlice] {
        let expenses = periodTransactions(from: transactions).filter { $0.type == .expense }
        let total = expenses.reduce(Decimal(0)) { $0 + $1.amount }
        guard total > 0 else { return [] }

        let grouped = Dictionary(grouping: expenses) { $0.category?.purpose }
        let order: [CategoryPurpose?] = CategoryPurpose.allCases + [nil]
        return order.compactMap { purpose in
            let amount = (grouped[purpose] ?? []).reduce(Decimal(0)) { $0 + $1.amount }
            guard amount > 0 || purpose != nil else { return nil }
            return PurposeSlice(
                purpose: purpose,
                amount: amount,
                fraction: (amount as NSDecimalNumber).doubleValue / (total as NSDecimalNumber).doubleValue
            )
        }
    }

    private func sum(of type: TransactionType, in transactions: [Transaction]) -> Decimal {
        transactions.filter { $0.type == type }.reduce(Decimal(0)) { $0 + $1.amount }
    }

    /// "Money left" — income minus expense for the currently selected period only.
    func balance(from transactions: [Transaction]) -> Decimal {
        totalIncome(from: transactions) - totalExpense(from: transactions)
    }

    /// Expense totals grouped by category for the selected period, largest first, with each
    /// slice's share of total spending.
    func categoryBreakdown(from transactions: [Transaction]) -> [CategorySlice] {
        let expenses = periodTransactions(from: transactions).filter { $0.type == .expense }
        let total = expenses.reduce(Decimal(0)) { $0 + $1.amount }
        guard total > 0 else { return [] }

        let grouped = Dictionary(grouping: expenses) { $0.category?.name ?? "Uncategorized" }
        return grouped.map { name, items in
            let amount = items.reduce(Decimal(0)) { $0 + $1.amount }
            return CategorySlice(
                name: name,
                amount: amount,
                fraction: (amount as NSDecimalNumber).doubleValue / (total as NSDecimalNumber).doubleValue,
                icon: items.first?.category
            )
        }
        .sorted { $0.amount > $1.amount }
    }

    func recentTransactions(from transactions: [Transaction], limit: Int = 5) -> [Transaction] {
        Array(transactions.sorted { $0.date > $1.date }.prefix(limit))
    }
}
