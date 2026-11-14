//
//  TransactionsListView.swift
//  Swiftlet
//

import SwiftData
import SwiftUI

struct TransactionsListView: View {
    @Query(sort: \Transaction.date, order: .reverse) private var allTransactions: [Transaction]
    @Environment(\.modelContext) private var modelContext

    @State private var viewModel = TransactionsListViewModel()
    @State private var editingTransaction: Transaction?
    @State private var isPresentingAdd = false

    private var filteredTransactions: [Transaction] {
        viewModel.filtered(allTransactions)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                TransactionFilterBar(selectedPeriod: $viewModel.selectedPeriod, customRange: $viewModel.customRange)
                    .padding(.vertical, 8)

                List {
                    ForEach(filteredTransactions, id: \.persistentModelID) { transaction in
                        NavigationLink {
                            TransactionDetailView(transaction: transaction)
                        } label: {
                            TransactionRowView(transaction: transaction)
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                modelContext.delete(transaction)
                                try? modelContext.save()
                            } label: {
                                Label("Delete", systemImage: "trash")
                                    .labelStyle(.iconOnly)
                            }
                            .tint(.red)

                            Button {
                                editingTransaction = transaction
                            } label: {
                                Image.swipeIcon("pencil")
                            }
                            .accessibilityLabel("Edit")
                            .tint(Color.ds(.accentFill))
                        }
                    }
                    .onDelete(perform: delete)
                }
                .listStyle(.plain)
                .overlay {
                    if filteredTransactions.isEmpty {
                        EmptyStateView(
                            systemImage: "tray",
                            title: "No Transactions",
                            message: "Try a different date range or search term."
                        )
                    }
                }
            }
            .navigationTitle("Transactions")
            .searchable(text: $viewModel.searchText, prompt: "Search title, description, or category")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("PDF") {
                            viewModel.startPDFExport(transactions: filteredTransactions)
                        }
                        ForEach(TransactionExportFormat.allCases) { format in
                            Button(format.displayName) {
                                viewModel.startExport(format: format, transactions: filteredTransactions)
                            }
                        }
                    } label: {
                        Label("Export", systemImage: "square.and.arrow.up")
                    }
                }
                ToolbarAddButton(title: "Add Transaction") { isPresentingAdd = true }
            }
            .fileExporter(
                isPresented: $viewModel.isPresentingExporter,
                document: viewModel.exportDocument,
                contentType: viewModel.exportContentType,
                defaultFilename: "Transactions"
            ) { result in
                viewModel.handleExportResult(result)
            }
            .alert("Transactions", isPresented: $viewModel.isPresentingStatusAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.statusMessage ?? "")
            }
            .sheet(item: $editingTransaction) { transaction in
                AddTransactionView(transaction: transaction)
            }
            .sheet(isPresented: $isPresentingAdd) {
                AddTransactionView()
            }
        }
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(filteredTransactions[index])
        }
        try? modelContext.save()
    }
}

#Preview {
    TransactionsListView()
        .modelContainer(for: [Transaction.self, TransactionCategory.self], inMemory: true)
}
