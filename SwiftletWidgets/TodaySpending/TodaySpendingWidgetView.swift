//
//  TodaySpendingWidgetView.swift
//  SwiftletWidgets
//

import Charts
import SwiftUI
import WidgetKit

/// Widget-sized version of Home's "Spending by Category" donut: a compact ring plus a
/// capped legend that adapts to the medium / large families.
struct TodaySpendingWidgetView: View {
    //    Widget Size
    @Environment(\.widgetFamily) private var family
    let entry: TodaySpendingEntry

    private static let palette: [Color] = [
        .blue, .green, .orange, .purple, .pink, .teal, .red, .indigo, .brown, .mint,
    ]

    private var slices: [TodaySpendingSnapshot.Slice] { entry.snapshot.slices }
    private var legendLimit: Int { family == .systemLarge ? 7 : 3 }
    private var donutSize: CGFloat { family == .systemLarge ? 150 : 104 }

    var body: some View {
        if slices.isEmpty {
            emptyState
        } else {
            breakdown
        }
    }

    private var breakdown: some View {
        VStack(alignment: .leading, spacing: family == .systemLarge ? 14 : 8) {
            header

            HStack(alignment: .center, spacing: 16) {
                donut
                    .frame(width: donutSize, height: donutSize)
                legend
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text("Today's Spending")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
            Text(CurrencyFormatter.rupiah(entry.snapshot.totalExpense))
                .font(family == .systemLarge ? .title2 : .headline)
                .fontWeight(.bold)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
        }
    }

    private var donut: some View {
        Chart(Array(slices.enumerated()), id: \.element.id) { index, slice in
            SectorMark(
                angle: .value("Amount", slice.fraction),
                innerRadius: .ratio(0.62),
                angularInset: 1.5
            )
            .cornerRadius(3)
            .foregroundStyle(color(for: index))
        }
        .chartLegend(.hidden)
    }

    private var legend: some View {
        VStack(alignment: .leading, spacing: family == .systemLarge ? 7 : 5) {
            ForEach(Array(slices.prefix(legendLimit).enumerated()), id: \.element.id) { index, slice in
                HStack(spacing: 6) {
                    Circle()
                        .fill(color(for: index))
                        .frame(width: 8, height: 8)
                    Text(slice.name)
                        .font(.caption)
                        .lineLimit(1)
                    Spacer(minLength: 4)
                    Text(slice.fraction, format: .percent.precision(.fractionLength(0)))
                        .font(.caption.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            }

            if slices.count > legendLimit {
                Text("+\(slices.count - legendLimit) more")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "chart.pie")
                .font(.system(size: 30))
                .foregroundStyle(.secondary)
            Text("No Spending Yet Today")
                .font(.callout)
                .fontWeight(.semibold)
            Text("Add an expense to see how today breaks down.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func color(for index: Int) -> Color {
        Self.palette[index % Self.palette.count]
    }
}
