//
//  SpendingInsightEngine.swift
//  Swiftlet
//

import Foundation
import SwiftData

struct SpendingInsight: Identifiable, Equatable {
    enum Kind: Equatable {
        case overBudget
        case nearBudget
        case spike
        case paceAhead
    }

    let id: String
    let kind: Kind
    let title: String
    let message: String
    let category: TransactionCategory?

    static func == (lhs: SpendingInsight, rhs: SpendingInsight) -> Bool {
        lhs.id == rhs.id
    }

    var symbolName: String {
        switch kind {
        case .overBudget: "exclamationmark.triangle.fill"
        case .nearBudget: "gauge.with.dots.needle.67percent"
        case .spike: "wand.and.sparkles"
        case .paceAhead: "speedometer"
        }
    }

    var colorHex: String {
        switch kind {
        case .overBudget: "FF3B30"
        case .nearBudget, .paceAhead: "FF9500"
        case .spike: "C644FC"
        }
    }
}

/// Rule-based insights computed on device. Deliberately deterministic (no model call) so the
/// banners are instant, explainable, and identical across launches.
enum SpendingInsightEngine {
    /// Last-7-days spend must beat the trailing weekly average by this factor to count as a spike.
    static let spikeFactor = 1.5
    static let spikeMinimum: Decimal = 50000
    static let historyWeeks = 8
    static let minimumHistoryWeeks = 3

    static func insights(
        categories: [TransactionCategory],
        transactions: [Transaction],
        now: Date = .now,
        calendar: Calendar = .current
    ) -> [SpendingInsight] {
        var results: [SpendingInsight] = []
        let dateKey = now.formatted(.iso8601.year().month())

        for progress in BudgetCalculator.progress(for: categories, transactions: transactions, in: BudgetCalculator.monthRange(containing: now)) {
            let name = progress.category.name
            switch progress.status {
            case .over:
                results.append(SpendingInsight(
                    id: "over-\(name)-\(dateKey)",
                    kind: .overBudget,
                    title: "\(name) budget exceeded",
                    message: "You're \(CurrencyFormatter.rupiah(-progress.remaining)) over this month's \(CurrencyFormatter.rupiah(progress.limit)) budget.",
                    category: progress.category
                ))
            case .warning:
                results.append(SpendingInsight(
                    id: "near-\(name)-\(dateKey)",
                    kind: .nearBudget,
                    title: "\(Int(progress.fraction * 100))% of \(name) budget used",
                    message: "\(CurrencyFormatter.rupiah(progress.remaining)) left for the rest of the month.",
                    category: progress.category
                ))
            case .onTrack:
                break
            }
        }

        results += spikes(categories: categories, transactions: transactions, now: now, calendar: calendar)

        if let pace = monthPace(transactions: transactions, now: now, calendar: calendar) {
            results.append(pace)
        }

        return results
    }

    private static func spikes(
        categories: [TransactionCategory],
        transactions: [Transaction],
        now: Date,
        calendar: Calendar
    ) -> [SpendingInsight] {
        let today = calendar.startOfDay(for: now)
        guard let recentStart = calendar.date(byAdding: .day, value: -6, to: today),
              let historyStart = calendar.date(byAdding: .weekOfYear, value: -historyWeeks, to: recentStart)
        else { return [] }

        let recentRange = recentStart ... now
        let historyRange = historyStart ... recentStart.addingTimeInterval(-1)

        let recent = BudgetCalculator.spending(in: recentRange, transactions: transactions)
        let history = BudgetCalculator.spending(in: historyRange, transactions: transactions)

        let expenses = transactions.filter { $0.type == .expense }
        guard let oldest = expenses.map(\.date).min(),
              let weeksOfHistory = calendar.dateComponents([.weekOfYear], from: oldest, to: recentStart).weekOfYear,
              weeksOfHistory >= minimumHistoryWeeks
        else { return [] }
        let weeks = Decimal(min(weeksOfHistory, historyWeeks))

        return categories.compactMap { category in
            let id = category.persistentModelID
            guard let recentSpend = recent[id], recentSpend >= spikeMinimum else { return nil }
            let weeklyAverage = (history[id] ?? 0) / weeks
            guard weeklyAverage > 0 else { return nil }
            let ratio = (recentSpend / weeklyAverage as NSDecimalNumber).doubleValue
            guard ratio >= spikeFactor else { return nil }

            let action = category.hasBudget ? "Want to review your \(category.name.lowercased()) budget?" : "Want to set a \(category.name.lowercased()) budget?"
            return SpendingInsight(
                id: "spike-\(category.name)-\(today.formatted(.iso8601.year().month().day()))",
                kind: .spike,
                title: "Spending spike detected",
                message: "\(category.name) is \(String(format: "%.1f", ratio))× your usual week. \(action)",
                category: category
            )
        }
    }

    /// Flags when this month's spending is running well ahead of last month at the same point.
    private static func monthPace(transactions: [Transaction], now: Date, calendar: Calendar) -> SpendingInsight? {
        let thisMonth = BudgetCalculator.monthRange(containing: now, calendar: calendar)
        guard let lastMonthDate = calendar.date(byAdding: .month, value: -1, to: now),
              let dayOfMonth = calendar.dateComponents([.day], from: thisMonth.lowerBound, to: now).day,
              dayOfMonth >= 7
        else { return nil }

        let lastMonth = BudgetCalculator.monthRange(containing: lastMonthDate, calendar: calendar)
        guard let lastMonthSameDay = calendar.date(byAdding: .day, value: dayOfMonth, to: lastMonth.lowerBound) else { return nil }

        let expenses = transactions.filter { $0.type == .expense }
        let current = expenses.filter { thisMonth.lowerBound ... now ~= $0.date }.reduce(Decimal(0)) { $0 + $1.amount }
        let previous = expenses.filter { lastMonth.lowerBound ... lastMonthSameDay ~= $0.date }.reduce(Decimal(0)) { $0 + $1.amount }

        guard previous > 0, current > previous * Decimal(1.25) else { return nil }
        let ratio = ((current - previous) / previous as NSDecimalNumber).doubleValue

        return SpendingInsight(
            id: "pace-\(now.formatted(.iso8601.year().month().day()))",
            kind: .paceAhead,
            title: "Spending ahead of last month",
            message: "You've spent \(Int(ratio * 100))% more than by this day last month.",
            category: nil
        )
    }
}
