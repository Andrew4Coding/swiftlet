//
//  StatsViewModel.swift
//  Swiftlet
//

import Foundation
import Observation

@Observable
final class StatsViewModel {
    var selectedPeriod: StatsPeriod = .week
    var customRange: ClosedRange<Date>?

    func buckets(from transactions: [Transaction]) -> [StatBucket] {
        StatsBucketing.buckets(for: selectedPeriod, customRange: customRange, transactions: transactions)
    }

    func totalIncome(_ buckets: [StatBucket]) -> Decimal {
        buckets.reduce(Decimal(0)) { $0 + $1.income }
    }

    func totalExpense(_ buckets: [StatBucket]) -> Decimal {
        buckets.reduce(Decimal(0)) { $0 + $1.expense }
    }
}
