//
//  PurposeBreakdownCard.swift
//  Swiftlet
//

import SwiftUI

/// Actual Needs / Wants / Savings split against the 50/30/20 rule of thumb.
struct PurposeBreakdownCard: View {
    let slices: [PurposeSlice]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("50 / 30 / 20")
                    .font(.headline)
                Spacer()
                Text("Needs · Wants · Savings")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            GeometryReader { proxy in
                let visible = slices.filter { $0.amount > 0 }
                let spacing: CGFloat = 3
                let available = proxy.size.width - spacing * CGFloat(max(visible.count - 1, 0))
                HStack(spacing: spacing) {
                    ForEach(visible) { slice in
                        Capsule()
                            .fill(color(for: slice).gradient)
                            .frame(width: available * slice.fraction)
                    }
                }
            }
            .frame(height: 12)
            .accessibilityHidden(true)

            VStack(spacing: 10) {
                ForEach(slices) { slice in
                    row(for: slice)
                }
            }
        }
        .card()
    }

    private func row(for slice: PurposeSlice) -> some View {
        HStack(spacing: 10) {
            Circle()
                .fill(color(for: slice))
                .frame(width: 10, height: 10)
            Text(slice.purpose?.displayName ?? "Unassigned")
                .font(.subheadline)
            Spacer()
            Text(CurrencyFormatter.rupiahCompact(slice.amount))
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
            Text(slice.fraction, format: .percent.precision(.fractionLength(0)))
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
                .frame(minWidth: 44, alignment: .trailing)
            if let purpose = slice.purpose {
                targetBadge(actual: slice.fraction, purpose: purpose)
            } else {
                Color.clear.frame(width: 64, height: 1)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func targetBadge(actual: Double, purpose: CategoryPurpose) -> some View {
        // Savings under target is the problem; for needs and wants it's going over.
        let isOnTrack = purpose == .savings ? actual >= purpose.targetShare : actual <= purpose.targetShare
        return Text("of \(Int(purpose.targetShare * 100))%")
            .font(.caption2.weight(.semibold))
            .foregroundStyle(isOnTrack ? AppTheme.income : AppTheme.expense)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background((isOnTrack ? AppTheme.income : AppTheme.expense).opacity(0.12), in: Capsule())
            .frame(width: 64, alignment: .trailing)
    }

    private func color(for slice: PurposeSlice) -> Color {
        slice.purpose.map { Color(hex: $0.colorHex) } ?? Color(.systemGray3)
    }
}

#Preview {
    PurposeBreakdownCard(slices: [
        PurposeSlice(purpose: .needs, amount: 3_000_000, fraction: 0.55),
        PurposeSlice(purpose: .wants, amount: 1_500_000, fraction: 0.3),
        PurposeSlice(purpose: .savings, amount: 500_000, fraction: 0.1),
        PurposeSlice(purpose: nil, amount: 250_000, fraction: 0.05),
    ])
    .padding()
}
