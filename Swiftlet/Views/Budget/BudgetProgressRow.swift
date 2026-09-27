//
//  BudgetProgressRow.swift
//  Swiftlet
//

import SwiftUI

struct BudgetProgressRow: View {
    let progress: BudgetProgress

    private var tint: Color {
        switch progress.status {
        case .onTrack: Color(hex: progress.category.resolvedColorHex)
        case .warning: Color(hex: "FF9500")
        case .over: AppTheme.expense
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            CategoryBadgeView(category: progress.category, size: 36)
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(progress.category.name)
                        .font(.subheadline.weight(.medium))
                    Spacer()
                    Text("\(CurrencyFormatter.rupiahCompact(progress.spent)) / \(CurrencyFormatter.rupiahCompact(progress.limit))")
                        .font(.caption.weight(.medium))
                        .monospacedDigit()
                        .foregroundStyle(progress.status == .over ? AppTheme.expense : .secondary)
                }
                ProgressView(value: min(progress.fraction, 1))
                    .tint(tint)
                Text(caption)
                    .font(.caption2)
                    .foregroundStyle(progress.status == .onTrack ? Color.secondary : tint)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var caption: String {
        switch progress.status {
        case .over: "\(CurrencyFormatter.rupiah(-progress.remaining)) over budget"
        case .warning, .onTrack: "\(CurrencyFormatter.rupiah(progress.remaining)) left this month"
        }
    }
}
