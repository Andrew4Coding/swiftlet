//
//  RootTabView.swift
//  Swiftlet
//

import SwiftData
import SwiftUI

private struct SharedReceipt: Identifiable {
    let id = UUID()
    let imageData: Data
}

struct RootTabView: View {
    @Binding var pendingReceiptImageData: Data?

    @State private var sharedReceipt: SharedReceipt?
    @State private var selection = 0

    var body: some View {
        TabView(selection: $selection) {
            Tab("Home", systemImage: "house.fill", value: 0) {
                HomeView()
            }

            Tab("Transactions", systemImage: "list.bullet", value: 1) {
                TransactionsListView()
            }

            Tab("Splits", systemImage: "person.2.fill", value: 2) {
                SplitBillsView()
            }

            Tab("Account", systemImage: "person.crop.circle", value: 3) {
                AccountView()
            }

            Tab("Ask", systemImage: "sparkles", value: 4, role: .search) {
                ChatView()
            }
        }
        .onChange(of: pendingReceiptImageData) { _, newValue in
            presentSharedTransactionIfNeeded(newValue)
        }
        .task {
            presentSharedTransactionIfNeeded(pendingReceiptImageData)
        }
        .sheet(item: $sharedReceipt) { receipt in
            AddTransactionView(receiptImageData: receipt.imageData)
        }
    }

    private func presentSharedTransactionIfNeeded(_ data: Data?) {
        guard let data else { return }
        pendingReceiptImageData = nil
        sharedReceipt = SharedReceipt(imageData: data)
    }
}

#Preview {
    RootTabView(pendingReceiptImageData: .constant(nil))
        .modelContainer(for: [Transaction.self, TransactionCategory.self], inMemory: true)
}
