//
//  RecentTransactionsSection.swift
//  Swiftlet
//

import SwiftData
import SwiftUI

struct RecentTransactionsSection: View {
    let transactions: [Transaction]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Transactions")
                .font(.headline)

            if transactions.isEmpty {
                Text("No transactions yet — tap + to add one.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 24)
            } else {
                VStack(spacing: 0) {
                    ForEach(transactions, id: \.persistentModelID) { transaction in
                        NavigationLink {
                            TransactionDetailView(transaction: transaction)
                        } label: {
                            TransactionRowView(transaction: transaction)
                        }
                        .buttonStyle(.plain)
                        if transaction.persistentModelID != transactions.last?.persistentModelID {
                            Divider()
                        }
                    }
                }
            }
        }
        .card()
    }
}
