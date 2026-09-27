//
//  StatsSectionView.swift
//  Swiftlet
//

import Charts
import SwiftData
import SwiftUI

/// Full statistics section (income/expense bar chart), embedded directly in Home.
struct StatsSectionView: View {
    let transactions: [Transaction]
    @Binding var selectedPeriod: PeriodOption

    @State private var viewModel = StatsViewModel()

    private var buckets: [StatBucket] {
        viewModel.buckets(from: transactions)
    }

    private var statsPeriod: StatsPeriod {
        switch selectedPeriod {
        case .today: .day
        case .thisWeek: .week
        case .thisMonth: .month
        case .all: .month
        case .custom: .month
        }
    }

    var body: some View {
        VStack(spacing: 16) {
            Text("Statistics")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            if buckets.allSatisfy({ $0.income == 0 && $0.expense == 0 }) {
                EmptyStateView(
                    systemImage: "chart.bar",
                    title: "No Data Yet",
                    message: "Add some transactions to see your spending trends."
                )
                .frame(maxWidth: .infinity)
                .padding(.top, 20)
            } else {
                Chart(buckets) { bucket in
                    BarMark(x: .value("Period", bucket.label), y: .value("Income", bucket.income))
                        .foregroundStyle(by: .value("Type", "Income"))
                        .position(by: .value("Type", "Income"))
                    BarMark(x: .value("Period", bucket.label), y: .value("Expense", bucket.expense))
                        .foregroundStyle(by: .value("Type", "Expense"))
                        .position(by: .value("Type", "Expense"))
                }
                .chartForegroundStyleScale(["Income": AppTheme.income.gradient, "Expense": AppTheme.expense.gradient])
                .chartLegend(position: .bottom, spacing: 8)
                .chartYAxis {
                    AxisMarks { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let decimal = value.as(Double.self) {
                                Text(CurrencyFormatter.rupiahCompact(Decimal(decimal)))
                            }
                        }
                    }
                }
                .frame(height: 220)
            }
        }
        .card()
    }

    private func summaryTile(title: String, amount: Decimal, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(CurrencyFormatter.rupiah(amount))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(tint)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.background, in: RoundedRectangle(cornerRadius: 14))
    }
}

#Preview {
    StatsSectionView(transactions: [], selectedPeriod: .constant(.thisMonth))
        .padding()
}
