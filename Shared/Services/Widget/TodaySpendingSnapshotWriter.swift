//
//  TodaySpendingSnapshotWriter.swift
//  Swiftlet
//

import Foundation
import SwiftData
import WidgetKit

/// Recomputes the widget's today-spending snapshot from the live store and asks WidgetKit to reload.
enum TodaySpendingSnapshotWriter {
    @MainActor
    static func rebuild(using context: ModelContext) {
        let transactions = (try? context.fetch(FetchDescriptor<Transaction>())) ?? []

        let viewModel = HomeViewModel()
        viewModel.selectedPeriod = .today

        let slices = viewModel.categoryBreakdown(from: transactions).map { slice in
            TodaySpendingSnapshot.Slice(name: slice.name, amount: slice.amount, fraction: slice.fraction)
        }

        TodaySpendingSnapshot(
            generatedAt: .now,
            totalExpense: viewModel.totalExpense(from: transactions),
            slices: slices
        )
        .save()

        WidgetCenter.shared.reloadTimelines(ofKind: SwiftletWidgetKind.todaySpending)
    }
}
