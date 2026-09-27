//
//  TransactionRowView.swift
//  Swiftlet
//

import SwiftUI

/// Shared row: category logo, wallet chip, title, date, and signed amount.
struct TransactionRowView: View {
    let transaction: Transaction

    var body: some View {
        HStack(spacing: 12) {
            if transaction.type == .transfer {
                IconBadge(iconType: .system, iconValue: "arrow.left.arrow.right", colorHex: "8E8E93", size: 44)
            } else {
                CategoryBadgeView(category: transaction.category, size: 44)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(transaction.title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)

                HStack(spacing: 6) {
                    WalletChip(transaction: transaction)
                    Text(transaction.date.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Text(transaction.signedAmountText)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(transaction.type.amountColor)
                .monospacedDigit()
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(transaction.title), \(transaction.type == .transfer ? "Transfer" : transaction.category?.name ?? "Uncategorized"), \(transaction.walletDescription), \(CurrencyFormatter.rupiah(transaction.amount)), \(transaction.type.displayName)"
        )
    }
}

#Preview {
    let category = TransactionCategory(name: "Food", iconType: .system, iconValue: "fork.knife", isDefault: true)
    List {
        TransactionRowView(transaction: Transaction(type: .expense, title: "Lunch", amount: 45000, source: .grab, date: .now, description: "", category: category))
        TransactionRowView(transaction: Transaction(type: .income, title: "July Salary", amount: 5_000_000, source: .bca, date: .now, description: "", category: category))
    }
}
