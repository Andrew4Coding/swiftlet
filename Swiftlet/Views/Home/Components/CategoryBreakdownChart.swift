//
//  CategoryBreakdownChart.swift
//  Swiftlet
//

import Charts
import SwiftData
import SwiftUI

/// Donut chart breaking down expenses by category for the currently selected Home period,
/// with a legend showing each category's percentage share.
struct CategoryBreakdownChart: View {
    let slices: [CategorySlice]

    var body: some View {
        VStack(spacing: 16) {
            Text("Spending by Category")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            if slices.isEmpty {
                EmptyStateView(
                    systemImage: "chart.pie",
                    title: "No Spending Yet",
                    message: "Add some expenses to see how your spending breaks down."
                )
                .frame(maxWidth: .infinity)
                .padding(.top, 20)
            } else {
                Chart(slices) { slice in
                    SectorMark(
                        angle: .value("Amount", slice.fraction),
                        innerRadius: .ratio(0.6),
                        angularInset: 1.5
                    )
                    .cornerRadius(4)
                    .foregroundStyle(Color(hex: slice.colorHex).gradient)
                }
                .frame(height: 200)

                VStack(spacing: 8) {
                    ForEach(slices) { slice in
                        HStack(spacing: 10) {
                            CategoryBadgeView(category: slice.icon, size: 26)
                            Text(slice.name)
                                .font(.subheadline)
                                .lineLimit(1)
                            Spacer()
                            Text(CurrencyFormatter.rupiahCompact(slice.amount))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                            Text(slice.fraction, format: .percent.precision(.fractionLength(0)))
                                .font(.subheadline.weight(.semibold))
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .card()
    }
}

#Preview {
    CategoryBreakdownChart(slices: [
        CategorySlice(name: "Food", amount: 120_000, fraction: 0.6, icon: nil),
        CategorySlice(name: "Transport", amount: 80000, fraction: 0.4, icon: nil),
    ])
    .padding()
}
