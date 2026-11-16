//
//  DateRangeProvider.swift
//  Swiftlet
//

import Foundation

/// Period presets shared by Home's summary and the Transactions filter bar.
enum PeriodOption: String, CaseIterable, Identifiable {
    case today
    case thisWeek
    case thisMonth
    case all
    case custom

    var id: String {
        rawValue
    }

    var displayName: String {
        switch self {
        case .today: "Today"
        case .thisWeek: "This Week"
        case .thisMonth: "This Month"
        case .all: "All"
        case .custom: "Custom"
        }
    }
}

/// Granularity used to bucket transactions for the bar chart.
enum StatsPeriod: String, CaseIterable, Identifiable {
    case day
    case week
    case month
    case custom

    var id: String {
        rawValue
    }

    var displayName: String {
        switch self {
        case .day: "Day"
        case .week: "Week"
        case .month: "Month"
        case .custom: "Custom"
        }
    }
}

enum DateRangeProvider {
    /// Resolves a `PeriodOption` to a concrete date range, `nil` meaning "no bound" (used by `.all`).
    static func range(for option: PeriodOption, customRange: ClosedRange<Date>?, calendar: Calendar = .current) -> ClosedRange<Date>? {
        let now = Date.now
        switch option {
        case .today:
            let start = calendar.startOfDay(for: now)
            let end = calendar.date(byAdding: .day, value: 1, to: start)!.addingTimeInterval(-1)
            return start ... end
        case .thisWeek:
            guard let interval = calendar.dateInterval(of: .weekOfYear, for: now) else { return nil }
            return interval.start ... interval.end.addingTimeInterval(-1)
        case .thisMonth:
            guard let interval = calendar.dateInterval(of: .month, for: now) else { return nil }
            return interval.start ... interval.end.addingTimeInterval(-1)
        case .all:
            return nil
        case .custom:
            return customRange
        }
    }

    /// The equally long period immediately before `option`, for "vs last month"-style comparisons.
    /// `nil` when the option has no natural predecessor.
    static func previousRange(for option: PeriodOption, calendar: Calendar = .current) -> ClosedRange<Date>? {
        let component: Calendar.Component
        switch option {
        case .today: component = .day
        case .thisWeek: component = .weekOfYear
        case .thisMonth: component = .month
        case .all, .custom: return nil
        }
        guard let current = range(for: option, customRange: nil, calendar: calendar),
              let start = calendar.date(byAdding: component, value: -1, to: current.lowerBound)
        else { return nil }
        return start ... current.lowerBound.addingTimeInterval(-1)
    }

    /// Resolves a `StatsPeriod` to the date range whose transactions should be bucketed.
    static func range(for period: StatsPeriod, customRange: ClosedRange<Date>?, calendar: Calendar = .current) -> ClosedRange<Date> {
        let now = Date.now
        switch period {
        case .day:
            let start = calendar.date(byAdding: .day, value: -6, to: calendar.startOfDay(for: now))!
            let end = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now))!.addingTimeInterval(-1)
            return start ... end
        case .week:
            let interval = calendar.dateInterval(of: .weekOfYear, for: now)!
            return interval.start ... interval.end.addingTimeInterval(-1)
        case .month:
            let interval = calendar.dateInterval(of: .month, for: now)!
            return interval.start ... interval.end.addingTimeInterval(-1)
        case .custom:
            return customRange ?? (calendar.startOfDay(for: now) ... now)
        }
    }
}
