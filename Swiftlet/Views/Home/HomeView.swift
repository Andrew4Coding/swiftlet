//
//  HomeView.swift
//  Swiftlet
//

import SwiftData
import SwiftUI

struct HomeView: View {
    @Query(sort: \Transaction.date, order: .reverse) private var allTransactions: [Transaction]
    @Query(sort: [SortDescriptor(\Wallet.sortIndex), SortDescriptor(\Wallet.createdAt)]) private var allWallets: [Wallet]
    @Query(sort: \TransactionCategory.sortIndex) private var categories: [TransactionCategory]
    @Query(filter: #Predicate<RecurringTransaction> { $0.isActive }, sort: \RecurringTransaction.nextDueDate)
    private var upcomingRecurring: [RecurringTransaction]

    @State private var viewModel = HomeViewModel()
    @State private var isPresentingAdd = false
    @State private var isPresentingWalletEditor = false
    @State private var dismissedInsightIDs: Set<String> = []

    private var wallets: [Wallet] {
        allWallets.filter { !$0.isArchived }
    }

    private var visibleInsights: [SpendingInsight] {
        SpendingInsightEngine.insights(categories: categories, transactions: allTransactions)
            .filter { !dismissedInsightIDs.contains($0.id) && !InsightDismissals.isDismissed($0) }
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

                    ForEach(visibleInsights.prefix(2)) { insight in
                        InsightBanner(insight: insight) {
                            InsightDismissals.dismiss(insight)
                            _ = withAnimation(.snappy) { dismissedInsightIDs.insert(insight.id) }
                        }
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }

                    WalletCarousel(wallets: wallets) { isPresentingWalletEditor = true }

                    BudgetsCard(progress: BudgetCalculator.progress(for: categories, transactions: allTransactions))

                    UpcomingRecurringCard(rules: upcomingRecurring)

                    let purposeSlices = viewModel.purposeBreakdown(from: allTransactions)
                    if !purposeSlices.isEmpty {
                        PurposeBreakdownCard(slices: purposeSlices)
                    }

                    CategoryBreakdownChart(slices: viewModel.categoryBreakdown(from: allTransactions))

                    StatsSectionView(transactions: allTransactions, selectedPeriod: $viewModel.selectedPeriod)

                    RecentTransactionsSection(transactions: viewModel.recentTransactions(from: allTransactions))
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .background(SkyBackground())
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Add Transaction", systemImage: "plus") { isPresentingAdd = true }
                        .buttonStyle(.glassProminent)
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
