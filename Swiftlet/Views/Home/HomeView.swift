//
//  HomeView.swift
//  Swiftlet
//

import SwiftData
import SwiftUI

struct HomeView: View {
    @Query(sort: \Transaction.date, order: .reverse) private var allTransactions: [Transaction]
    @Query(sort: [SortDescriptor(\Wallet.sortIndex), SortDescriptor(\Wallet.createdAt)]) private var allWallets: [Wallet]
    @Query(filter: #Predicate<RecurringTransaction> { $0.isActive }, sort: \RecurringTransaction.nextDueDate)
    private var upcomingRecurring: [RecurringTransaction]

    @State private var viewModel = HomeViewModel()
    @State private var isPresentingAdd = false
    @State private var isPresentingWalletEditor = false

    private var wallets: [Wallet] {
        allWallets.filter { !$0.isArchived }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    BalanceCard(
                        totalBalance: wallets.reduce(Decimal(0)) { $0 + $1.balance },
                        income: viewModel.totalIncome(from: allTransactions),
                        expense: viewModel.totalExpense(from: allTransactions),
                        incomeChange: viewModel.change(of: .income, from: allTransactions),
                        expenseChange: viewModel.change(of: .expense, from: allTransactions),
                        period: $viewModel.selectedPeriod
                    )

                    WalletCarousel(wallets: wallets) { isPresentingWalletEditor = true }

                    UpcomingRecurringCard(rules: upcomingRecurring)

                    CategoryBreakdownChart(slices: viewModel.categoryBreakdown(from: allTransactions))

                    StatsSectionView(transactions: allTransactions, selectedPeriod: $viewModel.selectedPeriod)

                    RecentTransactionsSection(transactions: viewModel.recentTransactions(from: allTransactions))
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .background(Color.ds(.canvas))
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    NavigationLink {
                        SplitBillsView()
                    } label: {
                        Label("Splits", systemImage: "person.2.fill")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Add Transaction", systemImage: "plus") { isPresentingAdd = true }
                        .buttonStyle(.glassProminent)
                        .tint(Color.ds(.accentFill))
                        .foregroundStyle(Color.ds(.onAccent))
                }
            }
            .sheet(isPresented: $isPresentingAdd) {
                AddTransactionView()
            }
            .sheet(isPresented: $isPresentingWalletEditor) {
                WalletEditorView()
            }
        }
    }
}

#Preview {
    HomeView()
        .modelContainer(for: [Transaction.self, TransactionCategory.self, Wallet.self], inMemory: true)
}
