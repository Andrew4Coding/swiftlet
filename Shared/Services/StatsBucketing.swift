//
//  StatsBucketing.swift
//  Swiftlet
//

import Foundation

/// Shared aggregation algorithm used by both Home's mini chart and the full Stats screen,
/// so bucketing logic never has to be duplicated across ViewModels.
enum StatsBucketing {
    static func buckets(
        for period: StatsPeriod,
        customRange: ClosedRange<Date>?,
        transactions: [Transaction],
        calendar: Calendar = .current
    ) -> [StatBucket] {
        let range = DateRangeProvider.range(for: period, customRange: customRange, calendar: calendar)

        switch period {
        case .day:
            return dailyBuckets(range: range, transactions: transactions, dayLabelStyle: .weekdayShort, calendar: calendar)
        case .week:
            return dailyBuckets(range: range, transactions: transactions, dayLabelStyle: .weekdayShort, calendar: calendar)
        case .month:
            return dailyBuckets(range: range, transactions: transactions, dayLabelStyle: .dayOfMonth, calendar: calendar)
        case .custom:
            let days = calendar.dateComponents([.day], from: range.lowerBound, to: range.upperBound).day ?? 0
            return days > 31
                ? weeklyBuckets(range: range, transactions: transactions, calendar: calendar)
                : dailyBuckets(range: range, transactions: transactions, dayLabelStyle: .dayOfMonth, calendar: calendar)
        }
    }

    private enum DayLabelStyle {
        case weekdayShort
        case dayOfMonth
    }

    private static func dailyBuckets(
        range: ClosedRange<Date>,
        transactions: [Transaction],
        dayLabelStyle: DayLabelStyle,
        calendar: Calendar
    ) -> [StatBucket] {
        var buckets: [StatBucket] = []
        var cursor = calendar.startOfDay(for: range.lowerBound)
        let end = calendar.startOfDay(for: range.upperBound)

        let labelFormatter = DateFormatter()
        labelFormatter.calendar = calendar
        labelFormatter.dateFormat = dayLabelStyle == .weekdayShort ? "EEE" : "d"

        while cursor <= end {
            let dayStart = cursor
            let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart)!

            let dayTransactions = transactions.filter { $0.date >= dayStart && $0.date < dayEnd }
            let income = dayTransactions.filter { $0.type == .income }.reduce(Decimal(0)) { $0 + $1.amount }
            let expense = dayTransactions.filter { $0.type == .expense }.reduce(Decimal(0)) { $0 + $1.amount }

            buckets.append(StatBucket(label: labelFormatter.string(from: dayStart), date: dayStart, income: income, expense: expense))

            cursor = calendar.date(byAdding: .day, value: 1, to: cursor)!
        }

        return buckets
    }

    private static func weeklyBuckets(
        range: ClosedRange<Date>,
        transactions: [Transaction],
        calendar: Calendar
    ) -> [StatBucket] {
        var buckets: [StatBucket] = []
        var cursor = calendar.dateInterval(of: .weekOfYear, for: range.lowerBound)?.start ?? range.lowerBound
        let end = range.upperBound

        let labelFormatter = DateFormatter()
        labelFormatter.calendar = calendar
        labelFormatter.dateFormat = "d MMM"

        while cursor <= end {
            let weekStart = cursor
            let weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStart)!

            let weekTransactions = transactions.filter { $0.date >= weekStart && $0.date < weekEnd }
            let income = weekTransactions.filter { $0.type == .income }.reduce(Decimal(0)) { $0 + $1.amount }
            let expense = weekTransactions.filter { $0.type == .expense }.reduce(Decimal(0)) { $0 + $1.amount }

            buckets.append(StatBucket(label: labelFormatter.string(from: weekStart), date: weekStart, income: income, expense: expense))

            cursor = weekEnd
        }

        return buckets
    }
}
